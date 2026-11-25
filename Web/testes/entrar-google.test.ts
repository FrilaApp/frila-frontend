/**
 * "Entrar com Google" na web (OAuth do Supabase com PKCE, no servidor). Sem rede: o `fetch` é de mentira e o
 * `deste-ambiente` é simulado (a variável do Worker liga e desliga). Dados sintéticos.
 */
import { createHash } from "node:crypto";

import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createStaticHandler, createStaticRouter, RouterContextProvider, StaticRouterProvider } from "react-router";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import Entrar, { loader as entrarLoader } from "../app/rotas/entrar";
import { loader as inicioLoader } from "../app/rotas/entrar-google";
import { loader as retornoLoader } from "../app/rotas/entrar-google-retorno";
import { criarAuth } from "../app/servidor/auth";
import { googleLigado, verifierValido } from "../app/servidor/google";
import textoDoWrangler from "../wrangler.jsonc?raw";

const SUPABASE = "https://exemplo.supabase.co";
const SESSAO = { access_token: "acesso.sintetico.token", refresh_token: "renovacao-sintetica", token_type: "bearer", expires_in: 3600 };
const CODIGO = "codigo-sintetico-de-retorno";
const EMAIL = "pessoa.sintetica@example.com";

const mundo = vi.hoisted(() => ({
  ligado: true,
  pedidos: [] as { url: string; corpo: unknown }[],
  resposta: (): Response => Response.json({}),
}));

