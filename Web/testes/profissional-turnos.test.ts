import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as agirNoTurno, loader as carregarTurno } from "../app/rotas/profissional/turno";
import { criarApi } from "../app/servidor/api";
import { avisarACaminho, desistirDoTurno, listarMeusTurnos } from "../app/servidor/profissional/turnos";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const TURNO_ID = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";
const POSICAO_ID = "0b8a7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d";

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

const turno = {
  id: TURNO_ID,
  posicao_id: POSICAO_ID,
  vaga: { id: "v1", funcao: "Garçom", local: "Asa Norte", regiao_administrativa: "Plano Piloto", inicio_em: "2026-11-17T06:30:00Z", fim_em: "2026-11-17T07:30:00Z", valor_centavos: 15000 },
  contraparte: { id: "e1", tipo: "estabelecimento", nome: "Casa Sintética", reputacao: {} },
  a_caminho_em: null,
  checkin_em: null,
  checkin_tipo: null,
  checkin_distancia_m: null,
  checkin_confirmado_em: null,
  checkout_em: null,
  checkout_distancia_m: null,
  verificacao: "pendente",
  valor_acordado_centavos: 15000,
  pode_avaliar: false,
  estado: "confirmada",
};

describe("turnos do profissional (servidor)", () => {
  it("lista meus turnos com o token de quem entrou", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json([turno]));
    expect(await listarMeusTurnos(api)).toEqual({ estado: "ok", turnos: [turno] });
    expect(new URL(pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/meus_turnos");
    expect((await listarMeusTurnos(apiQueResponde(recusa(500, "x")).api)).estado).toBe("indisponivel");
  });

  it("a caminho: manda o turno; fora da janela e sem permissão viram aviso", async () => {
    const ok = apiQueResponde(() => Response.json({ turno_id: TURNO_ID, a_caminho_em: "2026-11-17T05:00:00Z" }));
    expect(await avisarACaminho(ok.api, TURNO_ID)).toEqual({ ok: true });
    expect(await ok.pedidos[0]?.json()).toEqual({ turno_id: TURNO_ID });
    expect(await avisarACaminho(apiQueResponde(recusa(422, "a_caminho_fora_da_janela")).api, TURNO_ID)).toEqual({ ok: false, motivo: "fora_da_janela" });
    expect(await avisarACaminho(apiQueResponde(recusa(403, "sem_permissao")).api, TURNO_ID)).toEqual({ ok: false, motivo: "sem_permissao" });
  });

  it("desistir: manda posição e motivo; diz se contou falta", async () => {
    const ok = apiQueResponde(() => Response.json({ posicao_id: POSICAO_ID, falta: true, reaberta: true, nova_posicao_id: null }));
    expect(await desistirDoTurno(ok.api, POSICAO_ID, "  imprevisto em casa ")).toEqual({ ok: true, falta: true });
    expect(await ok.pedidos[0]?.json()).toEqual({ posicao_id: POSICAO_ID, motivo: "imprevisto em casa" });
  });

  it("desistir: motivo curto nem sai; recusas do contrato viram aviso", async () => {
    const curto = apiQueResponde(() => Response.json({}));
    expect(await desistirDoTurno(curto.api, POSICAO_ID, "ok")).toEqual({ ok: false, motivo: "motivo_curto" });
    expect(curto.pedidos).toHaveLength(0);
    const casos: Array<[() => Response, string]> = [
      [recusa(422, "campo_invalido", "motivo"), "motivo_recusado"],
      [recusa(422, "campo_obrigatorio", "motivo"), "motivo_curto"],
      [recusa(409, "posicao_nao_cancelavel"), "nao_cancelavel"],
      [recusa(404, "nao_encontrado"), "nao_encontrada"],
      [recusa(503, "x"), "indisponivel"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await desistirDoTurno(apiQueResponde(resposta).api, POSICAO_ID, "imprevisto"), motivo).toEqual({ ok: false, motivo });
    }
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string> | null, logado = true, turnoId = TURNO_ID) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com", visitante: null } : null);
  const url = `https://frilabr.com/app/turnos/${turnoId}`;
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: { turnoId }, url: new URL(url), matches: [] } as never;
};
const ok = (corpo: unknown) => ({ data: corpo, response: new Response(null, { status: 200 }) });

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("tela do turno", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    await expect(carregarTurno(argumentos(null, false))).rejects.toHaveProperty("status", 302);
    await expect(agirNoTurno(argumentos({ intencao: "a_caminho", turno_id: TURNO_ID }, false))).rejects.toHaveProperty("status", 302);
    expect(api.GET).not.toHaveBeenCalled();
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("turno confirmado sem presença: oferece o aviso e a desistência; não devolve token", async () => {
    api.GET.mockResolvedValue(ok([turno]));
    const dados = (await carregarTurno(argumentos(null))) as { turno: { podeAvisar: boolean; podeDesistir: boolean; casa: string } };
    expect(dados.turno).toMatchObject({ podeAvisar: true, podeDesistir: true, casa: "Casa Sintética" });
    expect(JSON.stringify(dados)).not.toContain("token-sintetico");
  });

  it("turno com presença registrada: sem aviso e sem desistência", async () => {
    api.GET.mockResolvedValue(ok([{ ...turno, checkin_em: "2026-11-17T06:31:00Z" }]));
    const dados = (await carregarTurno(argumentos(null))) as { turno: { podeAvisar: boolean; podeDesistir: boolean } };
    expect(dados.turno).toMatchObject({ podeAvisar: false, podeDesistir: false });
  });

  it("turno que não é da pessoa responde 404", async () => {
    api.GET.mockResolvedValue(ok([turno]));
    const resposta = (await carregarTurno(argumentos(null, true, "00000000-0000-4000-8000-000000000000"))) as { init: ResponseInit | null };
    expect(resposta.init?.status).toBe(404);
  });

  it("a caminho e desistir pela action", async () => {
    api.POST.mockResolvedValueOnce(ok({ turno_id: TURNO_ID, a_caminho_em: "x" }));
    expect(await agirNoTurno(argumentos({ intencao: "a_caminho", turno_id: TURNO_ID }))).toEqual({ resultado: "a_caminho" });
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/avisar_a_caminho");
    api.POST.mockResolvedValueOnce(ok({ posicao_id: POSICAO_ID, falta: false, reaberta: true, nova_posicao_id: null }));
    expect(await agirNoTurno(argumentos({ intencao: "desistir", posicao_id: POSICAO_ID, motivo: "imprevisto" }))).toEqual({ resultado: "desistiu" });
    expect(api.POST.mock.calls[1]?.[0]).toBe("/rpc/cancelar_posicao");
  });
});
