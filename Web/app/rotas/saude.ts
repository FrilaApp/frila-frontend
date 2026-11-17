import { env } from "cloudflare:workers";

import { lerConfiguracaoDesteAmbiente } from "../servidor/abertura";
import { VERSAO_DA_WEB } from "../versao";

/** Rota de saúde: prova que o Worker está no ar e consegue ler `configuracao_do_app`. Sem dado pessoal. */
export async function loader() {
  const leitura = await lerConfiguracaoDesteAmbiente();
  return Response.json(
    {
      ambiente: env.AMBIENTE,
      versao: VERSAO_DA_WEB,
      web_ligada: env.WEB_LIGADA === "1",
      configuracao_do_app: leitura.estado,
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}
