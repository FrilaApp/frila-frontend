/**
 * Os gestos da casa no dia do turno: o código de chegada (gerar_codigo_checkin), a confirmação manual
 * (confirmar_checkin_manual) e a reabertura por atraso, que marca a falta (reabrir_por_atraso).
 * Janela, tolerância de 15 minutos e falta são do servidor; aqui só se traduz a resposta.
 */
import type { Api } from "../../api";
import { prazo, UUID } from "./turnos";

export type MotivoDaRecusa =
  | "sem_codigo"
  | "aguardando_chegada"
  | "ja_confirmada"
  | "codigo_encerrado"
  | "fora_da_janela"
  | "antes_da_tolerancia"
  | "situacao_mudou"
  | "nao_encontrado"
  | "sem_permissao"
  | "sem_sessao"
  | "indisponivel";

/** `checkin_pendente` muda de sentido: no código, a chegada não serve para ele; na confirmação, ainda não houve chegada. */
function motivoDa(status: number, code: string | undefined, checkinPendente: MotivoDaRecusa): MotivoDaRecusa {
  if (status === 401) return "sem_sessao";
  if (status === 403) return "sem_permissao";
  if (status === 404) return "nao_encontrado";
  if (status === 409) {
    if (code === "checkin_pendente") return checkinPendente;
    if (code === "checkin_ja_confirmado") return "ja_confirmada";
    if (code === "codigo_bloqueado") return "codigo_encerrado";
    return "situacao_mudou";
  }
  if (status === 422) {
    if (code === "fora_da_janela") return "fora_da_janela";
    if (code === "reabertura_antes_da_tolerancia") return "antes_da_tolerancia";
    return "situacao_mudou";
  }
  return "indisponivel";
}

type Recusa = { ok: false; motivo: MotivoDaRecusa };

/**
 * O código vale poucos minutos (hoje 5) e pedir de novo dentro da validade devolve o mesmo. A validade conta do
 * servidor (`segundos_restantes`), não do relógio do aparelho. O código só vai no corpo da resposta da tela.
 */
export async function gerarCodigo(api: Api | null, turnoId: string): Promise<{ ok: true; codigo: string; segundosRestantes: number } | Recusa> {
  if (!UUID.test(turnoId)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/gerar_codigo_checkin", { body: { turno_id: turnoId }, signal: prazo(8000) });
    if (data) return { ok: true, codigo: data.codigo, segundosRestantes: data.segundos_restantes };
    return { ok: false, motivo: motivoDa(response.status, error?.code, "sem_codigo") };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

/** Vale até 24 h depois do fim previsto; só então o check-in manual conta como presença. */
export async function confirmarPresenca(api: Api | null, turnoId: string): Promise<{ ok: true } | Recusa> {
  if (!UUID.test(turnoId)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/confirmar_checkin_manual", { body: { turno_id: turnoId }, signal: prazo(8000) });
    if (data) return { ok: true };
    return { ok: false, motivo: motivoDa(response.status, error?.code, "aguardando_chegada") };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

/** Depois de 15 minutos do início sem check-in. Marca a falta; perto do fim, a vaga não volta a ser oferecida. */
export async function reabrirPorAtraso(api: Api | null, posicaoId: string): Promise<{ ok: true; reaberta: boolean } | Recusa> {
  if (!UUID.test(posicaoId)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/reabrir_por_atraso", { body: { posicao_id: posicaoId }, signal: prazo(8000) });
    if (data) return { ok: true, reaberta: data.reaberta };
    return { ok: false, motivo: motivoDa(response.status, error?.code, "situacao_mudou") };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
