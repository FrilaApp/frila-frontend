import { createRequestHandler } from "react-router";

import { comCabecalhosDeSeguranca } from "../app/servidor/cabecalhos";
import { respostaAntesDoApp } from "../app/servidor/porteiro";

const requestHandler = createRequestHandler(
  () => import("virtual:react-router/server-build"),
  import.meta.env.MODE,
);

export default {
  async fetch(request, env) {
    // Em produção, http vai para https antes de tudo (o servidor local de desenvolvimento roda em http).
    const antes = respostaAntesDoApp(request, { webLigada: env.WEB_LIGADA === "1", exigirHttps: env.AMBIENTE === "producao" });
    return comCabecalhosDeSeguranca(antes ?? (await requestHandler(request)));
  },
} satisfies ExportedHandler<Env>;
