import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import { prazo } from "./casa";
import { quandoDaVaga } from "./painel";

export type Candidato = components["schemas"]["Candidato"];
export type Reputacao = components["schemas"]["Reputacao"];

export type LeituraDosCandidatos =
  | { estado: "ok"; candidatos: Candidato[] }
  | { estado: "sem_permissao" }
  | { estado: "nao_encontrada" }
  | { estado: "sem_sessao" }
  | { estado: "indisponivel" };

/** Candidatos pendentes, em ordem de chegada (RN06): a web não reordena. */
export async function lerCandidatos(api: Api | null, vagaId: string): Promise<LeituraDosCandidatos> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/candidatos_da_vaga", { params: { query: { vaga_id: vagaId } }, signal: prazo() });
    if (data) return { estado: "ok", candidatos: data };
    if (response.status === 401) return { estado: "sem_sessao" };
    if (response.status === 403) return { estado: "sem_permissao" };
    if (response.status === 404) return { estado: "nao_encontrada" };
    return { estado: "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type CandidatoNaTela = {
  candidaturaId: string;
  nome: string;
  daEquipe: boolean;
  /** "7 de 7": sempre com o denominador, nunca média (RN07, RN08). `null` = sem histórico. */
  chamariamDeNovo: { positivas: number; total: number } | null;
  turnosRealizados: number;
  /** Comparecimento em % inteiro, com o denominador; `null` sem turno considerado. */
  comparecimento: { porcento: number; considerados: number } | null;
  chegouEm: string;
};

export function candidatosParaATela(candidatos: Candidato[]): CandidatoNaTela[] {
  return candidatos.map(({ candidatura_id, profissional, criada_em, da_equipe }) => {
    const { reputacao } = profissional;
    const chegada = quandoDaVaga(criada_em, criada_em);
    return {
      candidaturaId: candidatura_id,
      nome: profissional.nome,
      daEquipe: da_equipe ?? false,
      chamariamDeNovo: reputacao.total > 0 ? { positivas: reputacao.positivas, total: reputacao.total } : null,
      turnosRealizados: reputacao.turnos_realizados,
      comparecimento:
        reputacao.taxa_comparecimento != null && reputacao.turnos_considerados > 0
          ? { porcento: Math.round(reputacao.taxa_comparecimento * 100), considerados: reputacao.turnos_considerados }
          : null,
      chegouEm: `${chegada.dia} · ${chegada.horario.split("–")[0]}`,
    };
  });
}

export type ResultadoDaEscolha =
  | { ok: true }
  | {
      ok: false;
      motivo:
        | "posicao_ja_preenchida"
        | "candidatura_indisponivel"
        | "vaga_encerrada"
        | "turno_sobreposto"
        | "vaga_oculta"
        | "sem_permissao"
        | "sem_sessao"
        | "indisponivel";
    };

const CONFLITOS = ["posicao_ja_preenchida", "candidatura_indisponivel", "vaga_encerrada"] as const;

/** Escolhe o candidato no modo seleção. Toda regra (posição livre, sobreposição, bloqueio) é do servidor. */
export async function escolherCandidato(api: Api | null, candidaturaId: string): Promise<ResultadoDaEscolha> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/escolher_candidato", { body: { candidatura_id: candidaturaId }, signal: prazo() });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "sem_permissao" };
    const conflito = CONFLITOS.find((codigo) => codigo === error?.code);
    if (response.status === 409 && conflito) return { ok: false, motivo: conflito };
    if (response.status === 422 && error?.code === "vaga_oculta") return { ok: false, motivo: "vaga_oculta" };
    if (response.status === 422 && error?.code === "inelegivel") return { ok: false, motivo: "turno_sobreposto" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
