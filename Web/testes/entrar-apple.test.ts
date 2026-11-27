import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { loader as entrarLoader } from "../app/rotas/entrar";
import { loader as entrarAppleLoader } from "../app/rotas/entrar-apple";
import { loader as entrarAppleRetornoLoader } from "../app/rotas/entrar-apple-retorno";
import {
  classificarErroCallbackSocial,
  cookieTransacaoSocial,
  desafioPkceS256,
  ehCodigoOauthValido,
  ehVerifierPkceValido,
  gerarCorrelacaoSocial,
  gerarVerifierPkce,
  lerCookieTransacaoSocial,
} from "../app/servidor/social";
import { criarAuth } from "../app/servidor/auth";
import { contextoDaSessao } from "../app/contexto";
import { argumentos } from "./contratante-apoio";

const ambienteMock = vi.hoisted(() => ({
  appleLigado: true,
  googleLigado: false,
}));

const authMock = vi.hoisted(() => ({
  iniciarLoginSocialPkce: vi.fn(),
  concluirLoginSocialPkce: vi.fn(),
}));

vi.mock("../app/servidor/deste-ambiente", () => ({
  appleEntrarLigado: () => ambienteMock.appleLigado,
  googleLigadoNesteAmbiente: () => ambienteMock.googleLigado,
  socialEntrarLigado: (provedor: "apple" | "google") =>
    provedor === "apple" ? ambienteMock.appleLigado : ambienteMock.googleLigado,
  authDesteAmbiente: () => authMock,
  emailsDeDemonstracao: () => new Set<string>(),
}));

const TX_ID = "33333333-3333-4333-8333-333333333333";
const CORRELACAO = "correlacao-apple-sintetica-123456";
const SESSAO_APPLE = {
  access_token: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMTExMTExMS0xMTExLTQxMTEtODExMS0xMTExMTExMTExMTEiLCJleHAiOjE5MDAwMDAwMDB9.sig",
  refresh_token: "refresh-apple-sintetico",
  token_type: "bearer",
  expires_in: 3600,
};

function argsRota(caminho: string, cookies?: string, comSessao = false) {
  const base = argumentos(caminho, undefined, comSessao) as {
    request: Request;
    context: RouterContextProvider;
    params: Record<string, string>;
    url: URL;
    matches: unknown[];
  };
  const headers = new Headers(base.request.headers);
  if (cookies) headers.set("Cookie", cookies);
  const request = new Request(base.request.url, { method: "GET", headers });
  if (comSessao) {
    base.context.set(contextoDaSessao, {
      acesso: SESSAO_APPLE.access_token,
      usuarioId: "11111111-1111-4111-8111-111111111111",
      email: "ana@frila.test",
      visitante: null,
    });
  }
  return { ...base, request };
}

beforeEach(() => {
  vi.clearAllMocks();
  ambienteMock.appleLigado = true;
  ambienteMock.googleLigado = false;
});

