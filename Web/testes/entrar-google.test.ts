/**
 * "Entrar com Google" na web via Edge Function `autenticar-social` (PKCE S256 server-side + B-116).
 * Sem rede: `fetch` sintético e `deste-ambiente` simulado. Dados sintéticos.
 */
import { createHash } from "node:crypto";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createStaticHandler, createStaticRouter, RouterContextProvider, StaticRouterProvider } from "react-router";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import Entrar, { loader as entrarLoader } from "../app/rotas/entrar";
import { loader as appleInicioLoader } from "../app/rotas/entrar-apple";
import { loader as appleRetornoLoader } from "../app/rotas/entrar-apple-retorno";
import { loader as inicioLoader } from "../app/rotas/entrar-google";
import { loader as retornoLoader } from "../app/rotas/entrar-google-retorno";
import { criarAuth } from "../app/servidor/auth";
import { ehVerifierPkceValido, lerCookieTransacaoSocial } from "../app/servidor/social";
import textoDoWrangler from "../wrangler.jsonc?raw";

const SUPABASE = "https://exemplo.supabase.co";
const TX_ID = "44444444-4444-4444-8444-444444444444";
const SESSAO = {
  access_token: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyMjIyMjIyMi0yMjIyLTQyMjItODIyMi0yMjIyMjIyMjIyMjIiLCJleHAiOjE5MDAwMDAwMDB9.sig",
  refresh_token: "renovacao-sintetica",
  token_type: "bearer",
  expires_in: 3600,
};
const CODIGO = "codigo-sintetico-de-retorno";
const EMAIL = "pessoa.sintetica@example.com";

const mundo = vi.hoisted(() => ({
  googleLigado: true,
  appleLigado: true,
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
    googleLigadoNesteAmbiente: () => mundo.googleLigado,
    appleEntrarLigado: () => mundo.appleLigado,
    socialEntrarLigado: (provedor: "apple" | "google") =>
      provedor === "google" ? mundo.googleLigado : mundo.appleLigado,
  };
});

const logs = ["log", "info", "warn", "error", "debug"] as const;
let espioes: ReturnType<typeof vi.spyOn>[] = [];

beforeEach(() => {
  mundo.googleLigado = true;
  mundo.appleLigado = true;
  mundo.pedidos = [];
  mundo.resposta = () =>
    Response.json({
      transacao_id: TX_ID,
      url_autorizacao: `${SUPABASE}/auth/v1/authorize?provider=google&code_challenge_method=s256`,
      expira_em: "2026-11-26T21:10:00Z",
    });
  espioes = logs.map((nivel) => vi.spyOn(console, nivel).mockImplementation(() => undefined));
});

afterEach(() => {
  espioes.forEach((espiao) => espiao.mockRestore());
});

function argumentos(url: string, opcoes: { cookie?: string; comSessao?: boolean } = {}) {
  const context = new RouterContextProvider();
  if (opcoes.comSessao) {
    context.set(contextoDaSessao, { acesso: "sintetico", usuarioId: "u1", email: EMAIL, visitante: null });
  }
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
  throw new Error("esperava um redirect ou response");
}

const INICIO = "https://frilabr.com/app/entrar/google";
const RETORNO = "https://frilabr.com/app/entrar/google/retorno";
const iniciar = () => resposta(() => inicioLoader(argumentos(INICIO)));
const voltar = (consulta: string, opcoes?: { cookie?: string; comSessao?: boolean }) =>
  resposta(() => retornoLoader(argumentos(`${RETORNO}${consulta}`, opcoes)));

async function comecar() {
  const res = await iniciar();
  const linha = res.headers.getSetCookie().find((c) => c.startsWith("__Host-frila-google=")) ?? "";
  const cookiePar = linha.split(";")[0] ?? "";
  const [, valor = ""] = cookiePar.split("=");
  const [transacaoId = "", verifier = "", correlacao = ""] = valor.split(".");
  return { res, linha, cookiePar, transacaoId, verifier, correlacao };
}

