import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as responder, loader as carregarChamada } from "../app/rotas/profissional/chamada";
import { criarApi } from "../app/servidor/api";
import { lerChamada, listarChamadas, responderChamada } from "../app/servidor/profissional/chamadas";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const CHAMADA_ID = "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88";

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

describe("chamadas (servidor)", () => {
  it("lista por cursor e traduz o recurso desligado", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json({ itens: [], proximo_cursor: "c2" }));
    expect(await listarChamadas(api, "c1")).toEqual({ estado: "ok", itens: [], proximoCursor: "c2" });
    expect(new URL(pedidos[0]?.url ?? "").searchParams.get("cursor")).toBe("c1");
    expect(await listarChamadas(apiQueResponde(recusa(403, "sem_permissao", "recurso_desligado")).api, null)).toEqual({ estado: "recurso_desligado" });
  });

  it("detalhe: id torto não sai; 404 é não encontrada", async () => {
    const torto = apiQueResponde(() => Response.json({}));
    expect(await lerChamada(torto.api, "x")).toEqual({ estado: "nao_encontrada" });
    expect(torto.pedidos).toHaveLength(0);
    expect(await lerChamada(apiQueResponde(recusa(404, "nao_encontrado")).api, CHAMADA_ID)).toEqual({ estado: "nao_encontrada" });
  });

  it("responder: aceitar sem motivo; recusar com a categoria", async () => {
    const aceitou = apiQueResponde(() => Response.json({ chamada: { estado: "aceita" }, turno_id: "t1" }));
    expect(await responderChamada(aceitou.api, CHAMADA_ID, "aceitar", "valor")).toEqual({ ok: true, aceita: true });
    expect(await aceitou.pedidos[0]?.json()).toEqual({ chamada_id: CHAMADA_ID, resposta: "aceitar" });
    const recusou = apiQueResponde(() => Response.json({ chamada: { estado: "recusada" } }));
    expect(await responderChamada(recusou.api, CHAMADA_ID, "recusar", "agenda")).toEqual({ ok: true, aceita: false });
    expect(await recusou.pedidos[0]?.json()).toEqual({ chamada_id: CHAMADA_ID, resposta: "recusar", motivo_recusa: "agenda" });
  });

  it("traduz as recusas da resposta", async () => {
    const casos: Array<[() => Response, string]> = [
      [recusa(409, "chamada_indisponivel", "expirada"), "expirada"],
      [recusa(409, "chamada_indisponivel", "encerrada"), "encerrada"],
      [recusa(422, "inelegivel", "turno_sobreposto"), "turno_sobreposto"],
      [recusa(422, "inelegivel", "funcao_incompativel"), "funcao_incompativel"],
      [recusa(404, "nao_encontrado"), "nao_encontrada"],
      [recusa(403, "sem_permissao", "conta_suspensa"), "conta_suspensa"],
      [recusa(503, "x"), "indisponivel"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await responderChamada(apiQueResponde(resposta).api, CHAMADA_ID, "aceitar", null), motivo).toEqual({ ok: false, motivo });
    }
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string> | null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com" } : null);
  const url = `https://frilabr.com/app/chamadas/${CHAMADA_ID}`;
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: { chamadaId: CHAMADA_ID }, url: new URL(url), matches: [] } as never;
};

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("tela da chamada", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    await expect(carregarChamada(argumentos(null, false))).rejects.toHaveProperty("status", 302);
    await expect(responder(argumentos({ resposta: "aceitar" }, false))).rejects.toHaveProperty("status", 302);
    expect(api.GET).not.toHaveBeenCalled();
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("antes do aceite não há endereço; o token não vai para a tela", async () => {
    api.GET.mockResolvedValue({
      data: {
        id: CHAMADA_ID,
        funcao: { nome: "Garçom" },
        outra_parte: { nome: "Casa" },
        inicio_em: "2026-11-21T22:00:00Z",
        fim_em: "2026-11-22T03:00:00Z",
        valor_centavos: 20000,
        regiao_administrativa: "Plano Piloto",
        distancia_faixa: "ate_5_km",
        inclui_refeicao: true,
        inclui_transporte: false,
        exige_material_proprio: false,
        estado: "aberta",
        expira_em: "2026-11-21T12:00:00Z",
      },
      response: new Response(),
    });
    const dados = (await carregarChamada(argumentos(null))) as { chamada: { local: unknown; distancia: unknown } };
    expect(dados.chamada).toMatchObject({ local: null, distancia: "ate_5_km" });
    expect(JSON.stringify(dados)).not.toContain("token-sintetico");
  });

  it("recusar manda a categoria só se for uma das do contrato", async () => {
    api.POST.mockResolvedValue({ data: { chamada: { estado: "recusada" } }, response: new Response() });
    expect(await responder(argumentos({ resposta: "recusar", motivo_recusa: "inventado" }))).toEqual({ resultado: "recusada" });
    expect(api.POST.mock.calls[0]?.[1].body).toEqual({ chamada_id: CHAMADA_ID, resposta: "recusar" });
    expect(await responder(argumentos({ resposta: "talvez" }))).toEqual({ resultado: "indisponivel" });
    expect(api.POST).toHaveBeenCalledOnce();
  });
});
