import type { components } from "../contrato/tipos.gerado";
import { VERSAO_DA_WEB } from "../versao";
import type { Api } from "./api";

export type ConfiguracaoDoApp = components["schemas"]["ConfiguracaoDoApp"];

export type LeituraDaConfiguracao =
  | { estado: "ok"; configuracao: ConfiguracaoDoApp }
  /** O servidor respondeu 404: a plataforma `web` ainda não tem linha em `configuracao_do_app`. */
  | { estado: "sem_configuracao" }
  /** Rede, prazo estourado ou resposta inesperada. A abertura da web nunca trava por isso. */
  | { estado: "indisponivel" }
  /** O Worker está sem o endereço ou a chave do Supabase. */
  | { estado: "nao_configurado" };

const PRAZO_MS = 3000;

export async function lerConfiguracaoDoApp(api: Api | null): Promise<LeituraDaConfiguracao> {
  if (!api) {
    return { estado: "nao_configurado" };
  }
  try {
    const { data, response } = await api.GET("/rpc/configuracao_do_app", {
      params: { query: { plataforma: "web", versao_app: VERSAO_DA_WEB } },
      signal: AbortSignal.timeout(PRAZO_MS),
    });
    if (data) {
      return { estado: "ok", configuracao: data };
    }
    return { estado: response.status === 404 ? "sem_configuracao" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}
