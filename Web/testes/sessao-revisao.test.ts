/**
 * Achados da revisão do #835 (Lince Codex): cada teste reproduz um defeito com tokens sintéticos.
 * 1. Uma renovação retida, que responde depois do sair, não pode reativar a sessão (nas duas ordens de chegada).
 * 2. Os cookies têm de chegar também a /app.data (o pedido de dados da página inicial).
 * 3. Cookie plantado por subdomínio (Domain=frilabr.com) não pode virar a sessão.
 */
import { RouterContextProvider } from "react-router";
import { describe, expect, it, vi } from "vitest";

import { action as sair } from "../app/rotas/sair";
import { middlewareDeSessao } from "../app/servidor/middleware-de-sessao";
import { cookiesDaSessao, cookiesDeSaida, lerCookiesDaSessao, resolverSessao, type Sessao } from "../app/servidor/sessao";

const auth = vi.hoisted(() => ({ renovar: vi.fn(), encerrar: vi.fn(async () => {}) }));
vi.mock("../app/servidor/deste-ambiente", () => ({ authDesteAmbiente: () => auth }));

const agora = Math.floor(Date.now() / 1000);
const token = (campos: Record<string, unknown>) => `cabecalho.${btoa(JSON.stringify(campos))}.assinatura-${campos.exp}`;
const SESSAO_ID = "0b7c1e2a-sessao-sintetica";
const antiga: Sessao = {
  access_token: token({ sub: "usuario", session_id: SESSAO_ID, exp: agora + 20 }),
  refresh_token: "r0",
  expires_in: 20,
  token_type: "bearer",
};
// Duas renovações do mesmo r0 (a retida e a do sair) dão tokens diferentes, da MESMA sessão do Auth.
const renovadaNoGet: Sessao = {
  access_token: token({ sub: "usuario", session_id: SESSAO_ID, exp: agora + 3600 }),
  refresh_token: "r1",
  expires_in: 3600,
  token_type: "bearer",
};
const renovadaNoSair: Sessao = {
  access_token: token({ sub: "usuario", session_id: SESSAO_ID, exp: agora + 3599 }),
  refresh_token: "r2",
  expires_in: 3599,
  token_type: "bearer",
};

/** Pote de cookies do navegador, do jeito mínimo: aplica Set-Cookie na ordem de chegada e respeita Max-Age=0. */
function pote() {
  const guardados = new Map<string, string>();
  return {
    aplicar(resposta: Response) {
      for (const linha of resposta.headers.getSetCookie()) {
        const par = linha.split(";")[0] ?? "";
        const corte = par.indexOf("=");
        const nome = par.slice(0, corte);
        if (/;\s*Max-Age=0(;|$)/.test(linha)) guardados.delete(nome);
        else guardados.set(nome, par.slice(corte + 1));
      }
    },
    cabecalho: () => [...guardados].map(([nome, valor]) => `${nome}=${valor}`).join("; "),
  };
}

const argumentos = (request: Request) => ({
  request,
  context: new RouterContextProvider(),
  params: {},
  url: new URL(request.url),
  matches: [],
});

async function corrida() {
  const navegador = pote();
  navegador.aplicar(new Response(null, { headers: cookiesDaSessao(antiga, true).map((c) => ["Set-Cookie", c]) }));

  auth.renovar.mockResolvedValueOnce({ ok: true, sessao: renovadaNoGet }).mockResolvedValueOnce({ ok: true, sessao: renovadaNoSair });
  let soltar!: () => void;
  let chegou!: () => void;
  const noMeio = new Promise<void>((r) => (chegou = r));
  const retida = new Promise<void>((r) => (soltar = r));
  const get = new Request("https://frilabr.com/app/", { headers: { Cookie: navegador.cabecalho() } });
  const emVoo = middlewareDeSessao(argumentos(get) as never, async () => {
    chegou();
    await retida;
    return new Response("pagina");
  });
  await noMeio;

  const post = new Request("https://frilabr.com/app/sair", {
    method: "POST",
    headers: { Origin: "https://frilabr.com", Cookie: navegador.cabecalho() },
  });
  const argsDoSair = argumentos(post);
  const respostaDoSair = await middlewareDeSessao(argsDoSair as never, async () => {
    try {
      await sair(argsDoSair as never);
      throw new Error("esperava o redirect");
    } catch (resposta) {
      if (resposta instanceof Response) return resposta;
      throw resposta;
    }
  });
  soltar();
  const respostaTardia = await emVoo;
  if (!(respostaDoSair instanceof Response) || !(respostaTardia instanceof Response)) throw new Error("esperava respostas");
  return { navegador, respostaDoSair, respostaTardia };
}

