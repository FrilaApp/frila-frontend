import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as agirNaVaga, loader as carregarVaga } from "../app/rotas/profissional/vaga";
import { criarApi } from "../app/servidor/api";
import { candidatar, listarMinhasCandidaturas, retirarCandidatura } from "../app/servidor/profissional/candidaturas";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const VAGA_ID = "7b84c3e2-8e3b-4f9e-a0e2-1a2b3c4d5e6f";
const CANDIDATURA_ID = "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88";

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

describe("candidatar-se", () => {
  it("manda o vaga_id e devolve confirmada (urgência) ou pendente (seleção)", async () => {
    const urgencia = apiQueResponde(() => Response.json({ estado: "confirmada", candidatura_id: CANDIDATURA_ID, posicao_id: null, turno_id: null }));
    expect(await candidatar(urgencia.api, VAGA_ID)).toEqual({ ok: true, estado: "confirmada" });
    expect(new URL(urgencia.pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/candidatar");
    expect(await urgencia.pedidos[0]?.json()).toEqual({ vaga_id: VAGA_ID });
    const selecao = apiQueResponde(() => Response.json({ estado: "pendente", candidatura_id: CANDIDATURA_ID, posicao_id: null, turno_id: null }));
    expect(await candidatar(selecao.api, VAGA_ID)).toEqual({ ok: true, estado: "pendente" });
  });

  it("traduz cada recusa do contrato", async () => {
    const casos: Array<[() => Response, string]> = [
      [recusa(409, "posicao_ja_preenchida"), "preenchida"],
      [recusa(409, "vaga_encerrada"), "encerrada"],
      [recusa(422, "inelegivel", "turno_sobreposto"), "turno_sobreposto"],
      [recusa(422, "inelegivel", "perfil_suspenso"), "perfil_suspenso"],
      [recusa(422, "inelegivel", "funcao_incompativel"), "funcao_incompativel"],
      [recusa(422, "perfil_incompativel"), "perfil_incompativel"],
      [recusa(404, "nao_encontrado"), "nao_encontrada"],
      [recusa(401, "nao_autenticado"), "sem_sessao"],
      [recusa(500, "erro"), "indisponivel"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await candidatar(apiQueResponde(resposta).api, VAGA_ID), motivo).toEqual({ ok: false, motivo });
    }
    expect(await candidatar(apiQueResponde(() => Promise.reject(new TypeError("rede"))).api, VAGA_ID)).toEqual({
      ok: false,
      motivo: "indisponivel",
    });
  });

  it("id torto não chega ao servidor", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json({}));
    expect(await candidatar(api, "x")).toEqual({ ok: false, motivo: "nao_encontrada" });
    expect(pedidos).toHaveLength(0);
  });
});

describe("retirar e listar", () => {
  it("retira pelo candidatura_id; já decidida é 409", async () => {
    const ok = apiQueResponde(() => Response.json({ id: CANDIDATURA_ID }));
    expect(await retirarCandidatura(ok.api, CANDIDATURA_ID)).toEqual({ ok: true });
    expect(await ok.pedidos[0]?.json()).toEqual({ candidatura_id: CANDIDATURA_ID });
    expect(await retirarCandidatura(apiQueResponde(recusa(409, "candidatura_indisponivel")).api, CANDIDATURA_ID)).toEqual({
      ok: false,
      motivo: "ja_decidida",
    });
  });

  it("lista as candidaturas e traduz as recusas", async () => {
    expect(await listarMinhasCandidaturas(apiQueResponde(() => Response.json([])).api)).toEqual({ estado: "ok", candidaturas: [] });
    expect(await listarMinhasCandidaturas(apiQueResponde(recusa(422, "perfil_incompativel")).api)).toEqual({
      estado: "perfil_incompativel",
    });
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string> | null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com", visitante: null } : null);
  const url = `https://frilabr.com/app/vagas/${VAGA_ID}`;
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: { vagaId: VAGA_ID }, url: new URL(url), matches: [] } as never;
};
const ok = (corpo: unknown) => ({ data: corpo, response: new Response(null, { status: 200 }) });

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("tela da vaga: envio", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    await expect(agirNaVaga(argumentos({ intencao: "candidatar" }, false))).rejects.toHaveProperty("status", 302);
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("candidatar manda a vaga do endereço e devolve o resultado para a tela", async () => {
    api.POST.mockResolvedValue(ok({ estado: "pendente", candidatura_id: CANDIDATURA_ID, posicao_id: null, turno_id: null }));
    expect(await agirNaVaga(argumentos({ intencao: "candidatar" }))).toEqual({ resultado: "pendente" });
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/candidatar");
    expect(api.POST.mock.calls[0]?.[1].body).toEqual({ vaga_id: VAGA_ID });
  });

  it("retirar manda a candidatura do formulário", async () => {
    api.POST.mockResolvedValue(ok({ id: CANDIDATURA_ID }));
    expect(await agirNaVaga(argumentos({ intencao: "retirar", candidatura_id: CANDIDATURA_ID }))).toEqual({ resultado: "retirada" });
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/retirar_candidatura");
  });

  it("o servidor diz que a sessão caiu: manda entrar", async () => {
    api.POST.mockResolvedValue({ error: { code: "nao_autenticado" }, response: new Response(null, { status: 401 }) });
    await expect(agirNaVaga(argumentos({ intencao: "candidatar" }))).rejects.toHaveProperty("status", 302);
  });
});

describe("tela da vaga: a candidatura da pessoa", () => {
  it("mostra a candidatura mais recente nesta vaga, sem dado de outras", async () => {
    const vaga = {
      id: VAGA_ID,
      funcao: { id: "f1", nome: "Garçom", categoria: "Salão" },
      estabelecimento: { id: "e1", tipo: "estabelecimento", nome: "Casa", reputacao: {} },
      inicio_em: "2026-11-21T22:00:00Z",
      fim_em: "2026-11-22T05:00:00Z",
      local: "Asa Norte",
      regiao_administrativa: "Plano Piloto",
      valor_centavos: 15000,
      posicoes: 2,
      posicoes_abertas: 2,
      inclusos: { inclui_refeicao: false, inclui_transporte: false, exige_material_proprio: false },
      responsavel_local: "Gerente",
      modo: "selecao",
      estado: "publicada",
      oculta: false,
    };
    const resumo = { id: VAGA_ID, funcao: "Garçom", local: "x", regiao_administrativa: "y", inicio_em: "a", fim_em: "b", valor_centavos: 1 };
    api.GET.mockImplementation(async (caminho: string) =>
      caminho === "/rpc/detalhe_vaga"
        ? ok(vaga)
        : ok([
            { id: "antiga", vaga: resumo, estado: "retirada", criada_em: "2026-11-16T10:00:00Z" },
            { id: CANDIDATURA_ID, vaga: resumo, estado: "pendente", criada_em: "2026-11-17T10:00:00Z" },
            { id: "outra", vaga: { ...resumo, id: "outra-vaga" }, estado: "aceita", criada_em: "2026-11-18T10:00:00Z" },
          ]),
    );
    const dados = (await carregarVaga(argumentos(null))) as { candidatura: unknown };
    expect(dados.candidatura).toEqual({ id: CANDIDATURA_ID, estado: "pendente" });
  });
});
