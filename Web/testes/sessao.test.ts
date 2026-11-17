import { describe, expect, it, vi } from "vitest";

import {
  cookiesDaSessao,
  cookiesDeSaida,
  lerCookiesDaSessao,
  lerToken,
  type Conferencia,
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

describe("cookies da sessão", () => {
  it("em HTTPS: HttpOnly, Secure, SameSite=Lax, presos ao host (Path=/) e com o prefixo __Host-", () => {
    const [acesso, renovacao] = cookiesDaSessao(sessaoNova, true);
    for (const linha of [acesso, renovacao]) {
      expect(linha).toMatch(/^__Host-frila-(acesso|renovacao)=/);
      expect(linha).toContain("; HttpOnly");
      expect(linha).toContain("; Secure");
      expect(linha).toContain("; SameSite=Lax");
      expect(linha).toContain("; Path=/;");
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
      expect(linha).toMatch(/^__Host-frila-(acesso|renovacao)=; /);
      expect(linha).toContain("; Max-Age=0");
      expect(linha).toContain("; HttpOnly");
    }
  });

  it("lê de volta o que gravou e ignora cookie de outro nome", () => {
    const lidos = lerCookiesDaSessao(pedido("outro=1; __Host-frila-acesso=aaa; __Host-frila-renovacao=bbb"));
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

/** Auth simulado: cada teste diz o que o Auth responde. */
function authQue(opcoes: { conferir?: Conferencia; renovar?: Renovacao } = {}) {
  return {
    conferir: vi.fn<(acesso: string) => Promise<Conferencia>>(async () => opcoes.conferir ?? { ok: true }),
    renovar: vi.fn<(t: string) => Promise<Renovacao>>(async () => opcoes.renovar ?? { ok: true, sessao: sessaoNova }),
  };
}

describe("sessão de um pedido", () => {
  it("sem cookies, ninguém entrou, nada é gravado e o Auth não é chamado", async () => {
    const auth = authQue();
    expect(await resolverSessao(pedido(""), auth, AGORA)).toEqual({ sessao: null, cookies: [] });
    expect(auth.conferir).not.toHaveBeenCalled();
    expect(auth.renovar).not.toHaveBeenCalled();
  });

  it("token de acesso com folga: confere no Auth e usa, sem renovar", async () => {
    const acesso = acessoQueVenceEm(600);
    const auth = authQue();
    const resultado = await resolverSessao(pedido(`__Host-frila-acesso=${acesso}; __Host-frila-renovacao=r1`), auth, AGORA);
    expect(resultado).toEqual({ sessao: { acesso, usuarioId: "usuario-1", email: "ana@example.com" }, cookies: [] });
    expect(auth.conferir).toHaveBeenCalledExactlyOnceWith(acesso);
    expect(auth.renovar).not.toHaveBeenCalled();
  });

  it("Auth recusa o token (sessão encerrada): sai e apaga os cookies", async () => {
    const auth = authQue({ conferir: { ok: false, motivo: "recusada" } });
    expect(await resolverSessao(pedido(`__Host-frila-acesso=${acessoQueVenceEm(600)}`), auth, AGORA)).toEqual({
      sessao: null,
      cookies: cookiesDeSaida(true),
    });
  });

  it("token perto de vencer: renova uma vez (sem conferir) e regrava os cookies", async () => {
    const auth = authQue();
    const resultado = await resolverSessao(
      pedido(`__Host-frila-acesso=${acessoQueVenceEm(30)}; __Host-frila-renovacao=r1`),
      auth,
      AGORA,
    );
    expect(auth.renovar).toHaveBeenCalledExactlyOnceWith("r1");
    expect(auth.conferir).not.toHaveBeenCalled();
    expect(resultado.sessao?.acesso).toBe(sessaoNova.access_token);
    expect(resultado.cookies).toEqual(cookiesDaSessao(sessaoNova, true));
  });

  it("só o token de renovação (o de acesso já sumiu): renova", async () => {
    const resultado = await resolverSessao(pedido("__Host-frila-renovacao=r1"), authQue(), AGORA);
    expect(resultado.sessao?.usuarioId).toBe("usuario-1");
    expect(resultado.cookies).toHaveLength(2);
  });

  it("renovação recusada: sai e apaga os cookies", async () => {
    const resultado = await resolverSessao(
      pedido(`__Host-frila-acesso=${acessoQueVenceEm(-10)}; __Host-frila-renovacao=velho`),
      authQue({ renovar: { ok: false, motivo: "recusada" } }),
      AGORA,
    );
    expect(resultado).toEqual({ sessao: null, cookies: cookiesDeSaida(true) });
  });

  it("Auth fora do ar: sem sessão neste pedido e sem apagar nada", async () => {
    const fora = authQue({ conferir: { ok: false, motivo: "indisponivel" }, renovar: { ok: false, motivo: "indisponivel" } });
    for (const cookie of [
      `__Host-frila-acesso=${acessoQueVenceEm(600)}`,
      `__Host-frila-acesso=${acessoQueVenceEm(30)}; __Host-frila-renovacao=r1`,
      `__Host-frila-acesso=${acessoQueVenceEm(-5)}; __Host-frila-renovacao=r1`,
    ]) {
      expect(await resolverSessao(pedido(cookie), fora, AGORA)).toEqual({ sessao: null, cookies: [] });
    }
  });

  it("sem Auth configurado: sem sessão, sem apagar nada", async () => {
    expect(await resolverSessao(pedido(`__Host-frila-acesso=${acessoQueVenceEm(600)}`), null, AGORA)).toEqual({
      sessao: null,
      cookies: [],
    });
  });

  it("token perto de vencer e sem renovação: confere no Auth e usa enquanto vale", async () => {
    const acesso = acessoQueVenceEm(30);
    const auth = authQue();
    expect((await resolverSessao(pedido(`__Host-frila-acesso=${acesso}`), auth, AGORA)).sessao?.acesso).toBe(acesso);
    expect(auth.conferir).toHaveBeenCalledOnce();
  });

  it("token vencido e sem renovação: sai, sem chamar o Auth", async () => {
    const auth = authQue();
    expect(await resolverSessao(pedido(`__Host-frila-acesso=${acessoQueVenceEm(-5)}`), auth, AGORA)).toEqual({
      sessao: null,
      cookies: cookiesDeSaida(true),
    });
    expect(auth.conferir).not.toHaveBeenCalled();
  });

  it("token sem vencimento legível não vale como sessão", async () => {
    expect(await resolverSessao(pedido("__Host-frila-acesso=lixo"), authQue(), AGORA)).toEqual({
      sessao: null,
      cookies: cookiesDeSaida(true),
    });
  });
});
