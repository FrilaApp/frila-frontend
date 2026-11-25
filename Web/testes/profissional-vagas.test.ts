import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { loader as carregarVaga } from "../app/rotas/profissional/vaga";
import { loader as carregarVagas } from "../app/rotas/profissional/vagas";
import { criarApi } from "../app/servidor/api";
import { formatarDistancia, formatarPeriodo, formatarValor } from "../app/servidor/profissional/formato";
import { aceitaCandidatura, filtrosDaUrl, listarVagasAbertas, lerVaga, type Vaga, type VagaNaLista } from "../app/servidor/profissional/vagas";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const VAGA_ID = "7b84c3e2-8e3b-4f9e-a0e2-1a2b3c4d5e6f";
const reputacao = { avaliacoes: 0 } as unknown as VagaNaLista["estabelecimento"]["reputacao"];
const naLista: VagaNaLista = {
  id: VAGA_ID,
  funcao: { id: "f1", nome: "Garçom", categoria: "Salão" },
  estabelecimento: { id: "e1", tipo: "estabelecimento", nome: "Casa Sintética", reputacao },
  inicio_em: "2026-11-21T22:00:00Z",
  fim_em: "2026-11-22T05:00:00Z",
  local: "Asa Norte",
  regiao_administrativa: "Plano Piloto",
  distancia_km: 3.25,
  valor_centavos: 15000,
  posicoes_abertas: 2,
  inclusos: { inclui_refeicao: true, inclui_transporte: false, exige_material_proprio: false },
  modo: "urgencia",
};
const detalhe = {
  ...naLista,
  ponto: { latitude: -15.79, longitude: -47.88 },
  posicoes: 2,
  responsavel_local: "Gerente do salão",
  estado: "publicada",
  oculta: false,
  publicado_em: "2026-11-17T03:00:00Z",
} as unknown as Vaga;

function apiQueResponde(resposta: () => Response | Promise<Response>) {
  const pedidos: Request[] = [];
  const api = criarApi(ambiente, {
    token: "token-do-usuario",
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { api, pedidos };
}
const recusa = (status: number, code: string, details: string | null = null) => () =>
  Response.json({ code, message: code, details, hint: null }, { status });
const semFiltro = { data: null, distanciaMaxKm: null, deslocamento: 0 };

describe("lista de vagas abertas", () => {
  it("pede pelo ponto base: sem latitude e longitude, com limite e deslocamento", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json([naLista]));
    expect(await listarVagasAbertas(api, { data: "2026-11-21", distanciaMaxKm: 10, deslocamento: 30 })).toEqual({
      estado: "ok",
      vagas: [naLista],
      temMais: false,
    });
    const url = new URL(pedidos[0]?.url ?? "");
    expect(url.pathname).toBe("/rest/v1/rpc/vagas_abertas");
    expect(url.searchParams.has("latitude")).toBe(false);
    expect(url.searchParams.has("longitude")).toBe(false);
    expect(Object.fromEntries(url.searchParams)).toEqual({ limite: "30", deslocamento: "30", data: "2026-11-21", distancia_max_km: "10" });
    expect(pedidos[0]?.headers.get("Authorization")).toBe("Bearer token-do-usuario");
  });

  it("página cheia indica que há mais", async () => {
    const { api } = apiQueResponde(() => Response.json(Array.from({ length: 30 }, () => naLista)));
    const leitura = await listarVagasAbertas(api, semFiltro);
    expect(leitura.estado === "ok" && leitura.temMais).toBe(true);
  });

  it("traduz cada recusa do contrato", async () => {
    const casos: Array<[() => Response, string]> = [
      [recusa(422, "campo_obrigatorio", "latitude"), "sem_ponto_base"],
      [recusa(422, "perfil_incompativel"), "perfil_incompativel"],
      [recusa(403, "conta_suspensa"), "conta_suspensa"],
      [recusa(500, "erro"), "indisponivel"],
      [recusa(422, "campo_invalido", "limite"), "indisponivel"],
    ];
    for (const [resposta, estado] of casos) {
      const { api } = apiQueResponde(resposta);
      expect((await listarVagasAbertas(api, semFiltro)).estado, estado).toBe(estado);
    }
    const { api } = apiQueResponde(() => Promise.reject(new TypeError("rede")));
    expect((await listarVagasAbertas(api, semFiltro)).estado).toBe("indisponivel");
    expect((await listarVagasAbertas(null, semFiltro)).estado).toBe("indisponivel");
  });

  it("filtros da URL: o que não serve é ignorado", () => {
    expect(filtrosDaUrl(new URL("https://x/app/vagas?data=2026-11-21&distancia=10&deslocamento=30"))).toEqual({
      data: "2026-11-21",
      distanciaMaxKm: 10,
      deslocamento: 30,
    });
    expect(filtrosDaUrl(new URL("https://x/app/vagas?data=amanha&distancia=-1&deslocamento=1.5"))).toEqual(semFiltro);
    expect(filtrosDaUrl(new URL("https://x/app/vagas?distancia=9999"))).toEqual(semFiltro);
  });
});

