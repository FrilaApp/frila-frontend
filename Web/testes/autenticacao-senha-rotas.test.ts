import { beforeEach, describe, expect, it, vi } from "vitest";

import { action as criarContaAction, loader as criarContaLoader } from "../app/rotas/criar-conta";
import { action as definirSenhaAction, loader as definirSenhaLoader } from "../app/rotas/definir-senha";
import { action as entrarAction, loader as entrarLoader } from "../app/rotas/entrar";
import { action as recuperarSenhaAction, loader as recuperarSenhaLoader } from "../app/rotas/recuperar-senha";
import { argumentos } from "./contratante-apoio";

async function capturaRedirect(chamada: () => unknown | Promise<unknown>): Promise<Response> {
  try {
    const res = await chamada();
    if (res instanceof Response) return res;
  } catch (resposta) {
    if (resposta instanceof Response) return resposta;
    throw resposta;
  }
  throw new Error("esperava um redirect");
}

const authMock = vi.hoisted(() => ({
  entrarComSenha: vi.fn(),
  pedirCodigo: vi.fn(),
  pedirCodigoRecuperacao: vi.fn(),
  confirmarCodigo: vi.fn(),
  entrarDemonstracao: vi.fn(),
  atualizarSenha: vi.fn(),
  encerrarOutrasSessoes: vi.fn(),
}));

const contaMock = vi.hoisted(() => ({
  lerMinhaConta: vi.fn(),
}));

vi.mock("../app/servidor/deste-ambiente", () => ({
  authDesteAmbiente: () => authMock,
  emailsDeDemonstracao: () => new Set(["demo@frila.test"]),
  apiDoUsuario: () => ({}),
}));

vi.mock("../app/servidor/conta", () => ({
  lerMinhaConta: (...args: unknown[]) => contaMock.lerMinhaConta(...args),
}));

const SESSAO_SINTETICA = {
  access_token: "acesso.token.sintetico",
  refresh_token: "refresh.token.sintetico",
  token_type: "bearer",
  expires_in: 3600,
};

beforeEach(() => {
  vi.clearAllMocks();
  authMock.entrarComSenha.mockResolvedValue({ ok: true, sessao: SESSAO_SINTETICA });
  authMock.pedirCodigo.mockResolvedValue({ ok: true });
  authMock.pedirCodigoRecuperacao.mockResolvedValue({ ok: true, enviado: true });
  authMock.confirmarCodigo.mockResolvedValue({ ok: true, sessao: SESSAO_SINTETICA });
  authMock.entrarDemonstracao.mockResolvedValue({ ok: true, sessao: SESSAO_SINTETICA });
  authMock.atualizarSenha.mockResolvedValue({ ok: true });
  authMock.encerrarOutrasSessoes.mockResolvedValue({ ok: true });
  contaMock.lerMinhaConta.mockResolvedValue({ estado: "ok", nome: "Teste", perfil: "profissional", termosVersao: "2026-11-20" });
});