vi.mock("../app/servidor/deste-ambiente", async () => {
  const { criarAuth: criar } = await import("../app/servidor/auth");
  const auth = criar(
    { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" },
    {
      fetch: async (entrada, inicio) => {
        const pedido = new Request(entrada, inicio);
        mundo.pedidos.push({ url: pedido.url, corpo: await pedido.json().catch(() => null) });
        return mundo.resposta();
      },
    },
  );
  return {
    authDesteAmbiente: () => auth,
    emailsDeDemonstracao: () => new Set<string>(),
    googleLigadoNesteAmbiente: () => mundo.ligado,
  };
});

const logs = ["log", "info", "warn", "error", "debug"] as const;
let espioes: ReturnType<typeof vi.spyOn>[] = [];

beforeEach(() => {
  mundo.ligado = true;
  mundo.pedidos = [];
  mundo.resposta = () => Response.json(SESSAO);
  espioes = logs.map((nivel) => vi.spyOn(console, nivel).mockImplementation(() => undefined));
});
afterEach(() => {
  espioes.forEach((espiao) => espiao.mockRestore());
});

function argumentos(url: string, opcoes: { cookie?: string; comSessao?: boolean } = {}) {
  const context = new RouterContextProvider();
  if (opcoes.comSessao) context.set(contextoDaSessao, { acesso: "sintetico", usuarioId: "u1", email: EMAIL, visitante: null });
  const request = new Request(url, { headers: opcoes.cookie ? { Cookie: opcoes.cookie } : {} });
  return { request, context, params: {}, url: new URL(url), matches: [] } as never;
}

async function resposta(chamada: () => unknown): Promise<Response> {
  try {
    const res = await chamada();
    if (res instanceof Response) return res;
  } catch (lancado) {
    if (lancado instanceof Response) return lancado;
    throw lancado;
  }
  throw new Error("esperava um redirect");
}

const INICIO = "https://frilabr.com/app/entrar/google";
const RETORNO = "https://frilabr.com/app/entrar/google/retorno";
const iniciar = () => resposta(() => inicioLoader(argumentos(INICIO)));
const voltar = (consulta: string, opcoes?: { cookie?: string; comSessao?: boolean }) =>
  resposta(() => retornoLoader(argumentos(`${RETORNO}${consulta}`, opcoes)));

/** Faz o início e devolve o verifier gravado no cookie (e a resposta). */
async function comecar() {
  const res = await iniciar();
  const linha = res.headers.getSetCookie().find((c) => c.startsWith("__Host-frila-google="));
  const verifier = linha?.split(";")[0]?.split("=")[1] ?? "";
  return { res, linha: linha ?? "", verifier };
}

describe("início do Entrar com Google", () => {
  it("manda ao Supabase (provider google) com PKCE S256 e o retorno desta web", async () => {
    const { res, verifier } = await comecar();
    const destino = new URL(res.headers.get("Location") ?? "");
    expect(`${destino.origin}${destino.pathname}`).toBe(`${SUPABASE}/auth/v1/authorize`);
    expect(destino.searchParams.get("provider")).toBe("google");
    expect(destino.searchParams.get("redirect_to")).toBe(RETORNO);
    expect(destino.searchParams.get("code_challenge_method")).toBe("s256");
    // M1: sem PKCE (sem code_challenge) este teste falha.
    const desafio = destino.searchParams.get("code_challenge");
    expect(desafio).toBeTruthy();
    expect(desafio).toBe(createHash("sha256").update(verifier).digest("base64url"));
    expect(desafio).not.toBe(verifier);
    expect(verifierValido(verifier)).toBe(true);
    expect(res.headers.get("Cache-Control")).toBe("no-store");
  });

  it("o cookie do verifier é HttpOnly, Secure, SameSite=Lax, de 10 minutos e preso ao host", async () => {
    const { linha } = await comecar();
    // M3: cookie sem HttpOnly faz este teste falhar.
    expect(linha).toMatch(/^__Host-frila-google=[A-Za-z0-9\-._~]{43}; /);
    expect(linha).toContain("HttpOnly");
    expect(linha).toContain("Secure");
    expect(linha).toContain("SameSite=Lax");
    expect(linha).toContain("Max-Age=600");
    expect(linha).toContain("Path=/");
    expect(linha).not.toContain("Domain");
  });

  it("cada início gera um verifier novo", async () => {
    const a = await comecar();
    const b = await comecar();
    expect(a.verifier).not.toBe(b.verifier);
  });

  it("M2: sem a variável do Worker, recusa: volta a /entrar, sem cookie e sem ir ao Google", async () => {
    mundo.ligado = false;
    const res = await iniciar();
    expect(res.headers.get("Location")).toBe("/entrar");
    expect(res.headers.getSetCookie()).toEqual([]);
  });
});

describe("retorno do Entrar com Google", () => {
  it("troca o code com o verifier do cookie e grava a sessão pelos cookies de sempre", async () => {
    const { verifier } = await comecar();
    const res = await voltar(`?code=${CODIGO}`, { cookie: `__Host-frila-google=${verifier}` });
    expect(mundo.pedidos).toEqual([{ url: `${SUPABASE}/auth/v1/token?grant_type=pkce`, corpo: { auth_code: CODIGO, code_verifier: verifier } }]);
    expect(res.headers.get("Location")).toBe("/");
    const cookies = res.headers.getSetCookie();
    expect(cookies.find((c) => c.startsWith("__Host-frila-acesso=acesso.sintetico.token;"))).toBeTruthy();
    expect(cookies.find((c) => c.startsWith("__Host-frila-renovacao=renovacao-sintetica;"))).toBeTruthy();
    // o verifier é apagado
    expect(cookies.find((c) => c.startsWith("__Host-frila-google=;"))).toContain("Max-Age=0");
  });

  it("erro do Google volta a /entrar com mensagem fixa, sem repetir o que veio na URL, e apaga o verifier", async () => {
    const { verifier } = await comecar();
    const res = await voltar(`?error=server_error&error_description=falha+para+${EMAIL}`, { cookie: `__Host-frila-google=${verifier}` });
    expect(res.headers.get("Location")).toBe("/entrar?erro=google_falhou");
    expect(res.headers.getSetCookie().some((c) => c.startsWith("__Host-frila-google=;"))).toBe(true);
    expect(mundo.pedidos).toEqual([]);
  });

  it("cancelar no Google tem a sua mensagem", async () => {
    const { verifier } = await comecar();
    const res = await voltar("?error=access_denied", { cookie: `__Host-frila-google=${verifier}` });
    expect(res.headers.get("Location")).toBe("/entrar?erro=google_cancelado");
  });

  it.each([
    ["sem code", "", true],
    ["sem verifier", `?code=${CODIGO}`, false],
    ["verifier fora do formato", `?code=${CODIGO}`, "curto"],
    ["code gigante", `?code=${"x".repeat(600)}`, true],
  ])("%s: volta a /entrar sem chamar o Supabase", async (_nome, consulta, cookie) => {
    const { verifier } = await comecar();
    const valor = cookie === true ? verifier : cookie === false ? null : cookie;
    const res = await voltar(consulta, valor ? { cookie: `__Host-frila-google=${valor}` } : undefined);
    expect(res.headers.get("Location")).toBe("/entrar?erro=google_falhou");
    expect(res.headers.getSetCookie().filter((c) => c.includes("frila-acesso"))).toEqual([]);
    expect(mundo.pedidos).toEqual([]);
  });

  it.each([400, 401, 422, 429, 500])("troca recusada pelo Supabase (%i): volta a /entrar sem sessão", async (status) => {
    const { verifier } = await comecar();
    mundo.resposta = () => Response.json({ msg: `detalhe técnico com ${EMAIL}` }, { status });
    const res = await voltar(`?code=${CODIGO}`, { cookie: `__Host-frila-google=${verifier}` });
    expect(res.headers.get("Location")).toBe("/entrar?erro=google_falhou");
    expect(res.headers.getSetCookie().filter((c) => c.includes("frila-acesso") || c.includes("frila-renovacao"))).toEqual([]);
  });

  it("resposta de sessão incompleta não vira sessão", async () => {
    const { verifier } = await comecar();
    mundo.resposta = () => Response.json({ access_token: "so-o-acesso" });
    const res = await voltar(`?code=${CODIGO}`, { cookie: `__Host-frila-google=${verifier}` });
    expect(res.headers.get("Location")).toBe("/entrar?erro=google_falhou");
  });

  it("sem a variável do Worker, recusa sem trocar nada", async () => {
    const { verifier } = await comecar();
    mundo.ligado = false;
    const res = await voltar(`?code=${CODIGO}`, { cookie: `__Host-frila-google=${verifier}` });
    expect(res.headers.get("Location")).toBe("/entrar");
    expect(mundo.pedidos).toEqual([]);
    expect(res.headers.getSetCookie().filter((c) => c.includes("frila-acesso"))).toEqual([]);
  });

  it("quem já tem sessão vai para a raiz sem trocar o code", async () => {
    const { verifier } = await comecar();
    const res = await voltar(`?code=${CODIGO}`, { cookie: `__Host-frila-google=${verifier}`, comSessao: true });
    expect(res.headers.get("Location")).toBe("/");
    expect(mundo.pedidos).toEqual([]);
  });

  it("nunca loga token, code, verifier nem e-mail", async () => {
    const { verifier } = await comecar();
    await voltar(`?code=${CODIGO}`, { cookie: `__Host-frila-google=${verifier}` });
    mundo.resposta = () => Response.json({ msg: EMAIL }, { status: 400 });
    await voltar(`?code=${CODIGO}&error_description=${EMAIL}`, { cookie: `__Host-frila-google=${verifier}` });
    await voltar(`?code=${CODIGO}`, { cookie: `__Host-frila-google=${verifier}` });
    for (const espiao of espioes) expect(espiao).not.toHaveBeenCalled();
  });
});

describe("botão na tela de entrada", () => {
  async function tela(consulta = "") {
    const dados = await entrarLoader(argumentos(`https://frilabr.com/app/entrar${consulta}`));
    const handler = createStaticHandler([{ id: "entrar", path: "/", loader: () => dados, Component: () => createElement(Entrar, { loaderData: dados } as never) }]);
    const contexto = await handler.query(new Request("https://frilabr.com/"));
    if (contexto instanceof Response) throw contexto;
    const roteador = createStaticRouter(handler.dataRoutes, contexto);
    return renderToStaticMarkup(createElement(StaticRouterProvider, { router: roteador, context: contexto, hydrate: false }));
  }

  it("aparece com a variável e leva ao início do fluxo", async () => {
    const html = await tela();
    expect(html).toContain('href="/app/entrar/google"');
    expect(html).toContain("Entrar com o Google");
  });

  it("some sem a variável", async () => {
    mundo.ligado = false;
    const html = await tela();
    expect(html).not.toContain("/entrar/google");
    expect(html).not.toContain("Entrar com o Google");
  });

  it("mostra só as mensagens fixas do Google; o resto da URL é ignorado", async () => {
    expect(await tela("?erro=google_falhou")).toContain("Não deu para entrar com o Google");
    expect(await tela("?erro=google_cancelado")).toContain("foi cancelada");
    const html = await tela("?erro=%3Cscript%3Ealert(1)%3C/script%3E");
    expect(html).not.toContain("alert(1)");
    expect(html).not.toContain('role="alert"');
  });
});

describe("variável e troca no cliente do Auth", () => {
  it("só 'ligado' liga", () => {
    expect(googleLigado("ligado")).toBe(true);
    for (const valor of [undefined, "", "1", "true", "LIGADO", "desligado"]) expect(googleLigado(valor)).toBe(false);
  });

  it("a troca usa auth_code e code_verifier e só aceita sessão completa", async () => {
    const pedidos: Request[] = [];
    const auth = criarAuth(
      { url: SUPABASE, chavePublicavel: "sb_publishable_teste" },
      { fetch: async (entrada, inicio) => (pedidos.push(new Request(entrada, inicio)), Response.json(SESSAO)) },
    );
    expect(await auth.trocarCodigoPkce("c", "v".repeat(43))).toEqual({ ok: true, sessao: SESSAO });
    expect(pedidos[0]?.method).toBe("POST");
    expect(pedidos[0]?.headers.get("apikey")).toBe("sb_publishable_teste");
  });

  it("falha de rede vira indisponível, sem lançar", async () => {
    const auth = criarAuth({ url: SUPABASE, chavePublicavel: "sb_publishable_teste" }, { fetch: async () => Promise.reject(new Error("rede")) });
    expect(await auth.trocarCodigoPkce("c", "v".repeat(43))).toEqual({ ok: false, motivo: "indisponivel" });
  });
});

describe("configuração do Worker", () => {
  function semComentarios(texto: string): string {
    let saida = "";
    for (let i = 0, emTexto = false; i < texto.length; i++) {
      const c = texto[i] ?? "";
      if (emTexto) {
        saida += c;
        if (c === "\\") saida += texto[++i] ?? "";
        else if (c === '"') emTexto = false;
      } else if (c === '"') {
        emTexto = true;
        saida += c;
      } else if (c === "/" && texto[i + 1] === "/") {
        while (i < texto.length && texto[i] !== "\n") i++;
        saida += "\n";
      } else if (c === "/" && texto[i + 1] === "*") {
        i = texto.indexOf("*/", i + 2) + 1;
      } else saida += c;
    }
    return saida.replace(/,(\s*[}\]])/g, "$1");
  }
  const config = JSON.parse(semComentarios(textoDoWrangler)) as { vars?: Record<string, string>; env?: { producao?: { vars?: Record<string, string> } } };

  it("o dev liga e o Prod não tem a variável", () => {
    expect(config.vars?.GOOGLE_ENTRAR).toBe("ligado");
    expect(config.env?.producao?.vars).toBeDefined();
    expect(Object.keys(config.env?.producao?.vars ?? {})).not.toContain("GOOGLE_ENTRAR");
  });
});
