import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as salvarPerfil, loader as carregarPerfil } from "../app/rotas/profissional/perfil";
import { criarApi } from "../app/servidor/api";
import { lerMeuPerfil, salvarApresentacao } from "../app/servidor/profissional/perfil";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const perfil = {
  id: "p1",
  usuario_id: "u1",
  funcoes: [{ id: "f1", nome: "Garçom", categoria: "Salão" }],
  ponto_base: { latitude: -15.79, longitude: -47.88 },
  disponibilidades: [],
  reputacao: { positivas: 3, total: 4, taxa_comparecimento: null },
  servicos: [],
  regioes: [{ id: 1, numero: "I", nome: "Plano Piloto" }],
  atende_todo_df: false,
  cursos: [],
  idiomas: [],
  apresentacao: "Garçom há 5 anos.",
  onde_trabalhei: null,
};

function apiQueResponde(resposta: () => Response | Promise<Response>) {
  const pedidos: Request[] = [];
  const api = criarApi(ambiente, {
    token: "t",
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { api, pedidos };
}
const recusa = (status: number, code: string, details: string | null = null) => () =>
  Response.json({ code, message: code, details, hint: null }, { status });

describe("perfil do profissional (servidor)", () => {
  it("lê o perfil detalhado e traduz 404 e recusas", async () => {
    expect(await lerMeuPerfil(apiQueResponde(() => Response.json(perfil)).api)).toEqual({ estado: "ok", perfil });
    expect(await lerMeuPerfil(apiQueResponde(recusa(404, "nao_encontrado")).api)).toEqual({ estado: "sem_perfil" });
    expect(await lerMeuPerfil(apiQueResponde(recusa(422, "perfil_incompativel")).api)).toEqual({ estado: "perfil_incompativel" });
  });

  it("salva os dois textos; vazio limpa (null)", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(perfil));
    expect(await salvarApresentacao(api, { apresentacao: "  Garçom.  ", onde_trabalhei: "  " })).toEqual({ ok: true });
    expect(await pedidos[0]?.json()).toEqual({ apresentacao: "Garçom.", onde_trabalhei: null });
  });

  it("texto longo demais nem sai; filtro de contato e chave desligada viram aviso", async () => {
    const longo = apiQueResponde(() => Response.json(perfil));
    expect(await salvarApresentacao(longo.api, { apresentacao: "a".repeat(601), onde_trabalhei: "" })).toEqual({
      ok: false,
      motivo: "longo_demais",
      campo: "apresentacao",
    });
    expect(longo.pedidos).toHaveLength(0);
    expect(await salvarApresentacao(apiQueResponde(recusa(422, "campo_invalido", "onde_trabalhei")).api, { apresentacao: "", onde_trabalhei: "x" })).toEqual({
      ok: false,
      motivo: "campo_recusado",
      campo: "onde_trabalhei",
    });
    expect(await salvarApresentacao(apiQueResponde(recusa(403, "sem_permissao", "recurso_desligado")).api, { apresentacao: "x", onde_trabalhei: "" })).toEqual({
      ok: false,
      motivo: "recurso_desligado",
    });
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string> | null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com", visitante: null } : null);
  const url = "https://frilabr.com/app/perfil";
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: {}, url: new URL(url), matches: [] } as never;
};

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("tela do perfil", () => {
  it("sem sessão, manda entrar", async () => {
    await expect(carregarPerfil(argumentos(null, false))).rejects.toHaveProperty("status", 302);
    await expect(salvarPerfil(argumentos({ apresentacao: "x" }, false))).rejects.toHaveProperty("status", 302);
    expect(api.GET).not.toHaveBeenCalled();
  });

  it("não manda ponto base nem disponibilidade ao navegador", async () => {
    api.GET.mockResolvedValue({ data: perfil, response: new Response() });
    const dados = await carregarPerfil(argumentos(null));
    expect(dados.perfil).toEqual({ funcoes: ["Garçom"], regioes: ["Plano Piloto"], positivas: 3, total: 4, apresentacao: "Garçom há 5 anos.", ondeTrabalhei: "" });
    expect(JSON.stringify(dados)).not.toContain("-15.79");
  });

  it("salvar devolve o resultado e o campo recusado", async () => {
    api.POST.mockResolvedValueOnce({ data: perfil, response: new Response() });
    expect(await salvarPerfil(argumentos({ apresentacao: "a", onde_trabalhei: "" }))).toEqual({ resultado: "salvo", campo: null });
    api.POST.mockResolvedValueOnce({ error: { code: "campo_invalido", details: "apresentacao" }, response: new Response(null, { status: 422 }) });
    expect(await salvarPerfil(argumentos({ apresentacao: "me chama no zap", onde_trabalhei: "" }))).toEqual({
      resultado: "campo_recusado",
      campo: "apresentacao",
    });
  });
});
