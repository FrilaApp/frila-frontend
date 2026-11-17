import type { MiddlewareFunction } from "react-router";

import { contextoDaSessao } from "../contexto";
import { authDesteAmbiente } from "./deste-ambiente";
import { resolverSessao, respostaJaGravaSessao } from "./sessao";

/**
 * Roda uma vez por pedido, na raiz: decide a sessão (renovando se for a hora), deixa no contexto para loaders e
 * actions e, na volta, regrava os cookies. Se a rota já gravou a sessão (entrar, sair), não passa por cima.
 */
export const middlewareDeSessao: MiddlewareFunction<Response> = async ({ request, context }, next) => {
  const auth = authDesteAmbiente();
  const { sessao, cookies } = await resolverSessao(request, async (token) =>
    auth ? auth.renovar(token) : { ok: false, motivo: "indisponivel" },
  );
  context.set(contextoDaSessao, sessao);

  const resposta = await next();
  if (cookies.length > 0 && !respostaJaGravaSessao(resposta)) {
    for (const linha of cookies) resposta.headers.append("Set-Cookie", linha);
  }
  return resposta;
};
