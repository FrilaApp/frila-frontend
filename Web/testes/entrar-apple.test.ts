import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { loader as entrarLoader } from "../app/rotas/entrar";
import { loader as entrarAppleLoader } from "../app/rotas/entrar-apple";
import { loader as entrarAppleRetornoLoader } from "../app/rotas/entrar-apple-retorno";
import {
  classificarErroCallbackApple,
  cookieVerifierApple,
  desafioPkceS256,
  ehCodigoOauthValido,
  ehVerifierPkceValido,
  gerarVerifierPkce,
  lerCookieVerifierApple,
  montarUrlAutorizacaoApple,
} from "../app/servidor/apple";
import { criarAuth } from "../app/servidor/auth";
import { contextoDaSessao } from "../app/contexto";
import { argumentos } from "./contratante-apoio";

const ambienteMock = vi.hoisted(() => ({
  appleLigado: true,
  supabaseUrl: "https://dev.supabase.co" as string | null,
}));

const authMock = vi.hoisted(() => ({
  trocarCodigoPkce: vi.fn(),
}));

vi.mock("../app/servidor/deste-ambiente", () => ({
  appleEntrarLigado: () => ambienteMock.appleLigado,
  urlDoSupabaseDesteAmbiente: () => ambienteMock.supabaseUrl,
  authDesteAmbiente: () => authMock,
  emailsDeDemonstracao: () => new Set<string>(),
}));

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
  ambienteMock.supabaseUrl = "https://dev.supabase.co";
});

