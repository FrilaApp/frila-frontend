/**
 * Avaliação do profissional sobre a casa, depois do turno: uma pergunta, sim ou não (avaliar). Quando abre (depois do
 * fim, com presença verificada) é o servidor que diz, em `Turno.pode_avaliar`.
 */
import type { Api } from "../api";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type ResultadoDaAvaliacao =
  | { ok: true }
  | { ok: false; motivo: "antes_do_fim" | "sem_presenca_verificada" | "ja_registrada" | "conta_suspensa" | "sem_permissao" | "sem_sessao" | "indisponivel" };

/** Reenviar a mesma resposta devolve a gravada; resposta diferente é 409 (já registrada). */
export async function avaliarACasa(api: Api | null, turnoId: string, resposta: boolean): Promise<ResultadoDaAvaliacao> {
  if (!UUID.test(turnoId)) return { ok: false, motivo: "sem_permissao" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/avaliar", {
      body: { turno_id: turnoId, resposta },
      signal: AbortSignal.timeout(8000),
    });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: error?.details === "conta_suspensa" ? "conta_suspensa" : "sem_permissao" };
    if (response.status === 409) return { ok: false, motivo: "ja_registrada" };
    if (response.status === 422 && (error?.details === "antes_do_fim" || error?.details === "sem_presenca_verificada")) {
      return { ok: false, motivo: error.details };
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
