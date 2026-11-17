/**
 * Vagas do lado do profissional: a lista das abertas (pela distância até o ponto base) e o detalhe de uma vaga.
 * A web não pede a posição do navegador: sem latitude e longitude, o servidor ordena pelo ponto base do perfil.
 * A regra (quem vê o quê, a ordem, o endereço) é do servidor; aqui só se traduz cada resposta num estado.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";

export type VagaNaLista = components["schemas"]["VagaNaLista"];
export type Vaga = components["schemas"]["Vaga"];

/** Recusas que valem para qualquer leitura do profissional. */
export type RecusaDoProfissional = "perfil_incompativel" | "conta_suspensa" | "indisponivel";

export const VAGAS_POR_PAGINA = 30;
const PRAZO_MS = 5000;
const prazo = () => AbortSignal.timeout(PRAZO_MS);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type FiltrosDaLista = { data: string | null; distanciaMaxKm: number | null; deslocamento: number };

export type LeituraDaLista =
  | { estado: "ok"; vagas: VagaNaLista[]; temMais: boolean }
  /** O perfil ainda não tem ponto base: sem ele não há ordem (422 campo_obrigatorio, latitude). */
  | { estado: "sem_ponto_base" }
  | { estado: RecusaDoProfissional };

type Recusa = { status: number; code?: string; details?: string | null };

function recusaComum({ status, code }: Recusa): RecusaDoProfissional {
  if (status === 403) return "conta_suspensa";
  if (status === 422 && code === "perfil_incompativel") return "perfil_incompativel";
  return "indisponivel";
}

/** Lê os filtros da URL. O que não serve é ignorado (o servidor também confere). */
export function filtrosDaUrl(url: URL): FiltrosDaLista {
  const data = url.searchParams.get("data") ?? "";
  const distancia = Number(url.searchParams.get("distancia") ?? "");
  const deslocamento = Number(url.searchParams.get("deslocamento") ?? "0");
  return {
    data: /^\d{4}-\d{2}-\d{2}$/.test(data) ? data : null,
    distanciaMaxKm: Number.isFinite(distancia) && distancia > 0 && distancia <= 100 ? distancia : null,
    deslocamento: Number.isInteger(deslocamento) && deslocamento > 0 ? deslocamento : 0,
  };
}

export async function listarVagasAbertas(api: Api | null, filtros: FiltrosDaLista): Promise<LeituraDaLista> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, error, response } = await api.GET("/rpc/vagas_abertas", {
      params: {
        query: {
          limite: VAGAS_POR_PAGINA,
          deslocamento: filtros.deslocamento,
          ...(filtros.data ? { data: filtros.data } : {}),
          ...(filtros.distanciaMaxKm ? { distancia_max_km: filtros.distanciaMaxKm } : {}),
        },
      },
      signal: prazo(),
    });
    if (data) return { estado: "ok", vagas: data, temMais: data.length === VAGAS_POR_PAGINA };
    if (response.status === 422 && error?.code === "campo_obrigatorio" && error.details === "latitude") {
      return { estado: "sem_ponto_base" };
    }
    return { estado: recusaComum({ status: response.status, code: error?.code }) };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type LeituraDaVaga = { estado: "ok"; vaga: Vaga } | { estado: "nao_encontrada" } | { estado: RecusaDoProfissional };

export async function lerVaga(api: Api | null, vagaId: string): Promise<LeituraDaVaga> {
  if (!UUID.test(vagaId)) return { estado: "nao_encontrada" };
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, error, response } = await api.GET("/rpc/detalhe_vaga", {
      params: { query: { vaga_id: vagaId } },
      signal: prazo(),
    });
    if (data) return { estado: "ok", vaga: data };
    if (response.status === 404) return { estado: "nao_encontrada" };
    return { estado: recusaComum({ status: response.status, code: error?.code }) };
  } catch {
    return { estado: "indisponivel" };
  }
}

/** O botão de candidatura só aparece com a vaga publicada e posição aberta, nunca pelo relógio (regra do contrato). */
export function aceitaCandidatura(vaga: Vaga): boolean {
  return vaga.estado === "publicada" && vaga.posicoes_abertas > 0;
}