describe("detalhe da vaga", () => {
  it("id que não é uuid nem chega ao servidor", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(detalhe));
    expect(await lerVaga(api, "nao-e-uuid")).toEqual({ estado: "nao_encontrada" });
    expect(pedidos).toHaveLength(0);
  });

  it("lê pelo vaga_id e traduz 404 e as recusas", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(detalhe));
    expect(await lerVaga(api, VAGA_ID)).toEqual({ estado: "ok", vaga: detalhe });
    expect(new URL(pedidos[0]?.url ?? "").searchParams.get("vaga_id")).toBe(VAGA_ID);
    expect(await lerVaga(apiQueResponde(recusa(404, "nao_encontrado")).api, VAGA_ID)).toEqual({ estado: "nao_encontrada" });
    expect(await lerVaga(apiQueResponde(recusa(422, "perfil_incompativel")).api, VAGA_ID)).toEqual({ estado: "perfil_incompativel" });
  });

  it("o botão de candidatura segue só estado e posições abertas", () => {
    expect(aceitaCandidatura(detalhe)).toBe(true);
    expect(aceitaCandidatura({ ...detalhe, posicoes_abertas: 0 })).toBe(false);
    expect(aceitaCandidatura({ ...detalhe, estado: "preenchida" })).toBe(false);
  });
});

describe("formatação no fuso de Brasília", () => {
  it("valor, período e distância", () => {
    expect(formatarValor(15000).replace(/\s/g, " ")).toBe("R$ 150,00");
    expect(formatarPeriodo("2026-11-21T22:00:00Z", "2026-11-22T05:00:00Z")).toBe("sáb., 21/11 · 19:00 às 02:00");
    expect(formatarDistancia(3.25)).toBe("3,3 km");
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const contexto = (logado = true) => {
  const c = new RouterContextProvider();
  c.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com", visitante: null } : null);
  return c;
};
const argumentos = (url: string, logado = true, params: Record<string, string> = {}) =>
  ({ request: new Request(url), context: contexto(logado), params, url: new URL(url), matches: [] }) as never;

beforeEach(() => {
  api.GET.mockReset();
});

describe("telas do profissional (loaders)", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    await expect(carregarVagas(argumentos("https://frilabr.com/app/vagas", false))).rejects.toHaveProperty("status", 302);
    await expect(carregarVaga(argumentos(`https://frilabr.com/app/vagas/${VAGA_ID}`, false, { vagaId: VAGA_ID }))).rejects.toHaveProperty(
      "status",
      302,
    );
    expect(api.GET).not.toHaveBeenCalled();
  });

  it("a lista devolve só o que a tela mostra, já formatado, sem token", async () => {
    api.GET.mockResolvedValue({ data: [naLista], response: new Response(null, { status: 200 }) });
    const dados = await carregarVagas(argumentos("https://frilabr.com/app/vagas"));
    expect(dados.estado).toBe("ok");
    expect(dados.vagas[0]).toMatchObject({ funcao: "Garçom", casa: "Casa Sintética", regiao: "Plano Piloto", posicoes: 2 });
    expect(JSON.stringify(dados)).not.toContain("token-sintetico");
  });

  it("vaga inexistente responde 404", async () => {
    api.GET.mockResolvedValue({ error: { code: "nao_encontrado" }, response: new Response(null, { status: 404 }) });
    const resposta = (await carregarVaga(argumentos(`https://frilabr.com/app/vagas/${VAGA_ID}`, true, { vagaId: VAGA_ID }))) as {
      init: ResponseInit | null;
      data: { estado: string };
    };
    expect(resposta.init?.status).toBe(404);
    expect(resposta.data.estado).toBe("nao_encontrada");
  });
});
