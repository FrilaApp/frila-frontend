import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import { prazo } from "./casa";

export type Funcao = Pick<components["schemas"]["Funcao"], "id" | "nome" | "categoria">;

export type LeituraDasFuncoes = { estado: "ok"; funcoes: Funcao[] } | { estado: "indisponivel" };

/** Catálogo fechado de funções (RN05): a vaga nunca leva função em texto livre. */
export async function lerFuncoes(api: Api | null): Promise<LeituraDasFuncoes> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data } = await api.GET("/funcao", {
      params: { query: { select: "id,nome,categoria", ativo: "eq.true" } },
      signal: prazo(),
    });
    if (!data) return { estado: "indisponivel" };
    const funcoes = data
      .map(({ id, nome, categoria }) => ({ id, nome, categoria }))
      .sort((a, b) => a.categoria.localeCompare(b.categoria, "pt-BR") || a.nome.localeCompare(b.nome, "pt-BR"));
    return { estado: "ok", funcoes };
  } catch {
    return { estado: "indisponivel" };
  }
}

/** As funções agrupadas por categoria, para o seletor. */
export function porCategoria(funcoes: Funcao[]): Array<{ categoria: string; funcoes: Funcao[] }> {
  const grupos = new Map<string, Funcao[]>();
  for (const funcao of funcoes) grupos.set(funcao.categoria, [...(grupos.get(funcao.categoria) ?? []), funcao]);
  return [...grupos].map(([categoria, lista]) => ({ categoria, funcoes: lista }));
}
