import { describe, expect, it, vi } from "vitest";

import {
  cookiesDaSessao,
  cookiesDeSaida,
  lerCookiesDaSessao,
  lerToken,
  type Renovacao,
  resolverSessao,
  respostaJaGravaSessao,
  type Sessao,
} from "~/servidor/sessao";

const AGORA = 1_800_000_000;
const token = (campos: Record<string, unknown>) =>
  `cabecalho.${btoa(JSON.stringify(campos)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")}.assinatura`;
const acessoQueVenceEm = (segundos: number) => token({ exp: AGORA + segundos, sub: "usuario-1", email: "ana@example.com" });
const sessaoNova: Sessao = {
  access_token: acessoQueVenceEm(3600),
  refresh_token: "renovacao-nova",
  token_type: "bearer",
  expires_in: 3600,
};
const pedido = (cookies: string, url = "https://frilabr.com/app/") => new Request(url, { headers: { Cookie: cookies } });
const semRenovar = vi.fn<(t: string) => Promise<Renovacao>>(() => Promise.reject(new Error("não devia renovar")));

describe("cookies da sessão", () => {
  it("em HTTPS: HttpOnly, Secure, SameSite=Lax, presos a /app e com o prefixo __Secure-", () => {
    const [acesso, renovacao] = cookiesDaSessao(sessaoNova, true);
    for (const linha of [acesso, renovacao]) {
      expect(linha).toMatch(/^__Secure-frila-(acesso|renovacao)=/);
      expect(linha).toContain("; HttpOnly");
      expect(linha).toContain("; Secure");
      expect(linha).toContain("; SameSite=Lax");
      expect(linha).toContain("; Path=/app");
      expect(linha).not.toContain("Domain=");
    }
    expect(acesso).toContain("; Max-Age=3600");
    expect(renovacao).toContain(`; Max-Age=${60 * 60 * 24 * 30}`);
  });

  it("no servidor local (HTTP) continua HttpOnly, só sem Secure e sem o prefixo", () => {
    for (const linha of cookiesDaSessao(sessaoNova, false)) {
      expect(linha).toMatch(/^frila-(acesso|renovacao)=/);
      expect(linha).toContain("; HttpOnly");
      expect(linha).not.toContain("Secure");
    }
  });

  it("sair apaga os dois cookies", () => {
    const linhas = cookiesDeSaida(true);
    expect(linhas).toHaveLength(2);
    for (const linha of linhas) {
      expect(linha).toMatch(/^__Secure-frila-(acesso|renovacao)=; /);
      expect(linha).toContain("; Max-Age=0");
      expect(linha).toContain("; HttpOnly");
    }
  });

  it("lê de volta o que gravou e ignora cookie de outro nome", () => {
    const lidos = lerCookiesDaSessao(pedido("outro=1; __Secure-frila-acesso=aaa; __Secure-frila-renovacao=bbb"));
    expect(lidos).toEqual({ acesso: "aaa", renovacao: "bbb" });
    // Em HTTPS o cookie sem prefixo (que um subdomínio poderia plantar) não vale.
    expect(lerCookiesDaSessao(pedido("frila-acesso=aaa"))).toEqual({ acesso: null, renovacao: null });
  });

  it("sabe quando a resposta já grava a sessão", () => {
    const cabecalhos = new Headers();
    for (const linha of cookiesDeSaida(true)) cabecalhos.append("Set-Cookie", linha);
    expect(respostaJaGravaSessao(new Response(null, { headers: cabecalhos }))).toBe(true);
    expect(respostaJaGravaSessao(new Response(null, { headers: { "Set-Cookie": "outro=1" } }))).toBe(false);
  });
});

describe("leitura do token", () => {
  it("tira vencimento, usuário e e-mail", () => {
    expect(lerToken(acessoQueVenceEm(10))).toEqual({ venceEm: AGORA + 10, usuarioId: "usuario-1", email: "ana@example.com" });
  });

  it("token estragado não derruba nada", () => {
    expect(lerToken("lixo")).toEqual({ venceEm: null, usuarioId: null, email: null });
    expect(lerToken("a.@@@.c")).toEqual({ venceEm: null, usuarioId: null, email: null });
  });
});