describe("Web — Continuar com a Apple (autenticar-social PKCE S256 + correlação P2)", () => {
  it("gera verifier PKCE de 43 chars base64url, correlação e challenge S256 válido", async () => {
    const verifier = gerarVerifierPkce();
    expect(verifier.length).toBe(43);
    expect(ehVerifierPkceValido(verifier)).toBe(true);
    expect(ehVerifierPkceValido("curto")).toBe(false);

    const correlacao = gerarCorrelacaoSocial();
    expect(correlacao.length).toBeGreaterThanOrEqual(16);

    const challenge = await desafioPkceS256(verifier);
    expect(challenge.length).toBe(43);
    expect(challenge).not.toBe(verifier);
  });

  it("valida código OAuth e classifica erros de cancelamento e conflito de identidade", () => {
    expect(ehCodigoOauthValido("abc123-code")).toBe(true);
    expect(ehCodigoOauthValido("")).toBe(false);
    expect(ehCodigoOauthValido("a b c d")).toBe(false);

    expect(classificarErroCallbackSocial("apple", "access_denied", null, null)).toBe("apple_cancelado");
    expect(classificarErroCallbackSocial("apple", null, "identity_already_exists", null)).toBe("conflito_identidade");
    expect(classificarErroCallbackSocial("apple", "server_error", null, "erro generico")).toBe("apple_recusado");
  });

  it("wrangler.jsonc liga APPLE_ENTRAR apenas no DEV e mantém ausente em producao", () => {
    const raw = readFileSync(resolve(import.meta.dirname, "../wrangler.jsonc"), "utf-8");
    const semComentarios = raw.replace(/^\s*\/\/.*$/gm, "").replace(/\/\*[\s\S]*?\*\//g, "");
    const cfg = JSON.parse(semComentarios) as {
      vars?: Record<string, string>;
      env?: { producao?: { vars?: Record<string, string> } };
    };
    expect(cfg.vars?.APPLE_ENTRAR).toBe("ligado");
    expect(cfg.env?.producao?.vars?.APPLE_ENTRAR).toBeUndefined();
  });

  it("GET /entrar/apple recusa com 404 quando APPLE_ENTRAR está desligado", async () => {
    ambienteMock.appleLigado = false;
    const res = await entrarAppleLoader(argsRota("/app/entrar/apple") as never);
    expect(res.status).toBe(404);
    expect(res.headers.get("Set-Cookie")).toBeNull();
  });

  it("GET /entrar/apple inicia transação server-side, grava cookie transacaoId.verifier.correlacao HttpOnly/Secure e redireciona", async () => {
    authMock.iniciarLoginSocialPkce.mockResolvedValueOnce({
      ok: true,
      transacaoId: TX_ID,
      urlAutorizacao: "https://dev.supabase.co/auth/v1/authorize?provider=apple&code_challenge_method=s256",
    });

    const res = await entrarAppleLoader(argsRota("/app/entrar/apple") as never);
    expect(res.status).toBe(302);
    expect(res.headers.get("Cache-Control")).toBe("no-store");
    expect(res.headers.get("Location")).toContain("provider=apple");
    expect(authMock.iniciarLoginSocialPkce).toHaveBeenCalledWith(
      expect.objectContaining({
        provedor: "apple",
        codeChallenge: expect.stringMatching(/^[A-Za-z0-9_-]{43}$/),
        redirectTo: expect.stringMatching(/\/app\/entrar\/apple\/retorno\?tx=[A-Za-z0-9_-]{16,64}$/),
      }),
    );

    const setCookie = res.headers.get("Set-Cookie") ?? "";
    expect(setCookie).toContain(`__Host-frila-apple=${TX_ID}.`);
    expect(setCookie).toContain("HttpOnly");
    expect(setCookie).toContain("Secure");
    expect(setCookie).toContain("SameSite=Lax");
    expect(setCookie).toContain("Max-Age=600");
  });

  it("P2 correlação: callback forjado (?error ou ?code) SEM tx correspondente NÃO apaga o cookie da transação ativa", async () => {
    const verifier = gerarVerifierPkce();
    const cookieAtivo = `__Host-frila-apple=${TX_ID}.${verifier}.${CORRELACAO}`;

    const resForjado = await entrarAppleRetornoLoader(
      argsRota("/app/entrar/apple/retorno?error=access_denied", cookieAtivo) as never,
    );
    expect(resForjado.status).toBe(302);
    expect(resForjado.headers.get("Location")).toBe("/entrar?erro=apple_cancelado");
    expect(resForjado.headers.get("Set-Cookie")).toBeNull();
    expect(authMock.concluirLoginSocialPkce).not.toHaveBeenCalled();

    // Code sem tx ou com tx divergente também rejeita sem limpar cookie legítimo
    const resSemTx = await entrarAppleRetornoLoader(
      argsRota("/app/entrar/apple/retorno?code=codigo-valido-123", cookieAtivo) as never,
    );
    expect(resSemTx.status).toBe(302);
    expect(resSemTx.headers.get("Location")).toBe("/entrar?erro=apple_recusado");
    expect(resSemTx.headers.get("Set-Cookie")).toBeNull();
    expect(authMock.concluirLoginSocialPkce).not.toHaveBeenCalled();

    const resTxDivergente = await entrarAppleRetornoLoader(
      argsRota("/app/entrar/apple/retorno?code=codigo-valido-123&tx=tx-errado-1234567890", cookieAtivo) as never,
    );
    expect(resTxDivergente.status).toBe(302);
    expect(resTxDivergente.headers.get("Location")).toBe("/entrar?erro=apple_recusado");
    expect(resTxDivergente.headers.get("Set-Cookie")).toBeNull();

    // Hit vazio sem código também preserva transação legítima em andamento
    const resVazio = await entrarAppleRetornoLoader(
      argsRota("/app/entrar/apple/retorno", cookieAtivo) as never,
    );
    expect(resVazio.status).toBe(302);
    expect(resVazio.headers.get("Set-Cookie")).toBeNull();

    // Com tx exato da transação, limpa o cookie normalmente
    const resCorrelacionado = await entrarAppleRetornoLoader(
      argsRota(`/app/entrar/apple/retorno?error=access_denied&tx=${CORRELACAO}`, cookieAtivo) as never,
    );
    expect(resCorrelacionado.status).toBe(302);
    expect(resCorrelacionado.headers.get("Set-Cookie")).toContain("__Host-frila-apple=; Path=/; Max-Age=0");
  });

  it("GET /entrar/apple/retorno com cookie corrompido limpa o cookie e não chama Auth", async () => {
    const res = await entrarAppleRetornoLoader(
      argsRota(`/app/entrar/apple/retorno?code=abc12345&tx=${CORRELACAO}`, "__Host-frila-apple=corrompido") as never,
    );
    expect(res.status).toBe(302);
    expect(res.headers.get("Location")).toBe("/entrar?erro=apple_recusado");
    expect(res.headers.get("Set-Cookie")).toContain("__Host-frila-apple=; Path=/; Max-Age=0");
    expect(authMock.concluirLoginSocialPkce).not.toHaveBeenCalled();
  });

  it("GET /entrar/apple/retorno trata conflito de identidade (409) sem gravar sessão e limpa cookie", async () => {
    const verifier = gerarVerifierPkce();
    authMock.concluirLoginSocialPkce.mockResolvedValueOnce({ ok: false, motivo: "conflito_identidade" });

    const res = await entrarAppleRetornoLoader(
      argsRota(
        `/app/entrar/apple/retorno?code=codigo-valido-123&tx=${CORRELACAO}`,
        `__Host-frila-apple=${TX_ID}.${verifier}.${CORRELACAO}`,
      ) as never,
    );
    expect(res.status).toBe(302);
    expect(res.headers.get("Location")).toBe("/entrar?erro=conflito_identidade");
    const cookies = res.headers.getSetCookie();
    expect(cookies.some((c) => c.includes("__Host-frila-apple=; Path=/; Max-Age=0"))).toBe(true);
    expect(cookies.some((c) => c.includes("frila-acesso="))).toBe(false);
  });

  it("GET /entrar/apple/retorno preserva cookie em indisponibilidade transitória (503)", async () => {
    const verifier = gerarVerifierPkce();
    authMock.concluirLoginSocialPkce.mockResolvedValueOnce({ ok: false, motivo: "indisponivel" });

    const res = await entrarAppleRetornoLoader(
      argsRota(
        `/app/entrar/apple/retorno?code=codigo-valido-123&tx=${CORRELACAO}`,
        `__Host-frila-apple=${TX_ID}.${verifier}.${CORRELACAO}`,
      ) as never,
    );
    expect(res.status).toBe(302);
    expect(res.headers.get("Location")).toBe("/entrar?erro=indisponivel");
    expect(res.headers.get("Set-Cookie")).toBeNull();
  });

  it("GET /entrar/apple/retorno conclui via autenticar-social, grava sessão HttpOnly, limpa cookie Apple e não loga tokens", async () => {
    const verifier = gerarVerifierPkce();
    authMock.concluirLoginSocialPkce.mockResolvedValueOnce({
      ok: true,
      sessao: SESSAO_APPLE,
      precisaDefinirSenha: false,
    });
    const spyLog = vi.spyOn(console, "log").mockImplementation(() => {});
    const spyErr = vi.spyOn(console, "error").mockImplementation(() => {});

    try {
      const res = await entrarAppleRetornoLoader(
        argsRota(
          `/app/entrar/apple/retorno?code=codigo-valido-123&tx=${CORRELACAO}`,
          `__Host-frila-apple=${TX_ID}.${verifier}.${CORRELACAO}`,
        ) as never,
      );
      expect(res.status).toBe(302);
      expect(res.headers.get("Location")).toBe("/");
      expect(authMock.concluirLoginSocialPkce).toHaveBeenCalledWith(
        expect.objectContaining({
          provedor: "apple",
          transacaoId: TX_ID,
          codigo: "codigo-valido-123",
          codeVerifier: verifier,
        }),
      );

      const cookies = res.headers.getSetCookie();
      expect(cookies.some((c) => c.includes("__Host-frila-apple=; Path=/; Max-Age=0"))).toBe(true);
      expect(cookies.some((c) => c.includes("__Host-frila-acesso=") && c.includes("HttpOnly"))).toBe(true);
      expect(cookies.some((c) => c.includes("__Host-frila-renovacao=") && c.includes("HttpOnly"))).toBe(true);
      expect(spyLog).not.toHaveBeenCalled();
      expect(spyErr).not.toHaveBeenCalled();
    } finally {
      spyLog.mockRestore();
      spyErr.mockRestore();
    }
  });

  it("loader de /entrar aceita apenas chaves de erro da allow-list e ignora parâmetro arbitrário", () => {
    expect(entrarLoader(argsRota("/app/entrar?erro=conflito_identidade") as never)).toEqual({
      appleLigado: true,
      googleLigado: false,
      erroUrl: "conflito_identidade",
    });
    expect(entrarLoader(argsRota("/app/entrar?erro=mensagem_injetada") as never)).toEqual({
      appleLigado: true,
      googleLigado: false,
      erroUrl: undefined,
    });
  });

  it("auth.iniciarLoginSocialPkce e concluirLoginSocialPkce chamam /functions/v1/autenticar-social", async () => {
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        Response.json({
          transacao_id: TX_ID,
          url_autorizacao: "https://dev.supabase.co/auth/v1/authorize?provider=apple",
          expira_em: "2026-11-25T21:10:00Z",
        }),
      )
      .mockResolvedValueOnce(
        Response.json({ sessao: SESSAO_APPLE, provedor: "apple", precisa_definir_senha: false }),
      )
      .mockResolvedValueOnce(Response.json({ code: "conflito_identidade" }, { status: 409 }));

    const auth = criarAuth({ url: "https://dev.supabase.co", chavePublicavel: "pub-key" }, { fetch: fetchMock });

    const rInit = await auth.iniciarLoginSocialPkce({
      provedor: "apple",
      codeChallenge: "c".repeat(43),
      redirectTo: "https://frila-web-dev.frilabr.workers.dev/app/entrar/apple/retorno?tx=" + CORRELACAO,
    });
    expect(rInit).toEqual({
      ok: true,
      transacaoId: TX_ID,
      urlAutorizacao: "https://dev.supabase.co/auth/v1/authorize?provider=apple",
    });
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("https://dev.supabase.co/functions/v1/autenticar-social");

    const rOk = await auth.concluirLoginSocialPkce({
      provedor: "apple",
      transacaoId: TX_ID,
      codigo: "cod-1234",
      codeVerifier: "v".repeat(43),
    });
    expect(rOk).toEqual({ ok: true, sessao: SESSAO_APPLE, precisaDefinirSenha: false });

    const r409 = await auth.concluirLoginSocialPkce({
      provedor: "apple",
      transacaoId: TX_ID,
      codigo: "cod-1234",
      codeVerifier: "v".repeat(43),
    });
    expect(r409).toEqual({ ok: false, motivo: "conflito_identidade" });
  });

  it("cookieTransacaoSocial e lerCookieTransacaoSocial validam transacaoId + verifier + correlacao por provedor", () => {
    const verifier = gerarVerifierPkce();
    const linha = cookieTransacaoSocial("apple", { transacaoId: TX_ID, verifier, correlacao: CORRELACAO }, true);
    expect(linha).toContain(`__Host-frila-apple=${TX_ID}.${verifier}.${CORRELACAO}`);
    const req = new Request("https://frila-web-dev.frilabr.workers.dev/app/entrar/apple/retorno", {
      headers: { Cookie: `__Host-frila-apple=${TX_ID}.${verifier}.${CORRELACAO}` },
    });
    expect(lerCookieTransacaoSocial("apple", req, true)).toEqual({
      presente: true,
      transacao: { transacaoId: TX_ID, verifier, correlacao: CORRELACAO },
    });
    expect(lerCookieTransacaoSocial("google", req, true)).toEqual({
      presente: false,
      transacao: null,
    });
  });
});
