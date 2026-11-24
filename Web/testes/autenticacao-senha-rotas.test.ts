import { beforeEach, describe, expect, it, vi } from "vitest";

import { action as criarContaAction, loader as criarContaLoader } from "../app/rotas/criar-conta";
import { action as definirSenhaAction, loader as definirSenhaLoader } from "../app/rotas/definir-senha";
import { action as entrarAction, loader as entrarLoader } from "../app/rotas/entrar";
import { action as recuperarSenhaAction, loader as recuperarSenhaLoader } from "../app/rotas/recuperar-senha";
import { argumentos } from "./contratante-apoio";

async function capturaRedirect(chamada: () => unknown | Promise<unknown>): Promise<string> {
  try {
    const res = await chamada();
    if (res instanceof Response) return res.headers.get("Location") ?? "";
  } catch (resposta) {
    if (resposta instanceof Response) return resposta.headers.get("Location") ?? "";
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
  contaMock.lerMinhaConta.mockResolvedValue({ estado: "ok", nome: "Teste", perfil: "profissional", termosVersao: "2026-11-20" });
});

describe("rotas: login habitual por senha (rotas/entrar)", () => {
  it("se já estiver logado, o loader redireciona para a raiz", async () => {
    expect(await capturaRedirect(() => entrarLoader(argumentos("/entrar", undefined, true)))).toBe("/");
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
    try {
      await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", senha: "senhaCorreta123" }, false));
      expect.fail("esperava redirect");
    } catch (resposta) {
      expect(resposta instanceof Response).toBe(true);
      const resp = resposta as Response;
      expect(resp.headers.get("Location")).toBe("/");
      const cookies = resp.headers.getSetCookie();
      expect(cookies.length).toBe(2);
      expect(cookies.every((c) => c.includes("HttpOnly"))).toBe(true);
      expect(authMock.entrarComSenha).toHaveBeenCalledWith("usuario@frila.test", "senhaCorreta123");
    }
  });

  it("login com senha incorreta devolve erro neutro credenciais_invalidas", async () => {
    authMock.entrarComSenha.mockResolvedValue({ ok: false, motivo: "credenciais_invalidas" });
    const res = await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", senha: "senhaErrada" }, false));
    expect(res).toEqual({ passo: "email", email: "usuario@frila.test", erro: "credenciais_invalidas" });
  });

  it("intencao=pedir pede código e avança para passo codigo", async () => {
    const res = await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "codigo", email: "usuario@frila.test" });
    expect(authMock.pedirCodigo).toHaveBeenCalledWith("usuario@frila.test");
  });

  it("intencao=pedir com conta demo avança para código sem chamar auth.pedirCodigo", async () => {
    const res = await entrarAction(argumentos("/entrar", { email: "demo@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "codigo", email: "demo@frila.test" });
    expect(authMock.pedirCodigo).not.toHaveBeenCalled();
  });

  it("intencao=confirmar com conta demo chama entrarDemonstracao", async () => {
    try {
      await entrarAction(argumentos("/entrar", { email: "demo@frila.test", codigo: "codigo-demo", intencao: "confirmar" }, false));
      expect.fail("esperava redirect");
    } catch (resposta) {
      expect(resposta instanceof Response).toBe(true);
      const resp = resposta as Response;
      expect(resp.headers.get("Location")).toBe("/");
      expect(authMock.entrarDemonstracao).toHaveBeenCalledWith("demo@frila.test", "codigo-demo");
    }
  });
});

describe("rotas: criação de conta com OTP (rotas/criar-conta)", () => {
  it("se já estiver logado, redireciona para a raiz", async () => {
    expect(await capturaRedirect(() => criarContaLoader(argumentos("/criar-conta", undefined, true)))).toBe("/");
  });

  it("intencao=pedir chama pedirCodigo com criarUsuario=true", async () => {
    const res = await criarContaAction(argumentos("/criar-conta", { email: "novo@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "codigo", email: "novo@frila.test" });
    expect(authMock.pedirCodigo).toHaveBeenCalledWith("novo@frila.test", { criarUsuario: true });
  });

  it("intencao=confirmar valida código de 6 dígitos, grava cookies e redireciona para /definir-senha?origem=cadastro", async () => {
    try {
      await criarContaAction(argumentos("/criar-conta", { email: "novo@frila.test", codigo: "123456", intencao: "confirmar" }, false));
      expect.fail("esperava redirect");
    } catch (resposta) {
      expect(resposta instanceof Response).toBe(true);
      const resp = resposta as Response;
      expect(resp.headers.get("Location")).toBe("/definir-senha?origem=cadastro");
      expect(authMock.confirmarCodigo).toHaveBeenCalledWith("novo@frila.test", "123456");
      expect(resp.headers.getSetCookie().length).toBe(2);
    }
  });

  it("intencao=confirmar com código inválido devolve erro codigo_invalido", async () => {
    authMock.confirmarCodigo.mockResolvedValue({ ok: false, motivo: "codigo_invalido" });
    const res = await criarContaAction(argumentos("/criar-conta", { email: "novo@frila.test", codigo: "000000", intencao: "confirmar" }, false));
    expect(res).toEqual({ passo: "codigo", email: "novo@frila.test", erro: "codigo_invalido" });
  });
});

describe("rotas: recuperação de senha e migração de conta legada (rotas/recuperar-senha)", () => {
  it("se já estiver logado, redireciona para a raiz", async () => {
    expect(await capturaRedirect(() => recuperarSenhaLoader(argumentos("/recuperar-senha", undefined, true)))).toBe("/");
  });

  it("recusa conta de demonstração com erro conta_demo", async () => {
    const res = await recuperarSenhaAction(argumentos("/recuperar-senha", { email: "demo@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "email", email: "demo@frila.test", erro: "conta_demo" });
  });

  it("conta existente (enviado=true) avança para o passo de código", async () => {
    authMock.pedirCodigoRecuperacao.mockResolvedValue({ ok: true, enviado: true });
    const res = await recuperarSenhaAction(argumentos("/recuperar-senha", { email: "existente@frila.test", intencao: "pedir" }, false));
    expect(res).toEqual({ passo: "codigo", email: "existente@frila.test" });
    expect(authMock.pedirCodigoRecuperacao).toHaveBeenCalledWith("existente@frila.test");
  });

  it("conta inexistente ou social-only (enviado=false) retorna mensagem neutra anti-enumeração sem avançar", async () => {
    authMock.pedirCodigoRecuperacao.mockResolvedValue({ ok: true, enviado: false });
    const res = await recuperarSenhaAction(argumentos("/recuperar-senha", { email: "inexistente@frila.test", intencao: "pedir" }, false));
    expect(res).toHaveProperty("passo", "email");
    expect(res).toHaveProperty("mensagemNeutra");
    expect(res).not.toHaveProperty("erro");
  });

  it("confirmar código de recuperação redireciona para /definir-senha?origem=recuperacao com cookies", async () => {
    try {
      await recuperarSenhaAction(argumentos("/recuperar-senha", { email: "existente@frila.test", codigo: "654321", intencao: "confirmar" }, false));
      expect.fail("esperava redirect");
    } catch (resposta) {
      expect(resposta instanceof Response).toBe(true);
      const resp = resposta as Response;
      expect(resp.headers.get("Location")).toBe("/definir-senha?origem=recuperacao");
      expect(authMock.confirmarCodigo).toHaveBeenCalledWith("existente@frila.test", "654321");
      expect(resp.headers.getSetCookie().length).toBe(2);
    }
  });
});

describe("rotas: definir senha na sessão ativa (rotas/definir-senha)", () => {
  it("sem sessão, loader redireciona para /entrar", async () => {
    expect(await capturaRedirect(() => definirSenhaLoader(argumentos("/definir-senha", undefined, false)))).toBe("/entrar");
  });

  it("com sessão, loader permite acesso", async () => {
    expect(await definirSenhaLoader(argumentos("/definir-senha", undefined, true))).toBeNull();
  });

  it("valida tamanho mínimo de 8 caracteres", async () => {
    const res = await definirSenhaAction(argumentos("/definir-senha", { senha: "123", confirmacao: "123" }, true));
    expect(res).toEqual({ erro: "senha_curta" });
    expect(authMock.atualizarSenha).not.toHaveBeenCalled();
  });

  it("valida confirmação idêntica", async () => {
    const res = await definirSenhaAction(argumentos("/definir-senha", { senha: "senha1234", confirmacao: "diferente12" }, true));
    expect(res).toEqual({ erro: "senhas_diferentes" });
    expect(authMock.atualizarSenha).not.toHaveBeenCalled();
  });

  it("trata erro de senha fraca devolvido pelo auth", async () => {
    authMock.atualizarSenha.mockResolvedValue({ ok: false, motivo: "senha_fraca" });
    const res = await definirSenhaAction(argumentos("/definir-senha", { senha: "senhafraca1", confirmacao: "senhafraca1" }, true));
    expect(res).toEqual({ erro: "senha_fraca" });
  });

  it("salvar senha com sucesso preservando auth.uid redireciona para /cadastro se perfil não preenchido", async () => {
    contaMock.lerMinhaConta.mockResolvedValue({ estado: "sem_conta" });
    expect(
      await capturaRedirect(() =>
        definirSenhaAction(argumentos("/definir-senha", { senha: "senhaForte123!", confirmacao: "senhaForte123!" }, true)),
      ),
    ).toBe("/cadastro");
    expect(authMock.atualizarSenha).toHaveBeenCalledWith("sintetico", "senhaForte123!");
  });

  it("salvar senha com sucesso redireciona para / se perfil já estiver pronto", async () => {
    contaMock.lerMinhaConta.mockResolvedValue({ estado: "ok", nome: "Ana", perfil: "profissional", termosVersao: "2026-11-20" });
    expect(
      await capturaRedirect(() =>
        definirSenhaAction(argumentos("/definir-senha", { senha: "senhaForte123!", confirmacao: "senhaForte123!" }, true)),
      ),
    ).toBe("/");
  });
});
