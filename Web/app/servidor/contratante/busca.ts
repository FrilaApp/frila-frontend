/**
 * Busca de profissionais pela casa (3.8, `buscar_profissionais`, 0.2.88 a 0.2.90): serviço, região e horário. Quem
 * aparece, a ordem e os limites são do servidor (RN39, RN40: sem filtro nem ordem por atributo pessoal, e a
 * reputação não ordena). A busca é um POST porque conta no limite de 60 por hora: os filtros ficam fora da URL.
 * Página por cursor opaco; ele volta só com os mesmos filtros.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import { ehUuid, horarioEmUtc } from "./publicar-vaga";

export type CartaoProfissional = components["schemas"]["CartaoProfissional"];
export type Regiao = { id: number; nome: string };

const prazo = () => AbortSignal.timeout(8000);

/** Catálogo fechado das regiões (RN44), na ordem oficial. */
export async function lerRegioes(api: Api | null): Promise<Regiao[] | null> {
  if (!api) return null;
  try {
    const { data } = await api.GET("/regiao_administrativa", {
      params: { query: { select: "id,numero,nome", ativo: "eq.true", order: "id.asc" } },
      signal: AbortSignal.timeout(5000),
    });
    return data ? data.map(({ id, nome }) => ({ id, nome })) : null;
  } catch {
    return null;
  }
}

/** O que a pessoa escolheu, como texto, para voltar ao formulário e à página seguinte. */
export type FiltrosDaBusca = { funcao_id: string; regiao_id: string; dia: string; inicio: string; fim: string };
export const CAMPOS_DA_BUSCA = ["funcao_id", "regiao_id", "dia", "inicio", "fim"] as const;
export type CampoDaBusca = "funcao_id" | "regiao_id" | "horario";

export function filtrosDoFormulario(formulario: FormData): FiltrosDaBusca {
  const texto = (campo: string) => String(formulario.get(campo) ?? "").trim();
  return { funcao_id: texto("funcao_id"), regiao_id: texto("regiao_id"), dia: texto("dia"), inicio: texto("inicio"), fim: texto("fim") };
}

export type CorpoDaBusca = { funcao_id: string; regiao_id?: number; inicio_em?: string; fim_em?: string };

/** Função obrigatória; região vazia = a da casa (o servidor decide); horário com os três campos ou nenhum. */
export function lerFiltros(filtros: FiltrosDaBusca): { ok: true; corpo: CorpoDaBusca } | { ok: false; campo: CampoDaBusca } {
  if (!ehUuid(filtros.funcao_id)) return { ok: false, campo: "funcao_id" };
  const corpo: CorpoDaBusca = { funcao_id: filtros.funcao_id };
  if (filtros.regiao_id) {
    const id = Number(filtros.regiao_id);
    if (!Number.isInteger(id) || id < 1) return { ok: false, campo: "regiao_id" };
    corpo.regiao_id = id;
  }
  const partes = [filtros.dia, filtros.inicio, filtros.fim].filter(Boolean).length;
  if (partes === 3) {
    const horario = horarioEmUtc(filtros.dia, filtros.inicio, filtros.fim);
    if (!horario) return { ok: false, campo: "horario" };
    Object.assign(corpo, horario);
  } else if (partes > 0) {
    return { ok: false, campo: "horario" };
  }
  return { ok: true, corpo };
}

export type FalhaDaBusca =
  | "recurso_desligado"
  | "termos_pendentes"
  | "conta_suspensa"
  | "sem_permissao"
  | "limite"
  | "cursor_invalido"
  | "sem_regiao_da_casa"
  | "sem_sessao"
  | "indisponivel";

export type ResultadoDaBusca =
  | { ok: true; itens: CartaoProfissional[]; proximoCursor: string | null }
  | { ok: false; motivo: "campo"; campo: CampoDaBusca }
  | { ok: false; motivo: FalhaDaBusca };

export async function buscarProfissionais(api: Api | null, casaId: string, corpo: CorpoDaBusca, cursor?: string): Promise<ResultadoDaBusca> {
  if (!ehUuid(casaId) || !api) return { ok: false, motivo: ehUuid(casaId) ? "indisponivel" : "sem_permissao" };
  try {
    const { data, error, response } = await api.POST("/rpc/buscar_profissionais", {
      body: { estabelecimento_id: casaId, ...corpo, ...(cursor ? { cursor } : {}) },
      signal: prazo(),
    });
    if (data) return { ok: true, itens: data.itens, proximoCursor: data.proximo_cursor ?? null };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 429) return { ok: false, motivo: "limite" };
    if (response.status === 403) {
      const motivo = error?.details;
      if (motivo === "recurso_desligado" || motivo === "termos_pendentes" || motivo === "conta_suspensa") return { ok: false, motivo };
      return { ok: false, motivo: "sem_permissao" };
    }
    if (response.status === 422 && error) {
      if (error.code === "cursor_invalido") return { ok: false, motivo: "cursor_invalido" };
      // Sem região escolhida e sem casar a região da casa com o catálogo: a pessoa escolhe a região.
      if (error.code === "campo_obrigatorio" && error.details === "regiao_id") return { ok: false, motivo: "sem_regiao_da_casa" };
      if (error.code === "campo_invalido" || error.code === "campo_obrigatorio") {
        if (error.details === "funcao_id") return { ok: false, motivo: "campo", campo: "funcao_id" };
        if (error.details === "regiao_id") return { ok: false, motivo: "campo", campo: "regiao_id" };
        if (error.details === "inicio_em" || error.details === "fim_em") return { ok: false, motivo: "campo", campo: "horario" };
      }
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
