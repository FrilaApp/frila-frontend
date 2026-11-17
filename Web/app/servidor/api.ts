import createClient from "openapi-fetch";

import type { paths } from "../contrato/tipos.gerado";
import type { AmbienteDoSupabase } from "./ambiente";

/**
 * Cliente tipado pelo contrato para a API REST do Supabase (tabelas e RPCs).
 * Só roda no servidor. Sem token de usuário, vale só para o que o contrato abre com a chave publicável.
 */
export function criarApi(ambiente: AmbienteDoSupabase, opcoes: { token?: string; fetch?: typeof fetch } = {}) {
  return createClient<paths>({
    baseUrl: `${ambiente.url}/rest/v1`,
    headers: {
      apikey: ambiente.chavePublicavel,
      Authorization: `Bearer ${opcoes.token ?? ambiente.chavePublicavel}`,
    },
    fetch: opcoes.fetch,
  });
}

export type Api = ReturnType<typeof criarApi>;
