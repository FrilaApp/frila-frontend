/**
 * As chamadas da casa (3.8): acompanhar (minhas_chamadas, a mesma leitura do profissional, que para o contratante traz
 * as chamadas de todas as casas de que ele é membro), cancelar uma aberta (cancelar_chamada) e publicar para todos a
 * partir da vaga direta (publicar_a_partir_da_chamada). Quem decide se ainda dá é o servidor (409 com o motivo).
 */
import type { Api } from "../api";
import { ehUuid } from "./publicar-vaga";

const prazo = () => AbortSignal.timeout(8000);

export type FalhaNaChamada = "indisponivel_agora" | "vaga_encerrada" | "selecao_sem_antecedencia" | "recurso_desligado" | "conta_suspensa" | "sem_permissao" | "nao_encontrada" | "sem_sessao" | "indisponivel";
export type GestoNaChamada = { ok: true } | { ok: false; motivo: FalhaNaChamada };

function recusa(status: number, erro: { code?: string; details?: string | null } | undefined): FalhaNaChamada {
  if (status === 401) return "sem_sessao";
  if (status === 404) return "nao_encontrada";
  if (status === 403) return erro?.details === "recurso_desligado" ? "recurso_desligado" : erro?.details === "conta_suspensa" ? "conta_suspensa" : "sem_permissao";
  if (status === 409) return erro?.code === "vaga_encerrada" ? "vaga_encerrada" : "indisponivel_agora";
  if (status === 422 && erro?.code === "selecao_sem_antecedencia") return "selecao_sem_antecedencia";
  return "indisponivel";
}

/** Sem efeito para ninguém; o profissional é avisado. Chamada que já não está aberta: 409. */
export async function cancelarChamada(api: Api | null, chamadaId: string): Promise<GestoNaChamada> {
  if (!ehUuid(chamadaId)) return { ok: false, motivo: "nao_encontrada" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/cancelar_chamada", { body: { chamada_id: chamadaId }, signal: prazo() });
    return data ? { ok: true } : { ok: false, motivo: recusa(response.status, error) };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

/** A vaga direta vira uma vaga normal nova, com os mesmos termos, em urgência. Repetir devolve a mesma vaga. */
export async function publicarParaTodos(api: Api | null, vagaId: string, chave: string): Promise<GestoNaChamada> {
  if (!ehUuid(vagaId) || !ehUuid(chave)) return { ok: false, motivo: "nao_encontrada" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/publicar_a_partir_da_chamada", { body: { vaga_id: vagaId, chave }, signal: prazo() });
    return data ? { ok: true } : { ok: false, motivo: recusa(response.status, error) };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