describe("sessão de um pedido", () => {
  it("sem cookies, ninguém entrou e nada é gravado", async () => {
    expect(await resolverSessao(pedido(""), semRenovar, AGORA)).toEqual({ sessao: null, cookies: [] });
  });

  it("token de acesso com folga: usa sem renovar", async () => {
    const acesso = acessoQueVenceEm(600);
    const resultado = await resolverSessao(pedido(`__Secure-frila-acesso=${acesso}; __Secure-frila-renovacao=r1`), semRenovar, AGORA);
    expect(resultado).toEqual({ sessao: { acesso, usuarioId: "usuario-1", email: "ana@example.com" }, cookies: [] });
    expect(semRenovar).not.toHaveBeenCalled();
  });

  it("token perto de vencer: renova uma vez e regrava os cookies", async () => {
    const renovar = vi.fn<(t: string) => Promise<Renovacao>>(async () => ({ ok: true, sessao: sessaoNova }));
    const resultado = await resolverSessao(
      pedido(`__Secure-frila-acesso=${acessoQueVenceEm(30)}; __Secure-frila-renovacao=r1`),
      renovar,
      AGORA,
    );
    expect(renovar).toHaveBeenCalledExactlyOnceWith("r1");
    expect(resultado.sessao?.acesso).toBe(sessaoNova.access_token);
    expect(resultado.cookies).toEqual(cookiesDaSessao(sessaoNova, true));
  });

  it("só o token de renovação (o de acesso já sumiu): renova", async () => {
    const renovar = vi.fn<(t: string) => Promise<Renovacao>>(async () => ({ ok: true, sessao: sessaoNova }));
    const resultado = await resolverSessao(pedido("__Secure-frila-renovacao=r1"), renovar, AGORA);
    expect(resultado.sessao?.usuarioId).toBe("usuario-1");
    expect(resultado.cookies).toHaveLength(2);
  });

  it("renovação recusada: sai e apaga os cookies", async () => {
    const resultado = await resolverSessao(
      pedido(`__Secure-frila-acesso=${acessoQueVenceEm(-10)}; __Secure-frila-renovacao=velho`),
      async () => ({ ok: false, motivo: "recusada" }),
      AGORA,
    );
    expect(resultado).toEqual({ sessao: null, cookies: cookiesDeSaida(true) });
  });

  it("Supabase fora do ar: segue com o token enquanto ele vale, sem apagar nada", async () => {
    const fora = async (): Promise<Renovacao> => ({ ok: false, motivo: "indisponivel" });
    const aindaVale = acessoQueVenceEm(30);
    expect(await resolverSessao(pedido(`__Secure-frila-acesso=${aindaVale}; __Secure-frila-renovacao=r1`), fora, AGORA)).toEqual({
      sessao: { acesso: aindaVale, usuarioId: "usuario-1", email: "ana@example.com" },
      cookies: [],
    });
    expect(
      await resolverSessao(pedido(`__Secure-frila-acesso=${acessoQueVenceEm(-5)}; __Secure-frila-renovacao=r1`), fora, AGORA),
    ).toEqual({ sessao: null, cookies: [] });
  });

  it("token vencido e sem renovação: sai", async () => {
    expect(await resolverSessao(pedido(`__Secure-frila-acesso=${acessoQueVenceEm(-5)}`), semRenovar, AGORA)).toEqual({
      sessao: null,
      cookies: cookiesDeSaida(true),
    });
  });

  it("token sem vencimento legível não vale como sessão", async () => {
    expect(await resolverSessao(pedido("__Secure-frila-acesso=lixo"), semRenovar, AGORA)).toEqual({
      sessao: null,
      cookies: cookiesDeSaida(true),
    });
  });
});