describe("Web — Continuar com a Apple (OAuth PKCE S256 no servidor)", () => {
  it("gera verifier PKCE de 43 chars base64url e challenge S256 válido", async () => {
    const verifier = gerarVerifierPkce();
    expect(verifier.length).toBe(43);
    expect(ehVerifierPkceValido(verifier)).toBe(true);
    expect(ehVerifierPkceValido("curto")).toBe(false);
    expect(ehVerifierPkceValido("com espaco".repeat(6))).toBe(false);

    const challenge = await desafioPkceS256(verifier);
    expect(challenge.length).toBe(43);
    expect(challenge).not.toBe(verifier);
  });

  it("valida código OAuth e classifica erros de cancelamento e conflito de identidade", () => {
    expect(ehCodigoOauthValido("abc123-code")).toBe(true);
    expect(ehCodigoOauthValido("")).toBe(false);
    expect(ehCodigoOauthValido("ab")).toBe(false);
    expect(ehCodigoOauthValido("a b c d")).toBe(false);

    expect(classificarErroCallbackApple("access_denied", null, null)).toBe("apple_cancelado");
    expect(classificarErroCallbackApple(null, "identity_already_exists", null)).toBe("conflito_identidade");
    expect(classificarErroCallbackApple("server_error", null, "manual_linking_required")).toBe("conflito_identidade");
    expect(classificarErroCallbackApple("server_error", null, "erro generico")).toBe("apple_recusado");
  });

  it("monta URL /auth/v1/authorize com provider=apple e PKCE S256", () => {
    const url = new URL(
      montarUrlAutorizacaoApple({
        supabaseUrl: "https://dev.supabase.co/",
        urlRetorno: "https://frila-web-dev.frilabr.workers.dev/app/entrar/apple/retorno",
        codeChallenge: "desafio-s256-sintetico",
      }),
    );
    expect(url.origin).toBe("https://dev.supabase.co");
    expect(url.pathname).toBe("/auth/v1/authorize");
    expect(url.searchParams.get("provider")).toBe("apple");
    expect(url.searchParams.get("code_challenge")).toBe("desafio-s256-sintetico");
    expect(url.searchParams.get("code_challenge_method")).toBe("s256");
    expect(url.searchParams.get("redirect_to")).toBe(
      "https://frila-web-dev.frilabr.workers.dev/app/entrar/apple/retorno",
    );
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

  it("GET /entrar/apple grava cookie HttpOnly/Secure/SameSite=Lax e redireciona com PKCE S256", async () => {
    const res = await entrarAppleLoader(argsRota("/app/entrar/apple") as never);
    expect(res.status).toBe(302);
    expect(res.headers.get("Cache-Control")).toBe("no-store");

    const location = res.headers.get("Location") ?? "";
    const destino = new URL(location);
    expect(destino.pathname).toBe("/auth/v1/authorize");
    expect(destino.searchParams.get("provider")).toBe("apple");
    expect(destino.searchParams.get("code_challenge_method")).toBe("s256");
    expect(destino.searchParams.get("code_challenge")).toMatch(/^[A-Za-z0-9_-]{43}$/);

    const setCookie = res.headers.get("Set-Cookie") ?? "";
    expect(setCookie).toContain("__Host-frila-apple=");
    expect(setCookie).toContain("HttpOnly");
    expect(setCookie).toContain("Secure");
    expect(setCookie).toContain("SameSite=Lax");
    expect(setCookie).toContain("Max-Age=600");
  });

  it("GET /entrar/apple/retorno recusa com 404 e apaga cookie quando APPLE_ENTRAR está desligado", async () => {
    ambienteMock.appleLigado = false;
    const res = await entrarAppleRetornoLoader(argsRota("/app/entrar/apple/retorno?code=abc12345") as never);
    expect(res.status).toBe(404);
    expect(res.headers.get("Set-Cookie")).toContain("__Host-frila-apple=; Path=/; Max-Age=0");
  });

  it("GET /entrar/apple/retorno sem verifier ou verifier inválido redireciona sem chamar Auth e apaga cookie", async () => {
    const resSemCookie = await entrarAppleRetornoLoader(argsRota("/app/entrar/apple/retorno?code=abc12345") as never);
    expect(resSemCookie.status).toBe(302);
    expect(resSemCookie.headers.get("Location")).toBe("/app/entrar?erro=apple_recusado");
    expect(resSemCookie.headers.get("Set-Cookie")).toContain("__Host-frila-apple=; Path=/; Max-Age=0");
    expect(authMock.trocarCodigoPkce).not.toHaveBeenCalled();

    const resInvalido = await entrarAppleRetornoLoader(
      argsRota("/app/entrar/apple/retorno?code=abc12345", "__Host-frila-apple=curto") as never,
    );
    expect(resInvalido.status).toBe(302);
    expect(resInvalido.headers.get("Location")).toBe("/app/entrar?erro=apple_recusado");
    expect(authMock.trocarCodigoPkce).not.toHaveBeenCalled();
  });

  it("GET /entrar/apple/retorno trata cancelamento do usuário e apaga cookie", async () => {
    const verifier = gerarVerifierPkce();
    const res = await entrarAppleRetornoLoader(
      argsRota("/app/entrar/apple/retorno?error=access_denied", `__Host-frila-apple=${verifier}`) as never,
    );
    expect(res.status).toBe(302);
    expect(res.headers.get("Location")).toBe("/app/entrar?erro=apple_cancelado");
    expect(res.headers.get("Set-Cookie")).toContain("__Host-frila-apple=; Path=/; Max-Age=0");
    expect(authMock.trocarCodigoPkce).not.toHaveBeenCalled();
  });

  it("GET /entrar/apple/retorno trata conflito de identidade sem gravar sessão e apaga cookie", async () => {
    const verifier = gerarVerifierPkce();
    authMock.trocarCodigoPkce.mockResolvedValueOnce({ ok: false, motivo: "conflito_identidade" });

    const res = await entrarAppleRetornoLoader(
      argsRota("/app/entrar/apple/retorno?code=codigo-valido-123", `__Host-frila-apple=${verifier}`) as never,
    );
    expect(res.status).toBe(302);
    expect(res.headers.get("Location")).toBe("/app/entrar?erro=conflito_identidade");
    const cookies = res.headers.getSetCookie();
    expect(cookies.some((c) => c.includes("__Host-frila-apple=; Path=/; Max-Age=0"))).toBe(true);
    expect(cookies.some((c) => c.includes("frila-acesso="))).toBe(false);
  });

  it("GET /entrar/apple/retorno com código + verifier válidos grava cookies de sessão, apaga cookie Apple e não loga tokens", async () => {
    const verifier = gerarVerifierPkce();
    authMock.trocarCodigoPkce.mockResolvedValueOnce({ ok: true, sessao: SESSAO_APPLE });
    const spyLog = vi.spyOn(console, "log").mockImplementation(() => {});
    const spyErr = vi.spyOn(console, "error").mockImplementation(() => {});

    try {
      const res = await entrarAppleRetornoLoader(
        argsRota("/app/entrar/apple/retorno?code=codigo-valido-123", `__Host-frila-apple=${verifier}`) as never,
      );
      expect(res.status).toBe(302);
      expect(res.headers.get("Location")).toBe("/app/");
      expect(authMock.trocarCodigoPkce).toHaveBeenCalledWith("codigo-valido-123", verifier);

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
    const ok = entrarLoader(argsRota("/app/entrar?erro=conflito_identidade") as never);
    expect(ok).toEqual({ appleLigado: true, erroUrl: "conflito_identidade" });

    const arbitrario = entrarLoader(argsRota("/app/entrar?erro=mensagem_injetada") as never);
    expect(arbitrario).toEqual({ appleLigado: true, erroUrl: undefined });
  });

  it("auth.trocarCodigoPkce envia grant_type=pkce e mapeia conflito de identidade (409/identity_already_exists)", async () => {
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(Response.json(SESSAO_APPLE, { status: 200 }))
      .mockResolvedValueOnce(
        Response.json({ error_code: "identity_already_exists", msg: "Identity already linked" }, { status: 400 }),
      );

    const auth = criarAuth({ url: "https://dev.supabase.co", chavePublicavel: "pub-key" }, { fetch: fetchMock });

    const r1 = await auth.trocarCodigoPkce("cod-1234", "v".repeat(43));
    expect(r1).toEqual({ ok: true, sessao: SESSAO_APPLE });
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe("https://dev.supabase.co/auth/v1/token?grant_type=pkce");

    const r2 = await auth.trocarCodigoPkce("cod-1234", "v".repeat(43));
    expect(r2).toEqual({ ok: false, motivo: "conflito_identidade" });
  });

  it("cookieVerifierApple e lerCookieVerifierApple respeitam prefixo __Host- em HTTPS", () => {
    const verifier = gerarVerifierPkce();
    const linha = cookieVerifierApple(verifier, true);
    expect(linha).toContain(`__Host-frila-apple=${verifier}`);
    const req = new Request("https://frila-web-dev.frilabr.workers.dev/app/entrar/apple/retorno", {
      headers: { Cookie: `__Host-frila-apple=${verifier}` },
    });
    expect(lerCookieVerifierApple(req, true)).toBe(verifier);
  });
});
