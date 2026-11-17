/**
 * Os próprios dados (2.11): exportar (Edge Function `exportar-meus-dados`, o JSON vem no corpo e não fica guardado
 * em lugar nenhum) e excluir a conta (`excluir-conta`, definitivo: anonimiza e apaga a credencial). Só do Worker, com o
 * token de quem entrou e a chave publicável; o JSON exportado é dado pessoal: não vai a log, cookie nem URL.
 */
import createClient from "openapi-fetch";

import type { components, paths } from "../../contrato/tipos.gerado";
import type { AmbienteDoSupabase } from "../ambiente";

export type MeusDados = components["schemas"]["MeusDados"];

export function criarFuncoesDoUsuario(ambiente: AmbienteDoSupabase, acesso: string, opcoes: { fetch?: typeof fetch } = {}) {
  return createClient<paths>({
    baseUrl: `${ambiente.url}/functions/v1`,
    headers: { apikey: ambiente.chavePublicavel, Authorization: `Bearer ${acesso}` },
    fetch: opcoes.fetch,
  });
}
export type FuncoesDoUsuario = ReturnType<typeof criarFuncoesDoUsuario>;

export type Exportacao = { ok: true; dados: MeusDados } | { ok: false; motivo: "sem_conta" | "sem_sessao" | "indisponivel" };

export async function exportarMeusDados(funcoes: FuncoesDoUsuario | null): Promise<Exportacao> {
  if (!funcoes) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, response } = await funcoes.POST("/exportar-meus-dados", { signal: AbortSignal.timeout(15000) });
    if (data) return { ok: true, dados: data };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    // Sessão sem conta (antes do cadastro): não há o que exportar.
    if (response.status === 404) return { ok: false, motivo: "sem_conta" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type Exclusao = { ok: true } | { ok: false; motivo: "administrador_unico" | "sem_sessao" | "indisponivel" };

/** Idempotente no servidor: reenviar depois de uma resposta perdida devolve 202 de novo. */
export async function excluirConta(funcoes: FuncoesDoUsuario | null): Promise<Exclusao> {
  if (!funcoes) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await funcoes.POST("/excluir-conta", { body: { confirmar: true }, signal: AbortSignal.timeout(15000) });
    if (data || response.status === 202) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 409 && error?.code === "administrador_unico") return { ok: false, motivo: "administrador_unico" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
