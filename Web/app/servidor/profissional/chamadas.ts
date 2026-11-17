/**
 * Chamadas diretas que o profissional recebe: a lista (minhas_chamadas, por cursor), a chamada (detalhe_chamada,
 * sem endereço antes do aceite) e a resposta (responder_chamada). Ligar ou não o recurso é do servidor
 * (`recursos.chamada_direta`: 403 recurso_desligado).
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import type { RecusaDoProfissional } from "./vagas";

export type ChamadaResumo = components["schemas"]["ChamadaResumo"];
export type ChamadaDetalhe = components["schemas"]["ChamadaDetalhe"];
export type MotivoDaRecusa = components["schemas"]["MotivoRecusaChamada"];
export const MOTIVOS_DA_RECUSA: readonly MotivoDaRecusa[] = ["agenda", "distancia", "valor", "tipo_de_servico", "outro"];

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
type Erro = { code?: string; details?: string | null } | undefined;
type Leitura = "recurso_desligado" | RecusaDoProfissional;

function leituraRecusada(status: number, erro: Erro): Leitura {
  if (status === 403 && erro?.details === "recurso_desligado") return "recurso_desligado";
  if (status === 403) return "conta_suspensa";
  if (status === 422 && erro?.code === "perfil_incompativel") return "perfil_incompativel";
  return "indisponivel";
}

export type LeituraDasChamadas = { estado: "ok"; itens: ChamadaResumo[]; proximoCursor: string | null } | { estado: Leitura };

export async function listarChamadas(api: Api | null, cursor: string | null): Promise<LeituraDasChamadas> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, error, response } = await api.GET("/rpc/minhas_chamadas", {
      params: { query: cursor ? { cursor } : {} },
      signal: AbortSignal.timeout(5000),
    });
    if (data) return { estado: "ok", itens: data.itens, proximoCursor: data.proximo_cursor ?? null };
    return { estado: leituraRecusada(response.status, error) };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type LeituraDaChamada = { estado: "ok"; chamada: ChamadaDetalhe } | { estado: "nao_encontrada" } | { estado: Leitura };

export async function lerChamada(api: Api | null, chamadaId: string): Promise<LeituraDaChamada> {
  if (!UUID.test(chamadaId)) return { estado: "nao_encontrada" };
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, error, response } = await api.GET("/rpc/detalhe_chamada", {
      params: { query: { chamada_id: chamadaId } },
      signal: AbortSignal.timeout(5000),
    });
    if (data) return { estado: "ok", chamada: data };
    if (response.status === 404) return { estado: "nao_encontrada" };
    return { estado: leituraRecusada(response.status, error) };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type ResultadoDaResposta =
  | { ok: true; aceita: boolean }
  | {
      ok: false;
      motivo: "expirada" | "encerrada" | "turno_sobreposto" | "funcao_incompativel" | "nao_encontrada" | "sem_sessao" | Leitura;
    };

/** Aceitar é candidatar e confirmar numa só vez (o servidor decide a corrida). Recusar não penaliza. */
export async function responderChamada(
  api: Api | null,
  chamadaId: string,
  resposta: "aceitar" | "recusar",
  motivo: MotivoDaRecusa | null,
): Promise<ResultadoDaResposta> {
  if (!UUID.test(chamadaId)) return { ok: false, motivo: "nao_encontrada" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/responder_chamada", {
      body: { chamada_id: chamadaId, resposta, ...(resposta === "recusar" && motivo ? { motivo_recusa: motivo } : {}) },
      signal: AbortSignal.timeout(8000),
    });
    if (data) return { ok: true, aceita: data.chamada.estado === "aceita" };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 404) return { ok: false, motivo: "nao_encontrada" };
    if (response.status === 409) return { ok: false, motivo: error?.details === "expirada" ? "expirada" : "encerrada" };
    if (response.status === 422 && error?.code === "inelegivel" && (error.details === "turno_sobreposto" || error.details === "funcao_incompativel")) {
      return { ok: false, motivo: error.details };
    }
    return { ok: false, motivo: leituraRecusada(response.status, error) };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
