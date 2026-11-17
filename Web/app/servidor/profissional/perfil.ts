/**
 * Perfil do próprio profissional: leitura completa (meu_perfil_detalhado) e a apresentação, "Sobre mim" e
 * "Onde já trabalhei" (atualizar_apresentacao_profissional). Filtro de termos e de contato, limites e a chave do
 * perfil rico são do servidor; aqui só se traduz.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import type { RecusaDoProfissional } from "./vagas";

export type PerfilDetalhado = components["schemas"]["PerfilProfissionalDetalhado"];
export const LIMITE_DA_APRESENTACAO = 600;
export const LIMITE_DE_ONDE_TRABALHEI = 400;

export type LeituraDoPerfil = { estado: "ok"; perfil: PerfilDetalhado } | { estado: "sem_perfil" } | { estado: RecusaDoProfissional };

export async function lerMeuPerfil(api: Api | null): Promise<LeituraDoPerfil> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, error, response } = await api.GET("/rpc/meu_perfil_detalhado", { signal: AbortSignal.timeout(5000) });
    if (data) return { estado: "ok", perfil: data };
    if (response.status === 404) return { estado: "sem_perfil" };
    if (response.status === 403) return { estado: "conta_suspensa" };
    if (response.status === 422 && error?.code === "perfil_incompativel") return { estado: "perfil_incompativel" };
    return { estado: "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type CampoDaApresentacao = "apresentacao" | "onde_trabalhei";
export type ResultadoDaApresentacao =
  | { ok: true }
  | { ok: false; motivo: "campo_recusado"; campo: CampoDaApresentacao }
  | { ok: false; motivo: "longo_demais"; campo: CampoDaApresentacao }
  | { ok: false; motivo: "recurso_desligado" | "sem_sessao" | "indisponivel" };

/** Texto vazio limpa o campo (null). Os dois campos vão juntos: o que a tela mostrou é o que fica. */
export async function salvarApresentacao(
  api: Api | null,
  textos: Record<CampoDaApresentacao, string>,
): Promise<ResultadoDaApresentacao> {
  const apresentacao = textos.apresentacao.trim();
  const ondeTrabalhei = textos.onde_trabalhei.trim();
  if (apresentacao.length > LIMITE_DA_APRESENTACAO) return { ok: false, motivo: "longo_demais", campo: "apresentacao" };
  if (ondeTrabalhei.length > LIMITE_DE_ONDE_TRABALHEI) return { ok: false, motivo: "longo_demais", campo: "onde_trabalhei" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/atualizar_apresentacao_profissional", {
      body: { apresentacao: apresentacao || null, onde_trabalhei: ondeTrabalhei || null },
      signal: AbortSignal.timeout(8000),
    });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403 && error?.details === "recurso_desligado") return { ok: false, motivo: "recurso_desligado" };
    if (response.status === 422 && error?.code === "campo_invalido" && (error.details === "apresentacao" || error.details === "onde_trabalhei")) {
      return { ok: false, motivo: "campo_recusado", campo: error.details };
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