describe("início do Entrar com Google (autenticar-social)", () => {
  it("chama POST /functions/v1/autenticar-social (iniciar_pkce) com PKCE S256 e tx no redirect_to", async () => {
    const { res, verifier, correlacao } = await comecar();
    expect(res.status).toBe(302);
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    expect(res.headers.get("Location")).toContain("provider=google");
    expect(ehVerifierPkceValido(verifier)).toBe(true);
    expect(correlacao.length).toBeGreaterThanOrEqual(16);

    const desafioEsperado = createHash("sha256").update(verifier).digest("base64url");
    expect(mundo.pedidos).toEqual([
      {
        url: `${SUPABASE}/functions/v1/autenticar-social`,
        corpo: {
          fluxo: "iniciar_pkce",
          provedor: "google",
          plataforma: "web",
          redirect_to: `${RETORNO}?tx=${correlacao}`,
          code_challenge: desafioEsperado,
        },
      },
    ]);
  });

  it("grava cookie __Host-frila-google HttpOnly, Secure, SameSite=Lax, de 10 minutos", async () => {
    const { linha } = await comecar();
    expect(linha).toMatch(/^__Host-frila-google=[0-9a-f-]+\.[A-Za-z0-9\-._~]{43}\.[A-Za-z0-9_-]{16,64}; /);
    expect(linha).toContain("HttpOnly");
    expect(linha).toContain("Secure");
    expect(linha).toContain("SameSite=Lax");
    expect(linha).toContain("Max-Age=600");
    expect(linha).toContain("Path=/");
    expect(linha).not.toContain("Domain");
  });

  it("cada início gera verifier e correlação novos", async () => {
    const a = await comecar();
    const b = await comecar();
    expect(a.verifier).not.toBe(b.verifier);
    expect(a.correlacao).not.toBe(b.correlacao);
  });

  it("com GOOGLE_ENTRAR desligado, recusa com 404 sem cookie e sem chamar backend", async () => {
    mundo.googleLigado = false;
    const res = await iniciar();
    expect(res.status).toBe(404);
    expect(res.headers.getSetCookie()).toEqual([]);
    expect(mundo.pedidos).toEqual([]);
  });
});

