import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import {
  createStaticHandler,
  createStaticRouter,
  RouterContextProvider,
  StaticRouterProvider,
  useActionData,
  useLoaderData,
} from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { action as dadosAction } from "../app/rotas/conta/dados";
import { action as criarContaAction, loader as criarContaLoader } from "../app/rotas/criar-conta";
import { action as definirSenhaAction, loader as definirSenhaLoader } from "../app/rotas/definir-senha";
import Entrar, { action as entrarAction, loader as entrarLoader } from "../app/rotas/entrar";
import { action as recuperarSenhaAction, loader as recuperarSenhaLoader } from "../app/rotas/recuperar-senha";
import { action as sairAction } from "../app/rotas/sair";
import { middlewareDeSessao } from "../app/servidor/middleware-de-sessao";
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

function jwtComAppMetadata(appMetadata: Record<string, unknown>, exp = Math.floor(Date.now() / 1000) + 3600): string {
  const b64 = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${b64({ alg: "HS256", typ: "JWT" })}.${b64({
    sub: "11111111-1111-4111-8111-111111111111",
    email: "ana@frila.test",
    exp,
    app_metadata: appMetadata,
  })}.assinatura`;
}

const authMock = vi.hoisted(() => ({
  autenticarSenha: vi.fn(),
  confirmarDispositivoOtp: vi.fn(),
  reenviarDispositivoOtp: vi.fn(),
  definirSenha: vi.fn(),
  revogarDispositivos: vi.fn(),
  pedirCodigo: vi.fn(),
  pedirCodigoRecuperacao: vi.fn(),
  confirmarCodigo: vi.fn(),
  entrarDemonstracao: vi.fn(),
  conferir: vi.fn(),
  renovar: vi.fn(),
  encerrar: vi.fn(),
}));

const contaMock = vi.hoisted(() => ({
  lerMinhaConta: vi.fn(),
}));

vi.mock("../app/servidor/deste-ambiente", () => ({
  authDesteAmbiente: () => authMock,
  appleEntrarLigado: () => false,
  emailsDeDemonstracao: () => new Set(["demo@frila.test"]),
  googleLigadoNesteAmbiente: () => false,
  apiDoUsuario: () => ({}),
  funcoesDoUsuario: () => ({}),
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

function pedidoComCookies(caminho: string, dados?: Record<string, string>, cookies?: string) {
  const base = argumentos(caminho, dados, false) as {
    request: Request;
    context: RouterContextProvider;
    params: Record<string, string>;
    url: URL;
    matches: unknown[];
  };
  const headers = new Headers(base.request.headers);
  if (cookies) headers.set("Cookie", cookies);
  headers.set("CF-Connecting-IP", "198.51.100.77");
  const request = new Request(base.request, { headers });
  return { ...base, request };
}

beforeEach(() => {
  vi.clearAllMocks();
  authMock.autenticarSenha.mockResolvedValue({
    ok: true,
    status: "autenticado",
    sessao: SESSAO_SINTETICA,
    precisaDefinirSenha: false,
  });
  authMock.confirmarDispositivoOtp.mockResolvedValue({
    ok: true,
    sessao: SESSAO_SINTETICA,
    precisaDefinirSenha: false,
    deviceToken: null,
  });
  authMock.reenviarDispositivoOtp.mockResolvedValue({ ok: true, reenviarEmSegundos: 60 });
  authMock.definirSenha.mockResolvedValue({ ok: true, sessao: SESSAO_SINTETICA });
  authMock.revogarDispositivos.mockResolvedValue({ ok: true });
  authMock.pedirCodigo.mockResolvedValue({ ok: true });
  authMock.pedirCodigoRecuperacao.mockResolvedValue({ ok: true, enviado: true });
  authMock.confirmarCodigo.mockResolvedValue({ ok: true, sessao: SESSAO_SINTETICA });
  authMock.entrarDemonstracao.mockResolvedValue({ ok: true, sessao: SESSAO_SINTETICA });
  authMock.conferir.mockResolvedValue({ ok: true });
  authMock.encerrar.mockResolvedValue({ ok: true });
  contaMock.lerMinhaConta.mockResolvedValue({
    estado: "ok",
    nome: "Teste",
    perfil: "profissional",
    termosVersao: "2026-11-20",
  });
});

describe("rotas: login por senha, dispositivo confiável 30d e desafio OTP (rotas/entrar)", () => {
  it("se já estiver logado, o loader redireciona para a raiz", async () => {
    const resp = await capturaRedirect(() => entrarLoader(argumentos("/entrar", undefined, true)));
    expect(resp.headers.get("Location")).toBe("/");
  });

  it("rejeita e-mail inválido e senha vazia", async () => {
    expect(await entrarAction(argumentos("/entrar", { email: "invalido", senha: "senha" }, false))).toEqual({
      passo: "email",
      email: "invalido",
      erro: "email_invalido",
    });
    expect(await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", senha: "" }, false))).toEqual({
      passo: "email",
      email: "usuario@frila.test",
      erro: "senha_invalida",
    });
  });

  it("login com dispositivo confiável válido repassa cookie __Host-frila-dispositivo e redireciona para /", async () => {
    const args = pedidoComCookies("/entrar", { email: "usuario@frila.test", senha: "senhaCorreta123" }, "__Host-frila-dispositivo=dev-tok-30d");
    const resp = await capturaRedirect(() => entrarAction(args as never));
    expect(resp.headers.get("Location")).toBe("/");
    const cookies = resp.headers.getSetCookie();
    expect(cookies.length).toBe(2);
    expect(cookies.every((c) => c.includes("HttpOnly"))).toBe(true);
    expect(authMock.autenticarSenha).toHaveBeenCalledWith({
      email: "usuario@frila.test",
      senha: "senhaCorreta123",
      deviceToken: "dev-tok-30d",
      visitante: "198.51.100.77",
    });
  });

  it("dispositivo novo/expirado abre passo desafio e expira cookie antigo quando descartarDeviceToken=true", async () => {
    authMock.autenticarSenha.mockResolvedValue({
      ok: true,
      status: "desafio_otp",
      desafioId: "des-123",
      descartarDeviceToken: true,
    });
    const args = pedidoComCookies("/entrar", { email: "usuario@frila.test", senha: "senhaCorreta123" }, "__Host-frila-dispositivo=vencido");
    const res = (await entrarAction(args as never)) as { data: unknown; init?: ResponseInit };
    expect(res.data).toEqual({ passo: "desafio", email: "usuario@frila.test", desafioId: "des-123" });
    const headerCookie = (res.init?.headers as Record<string, string>)["Set-Cookie"];
    expect(headerCookie).toContain("__Host-frila-dispositivo=");
    expect(headerCookie).toContain("Max-Age=0");
  });

  it("confirmar_desafio com lembrar_dispositivo=sim grava cookie __Host-frila-dispositivo HttpOnly 30 dias", async () => {
    authMock.confirmarDispositivoOtp.mockResolvedValue({
      ok: true,
      sessao: SESSAO_SINTETICA,
      precisaDefinirSenha: false,
      deviceToken: "novo-device-token",
    });
    const args = pedidoComCookies("/entrar", {
      email: "usuario@frila.test",
      desafio_id: "des-123",
      codigo: "654321",
      lembrar_dispositivo: "sim",
      intencao: "confirmar_desafio",
    });
    const resp = await capturaRedirect(() => entrarAction(args as never));
    expect(resp.headers.get("Location")).toBe("/");
    expect(authMock.confirmarDispositivoOtp).toHaveBeenCalledWith({
      tipo: "login_dispositivo",
      desafioId: "des-123",
      codigo: "654321",
      lembrarDispositivo: true,
      visitante: "198.51.100.77",
    });
    const cookies = resp.headers.getSetCookie();
    const dispositivo = cookies.find((c) => c.startsWith("__Host-frila-dispositivo="));
    expect(dispositivo).toContain("novo-device-token");
    expect(dispositivo).toContain("Max-Age=2592000");
    expect(dispositivo).toContain("HttpOnly");
    expect(dispositivo).toContain("SameSite=Lax");
    expect(dispositivo).toContain("Secure");
  });

  it("confirmar_desafio com precisaDefinirSenha=true redireciona para /definir-senha?origem=pendente mantendo dispositivo", async () => {
    authMock.confirmarDispositivoOtp.mockResolvedValue({
      ok: true,
      sessao: SESSAO_SINTETICA,
      precisaDefinirSenha: true,
      deviceToken: "novo-device-token",
    });
    const args = pedidoComCookies("/entrar", {
      email: "usuario@frila.test",
      desafio_id: "des-123",
      codigo: "654321",
      lembrar_dispositivo: "sim",
      intencao: "confirmar_desafio",
    });
    const resp = await capturaRedirect(() => entrarAction(args as never));
    expect(resp.headers.get("Location")).toBe("/definir-senha?origem=pendente");
    expect(resp.headers.getSetCookie().some((c) => c.includes("__Host-frila-dispositivo=novo-device-token"))).toBe(true);
  });

  it("autenticarSenha com precisaDefinirSenha=true redireciona para /definir-senha?origem=pendente", async () => {
    authMock.autenticarSenha.mockResolvedValue({
      ok: true,
      status: "autenticado",
      sessao: SESSAO_SINTETICA,
      precisaDefinirSenha: true,
    });
    const args = pedidoComCookies("/entrar", { email: "usuario@frila.test", senha: "senhaCorreta123" }, "__Host-frila-dispositivo=dev-tok-30d");
    const resp = await capturaRedirect(() => entrarAction(args as never));
    expect(resp.headers.get("Location")).toBe("/definir-senha?origem=pendente");
  });

  it("confirmar_desafio sem checkbox não grava cookie de dispositivo", async () => {
    const args = pedidoComCookies("/entrar", {
      email: "usuario@frila.test",
      desafio_id: "des-123",
      codigo: "654321",
      intencao: "confirmar_desafio",
    });
    const resp = await capturaRedirect(() => entrarAction(args as never));
    expect(resp.headers.getSetCookie().some((c) => c.includes("frila-dispositivo"))).toBe(false);
    expect(authMock.confirmarDispositivoOtp).toHaveBeenCalledWith(
      expect.objectContaining({ lembrarDispositivo: false }),
    );
  });

  it("reenviar_desafio chama reenviarDispositivoOtp preservando desafioId", async () => {
    const args = pedidoComCookies("/entrar", {
      email: "usuario@frila.test",
      desafio_id: "des-123",
      intencao: "reenviar_desafio",
    });
    const res = await entrarAction(args as never);
    expect(res).toEqual({ passo: "desafio", email: "usuario@frila.test", desafioId: "des-123", reenviado: true });
    expect(authMock.reenviarDispositivoOtp).toHaveBeenCalledWith({
      desafioId: "des-123",
      visitante: "198.51.100.77",
    });
  });

  it("regressão P1: intencao=pedir e intencao=confirmar em /entrar para conta não-demo são bloqueados", async () => {
    expect(await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", intencao: "pedir" }, false))).toEqual({
      passo: "email",
      email: "usuario@frila.test",
      erro: "codigo_apenas_demo",
    });
    expect(
      await entrarAction(argumentos("/entrar", { email: "usuario@frila.test", codigo: "123456", intencao: "confirmar" }, false)),
    ).toEqual({
      passo: "email",
      email: "usuario@frila.test",
      erro: "codigo_apenas_demo",
    });
    expect(authMock.pedirCodigo).not.toHaveBeenCalled();
    expect(authMock.confirmarCodigo).not.toHaveBeenCalled();
  });

  it("isolamento demo P2: conta demo entra somente via demo e é recusada na senha", async () => {
    expect(await entrarAction(argumentos("/entrar", { email: "demo@frila.test", senha: "123" }, false))).toEqual({
      passo: "email",
      email: "demo@frila.test",
      erro: "conta_demo",
    });
    expect(authMock.autenticarSenha).not.toHaveBeenCalled();

    const resp = await capturaRedirect(() =>
      entrarAction(argumentos("/entrar", { email: "demo@frila.test", codigo: "codigo-demo", intencao: "confirmar" }, false)),
    );
    expect(resp.headers.get("Location")).toBe("/");
    expect(authMock.entrarDemonstracao).toHaveBeenCalledWith("demo@frila.test", "codigo-demo");
  });
});

describe("rotas: criação de conta e recuperação com dispositivo opcional (criar-conta / recuperar-senha)", () => {
  it("criar-conta recusa demo e confirma via confirmarDispositivoOtp gravando cookie de dispositivo quando marcado", async () => {
    expect(await criarContaAction(argumentos("/criar-conta", { email: "demo@frila.test", intencao: "pedir" }, false))).toEqual({
      passo: "email",
      email: "demo@frila.test",
      erro: "conta_demo",
    });

    authMock.confirmarDispositivoOtp.mockResolvedValue({
      ok: true,
      sessao: SESSAO_SINTETICA,
      precisaDefinirSenha: true,
      deviceToken: "dev-cadastro",
    });
    const resp = await capturaRedirect(() =>
      criarContaAction(
        argumentos("/criar-conta", { email: "novo@frila.test", codigo: "123456", lembrar_dispositivo: "sim", intencao: "confirmar" }, false),
      ),
    );
    expect(resp.headers.get("Location")).toBe("/definir-senha?origem=cadastro");
    expect(resp.headers.getSetCookie().some((c) => c.includes("__Host-frila-dispositivo=dev-cadastro"))).toBe(true);
    expect(authMock.confirmarDispositivoOtp).toHaveBeenCalledWith(
      expect.objectContaining({ tipo: "cadastro", email: "novo@frila.test", codigo: "123456", lembrarDispositivo: true }),
    );
  });

  it("regressão P1 anti-enumeração: recuperar-senha existente e inexistente produzem estado idêntico", async () => {
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
  });

  it("recuperar-senha confirma via confirmarDispositivoOtp(tipo=recuperacao)", async () => {
    const resp = await capturaRedirect(() =>
      recuperarSenhaAction(
        argumentos("/recuperar-senha", { email: "existente@frila.test", codigo: "654321", intencao: "confirmar" }, false),
      ),
    );
    expect(resp.headers.get("Location")).toBe("/definir-senha?origem=recuperacao");
    expect(authMock.confirmarDispositivoOtp).toHaveBeenCalledWith(
      expect.objectContaining({ tipo: "recuperacao", email: "existente@frila.test", codigo: "654321", lembrarDispositivo: false }),
    );
  });

  it("loaders de criar-conta e recuperar-senha redirecionam para / quando já logado", async () => {
    expect((await capturaRedirect(() => criarContaLoader(argumentos("/criar-conta", undefined, true)))).headers.get("Location")).toBe("/");
    expect((await capturaRedirect(() => recuperarSenhaLoader(argumentos("/recuperar-senha", undefined, true)))).headers.get("Location")).toBe("/");
  });
});

describe("rotas: definir-senha, logout e trava SSR de precisa_definir_senha", () => {
  it("sem sessão, definir-senha loader redireciona para /entrar", async () => {
    const resp = await capturaRedirect(() => definirSenhaLoader(argumentos("/definir-senha", undefined, false)));
    expect(resp.headers.get("Location")).toBe("/entrar");
  });

  it("definir-senha em origem=cadastro, recuperacao e pendente preserva dispositivo apenas quando há cookie lembrado e pendência", async () => {
    const jwtPendente = jwtComAppMetadata({ precisa_definir_senha: true, dispositivo_verificado: true });
    for (const origem of ["cadastro", "recuperacao", "pendente"] as const) {
      authMock.definirSenha.mockClear();
      const args = pedidoComCookies(
        `/definir-senha?origem=${origem}`,
        { senha: "novaSenha123", confirmacao: "novaSenha123", origem },
        "__Host-frila-renovacao=ref-antigo; __Host-frila-dispositivo=dev-atual",
      );
      args.context.set(
        (await import("../app/contexto")).contextoDaSessao,
        { acesso: jwtPendente, usuarioId: "u1", email: "a@b.co", visitante: "198.51.100.77" },
      );
      const resp = await capturaRedirect(() => definirSenhaAction(args as never));
      expect(resp.headers.get("Location")).toBe("/");
      expect(authMock.definirSenha).toHaveBeenCalledWith({
        acesso: jwtPendente,
        novaSenha: "novaSenha123",
        manterDispositivoAtual: true,
        deviceTokenAtual: "dev-atual",
        refreshToken: "ref-antigo",
        visitante: "198.51.100.77",
      });
      expect(resp.headers.getSetCookie().some((c) => c.startsWith("__Host-frila-acesso="))).toBe(true);
      expect(resp.headers.getSetCookie().some((c) => c.startsWith("__Host-frila-dispositivo="))).toBe(false);
    }
  });

  it("definir-senha em origem=pendente sem cookie lembrado envia manterDispositivoAtual=false", async () => {
    const jwtPendente = jwtComAppMetadata({ precisa_definir_senha: true, dispositivo_verificado: true });
    const args = pedidoComCookies(
      "/definir-senha?origem=pendente",
      { senha: "novaSenha123", confirmacao: "novaSenha123", origem: "pendente" },
      "__Host-frila-renovacao=ref-antigo",
    );
    args.context.set(
      (await import("../app/contexto")).contextoDaSessao,
      { acesso: jwtPendente, usuarioId: "u1", email: "a@b.co", visitante: null },
    );
    const resp = await capturaRedirect(() => definirSenhaAction(args as never));
    expect(resp.headers.get("Location")).toBe("/");
    expect(authMock.definirSenha).toHaveBeenCalledWith(
      expect.objectContaining({ manterDispositivoAtual: false, deviceTokenAtual: null }),
    );
  });

  it("troca real de senha (alteracao ou JWT com precisa_definir_senha=false) revoga trust mesmo se origem=cadastro for forjado", async () => {
    const jwtSemPendencia = jwtComAppMetadata({ precisa_definir_senha: false, dispositivo_verificado: true });
    const args = pedidoComCookies(
      "/definir-senha?origem=cadastro",
      { senha: "novaSenha123", confirmacao: "novaSenha123", origem: "cadastro" },
      "__Host-frila-renovacao=ref-antigo; __Host-frila-dispositivo=dev-atual",
    );
    args.context.set(
      (await import("../app/contexto")).contextoDaSessao,
      { acesso: jwtSemPendencia, usuarioId: "u1", email: "a@b.co", visitante: null },
    );
    const resp = await capturaRedirect(() => definirSenhaAction(args as never));
    expect(resp.headers.get("Location")).toBe("/");
    expect(authMock.definirSenha).toHaveBeenCalledWith(
      expect.objectContaining({ manterDispositivoAtual: false }),
    );
    const devCookie = resp.headers.getSetCookie().find((c) => c.startsWith("__Host-frila-dispositivo="));
    expect(devCookie).toContain("Max-Age=0");
  });

  it("definir-senha em origem=alteracao revoga dispositivos e apaga __Host-frila-dispositivo local", async () => {
    const args = pedidoComCookies(
      "/definir-senha",
      { senha: "novaSenha123", confirmacao: "novaSenha123", origem: "alteracao" },
      "__Host-frila-renovacao=ref-antigo; __Host-frila-dispositivo=dev-atual",
    );
    args.context.set(
      (await import("../app/contexto")).contextoDaSessao,
      { acesso: "sintetico", usuarioId: "u1", email: "a@b.co", visitante: null },
    );
    const resp = await capturaRedirect(() => definirSenhaAction(args as never));
    expect(resp.headers.get("Location")).toBe("/");
    expect(authMock.definirSenha).toHaveBeenCalledWith(
      expect.objectContaining({ manterDispositivoAtual: false }),
    );
    const devCookie = resp.headers.getSetCookie().find((c) => c.startsWith("__Host-frila-dispositivo="));
    expect(devCookie).toContain("Max-Age=0");
  });

  it("logout normal (/sair) apaga sessão mas PRESERVA __Host-frila-dispositivo", async () => {
    const args = pedidoComCookies("/sair", {}, "__Host-frila-acesso=a; __Host-frila-renovacao=r; __Host-frila-dispositivo=dev-ok");
    args.context.set(
      (await import("../app/contexto")).contextoDaSessao,
      { acesso: "a", usuarioId: "u1", email: "a@b.co", visitante: null },
    );
    const resp = await capturaRedirect(() => sairAction(args as never));
    expect(resp.headers.get("Location")).toBe("/entrar");
    const cookies = resp.headers.getSetCookie();
    expect(cookies.some((c) => c.startsWith("__Host-frila-acesso=") && c.includes("Max-Age=0"))).toBe(true);
    expect(cookies.some((c) => c.startsWith("__Host-frila-renovacao=") && c.includes("Max-Age=0"))).toBe(true);
    expect(cookies.some((c) => c.includes("frila-dispositivo"))).toBe(false);
  });

  it("Sair de todos os dispositivos (/conta) chama revogarDispositivos e apaga __Host-frila-dispositivo", async () => {
    const resp = await capturaRedirect(() =>
      dadosAction(argumentos("/conta", { intencao: "revogar_dispositivos" }, true)),
    );
    expect(resp.headers.get("Location")).toBe("/entrar");
    expect(authMock.revogarDispositivos).toHaveBeenCalled();
    expect(resp.headers.getSetCookie().some((c) => c.startsWith("__Host-frila-dispositivo=") && c.includes("Max-Age=0"))).toBe(true);
  });

  it("SSR middleware bloqueia navegação para /app/vagas quando JWT tem precisa_definir_senha=true e permite /app/definir-senha", async () => {
    const jwtPendente = jwtComAppMetadata({ precisa_definir_senha: true, dispositivo_verificado: true });
    const reqBloqueado = new Request("https://frilabr.com/app/vagas", {
      headers: { Cookie: `__Host-frila-acesso=${jwtPendente}; __Host-frila-renovacao=r1` },
    });
    const resBloqueado = (await middlewareDeSessao(
      { request: reqBloqueado, context: new RouterContextProvider(), params: {}, unstable_pattern: "" } as never,
      async () => new Response("ok"),
    )) as Response;
    expect(resBloqueado.status).toBe(302);
    expect(resBloqueado.headers.get("Location")).toBe("https://frilabr.com/app/definir-senha?origem=pendente");

    const reqPermitido = new Request("https://frilabr.com/app/definir-senha", {
      headers: { Cookie: `__Host-frila-acesso=${jwtPendente}; __Host-frila-renovacao=r1` },
    });
    const resPermitido = (await middlewareDeSessao(
      { request: reqPermitido, context: new RouterContextProvider(), params: {}, unstable_pattern: "" } as never,
      async () => new Response("tela-definir-senha", { status: 200 }),
    )) as Response;
    expect(resPermitido.status).toBe(200);
  });
});

describe("Decisão A1: CTA 'Criar ou recuperar senha' e erro codigo_apenas_demo com basename='/app' real", () => {
  function EntrarRoteada() {
    return createElement(Entrar, {
      loaderData: useLoaderData(),
      actionData: useActionData(),
    } as never);
  }

  function criarRoteadorEntrar() {
    return createStaticHandler(
      [
        {
          id: "entrar",
          path: "entrar",
          loader: entrarLoader as never,
          action: entrarAction as never,
          Component: EntrarRoteada,
        },
        {
          id: "recuperar-senha",
          path: "recuperar-senha",
          loader: () => null,
        },
        {
          id: "criar-conta",
          path: "criar-conta",
          loader: () => null,
        },
      ],
      { basename: "/app" },
    );
  }

  async function renderizarViaRoteador(request: Request): Promise<string> {
    const handler = criarRoteadorEntrar();
    const contexto = await handler.query(request);
    if (contexto instanceof Response) throw contexto;
    const roteador = createStaticRouter(handler.dataRoutes, contexto);
    return renderToStaticMarkup(
      createElement(StaticRouterProvider, { router: roteador, context: contexto, hydrate: false }),
    );
  }

  it("GET /app/entrar exibe CTA 'Criar ou recuperar senha' apontando para /app/recuperar-senha sem /app/app/", async () => {
    const html = await renderizarViaRoteador(new Request("https://frilabr.com/app/entrar"));
    expect(html).toContain('href="/app/recuperar-senha"');
    expect(html).toContain("Criar ou recuperar senha");
    expect(html).toContain('href="/app/criar-conta"');
    expect(html).not.toContain("/app/app/");
  });

  it("POST /app/entrar intencao=pedir para conta real/inexistente exibe erro codigo_apenas_demo acessível com link /app/recuperar-senha sem enumerar conta", async () => {
    const formExistente = new URLSearchParams({ email: "existente@frila.test", intencao: "pedir" });
    const formInexistente = new URLSearchParams({ email: "naoexiste@frila.test", intencao: "pedir" });

    const htmlExistente = await renderizarViaRoteador(
      new Request("https://frilabr.com/app/entrar", { method: "POST", body: formExistente }),
    );
    const htmlInexistente = await renderizarViaRoteador(
      new Request("https://frilabr.com/app/entrar", { method: "POST", body: formInexistente }),
    );

    for (const html of [htmlExistente, htmlInexistente]) {
      expect(html).toContain('role="alert"');
      expect(html).toContain("Contas reais entram com senha");
      expect(html).toContain('href="/app/recuperar-senha"');
      expect(html).toContain("Criar ou recuperar senha");
      expect(html).not.toContain("/app/app/");
    }
    expect(htmlExistente.replace("existente@frila.test", "x")).toBe(
      htmlInexistente.replace("naoexiste@frila.test", "x"),
    );
  });
});
