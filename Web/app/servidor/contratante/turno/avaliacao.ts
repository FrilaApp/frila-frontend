/**
 * Avaliação da casa sobre o profissional, depois do turno. É a mesma operação do outro lado (avaliar
 * {turno_id, resposta}): o servidor sabe de que lado quem chama está, e o voto é da casa, não de cada membro.
 * Por isso reaproveita a tradução do lado do profissional, com as mesmas recusas.
 */
import type { Api } from "../../api";
import { avaliarACasa, type ResultadoDaAvaliacao } from "../../profissional/avaliacao";

export function avaliarOProfissional(api: Api | null, turnoId: string, resposta: boolean): Promise<ResultadoDaAvaliacao> {
  return avaliarACasa(api, turnoId, resposta);
}
