import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { loader as carregarPerfil } from "../app/rotas/contratante/profissional";
import { criarApi } from "../app/servidor/api";
import { lerPerfilDoProfissional } from "../app/servidor/contratante/perfil-profissional";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const PRO = "5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c8d";
const perfil = (extra: Record<string, unknown> = {}) => ({
  id: PRO,
  tipo: "profissional",
  nome: "Pessoa Sintética da Silva",
  funcoes: ["garçom", "barman"],
  reputacao: { positivas: 7, total: 8, turnos_realizados: 9, taxa_comparecimento: 0.9, turnos_considerados: 10 },
  apresentacao: "Trabalho com eventos há anos.",
  experiencia_faixa: "de_3_a_5_anos",
  onde_trabalhei: "Buffet de casamento",
  cursos: ["Boas práticas"],
  idiomas: ["portugues", "libras"],
  regioes: [{ id: 1, numero: "I", nome: "Plano Piloto" }],
  atende_todo_df: false,
  ...extra,
});

function apiQueResponde(resposta: () => Response) {
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

describe("perfil do profissional (servidor)", () => {
  it("lê perfil_publico pelo id; só serve perfil de profissional", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(perfil()));
    expect((await lerPerfilDoProfissional(api, PRO)).estado).toBe("ok");
    const url = new URL(pedidos[0]?.url ?? "");
    expect(url.pathname).toBe("/rest/v1/rpc/perfil_publico");
    expect(url.searchParams.get("id")).toBe(PRO);
    expect((await lerPerfilDoProfissional(apiQueResponde(() => Response.json(perfil({ tipo: "estabelecimento" }))).api, PRO)).estado).toBe("nao_encontrado");
  });

  it("404 (inexistente ou bloqueio, sem distinguir) e id torto viram 'indisponível para você'; falha vira indisponível", async () => {
    const naoAchou = () => Response.json({ code: "nao_encontrado", message: "x" }, { status: 404 });
    expect((await lerPerfilDoProfissional(apiQueResponde(naoAchou).api, PRO)).estado).toBe("nao_encontrado");
    const torto = apiQueResponde(() => Response.json(perfil()));
    expect((await lerPerfilDoProfissional(torto.api, "../x")).estado).toBe("nao_encontrado");
    expect(torto.pedidos).toHaveLength(0);
    expect((await lerPerfilDoProfissional(apiQueResponde(() => new Response(null, { status: 503 })).api, PRO)).estado).toBe("indisponivel");
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn(), foto: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api, fotoDoProfissional: api.foto }));
const argumentos = (busca = "", logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "c@example.com" } : null);
  const url = `https://frilabr.com/app/casa/profissionais/${PRO}${busca}`;
  return { request: new Request(url), context, params: { profissionalId: PRO }, url: new URL(url), matches: [] } as never;
};
const ok = (corpo: unknown) => ({ data: corpo, response: new Response(null, { status: 200 }) });

beforeEach(() => {
  api.GET.mockReset();
  api.foto.mockReset().mockResolvedValue(null);
});

describe("tela do perfil do profissional, do lado da casa", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    await expect(carregarPerfil(argumentos("", false))).rejects.toHaveProperty("status", 302);
    expect(api.GET).not.toHaveBeenCalled();
  });

  it("mostra a reputação com denominador e os rótulos do app; não devolve token", async () => {
    api.GET.mockResolvedValue(ok(perfil()));
    const dados = (await carregarPerfil(argumentos())) as { perfil: Record<string, unknown> };
    expect(dados.perfil).toMatchObject({
      nome: "Pessoa Sintética da Silva",
      funcoes: ["garçom", "barman"],
      chamariamDeNovo: "7 de 8 chamariam de novo",
      experiencia: "3 a 5 anos",
      idiomas: ["Português", "Libras"],
      regioes: ["Plano Piloto"],
    });
    expect(JSON.stringify(dados)).not.toContain("token-sintetico");
  });

  it("sem histórico diz 'Sem histórico', nunca nota zero", async () => {
    api.GET.mockResolvedValue(ok(perfil({ reputacao: { positivas: 0, total: 0, turnos_realizados: 0, taxa_comparecimento: null, turnos_considerados: 0 } })));
    expect(((await carregarPerfil(argumentos())) as { perfil: Record<string, unknown> }).perfil).toMatchObject({ chamariamDeNovo: "Sem histórico", comparecimento: null });
  });

  it("perfil indisponível responde 404, sem dizer se houve bloqueio", async () => {
    api.GET.mockResolvedValue({ error: { code: "nao_encontrado" }, response: new Response(null, { status: 404 }) });
    expect(((await carregarPerfil(argumentos())) as { init: ResponseInit | null }).init?.status).toBe(404);
  });

  it("o voltar só aceita caminho da própria casa; endereço de fora cai no painel", async () => {
    api.GET.mockResolvedValue(ok(perfil()));
    const volta = (busca: string) => async () => ((await carregarPerfil(argumentos(busca))) as { volta: string }).volta;
    expect(await volta(`?volta=${encodeURIComponent("/painel/vagas/abc?casa=x")}`)()).toBe("/painel/vagas/abc?casa=x");
    for (const ruim of ["//evil.example", "https://evil.example", "/\\evil", "javascript:alert(1)"]) {
      expect(await volta(`?volta=${encodeURIComponent(ruim)}`)(), ruim).toBe("/painel");
    }
  });
  it("a foto embutida (data:) entra no perfil; sem foto, sem imagem; no perfil indisponível, nada", async () => {
    api.GET.mockResolvedValue(ok(perfil()));
    api.foto.mockResolvedValue("data:image/jpeg;base64,AAAA");
    expect(((await carregarPerfil(argumentos())) as { perfil: { foto: string | null } }).perfil.foto).toBe("data:image/jpeg;base64,AAAA");
    expect(api.foto).toHaveBeenCalledWith("token-sintetico", PRO);
    api.GET.mockResolvedValue({ error: { code: "nao_encontrado" }, response: new Response(null, { status: 404 }) });
    expect(JSON.stringify(await carregarPerfil(argumentos()))).not.toContain("data:image");
  });
});