describe("rotas: login habitual por senha e isolamento demo (rotas/entrar)", () => {
  it("se já estiver logado, o loader redireciona para a raiz", async () => {
    const resp = await capturaRedirect(() => entrarLoader(argumentos("/entrar", undefined, true)));
    expect(resp.headers.get("Location")).toBe("/");
  });

  it("se não estiver logado, o loader retorna null", async () => {
    expect(await entrarLoader(argumentos("/entrar", undefined, false))).toBeNull();
  });

  it("rejeita e-mail inválido", async () => {
    const res = await entrarAction(argumentos("/entrar", { email: "invalido", senha: "senha" }, false));
    expect(res).toEqual({ passo: "email", email: "invalido", erro: "email_invalido" });
  });

  it("exige senha no login habitual", async () => {
    const res = await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", senha: "" }, false));
    expect(res).toEqual({ passo: "email", email: "usuario@frila.test", erro: "senha_invalida" });
  });

  it("login com senha correto grava cookies HttpOnly e redireciona para /", async () => {
    const resp = await capturaRedirect(() =>
      entrarAction(argumentos("/entrar", { email: "usuario@frila.test", senha: "senhaCorreta123" }, false)),
    );
    expect(resp.headers.get("Location")).toBe("/");
    const cookies = resp.headers.getSetCookie();
    expect(cookies.length).toBe(2);
    expect(cookies.every((c) => c.includes("HttpOnly"))).toBe(true);
    expect(authMock.entrarComSenha).toHaveBeenCalledWith("usuario@frila.test", "senhaCorreta123");
  });

  it("login com senha incorreta devolve erro neutro credenciais_invalidas", async () => {
    authMock.entrarComSenha.mockResolvedValue({ ok: false, motivo: "credenciais_invalidas" });
    const res = await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", senha: "senhaErrada" }, false));
    expect(res).toEqual({ passo: "email", email: "usuario@frila.test", erro: "credenciais_invalidas" });
  });

  it("regressão P1: intencao=pedir em /entrar para conta não-demo é bloqueado e NÃO chama pedirCodigo", async () => {
    const res = await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "email", email: "usuario@frila.test", erro: "codigo_apenas_demo" });
    expect(authMock.pedirCodigo).not.toHaveBeenCalled();
  });

  it("regressão P1: intencao=confirmar em /entrar para conta não-demo é bloqueado e NÃO chama confirmarCodigo", async () => {
    const res = await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", codigo: "123456", intencao: "confirmar" }, false));
    expect(res).toEqual({ passo: "email", email: "usuario@frila.test", erro: "codigo_apenas_demo" });
    expect(authMock.confirmarCodigo).not.toHaveBeenCalled();
  });

  it("isolamento demo P2: conta demo tentando entrar por senha é rejeitada sem chamar entrarComSenha", async () => {
    const res = await entrarAction(argumentos("/entrar", { email: "demo@frila.test", senha: "123" }, false));
    expect(res).toEqual({ passo: "email", email: "demo@frila.test", erro: "conta_demo" });
    expect(authMock.entrarComSenha).not.toHaveBeenCalled();
  });

  it("intencao=pedir com conta demo avança para código sem chamar auth.pedirCodigo", async () => {
    const res = await entrarAction(argumentos("/entrar", { email: "demo@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "codigo", email: "demo@frila.test" });
    expect(authMock.pedirCodigo).not.toHaveBeenCalled();
  });

  it("intencao=confirmar com conta demo chama entrarDemonstracao", async () => {
    const resp = await capturaRedirect(() =>
      entrarAction(argumentos("/entrar", { email: "demo@frila.test", codigo: "codigo-demo", intencao: "confirmar" }, false)),
    );
    expect(resp.headers.get("Location")).toBe("/");
    expect(authMock.entrarDemonstracao).toHaveBeenCalledWith("demo@frila.test", "codigo-demo");
  });
});

describe("rotas: criação de conta com OTP (rotas/criar-conta)", () => {
  it("se já estiver logado, redireciona para a raiz", async () => {
    const resp = await capturaRedirect(() => criarContaLoader(argumentos("/criar-conta", undefined, true)));
    expect(resp.headers.get("Location")).toBe("/");
  });

  it("isolamento demo P2: recusa conta demo no cadastro", async () => {
    const res = await criarContaAction(argumentos("/criar-conta", { email: "demo@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "email", email: "demo@frila.test", erro: "conta_demo" });
    expect(authMock.pedirCodigo).not.toHaveBeenCalled();
  });

  it("intencao=pedir chama pedirCodigo com criarUsuario=true", async () => {
    const res = await criarContaAction(argumentos("/criar-conta", { email: "novo@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "codigo", email: "novo@frila.test" });
    expect(authMock.pedirCodigo).toHaveBeenCalledWith("novo@frila.test", { criarUsuario: true });
  });

  it("intencao=confirmar valida código de 6 dígitos, grava cookies e redireciona para /definir-senha?origem=cadastro", async () => {
    const resp = await capturaRedirect(() =>
      criarContaAction(argumentos("/criar-conta", { email: "novo@frila.test", codigo: "123456", intencao: "confirmar" }, false)),
    );
    expect(resp.headers.get("Location")).toBe("/definir-senha?origem=cadastro");
    expect(authMock.confirmarCodigo).toHaveBeenCalledWith("novo@frila.test", "123456");
    expect(resp.headers.getSetCookie().length).toBe(2);
  });

  it("intencao=confirmar com código inválido devolve erro codigo_invalido", async () => {
    authMock.confirmarCodigo.mockResolvedValue({ ok: false, motivo: "codigo_invalido" });
    const res = await criarContaAction(argumentos("/criar-conta", { email: "novo@frila.test", codigo: "000000", intencao: "confirmar" }, false));
    expect(res).toEqual({ passo: "codigo", email: "novo@frila.test", erro: "codigo_invalido" });
  });
});

describe("rotas: recuperação de senha anti-enumeração (rotas/recuperar-senha)", () => {
  it("se já estiver logado, redireciona para a raiz", async () => {
    const resp = await capturaRedirect(() => recuperarSenhaLoader(argumentos("/recuperar-senha", undefined, true)));
    expect(resp.headers.get("Location")).toBe("/");
  });

  it("recusa conta de demonstração com erro conta_demo", async () => {
    const res = await recuperarSenhaAction(argumentos("/recuperar-senha", { email: "demo@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "email", email: "demo@frila.test", erro: "conta_demo" });
  });

  it("regressão P1 anti-enumeração: conta existente e inexistente produzem estado e passo rigorosamente idênticos", async () => {
    authMock.pedirCodigoRecuperacao.mockResolvedValueOnce({ ok: true, enviado: true });
    const resExistente = await recuperarSenhaAction(
      argumentos("/recuperar-senha", { email: "mesmo@frila.test", intencao: "pedir" }, false),
    );

    authMock.pedirCodigoRecuperacao.mockResolvedValueOnce({ ok: true, enviado: false });
    const resInexistente = await recuperarSenhaAction(
      argumentos("/recuperar-senha", { email: "mesmo@frila.test", intencao: "pedir" }, false),
    );

    expect(resExistente).toEqual({ passo: "codigo", email: "mesmo@frila.test" });
    expect(resInexistente).toEqual(resExistente);
    expect(authMock.pedirCodigoRecuperacao).toHaveBeenCalledTimes(2);
  });

  it("regressão P1 anti-enumeração: reenvio para conta existente e inexistente produzem estado idêntico", async () => {
    authMock.pedirCodigoRecuperacao.mockResolvedValueOnce({ ok: true, enviado: true });
    const reenvioExistente = await recuperarSenhaAction(
      argumentos("/recuperar-senha", { email: "mesmo@frila.test", intencao: "pedir", reenvio: "1" }, false),
    );

    authMock.pedirCodigoRecuperacao.mockResolvedValueOnce({ ok: true, enviado: false });
    const reenvioInexistente = await recuperarSenhaAction(
      argumentos("/recuperar-senha", { email: "mesmo@frila.test", intencao: "pedir", reenvio: "1" }, false),
    );

    expect(reenvioExistente).toEqual({ passo: "codigo", email: "mesmo@frila.test", reenviado: true });
    expect(reenvioInexistente).toEqual(reenvioExistente);
  });

  it("erros de limite (429) e indisponibilidade (5xx) não são mascarados", async () => {
    authMock.pedirCodigoRecuperacao.mockResolvedValueOnce({ ok: false, motivo: "limite" });
    expect(await recuperarSenhaAction(argumentos("/recuperar-senha", { email: "a@b.co", intencao: "pedir" }, false))).toEqual({
      passo: "email",
      email: "a@b.co",
      erro: "limite",
    });

    authMock.pedirCodigoRecuperacao.mockResolvedValueOnce({ ok: false, motivo: "indisponivel" });
    expect(
      await recuperarSenhaAction(argumentos("/recuperar-senha", { email: "a@b.co", intencao: "pedir", reenvio: "1" }, false)),
    ).toEqual({
      passo: "codigo",
      email: "a@b.co",
      erro: "indisponivel",
    });
  });

  it("confirmar código de recuperação redireciona para /definir-senha?origem=recuperacao com cookies", async () => {
    const resp = await capturaRedirect(() =>
      recuperarSenhaAction(argumentos("/recuperar-senha", { email: "existente@frila.test", codigo: "654321", intencao: "confirmar" }, false)),
    );
    expect(resp.headers.get("Location")).toBe("/definir-senha?origem=recuperacao");
    expect(authMock.confirmarCodigo).toHaveBeenCalledWith("existente@frila.test", "654321");
    expect(resp.headers.getSetCookie().length).toBe(2);
  });
});

describe("rotas: definir senha na sessão ativa (rotas/definir-senha)", () => {
  it("sem sessão, loader redireciona para /entrar", async () => {
    const resp = await capturaRedirect(() => definirSenhaLoader(argumentos("/definir-senha", undefined, false)));
    expect(resp.headers.get("Location")).toBe("/entrar");
  });

  it("com sessão, loader lê origem corretamente", async () => {
    expect(definirSenhaLoader(argumentos("/definir-senha?origem=cadastro", undefined, true))).toEqual({ origem: "cadastro" });
    expect(definirSenhaLoader(argumentos("/definir-senha?origem=recuperacao", undefined, true))).toEqual({ origem: "recuperacao" });
    expect(definirSenhaLoader(argumentos("/definir-senha", undefined, true))).toEqual({ origem: "alteracao" });
  });

  it("valida tamanho mínimo de 8 caracteres", async () => {
    const res = await definirSenhaAction(argumentos("/definir-senha", { senha: "123", confirmacao: "123", origem: "cadastro" }, true));
    expect(res).toEqual({ erro: "senha_curta", origem: "cadastro" });
    expect(authMock.atualizarSenha).not.toHaveBeenCalled();
  });

  it("valida confirmação idêntica", async () => {
    const res = await definirSenhaAction(argumentos("/definir-senha", { senha: "senha1234", confirmacao: "diferente12", origem: "recuperacao" }, true));
    expect(res).toEqual({ erro: "senhas_diferentes", origem: "recuperacao" });
    expect(authMock.atualizarSenha).not.toHaveBeenCalled();
  });

  it("trata erro de reautenticação necessária sem loop", async () => {
    authMock.atualizarSenha.mockResolvedValue({ ok: false, motivo: "reautenticacao_necessaria" });
    const res = await definirSenhaAction(argumentos("/definir-senha", { senha: "senhaForte123!", confirmacao: "senhaForte123!" }, true));
    expect(res).toEqual({ erro: "reautenticacao_necessaria", origem: "alteracao" });
  });

  it("sessão inválida apaga cookies de sessão ao redirecionar para /entrar, impedindo loop", async () => {
    authMock.atualizarSenha.mockResolvedValue({ ok: false, motivo: "sessao_invalida" });
    const resp = await capturaRedirect(() =>
      definirSenhaAction(argumentos("/definir-senha", { senha: "senhaForte123!", confirmacao: "senhaForte123!" }, true)),
    );
    expect(resp.headers.get("Location")).toBe("/entrar");
    const cookies = resp.headers.getSetCookie();
    expect(cookies.length).toBe(2);
    expect(cookies.every((c) => c.includes("Max-Age=0"))).toBe(true);
  });

  it("salvar senha com origem=recuperacao tenta revogar outras sessões", async () => {
    const resp = await capturaRedirect(() =>
      definirSenhaAction(argumentos("/definir-senha", { senha: "senhaForte123!", confirmacao: "senhaForte123!", origem: "recuperacao" }, true)),
    );
    expect(resp.headers.get("Location")).toBe("/");
    expect(authMock.encerrarOutrasSessoes).toHaveBeenCalledWith("sintetico");
  });

  it("salvar senha com origem=cadastro redireciona para /cadastro se perfil não preenchido e não revoga outras sessões", async () => {
    contaMock.lerMinhaConta.mockResolvedValue({ estado: "sem_conta" });
    const resp = await capturaRedirect(() =>
      definirSenhaAction(argumentos("/definir-senha", { senha: "senhaForte123!", confirmacao: "senhaForte123!", origem: "cadastro" }, true)),
    );
    expect(resp.headers.get("Location")).toBe("/cadastro");
    expect(authMock.atualizarSenha).toHaveBeenCalledWith("sintetico", "senhaForte123!");
    expect(authMock.encerrarOutrasSessoes).not.toHaveBeenCalled();
  });
});