describe("retorno do Entrar com Google (autenticar-social + correlação)", () => {
  it("troca code + transacao_id + verifier via autenticar-social (acao: pkce) e grava sessão", async () => {
    const { cookiePar, transacaoId, verifier, correlacao } = await comecar();
    mundo.pedidos = [];
    mundo.resposta = () => Response.json({ sessao: SESSAO, provedor: "google", precisa_definir_senha: false });

    const res = await voltar(`?code=${CODIGO}&tx=${correlacao}`, { cookie: cookiePar });
    expect(mundo.pedidos).toEqual([
      {
        url: `${SUPABASE}/functions/v1/autenticar-social`,
        corpo: {
          fluxo: "pkce",
          provedor: "google",
          plataforma: "web",
          transacao_id: transacaoId,
          codigo: CODIGO,
          code_verifier: verifier,
        },
      },
    ]);
    expect(res.headers.get("Location")).toBe("/");
    const cookies = res.headers.getSetCookie();
    expect(cookies.find((c) => c.startsWith(`__Host-frila-acesso=${SESSAO.access_token};`))).toBeTruthy();
    expect(cookies.find((c) => c.startsWith("__Host-frila-renovacao=renovacao-sintetica;"))).toBeTruthy();
    expect(cookies.find((c) => c.startsWith("__Host-frila-google=;"))).toContain("Max-Age=0");
  });

  it("B-116: redireciona para /definir-senha?origem=pendente quando precisa_definir_senha=true", async () => {
    const { cookiePar, correlacao } = await comecar();
    mundo.resposta = () => Response.json({ sessao: SESSAO, provedor: "google", precisa_definir_senha: true });

    const res = await voltar(`?code=${CODIGO}&tx=${correlacao}`, { cookie: cookiePar });
    expect(res.headers.get("Location")).toBe("/definir-senha?origem=pendente");
  });

  it("negativo cross-provider: cookie da Apple não completa Google e cookie do Google não completa Apple", async () => {
    const { cookiePar: cookieGoogle, correlacao } = await comecar();
    mundo.pedidos = [];

    // Cookie Apple enviado no callback Google
    const cookieApple = `__Host-frila-apple=${TX_ID}.${"a".repeat(43)}.${correlacao}`;
    const resNoGoogle = await voltar(`?code=${CODIGO}&tx=${correlacao}`, { cookie: cookieApple });
    expect(resNoGoogle.headers.get("Location")).toBe("/entrar?erro=google_recusado");
    expect(resNoGoogle.headers.get("Set-Cookie")).toBeNull();
    expect(mundo.pedidos).toEqual([]);

    // Cookie Google enviado no callback Apple
    const resNoApple = await resposta(() =>
      appleRetornoLoader(
        argumentos(`https://frilabr.com/app/entrar/apple/retorno?code=${CODIGO}&tx=${correlacao}`, {
          cookie: cookieGoogle,
        }),
      ),
    );
    expect(resNoApple.headers.get("Location")).toBe("/entrar?erro=apple_recusado");
    expect(resNoApple.headers.get("Set-Cookie")).toBeNull();
    expect(mundo.pedidos).toEqual([]);
  });

  it("negativo correlação: code sem tx ou com tx divergente recusa sem apagar transação legítima", async () => {
    const { cookiePar } = await comecar();
    mundo.pedidos = [];

    const semTx = await voltar(`?code=${CODIGO}`, { cookie: cookiePar });
    expect(semTx.headers.get("Location")).toBe("/entrar?erro=google_recusado");
    expect(semTx.headers.get("Set-Cookie")).toBeNull();
    expect(mundo.pedidos).toEqual([]);

    const txDivergente = await voltar(`?code=${CODIGO}&tx=tx-forjado-1234567890`, { cookie: cookiePar });
    expect(txDivergente.headers.get("Location")).toBe("/entrar?erro=google_recusado");
    expect(txDivergente.headers.get("Set-Cookie")).toBeNull();
    expect(mundo.pedidos).toEqual([]);
  });

  it("negativo erro forjado: ?error=access_denied sem tx correspondente não apaga cookie ativo", async () => {
    const { cookiePar, correlacao } = await comecar();
    mundo.pedidos = [];

    const forjado = await voltar(`?error=access_denied`, { cookie: cookiePar });
    expect(forjado.headers.get("Location")).toBe("/entrar?erro=google_cancelado");
    expect(forjado.headers.get("Set-Cookie")).toBeNull();

    const legitimo = await voltar(`?error=access_denied&tx=${correlacao}`, { cookie: cookiePar });
    expect(legitimo.headers.get("Location")).toBe("/entrar?erro=google_cancelado");
    expect(legitimo.headers.getSetCookie().some((c) => c.startsWith("__Host-frila-google=;"))).toBe(true);
  });

  it("negativo replay (409/410): limpa cookie, não grava sessão e mapeia erro", async () => {
    const { cookiePar, correlacao } = await comecar();
    mundo.resposta = () => Response.json({ code: "conflito_identidade" }, { status: 409 });
    const res409 = await voltar(`?code=${CODIGO}&tx=${correlacao}`, { cookie: cookiePar });
    expect(res409.headers.get("Location")).toBe("/entrar?erro=conflito_identidade");
    expect(res409.headers.getSetCookie().some((c) => c.startsWith("__Host-frila-google=;"))).toBe(true);
    expect(res409.headers.getSetCookie().filter((c) => c.includes("frila-acesso"))).toEqual([]);

    mundo.resposta = () => Response.json({ code: "transacao_expirada" }, { status: 410 });
    const res410 = await voltar(`?code=${CODIGO}&tx=${correlacao}`, { cookie: cookiePar });
    expect(res410.headers.get("Location")).toBe("/entrar?erro=google_recusado");
    expect(res410.headers.getSetCookie().some((c) => c.startsWith("__Host-frila-google=;"))).toBe(true);
  });

  it("negativo indisponível (503/transporte): preserva cookie para nova tentativa e não grava sessão", async () => {
    const { cookiePar, correlacao } = await comecar();
    mundo.resposta = () => Response.json({ msg: `detalhe técnico ${EMAIL}` }, { status: 503 });
    const res503 = await voltar(`?code=${CODIGO}&tx=${correlacao}`, { cookie: cookiePar });
    expect(res503.headers.get("Location")).toBe("/entrar?erro=indisponivel");
    expect(res503.headers.get("Set-Cookie")).toBeNull();
  });

  it("quem já tem sessão vai para / sem trocar o code", async () => {
    const { cookiePar, correlacao } = await comecar();
    mundo.pedidos = [];
    const res = await voltar(`?code=${CODIGO}&tx=${correlacao}`, { cookie: cookiePar, comSessao: true });
    expect(res.headers.get("Location")).toBe("/");
    expect(mundo.pedidos).toEqual([]);
  });

  it("nunca loga token, code, verifier nem e-mail", async () => {
    const { cookiePar, correlacao } = await comecar();
    mundo.resposta = () => Response.json({ sessao: SESSAO, provedor: "google", precisa_definir_senha: false });
    await voltar(`?code=${CODIGO}&tx=${correlacao}`, { cookie: cookiePar });
    mundo.resposta = () => Response.json({ msg: EMAIL }, { status: 400 });
    await voltar(`?code=${CODIGO}&tx=${correlacao}&error_description=${EMAIL}`, { cookie: cookiePar });
    for (const espiao of espioes) expect(espiao).not.toHaveBeenCalled();
  });

  it("lerCookieTransacaoSocial rejeita cookie malformado", () => {
    const req = new Request(RETORNO, { headers: { Cookie: "__Host-frila-google=invalido" } });
    expect(lerCookieTransacaoSocial("google", req, true)).toEqual({ presente: true, transacao: null });
  });
});

