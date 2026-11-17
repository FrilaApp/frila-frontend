/**
 * Denunciar e bloquear (denunciar, bloquear, listar_bloqueios, desbloquear), dos dois lados: o profissional denuncia
 * a casa, e a casa denuncia o profissional (`alvoTipo`). O alvo é o `id` do PerfilPublico que o servidor mostrou. A Equipe Frila responde à
 * denúncia por e-mail; o bloqueio vale na hora, nos dois sentidos.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";

export type MotivoDaDenuncia = components["schemas"]["MotivoDenuncia"];
export type ItemBloqueio = components["schemas"]["ItemBloqueio"];
export type TipoDeAlvo = components["schemas"]["TipoDeAlvo"];
export const MOTIVOS_DA_DENUNCIA: readonly MotivoDaDenuncia[] = ["assedio", "discriminacao", "risco_seguranca", "outro"];
export const MINIMO_DO_RELATO = 10;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const ehUuid = (valor: string) => UUID.test(valor);
const prazo = () => AbortSignal.timeout(8000);

/** O protocolo que a pessoa vê e cita: os 8 primeiros hexadecimais do id da ocorrência, em maiúsculas (contrato). */
export function protocoloCurto(ocorrenciaId: string): string {
  return ocorrenciaId.replace(/-/g, "").slice(0, 8).toUpperCase();
}

export type Falha = "relato_curto" | "nao_encontrado" | "sem_sessao" | "conta_suspensa" | "indisponivel";
export type ResultadoDaDenuncia = { ok: true; protocolo: string } | { ok: false; motivo: Falha };

function falha(status: number, erro: { code?: string; details?: string | null } | undefined): Falha {
  if (status === 401) return "sem_sessao";
  if (status === 403) return "conta_suspensa";
  if (status === 404) return "nao_encontrado";
  if (status === 422 && erro?.details === "relato") return "relato_curto";
  return "indisponivel";
}

export async function denunciarCasa(
  api: Api | null,
  dados: { alvoId: string; turnoId: string | null; motivo: MotivoDaDenuncia; relato: string; chave: string; alvoTipo?: TipoDeAlvo },
): Promise<ResultadoDaDenuncia> {
  const relato = dados.relato.trim();
  if (!ehUuid(dados.alvoId) || !ehUuid(dados.chave)) return { ok: false, motivo: "nao_encontrado" };
  if (relato.length < MINIMO_DO_RELATO) return { ok: false, motivo: "relato_curto" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/denunciar", {
      body: {
        alvo_tipo: dados.alvoTipo ?? "estabelecimento",
        alvo_id: dados.alvoId,
        turno_id: dados.turnoId && ehUuid(dados.turnoId) ? dados.turnoId : null,
        motivo: dados.motivo,
        relato,
        chave: dados.chave,
      },
      signal: prazo(),
    });
    if (data) return { ok: true, protocolo: protocoloCurto(data.ocorrencia_id) };
    return { ok: false, motivo: falha(response.status, error) };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

/** Bloquear e desbloquear são idempotentes no servidor. */
export async function bloquearCasa(
  api: Api | null,
  alvoId: string,
  desfazer = false,
  alvoTipo: TipoDeAlvo = "estabelecimento",
): Promise<{ ok: true } | { ok: false; motivo: Falha }> {
  if (!ehUuid(alvoId)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const corpo = { body: { alvo_tipo: alvoTipo, alvo_id: alvoId }, signal: prazo() };
    const { data, error, response } = desfazer ? await api.POST("/rpc/desbloquear", corpo) : await api.POST("/rpc/bloquear", corpo);
    if (data) return { ok: true };
    return { ok: false, motivo: falha(response.status, error) };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type LeituraDosBloqueios = { estado: "ok"; bloqueios: ItemBloqueio[] } | { estado: "conta_suspensa" | "indisponivel" };

export async function listarBloqueios(api: Api | null): Promise<LeituraDosBloqueios> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/listar_bloqueios", { signal: AbortSignal.timeout(5000) });
    if (data) return { estado: "ok", bloqueios: data };
    return { estado: response.status === 403 ? "conta_suspensa" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}
