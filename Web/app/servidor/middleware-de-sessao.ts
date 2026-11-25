import type { MiddlewareFunction } from "react-router";

import { contextoDaSessao, contextoDoAuth } from "../contexto";
import { authDesteAmbiente } from "./deste-ambiente";
import { BASE } from "./porteiro";
import { lerClaimsDoToken, resolverSessao, respostaJaGravaSessao } from "./sessao";

const PERMITIDOS_COM_SENHA_PENDENTE = new Set([
  `${BASE}/definir-senha`,
  `${BASE}/definir-senha.data`,
  `${BASE}/sair`,
  `${BASE}/sair.data`,
  `${BASE}/saude`,
  `${BASE}/sem-conexao`,
  `${BASE}/avisos/texto-neutro`,
]);

/**
 * Roda uma vez por pedido, na raiz: decide a sessão pelo Auth (conferindo ou renovando, uma chamada só), deixa no contexto para loaders e
 * actions e, na volta, regrava os cookies. Se a rota já gravou a sessão (entrar, sair), não passa por cima.
 * Se o JWT validado carregar `app_metadata.precisa_definir_senha = true`, redireciona para `/app/definir-senha` até concluir.
 */
export const middlewareDeSessao: MiddlewareFunction<Response> = async ({ request, context }, next) => {
  const auth = authDesteAmbiente();
  const { sessao, cookies, auth: respostaDoAuth } = await resolverSessao(request, auth);
  context.set(contextoDaSessao, sessao);
  context.set(contextoDoAuth, respostaDoAuth);

  if (sessao && lerClaimsDoToken(sessao.acesso).precisaDefinirSenha) {
    const url = new URL(request.url);
    if (!PERMITIDOS_COM_SENHA_PENDENTE.has(url.pathname)) {
      const destino = new URL(`${BASE}/definir-senha?origem=pendente`, url.origin);
      const cabecalhos = new Headers({ Location: destino.toString(), "Cache-Control": "no-store" });
      for (const linha of cookies) cabecalhos.append("Set-Cookie", linha);
      return new Response(null, { status: 302, headers: cabecalhos });
    }
  }

  const resposta = await next();
  if (cookies.length > 0 && !respostaJaGravaSessao(resposta)) {
    for (const linha of cookies) resposta.headers.append("Set-Cookie", linha);
  }
  return resposta;
};
