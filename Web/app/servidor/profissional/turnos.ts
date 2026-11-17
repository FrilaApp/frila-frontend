/**
 * Turnos do profissional: a lista (meus_turnos), o aviso "estou a caminho" e a desistência (cancelar_posicao).
 * O servidor decide a janela do aviso, se a desistência conta como falta e o que reabre; aqui só se traduz.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import type { RecusaDoProfissional } from "./vagas";

export type Turno = components["schemas"]["Turno"];

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const prazo = (ms: number) => AbortSignal.timeout(ms);

export type LeituraDosTurnos = { estado: "ok"; turnos: Turno[] } | { estado: RecusaDoProfissional };

/** Hoje e os próximos primeiro, depois os anteriores (ordem do servidor). O turno cancelado continua na lista. */
export async function listarMeusTurnos(api: Api | null): Promise<LeituraDosTurnos> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/meus_turnos", { signal: prazo(5000) });
    if (data) return { estado: "ok", turnos: data };
    return { estado: response.status === 403 ? "conta_suspensa" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type ResultadoDoACaminho =
  | { ok: true }
  | { ok: false; motivo: "fora_da_janela" | "sem_permissao" | "sem_sessao" | "indisponivel" };

/** Idempotente: avisar de novo devolve o mesmo instante. A janela (3 h antes até 15 min depois) é do servidor. */
export async function avisarACaminho(api: Api | null, turnoId: string): Promise<ResultadoDoACaminho> {
  if (!UUID.test(turnoId)) return { ok: false, motivo: "sem_permissao" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/avisar_a_caminho", { body: { turno_id: turnoId }, signal: prazo(8000) });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "sem_permissao" };
    if (response.status === 422 && error?.code === "a_caminho_fora_da_janela") return { ok: false, motivo: "fora_da_janela" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type ResultadoDaDesistencia =
  | { ok: true; falta: boolean }
  | {
      ok: false;
      motivo: "motivo_curto" | "motivo_recusado" | "nao_cancelavel" | "nao_encontrada" | "sem_permissao" | "sem_sessao" | "indisponivel";
    };

/** Desistir de um turno confirmado. Com menos de 24 h do início, conta como falta (regra do servidor, mostrada antes). */
export async function desistirDoTurno(api: Api | null, posicaoId: string, motivo: string): Promise<ResultadoDaDesistencia> {
  if (!UUID.test(posicaoId)) return { ok: false, motivo: "nao_encontrada" };
  if (motivo.trim().length < 3) return { ok: false, motivo: "motivo_curto" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/cancelar_posicao", {
      body: { posicao_id: posicaoId, motivo: motivo.trim() },
      signal: prazo(8000),
    });
    if (data) return { ok: true, falta: data.falta };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "sem_permissao" };
    if (response.status === 404) return { ok: false, motivo: "nao_encontrada" };
    if (response.status === 409) return { ok: false, motivo: "nao_cancelavel" };
    if (response.status === 422 && error?.details === "motivo") {
      return { ok: false, motivo: error.code === "campo_invalido" ? "motivo_recusado" : "motivo_curto" };
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
