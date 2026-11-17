/**
 * A vaga pelo link, sem login (vaga_publica): só os campos publicáveis. A web chama SEM o token de quem entrou,
 * só com a chave publicável. Endereço exato e contato nunca saem por aqui (decisão do Cauê): só para quem foi aceito.
 */
import type { components } from "../contrato/tipos.gerado";
import type { Api } from "./api";

export type VagaPublica = components["schemas"]["VagaPublica"];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type LeituraDaVagaPublica = { estado: "ok"; vaga: VagaPublica } | { estado: "nao_encontrada" } | { estado: "indisponivel" };

export async function lerVagaPublica(api: Api | null, vagaId: string): Promise<LeituraDaVagaPublica> {
  if (!UUID.test(vagaId)) return { estado: "nao_encontrada" };
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/vaga_publica", { params: { query: { vaga_id: vagaId } }, signal: AbortSignal.timeout(5000) });
    if (data) return { estado: "ok", vaga: data };
    return { estado: response.status === 404 ? "nao_encontrada" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

/** Encerrada para a web (regra do contrato): não publicada, sem lugar aberto ou já começada. */
export function vagaEncerrada(vaga: VagaPublica, agora: Date = new Date()): boolean {
  return vaga.estado !== "publicada" || vaga.posicoes_abertas <= 0 || new Date(vaga.inicio_em) <= agora;
}

/** Entra no índice dos buscadores só com a chave ligada E a vaga aberta. */
export function podeIndexar(vaga: VagaPublica, chave: string | undefined, agora: Date = new Date()): boolean {
  return chave === "1" && !vagaEncerrada(vaga, agora);
}