describe("botão na tela de entrada e auth/wrangler", () => {
  async function tela(consulta = "") {
    const dados = await entrarLoader(argumentos(`https://frilabr.com/app/entrar${consulta}`));
    const handler = createStaticHandler([
      {
        id: "entrar",
        path: "/",
        loader: () => dados,
        Component: () => createElement(Entrar, { loaderData: dados } as never),
      },
    ]);
    const contexto = await handler.query(new Request("https://frilabr.com/"));
    if (contexto instanceof Response) throw contexto;
    const roteador = createStaticRouter(handler.dataRoutes, contexto);
    return renderToStaticMarkup(createElement(StaticRouterProvider, { router: roteador, context: contexto, hydrate: false }));
  }

  it("aparece com GOOGLE_ENTRAR=ligado e some quando desligado", async () => {
    const html = await tela();
    expect(html).toContain('href="/app/entrar/google"');
    expect(html).toContain("Entrar com o Google");
    expect(html).toContain("mesmo e-mail verificado");
    expect(html).toContain("Private Relay");

    mundo.googleLigado = false;
    mundo.appleLigado = false;
    const htmlSem = await tela();
    expect(htmlSem).not.toContain("/entrar/google");
    expect(htmlSem).not.toContain("Entrar com o Google");
    expect(htmlSem).not.toContain("Private Relay");
  });

  it("mostra só as mensagens fixas do Google; o resto da URL é ignorado", async () => {
    expect(await tela("?erro=google_recusado")).toContain("Não deu para entrar com o Google");
    expect(await tela("?erro=google_cancelado")).toContain("foi cancelada");
    const html = await tela("?erro=%3Cscript%3Ealert(1)%3C/script%3E");
    expect(html).not.toContain("alert(1)");
    expect(html).not.toContain('role="alert"');
  });

  it("falha de rede no auth.concluirLoginSocialPkce vira indisponível, sem lançar", async () => {
    const auth = criarAuth(
      { url: SUPABASE, chavePublicavel: "sb_publishable_teste" },
      { fetch: async () => Promise.reject(new Error("rede")) },
    );
    expect(
      await auth.concluirLoginSocialPkce({
        provedor: "google",
        transacaoId: TX_ID,
        codigo: "c",
        codeVerifier: "v".repeat(43),
      }),
    ).toEqual({ ok: false, motivo: "indisponivel" });
  });

  it("wrangler.jsonc liga GOOGLE_ENTRAR e APPLE_ENTRAR apenas no DEV e mantém ausentes em producao", () => {
    const semComentarios = textoDoWrangler.replace(/^\s*\/\/.*$/gm, "").replace(/\/\*[\s\S]*?\*\//g, "");
    const config = JSON.parse(semComentarios) as {
      vars?: Record<string, string>;
      env?: { producao?: { vars?: Record<string, string> } };
    };
    expect(config.vars?.GOOGLE_ENTRAR).toBe("ligado");
    expect(config.vars?.APPLE_ENTRAR).toBe("ligado");
    expect(config.env?.producao?.vars).toBeDefined();
    expect(Object.keys(config.env?.producao?.vars ?? {})).not.toContain("GOOGLE_ENTRAR");
    expect(Object.keys(config.env?.producao?.vars ?? {})).not.toContain("APPLE_ENTRAR");
  });
});

describe("regressão basename='/app': pedido real pelo roteador não duplica /app/app/", () => {
  function criarRoteadorComBasename() {
    return createStaticHandler(
      [
        { id: "entrar-google", path: "entrar/google", loader: inicioLoader },
        { id: "entrar-google-retorno", path: "entrar/google/retorno", loader: retornoLoader },
        { id: "entrar-apple", path: "entrar/apple", loader: appleInicioLoader },
        { id: "entrar-apple-retorno", path: "entrar/apple/retorno", loader: appleRetornoLoader },
      ],
      { basename: "/app" },
    );
  }

  async function requisitar(caminhoComApp: string, opcoes: { cookie?: string } = {}): Promise<Response> {
    const handler = criarRoteadorComBasename();
    const res = await handler.query(
      new Request(`https://frilabr.com${caminhoComApp}`, {
        headers: opcoes.cookie ? { Cookie: opcoes.cookie } : {},
      }),
    );
    expect(res).toBeInstanceOf(Response);
    return res as Response;
  }

  it("reproduz e previne 302 /app/app/entrar em Google e Apple sem cookie / erro / correlação", async () => {
    const gSemCookie = await requisitar("/app/entrar/google/retorno?tx=teste");
    expect(gSemCookie.status).toBe(302);
    expect(gSemCookie.headers.get("Location")).toBe("/app/entrar?erro=google_recusado");
    expect(gSemCookie.headers.get("Location")).not.toContain("/app/app/");

    const aSemCookie = await requisitar("/app/entrar/apple/retorno?tx=teste");
    expect(aSemCookie.status).toBe(302);
    expect(aSemCookie.headers.get("Location")).toBe("/app/entrar?erro=apple_recusado");
    expect(aSemCookie.headers.get("Location")).not.toContain("/app/app/");

    const gCancelado = await requisitar("/app/entrar/google/retorno?error=access_denied&tx=teste");
    expect(gCancelado.status).toBe(302);
    expect(gCancelado.headers.get("Location")).toBe("/app/entrar?erro=google_cancelado");
  });

  it("Google e Apple iniciar + concluir (sucesso, definir-senha, 409, 503 e tx divergente) mantêm Location único /app/ e redirectTo externo intacto", async () => {
    for (const provedor of ["google", "apple"] as const) {
      mundo.resposta = () =>
        Response.json({
          transacao_id: TX_ID,
          url_autorizacao: `${SUPABASE}/auth/v1/authorize?provider=${provedor}&code_challenge_method=s256`,
          expira_em: "2026-11-26T21:10:00Z",
        });
      const inicio = await requisitar(`/app/entrar/${provedor}`);
      expect(inicio.status).toBe(302);
      expect(inicio.headers.get("Location")).toContain(`provider=${provedor}`);
      const pedidoInicio = mundo.pedidos.at(-1)?.corpo as { redirect_to?: string } | undefined;
      expect(pedidoInicio?.redirect_to).toMatch(new RegExp(`^https://frilabr\\.com/app/entrar/${provedor}/retorno\\?tx=`));

      const cookieBruto = inicio.headers.getSetCookie()[0] ?? "";
      const cookiePar = cookieBruto.split(";")[0] ?? "";
      const transacao = lerCookieTransacaoSocial(
        provedor,
        new Request(RETORNO, { headers: { Cookie: cookiePar } }),
        true,
      ).transacao;
      expect(transacao).not.toBeNull();
      const tx = transacao?.correlacao ?? "";

      // Sucesso padrão -> /app/
      mundo.resposta = () => Response.json({ sessao: SESSAO, provedor, precisa_definir_senha: false });
      const resOk = await requisitar(`/app/entrar/${provedor}/retorno?code=${CODIGO}&tx=${tx}`, { cookie: cookiePar });
      expect(resOk.status).toBe(302);
      expect(resOk.headers.get("Location")).toBe("/app");

      // Sucesso com precisa_definir_senha=true -> /app/definir-senha?origem=pendente
      mundo.resposta = () => Response.json({ sessao: SESSAO, provedor, precisa_definir_senha: true });
      const resSenha = await requisitar(`/app/entrar/${provedor}/retorno?code=${CODIGO}&tx=${tx}`, { cookie: cookiePar });
      expect(resSenha.status).toBe(302);
      expect(resSenha.headers.get("Location")).toBe("/app/definir-senha?origem=pendente");

      // Correlação divergente -> /app/entrar?erro=<provedor>_recusado
      const resTxErrado = await requisitar(`/app/entrar/${provedor}/retorno?code=${CODIGO}&tx=divergente`, { cookie: cookiePar });
      expect(resTxErrado.status).toBe(302);
      expect(resTxErrado.headers.get("Location")).toBe(`/app/entrar?erro=${provedor}_recusado`);

      // Conflito 409 -> /app/entrar?erro=conflito_identidade
      mundo.resposta = () => Response.json({ code: "conflito_identidade" }, { status: 409 });
      const res409 = await requisitar(`/app/entrar/${provedor}/retorno?code=${CODIGO}&tx=${tx}`, { cookie: cookiePar });
      expect(res409.status).toBe(302);
      expect(res409.headers.get("Location")).toBe("/app/entrar?erro=conflito_identidade");

      // Rede / indisponível 503 -> /app/entrar?erro=indisponivel
      mundo.resposta = () => Response.json({ msg: "indisponivel" }, { status: 503 });
      const res503 = await requisitar(`/app/entrar/${provedor}/retorno?code=${CODIGO}&tx=${tx}`, { cookie: cookiePar });
      expect(res503.status).toBe(302);
      expect(res503.headers.get("Location")).toBe("/app/entrar?erro=indisponivel");
    }
  });
});