async function proximoPedido(cookie: string) {
  const renovar = vi.fn(async () => ({ ok: true as const, sessao: renovadaNoGet }));
  const resultado = await resolverSessao(new Request("https://frilabr.com/app/", { headers: { Cookie: cookie } }), renovar, agora);
  return { ...resultado, renovar };
}

describe("revisão do #835: renovação retida depois do sair", () => {
  it("a resposta do sair chega antes da renovação retida: a sessão não volta", async () => {
    const { navegador, respostaDoSair, respostaTardia } = await corrida();
    navegador.aplicar(respostaDoSair);
    navegador.aplicar(respostaTardia);
    const seguinte = await proximoPedido(navegador.cabecalho());
    expect(seguinte.sessao).toBeNull();
    expect(seguinte.cookies).toEqual(cookiesDeSaida(true));
  });

  it("a renovação retida chega antes do sair: a sessão também não volta", async () => {
    const { navegador, respostaDoSair, respostaTardia } = await corrida();
    navegador.aplicar(respostaTardia);
    navegador.aplicar(respostaDoSair);
    expect((await proximoPedido(navegador.cabecalho())).sessao).toBeNull();
  });

  it("só o token de renovação sobrou da sessão encerrada: renova, vê que é dela e sai", async () => {
    const { navegador, respostaDoSair, respostaTardia } = await corrida();
    navegador.aplicar(respostaDoSair);
    navegador.aplicar(respostaTardia);
    const semAcesso = navegador
      .cabecalho()
      .split("; ")
      .filter((par) => !par.includes("frila-acesso="))
      .join("; ");
    const seguinte = await proximoPedido(semAcesso);
    expect(seguinte.sessao).toBeNull();
    expect(seguinte.cookies).toEqual(cookiesDeSaida(true));
  });

  it("entrar de novo depois de sair (sessão nova do Auth) vale", async () => {
    const { navegador, respostaDoSair, respostaTardia } = await corrida();
    navegador.aplicar(respostaDoSair);
    navegador.aplicar(respostaTardia);
    const outraSessao: Sessao = { ...renovadaNoGet, access_token: token({ sub: "usuario", session_id: "outra", exp: agora + 3600 }) };
    navegador.aplicar(new Response(null, { headers: cookiesDaSessao(outraSessao, true).map((c) => ["Set-Cookie", c]) }));
    expect((await proximoPedido(navegador.cabecalho())).sessao?.usuarioId).toBe("usuario");
  });
});

/** O caminho do cookie casa com o do pedido? (RFC 6265, 5.1.4) */
function caminhoCasa(caminhoDoCookie: string, caminhoDoPedido: string): boolean {
  if (caminhoDoPedido === caminhoDoCookie) return true;
  if (!caminhoDoPedido.startsWith(caminhoDoCookie)) return false;
  return caminhoDoCookie.endsWith("/") || caminhoDoPedido[caminhoDoCookie.length] === "/";
}

describe("revisão do #835: escopo dos cookies", () => {
  it("os cookies chegam a todos os caminhos da web, inclusive /app.data", () => {
    for (const linha of cookiesDaSessao(antiga, true)) {
      const caminho = /;\s*Path=([^;]+)/.exec(linha)?.[1] ?? "";
      for (const pedido of ["/app", "/app/", "/app.data", "/app/_.data", "/app/entrar.data"]) {
        expect(caminhoCasa(caminho, pedido), `${pedido} com Path=${caminho}`).toBe(true);
      }
    }
  });

  it("em HTTPS os cookies são presos ao host: __Host-, Secure, Path=/ e sem Domain", () => {
    for (const linha of [...cookiesDaSessao(antiga, true), ...cookiesDeSaida(true)]) {
      expect(linha).toMatch(/^__Host-frila-/);
      expect(linha).toContain("; Secure");
      expect(linha).toContain("; Path=/;");
      expect(linha).not.toContain("Domain=");
    }
  });

  it("cookie que um subdomínio pode plantar (__Secure- ou sem prefixo) não vira sessão", () => {
    const plantado = new Request("https://frilabr.com/app/", {
      headers: { Cookie: "__Secure-frila-acesso=dominio; frila-acesso=dominio; __Secure-frila-renovacao=dominio" },
    });
    expect(lerCookiesDaSessao(plantado)).toEqual({ acesso: null, renovacao: null });
    const doHost = new Request("https://frilabr.com/app/", {
      headers: { Cookie: "__Secure-frila-acesso=dominio; __Host-frila-acesso=host" },
    });
    expect(lerCookiesDaSessao(doHost).acesso).toBe("host");
  });
});
