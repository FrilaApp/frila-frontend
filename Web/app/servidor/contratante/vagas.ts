import type { Api } from "../api";
import { prazo } from "./casa";

type Erro = { code?: string; details?: string | null } | undefined;

export type ResultadoDoCancelamento =
  | { ok: true }
  | { ok: false; motivo: "motivo_curto" | "motivo_recusado" | "vaga_encerrada" | "nao_encontrada" | "sem_permissao" | "sem_sessao" | "indisponivel" };

/** Cancela a vaga inteira, com motivo (RN12). O reenvio pelo mesmo autor devolve 200 sem avisar de novo. */
export async function cancelarVaga(api: Api | null, vagaId: string, motivo: string): Promise<ResultadoDoCancelamento> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/cancelar_vaga", { body: { vaga_id: vagaId, motivo }, signal: prazo() });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "sem_permissao" };
    if (response.status === 404) return { ok: false, motivo: "nao_encontrada" };
    if (response.status === 409) return { ok: false, motivo: "vaga_encerrada" };
    if (response.status === 422 && error?.details === "motivo") {
      return { ok: false, motivo: error.code === "campo_obrigatorio" ? "motivo_curto" : "motivo_recusado" };
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type MotivoDaRepublicacao =
  | "horario_invalido"
  | "selecao_sem_antecedencia"
  | "vaga_oculta"
  | "texto_recusado"
  | "ja_republicada"
  | "sem_posicoes_restantes"
  | "republicacao_indisponivel"
  | "nao_encontrada"
  | "sem_permissao"
  | "conta_suspensa"
  | "sem_sessao"
  | "indisponivel";

export type ResultadoDaRepublicacao = { ok: true; vagaId: string } | { ok: false; motivo: MotivoDaRepublicacao };

function recusaDaRepublicacao(status: number, error: Erro): MotivoDaRepublicacao {
  if (status === 401) return "sem_sessao";
  if (status === 403) return error?.details === "conta_suspensa" ? "conta_suspensa" : "sem_permissao";
  if (status === 404) return "nao_encontrada";
  if (status !== 422 || !error) return "indisponivel";
  if (error.code === "horario_invalido" || error.code === "selecao_sem_antecedencia" || error.code === "vaga_oculta") return error.code;
  // A cópia leva os textos da origem: se o filtro (diretriz 1.2) recusar algum agora, a casa precisa publicar de novo.
  if (error.code === "campo_invalido") return "texto_recusado";
  if (error.code === "republicacao_indisponivel") {
    if (error.details === "ja_republicada" || error.details === "sem_posicoes_restantes") return error.details;
    return "republicacao_indisponivel";
  }
  return "indisponivel";
}

/** Repete a vaga com outro dia e horário (RF05): o servidor copia todo o resto da origem. */
export async function republicarVaga(
  api: Api | null,
  pedido: { vaga_id: string; inicio_em: string; fim_em: string; chave: string },
): Promise<ResultadoDaRepublicacao> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/republicar_vaga", { body: pedido, signal: prazo() });
    return data ? { ok: true, vagaId: data.vaga_id } : { ok: false, motivo: recusaDaRepublicacao(response.status, error) };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

/** Publica em urgência os lugares que a seleção deixou vazios, no mesmo turno e valor (RN24). */
export async function republicarRestantes(api: Api | null, vagaId: string, chave: string): Promise<ResultadoDaRepublicacao> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/republicar_posicoes_restantes", { body: { vaga_id: vagaId, chave }, signal: prazo() });
    return data ? { ok: true, vagaId: data.vaga_id } : { ok: false, motivo: recusaDaRepublicacao(response.status, error) };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
