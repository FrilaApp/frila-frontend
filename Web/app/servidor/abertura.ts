import { env } from "cloudflare:workers";

import { lerConfiguracaoComVariaveis } from "./configuracao";

/** Lê `configuracao_do_app` pelo Worker, com as variáveis deste ambiente. */
export function lerConfiguracaoDesteAmbiente() {
  return lerConfiguracaoComVariaveis(env);
}
