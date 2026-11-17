import type { components } from "../contrato/tipos.gerado";
import { VERSAO_DA_WEB } from "../versao";
import { ambienteDoSupabase, ChaveProibida } from "./ambiente";
import { type Api, criarApi } from "./api";

export type ConfiguracaoDoApp = components["schemas"]["ConfiguracaoDoApp"];

export type LeituraDaConfiguracao =
  | { estado: "ok"; configuracao: ConfiguracaoDoApp }
  /** O servidor respondeu 404: a plataforma `web` ainda não tem linha em `configuracao_do_app`. */
  | { estado: "sem_configuracao" }
  /** Rede, prazo estourado ou resposta inesperada. A abertura da web nunca trava por isso. */
  | { estado: "indisponivel" }
  /** O Worker está sem o endereço ou a chave do Supabase. */
  | { estado: "nao_configurado" }
  /** A chave posta no Worker não é publicável. Nenhum pedido sai com ela. */
  | { estado: "chave_recusada" };

export const PRAZO_MS = 3000;

export async function lerConfiguracaoDoApp(
  api: Api | null,
  opcoes: { prazoMs?: number; plataforma?: "web" | "ios" } = {},
): Promise<LeituraDaConfiguracao> {
  if (!api) {
    return { estado: "nao_configurado" };
  }
  try {
    const { data, response } = await api.GET("/rpc/configuracao_do_app", {
      // A linha "ios" só serve para o link da loja (url_da_loja), que o próprio app usa.
      params: { query: { plataforma: opcoes.plataforma ?? "web", versao_app: VERSAO_DA_WEB } },
      signal: AbortSignal.timeout(opcoes.prazoMs ?? PRAZO_MS),
    });
    if (data) {
      return { estado: "ok", configuracao: data };
    }
    return { estado: response.status === 404 ? "sem_configuracao" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

/** Monta o cliente com as variáveis do Worker e lê a configuração. Chave de serviço vira estado, não erro 500. */
export async function lerConfiguracaoComVariaveis(
  variaveis: Parameters<typeof ambienteDoSupabase>[0],
  opcoes: { fetch?: typeof fetch; plataforma?: "web" | "ios" } = {},
): Promise<LeituraDaConfiguracao> {
  try {
    const ambiente = ambienteDoSupabase(variaveis);
    return await lerConfiguracaoDoApp(ambiente ? criarApi(ambiente, { fetch: opcoes.fetch }) : null, { plataforma: opcoes.plataforma });
  } catch (erro) {
    if (erro instanceof ChaveProibida) {
      console.error(erro.message);
      return { estado: "chave_recusada" };
    }
    throw erro;
  }
}
