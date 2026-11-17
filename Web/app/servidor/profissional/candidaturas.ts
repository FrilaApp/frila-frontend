/**
 * Candidaturas do profissional: candidatar-se, retirar e listar. O servidor escolhe a posição, decide a corrida do
 * modo urgência e diz quem é elegível; aqui só se traduz cada resposta do contrato num resultado.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import type { RecusaDoProfissional } from "./vagas";

export type Candidatura = components["schemas"]["Candidatura"];
export type EstadoDaCandidatura = components["schemas"]["EstadoCandidatura"];

const PRAZO_MS = 8000;
const prazo = () => AbortSignal.timeout(PRAZO_MS);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Erro = { code?: string; details?: string | null } | undefined;

export type FalhaDaCandidatura =
  /** Alguém chegou antes (ou a vaga encheu): resposta normal, não erro. */
  | "preenchida"
  /** Vaga cancelada, encerrada, fechada pelas 24 h do modo seleção ou cujo início passou. */
  | "encerrada"
  | "turno_sobreposto"
  | "perfil_suspenso"
  | "funcao_incompativel"
  | "nao_encontrada"
  | "sem_sessao"
  | RecusaDoProfissional;

export type ResultadoDaCandidatura = { ok: true; estado: "confirmada" | "pendente" } | { ok: false; motivo: FalhaDaCandidatura };

function falhaDe(status: number, erro: Erro): FalhaDaCandidatura {
  if (status === 401) return "sem_sessao";
  if (status === 404) return "nao_encontrada";
  if (status === 409 && erro?.code === "posicao_ja_preenchida") return "preenchida";
  if (status === 409 && erro?.code === "vaga_encerrada") return "encerrada";
  if (status === 422 && erro?.code === "inelegivel") {
    if (erro.details === "turno_sobreposto" || erro.details === "perfil_suspenso" || erro.details === "funcao_incompativel") {
      return erro.details;
    }
  }
  if (status === 422 && erro?.code === "perfil_incompativel") return "perfil_incompativel";
  if (status === 403) return "conta_suspensa";
  return "indisponivel";
}

/** Reenviar para a mesma vaga devolve o mesmo resultado (o contrato garante), então o duplo toque não duplica nada. */
export async function candidatar(api: Api | null, vagaId: string): Promise<ResultadoDaCandidatura> {
  if (!UUID.test(vagaId)) return { ok: false, motivo: "nao_encontrada" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/candidatar", { body: { vaga_id: vagaId }, signal: prazo() });
    if (data) return { ok: true, estado: data.estado };
    return { ok: false, motivo: falhaDe(response.status, error) };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type ResultadoDaRetirada =
  | { ok: true }
  | { ok: false; motivo: "ja_decidida" | "nao_encontrada" | "sem_sessao" | RecusaDoProfissional };

/** Retirar antes de ser escolhido, sem penalidade. Escolhida já não se retira: vira cancelamento do turno. */
export async function retirarCandidatura(api: Api | null, candidaturaId: string): Promise<ResultadoDaRetirada> {
  if (!UUID.test(candidaturaId)) return { ok: false, motivo: "nao_encontrada" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/retirar_candidatura", {
      body: { candidatura_id: candidaturaId },
      signal: prazo(),
    });
    if (data) return { ok: true };
    if (response.status === 409) return { ok: false, motivo: "ja_decidida" };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 404) return { ok: false, motivo: "nao_encontrada" };
    if (response.status === 403) return { ok: false, motivo: "conta_suspensa" };
    if (response.status === 422 && error?.code === "perfil_incompativel") return { ok: false, motivo: "perfil_incompativel" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type LeituraDasCandidaturas = { estado: "ok"; candidaturas: Candidatura[] } | { estado: RecusaDoProfissional };

export async function listarMinhasCandidaturas(api: Api | null): Promise<LeituraDasCandidaturas> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, error, response } = await api.GET("/rpc/minhas_candidaturas", { signal: AbortSignal.timeout(5000) });
    if (data) return { estado: "ok", candidaturas: data };
    if (response.status === 403) return { estado: "conta_suspensa" };
    if (response.status === 422 && error?.code === "perfil_incompativel") return { estado: "perfil_incompativel" };
    return { estado: "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}
