/**
 * Cadastro do profissional na web, em passos (2.8): funções, ponto base e regiões atendidas.
 * O perfil nasce com `criar_perfil_profissional` (funções, ponto base e a grade de horários vazia, que o contrato
 * aceita) e as regiões vão em `definir_regioes_atendidas`. O ponto base é o centro da Região Administrativa que a
 * pessoa escolhe: a web não lê a posição do aparelho em passo nenhum. Regra é do servidor; aqui só se traduz.
 */
import type { Api } from "../api";
import { centroDaRegiao, type Coordenada } from "./cadastro-centros";

export const PASSOS = ["funcoes", "ponto", "regioes"] as const;
export type Passo = (typeof PASSOS)[number];

/** O que a pessoa marcou até aqui, como veio do formulário (os passos já feitos viajam em campos escondidos). */
export type Valores = { funcoes: string[]; ponto_regiao: string; atende_todo_df: boolean; regioes: string[] };
export const VAZIO: Valores = { funcoes: [], ponto_regiao: "", atende_todo_df: false, regioes: [] };

const textosDe = (formulario: FormData, campo: string) => [...new Set(formulario.getAll(campo).map((valor) => String(valor).trim()).filter(Boolean))];

export function passoDoFormulario(formulario: FormData): Passo {
  return PASSOS.find((passo) => passo === formulario.get("passo")) ?? "funcoes";
}

export function valoresDoFormulario(formulario: FormData): Valores {
  return {
    funcoes: textosDe(formulario, "funcoes"),
    ponto_regiao: String(formulario.get("ponto_regiao") ?? "").trim(),
    atende_todo_df: formulario.get("atende_todo_df") === "sim",
    regioes: textosDe(formulario, "regioes"),
  };
}

/** Só as funções do catálogo ativo, como o app faz. Nenhuma: nulo. */
export function lerFuncoesMarcadas(valores: Valores, catalogo: readonly string[]): string[] | null {
  const funcoes = valores.funcoes.filter((id) => catalogo.includes(id));
  return funcoes.length > 0 ? funcoes : null;
}

const idDeRegiao = (texto: string, catalogo: readonly number[]): number | null => {
  const id = /^\d+$/.test(texto) ? Number(texto) : 0;
  return catalogo.includes(id) ? id : null;
};

/** O ponto base é o centro da região escolhida: ela tem de estar no catálogo e ter centro na tabela. */
export function lerPontoBase(valores: Valores, catalogo: readonly number[]): Coordenada | null {
  const id = idDeRegiao(valores.ponto_regiao, catalogo);
  return id === null ? null : centroDaRegiao(id);
}

export type RegioesAtendidas = { regioes: number[]; atende_todo_df: boolean };

/** Com "todo o DF", a lista vai vazia (o servidor a ignora). Região fora do catálogo: nulo. */
export function lerRegioesAtendidas(valores: Valores, catalogo: readonly number[]): RegioesAtendidas | null {
  if (valores.atende_todo_df) return { regioes: [], atende_todo_df: true };
  const regioes = valores.regioes.map((texto) => idDeRegiao(texto, catalogo));
  return regioes.includes(null) ? null : { regioes: regioes as number[], atende_todo_df: false };
}

export type LeituraDoPerfilCriado = "tem" | "nao_tem" | "sem_sessao" | "indisponivel";

/** Diz só se o perfil existe (`meu_perfil_profissional` não depende da chave do perfil rico). */
export async function lerSeTemPerfil(api: Api | null): Promise<LeituraDoPerfilCriado> {
  if (!api) return "indisponivel";
  try {
    const { data, response } = await api.GET("/rpc/meu_perfil_profissional", { signal: AbortSignal.timeout(5000) });
    if (data) return "tem";
    if (response.status === 404) return "nao_tem";
    return response.status === 401 ? "sem_sessao" : "indisponivel";
  } catch {
    return "indisponivel";
  }
}

export type ResultadoDaCriacao =
  | { ok: true }
  | { ok: false; motivo: "funcoes" | "ponto_base" | "perfil_incompativel" | "conta_suspensa" | "sem_sessao" | "indisponivel" };

/**
 * Cria o perfil com a grade vazia: os dias e horários ainda se marcam no app. `409 perfil_ja_existe` conta como
 * criado (o envio anterior gravou e só a resposta se perdeu): o contrato não sobrescreve, e vale o que está gravado.
 */
export async function criarPerfil(api: Api | null, funcoes: string[], pontoBase: Coordenada): Promise<ResultadoDaCriacao> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/criar_perfil_profissional", {
      body: { funcoes, ponto_base: pontoBase, disponibilidades: [] },
      signal: AbortSignal.timeout(8000),
    });
    if (data) return { ok: true };
    if (response.status === 409 && error?.code === "perfil_ja_existe") return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "conta_suspensa" };
    if (response.status === 422 && error) {
      if (error.code === "perfil_incompativel") return { ok: false, motivo: "perfil_incompativel" };
      if (error.details === "funcoes" || error.details === "ponto_base") return { ok: false, motivo: error.details };
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type ResultadoDasRegioes = { ok: true } | { ok: false; motivo: "recurso_desligado" | "sem_sessao" | "indisponivel" };

export async function definirRegioes(api: Api | null, regioes: RegioesAtendidas): Promise<ResultadoDasRegioes> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/definir_regioes_atendidas", { body: regioes, signal: AbortSignal.timeout(8000) });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403 && error?.details === "recurso_desligado") return { ok: false, motivo: "recurso_desligado" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
