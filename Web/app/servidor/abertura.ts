import { env } from "cloudflare:workers";

import { ambienteDoSupabase } from "./ambiente";
import { criarApi } from "./api";
import { lerConfiguracaoDoApp } from "./configuracao";

/** Lê `configuracao_do_app` pelo Worker, com as variáveis deste ambiente. */
export function lerConfiguracaoDesteAmbiente() {
  const ambiente = ambienteDoSupabase(env);
  return lerConfiguracaoDoApp(ambiente ? criarApi(ambiente) : null);
}
