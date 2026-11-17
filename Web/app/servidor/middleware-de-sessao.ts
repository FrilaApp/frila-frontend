import type { MiddlewareFunction } from "react-router";

import { contextoDaSessao, contextoDoAuth } from "../contexto";
import { authDesteAmbiente } from "./deste-ambiente";
import { resolverSessao, respostaJaGravaSessao } from "./sessao";

/**
 * Roda uma vez por pedido, na raiz: decide a sessão pelo Auth (conferindo ou renovando, uma chamada só), deixa no contexto para loaders e
 * actions e, na volta, regrava os cookies. Se a rota já gravou a sessão (entrar, sair), não passa por cima.
 */
export const middlewareDeSessao: MiddlewareFunction<Response> = async ({ request, context }, next) => {
  const auth = authDesteAmbiente();
  const { sessao, cookies, auth: respostaDoAuth } = await resolverSessao(request, auth);
  context.set(contextoDaSessao, sessao);
  context.set(contextoDoAuth, respostaDoAuth);

  const resposta = await next();
  if (cookies.length > 0 && !respostaJaGravaSessao(resposta)) {
    for (const linha of cookies) resposta.headers.append("Set-Cookie", linha);
  }
  return resposta;
};
