import { describe, expect, it } from "vitest";

import { criarApi } from "../app/servidor/api";
import { confirmarPresenca, gerarCodigo, reabrirPorAtraso } from "../app/servidor/contratante/turno/presenca";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const TURNO_ID = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";
const POSICAO_ID = "0b8a7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d";

function apiQueResponde(resposta: () => Response) {
  const pedidos: Request[] = [];
  const api = criarApi(ambiente, {
    token: "token-da-casa",
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { api, pedidos };
}
const recusa = (status: number, code: string, details: string | null = null) => () =>
  Response.json({ code, message: code, details, hint: null }, { status });

describe("código de chegada", () => {
  it("devolve o código e a validade contada pelo servidor", async () => {
    const { api, pedidos } = apiQueResponde(() =>
      Response.json({ turno_id: TURNO_ID, codigo: "482913", expira_em: "2026-11-17T07:05:00Z", segundos_restantes: 241 }),
    );
    expect(await gerarCodigo(api, TURNO_ID)).toEqual({ ok: true, codigo: "482913", segundosRestantes: 241 });
    expect(new URL(pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/gerar_codigo_checkin");
    expect(await pedidos[0]?.json()).toEqual({ turno_id: TURNO_ID });
  });

  it("cada recusa do contrato tem o seu aviso", async () => {
    const casos: Array<[() => Response, string]> = [
      [recusa(409, "checkin_pendente"), "sem_codigo"],
      [recusa(409, "checkin_ja_confirmado"), "ja_confirmada"],
      [recusa(409, "codigo_bloqueado", "encerrado"), "codigo_encerrado"],
      [recusa(422, "fora_da_janela"), "fora_da_janela"],
      [recusa(403, "sem_permissao"), "sem_permissao"],
      [recusa(404, "nao_encontrado"), "nao_encontrado"],
      [recusa(401, "nao_autenticado"), "sem_sessao"],
      [recusa(503, "x"), "indisponivel"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await gerarCodigo(apiQueResponde(resposta).api, TURNO_ID), motivo).toEqual({ ok: false, motivo });
    }
  });
});

describe("confirmação manual", () => {
  it("confirma; check-in pendente, já confirmada e fora do prazo viram aviso", async () => {
    const ok = apiQueResponde(() => Response.json({ turno_id: TURNO_ID }));
    expect(await confirmarPresenca(ok.api, TURNO_ID)).toEqual({ ok: true });
    expect(new URL(ok.pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/confirmar_checkin_manual");
    const casos: Array<[() => Response, string]> = [
      [recusa(409, "checkin_pendente"), "aguardando_chegada"],
      [recusa(409, "checkin_ja_confirmado"), "ja_confirmada"],
      [recusa(409, "vaga_encerrada", "posicao_cancelada"), "situacao_mudou"],
      [recusa(422, "fora_da_janela"), "fora_da_janela"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await confirmarPresenca(apiQueResponde(resposta).api, TURNO_ID), motivo).toEqual({ ok: false, motivo });
    }
  });
});

describe("reabrir por atraso", () => {
  it("reabre pela posição e diz se a vaga voltou a ser oferecida", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json({ posicao_id: POSICAO_ID, falta: true, reaberta: false, nova_posicao_id: null }));
    expect(await reabrirPorAtraso(api, POSICAO_ID)).toEqual({ ok: true, reaberta: false });
    expect(await pedidos[0]?.json()).toEqual({ posicao_id: POSICAO_ID });
    expect(await reabrirPorAtraso(apiQueResponde(recusa(422, "reabertura_antes_da_tolerancia")).api, POSICAO_ID)).toEqual({
      ok: false,
      motivo: "antes_da_tolerancia",
    });
    expect(await reabrirPorAtraso(apiQueResponde(recusa(409, "conflito")).api, POSICAO_ID)).toEqual({ ok: false, motivo: "situacao_mudou" });
  });
});
