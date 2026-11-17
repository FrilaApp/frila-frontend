/**
 * Conta suspensa: a situação (situacao_da_conta) e a contestação (contestar_suspensao). O relato é texto livre
 * (dado pessoal): vai só no corpo do POST, nunca em URL, cookie ou log, e não volta na resposta da tela.
 * Uma contestação por suspensão: a segunda é 409, que a tela lê como "já contestada" (sem duplicar no reenvio).
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";

export type SituacaoDaConta = components["schemas"]["SituacaoDaConta"];
export type Protocolo = components["schemas"]["Protocolo"];

export const RELATO_MINIMO = 10;

export async function lerSituacaoDaConta(api: Api | null): Promise<{ estado: "ok"; situacao: SituacaoDaConta } | { estado: "indisponivel" }> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data } = await api.GET("/rpc/situacao_da_conta", { signal: AbortSignal.timeout(5000) });
    return data ? { estado: "ok", situacao: data } : { estado: "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type ResultadoDaContestacao =
  | { ok: true; protocolo: Protocolo }
  | { ok: false; motivo: "relato_curto" | "ja_contestada" | "sem_suspensao" | "sem_sessao" | "indisponivel" };

export async function contestarSuspensao(api: Api | null, relato: string): Promise<ResultadoDaContestacao> {
  const texto = relato.trim();
  if (texto.length < RELATO_MINIMO) return { ok: false, motivo: "relato_curto" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/contestar_suspensao", { body: { relato: texto }, signal: AbortSignal.timeout(8000) });
    if (data) return { ok: true, protocolo: data };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 409) return { ok: false, motivo: "ja_contestada" };
    if (response.status === 422) return { ok: false, motivo: error?.code === "sem_suspensao_ativa" ? "sem_suspensao" : "relato_curto" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
