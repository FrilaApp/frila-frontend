/**
 * Achado da revisão do #836 (Lince Codex): o aceite tem de gravar a versão dos Termos que a pessoa VIU.
 * Uma página aberta na versão A e enviada depois da publicação da B não pode registrar a B: a tela volta com os
 * termos atuais para um novo aceite, sem gravar nada. Dados sintéticos e API simulada.
 */
import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as aceitar } from "../app/rotas/aceitar-termos";
import { action as cadastrar, loader as carregarCadastro } from "../app/rotas/cadastro";
import { VERSAO_DOS_TERMOS } from "../app/versao";

const api = vi.hoisted(() => ({ POST: vi.fn(), GET: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const VERSAO_ANTIGA = "2026-11-13";
const campos = {
  perfil: "profissional",
  nome: "Pessoa Sintética",
  telefone: "(11) 99999-0000",
  nascimento: "1990-04-12",
  aceite: "sim",
};

function argumentos(dados: Record<string, string>, caminho = "/app/cadastro") {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, { acesso: "sintetico", usuarioId: "u1", email: "pessoa@example.com" });
  const request = new Request(`https://frilabr.com${caminho}`, {
    method: "POST",
    headers: { Origin: "https://frilabr.com" },
    body: new URLSearchParams(dados),
  });
  return { request, context, params: {}, url: new URL(request.url), matches: [] } as never;
}

async function redirecionamento(promessa: Promise<unknown>): Promise<Response> {
  try {
    await promessa;
  } catch (resposta) {
    if (resposta instanceof Response) return resposta;
    throw resposta;
  }
  throw new Error("esperava um redirect");
}

beforeEach(() => {
  api.POST.mockReset().mockResolvedValue({
    data: { id: "u1", termos_versao: VERSAO_DOS_TERMOS },
    response: new Response(null, { status: 200 }),
  });
  api.GET.mockReset().mockResolvedValue({ response: new Response(null, { status: 404 }) });
});

describe("revisão do #836: cadastro grava a versão que a pessoa viu", () => {
  it("o formulário do cadastro recebe a versão atual dos termos", async () => {
    const dados = (await carregarCadastro(argumentos({}))) as { termosVersao?: string };
    expect(dados.termosVersao).toBe(VERSAO_DOS_TERMOS);
  });

  it("formulário mostrado na versão antiga: não grava e pede um novo aceite", async () => {
    const retorno = await cadastrar(argumentos({ ...campos, termos_versao: VERSAO_ANTIGA }));
    expect(api.POST).not.toHaveBeenCalled();
    expect(retorno.erros.aceite).toBeTruthy();
    expect(retorno.valores.nome).toBe(campos.nome);
  });

  it("formulário sem a versão: não grava e pede um novo aceite", async () => {
    const retorno = await cadastrar(argumentos(campos));
    expect(api.POST).not.toHaveBeenCalled();
    expect(retorno.erros.aceite).toBeTruthy();
  });

  it("formulário na versão atual: grava essa versão", async () => {
    await redirecionamento(cadastrar(argumentos({ ...campos, termos_versao: VERSAO_DOS_TERMOS })));
    expect(api.POST).toHaveBeenCalledOnce();
    expect(api.POST.mock.calls[0]?.[1].body.termos_versao).toBe(VERSAO_DOS_TERMOS);
  });
});

describe("revisão do #836: novo aceite grava a versão que a pessoa viu", () => {
  it("aceite enviado da versão antiga: não grava e volta ao início com os termos atuais", async () => {
    const resposta = await redirecionamento(aceitar(argumentos({ termos_versao: VERSAO_ANTIGA }, "/app/aceitar-termos")));
    expect(api.POST).not.toHaveBeenCalled();
    expect(resposta.headers.get("Location")).toBe("/?termos=mudou");
  });

  it("aceite sem a versão: não grava", async () => {
    const resposta = await redirecionamento(aceitar(argumentos({}, "/app/aceitar-termos")));
    expect(api.POST).not.toHaveBeenCalled();
    expect(resposta.headers.get("Location")).toBe("/?termos=mudou");
  });

  it("aceite na versão atual: grava essa versão", async () => {
    const resposta = await redirecionamento(aceitar(argumentos({ termos_versao: VERSAO_DOS_TERMOS }, "/app/aceitar-termos")));
    expect(api.POST.mock.calls[0]?.[1].body).toEqual({ termos_versao: VERSAO_DOS_TERMOS });
    expect(resposta.headers.get("Location")).toBe("/");
  });
});
