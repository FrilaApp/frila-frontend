import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as agirNoTurno, loader as carregarTurno } from "../app/rotas/profissional/turno";
import { criarApi } from "../app/servidor/api";
import { avaliarACasa } from "../app/servidor/profissional/avaliacao";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const TURNO_ID = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";

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

describe("avaliar a casa (servidor)", () => {
  it("manda turno e resposta (sim ou não)", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json({ turno_id: TURNO_ID, resposta: true, criada_em: "x" }));
    expect(await avaliarACasa(api, TURNO_ID, true)).toEqual({ ok: true });
    expect(await pedidos[0]?.json()).toEqual({ turno_id: TURNO_ID, resposta: true });
  });

  it("traduz as recusas do contrato", async () => {
    const casos: Array<[() => Response, string]> = [
      [recusa(422, "avaliacao_indisponivel", "antes_do_fim"), "antes_do_fim"],
      [recusa(422, "avaliacao_indisponivel", "sem_presenca_verificada"), "sem_presenca_verificada"],
      [recusa(409, "avaliacao_ja_registrada"), "ja_registrada"],
      [recusa(403, "sem_permissao"), "sem_permissao"],
      [recusa(500, "x"), "indisponivel"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await avaliarACasa(apiQueResponde(resposta).api, TURNO_ID, false), motivo).toEqual({ ok: false, motivo });
    }
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string> | null) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com" });
  const url = `https://frilabr.com/app/turnos/${TURNO_ID}`;
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: { turnoId: TURNO_ID }, url: new URL(url), matches: [] } as never;
};
const turno = {
  id: TURNO_ID,
  posicao_id: "p1",
  vaga: { id: "v1", funcao: "Garçom", local: "x", regiao_administrativa: "y", inicio_em: "2026-11-17T06:30:00Z", fim_em: "2026-11-17T07:30:00Z", valor_centavos: 1 },
  contraparte: { id: "e1", tipo: "estabelecimento", nome: "Casa", reputacao: {} },
  a_caminho_em: null,
  checkin_em: "2026-11-17T06:31:00Z",
  checkout_em: "2026-11-17T07:29:00Z",
  verificacao: "verificado",
  valor_acordado_centavos: 1,
  pode_avaliar: true,
  estado: "cumprida",
  avaliacao: null,
};

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("tela do turno: avaliação", () => {
  it("o servidor abre a avaliação: a tela pergunta; já respondida, mostra a resposta", async () => {
    api.GET.mockResolvedValueOnce({ data: [turno], response: new Response() });
    expect(((await carregarTurno(argumentos(null))) as { turno: unknown }).turno).toMatchObject({ podeAvaliar: true, respostaDada: null });
    api.GET.mockResolvedValueOnce({ data: [{ ...turno, pode_avaliar: false, avaliacao: { turno_id: TURNO_ID, resposta: false, criada_em: "x" } }], response: new Response() });
    expect(((await carregarTurno(argumentos(null))) as { turno: unknown }).turno).toMatchObject({ podeAvaliar: false, respostaDada: false });
  });

  it("sim e não pela action; resposta torta não sai", async () => {
    api.POST.mockResolvedValue({ data: { turno_id: TURNO_ID, resposta: true, criada_em: "x" }, response: new Response() });
    expect(await agirNoTurno(argumentos({ intencao: "avaliar", turno_id: TURNO_ID, resposta: "sim" }))).toEqual({ avaliacao: "registrada" });
    expect(api.POST.mock.calls[0]?.[1].body).toEqual({ turno_id: TURNO_ID, resposta: true });
    expect(await agirNoTurno(argumentos({ intencao: "avaliar", turno_id: TURNO_ID, resposta: "talvez" }))).toEqual({ avaliacao: "indisponivel" });
    expect(api.POST).toHaveBeenCalledOnce();
  });
});
