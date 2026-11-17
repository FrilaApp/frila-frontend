import { env } from "cloudflare:workers";

import { lerConfiguracaoComVariaveis } from "./configuracao";

/** Lê `configuracao_do_app` pelo Worker, com as variáveis deste ambiente. */
export function lerConfiguracaoDesteAmbiente() {
  return lerConfiguracaoComVariaveis(env);
}

/** O link da App Store: o `url_da_loja` da linha "ios" (o mesmo que o app usa). Sem a linha, nulo. */
export async function lerLinkDaAppStore(): Promise<string | null> {
  const leitura = await lerConfiguracaoComVariaveis(env, { plataforma: "ios" });
  return leitura.estado === "ok" ? leitura.configuracao.url_da_loja : null;
}
