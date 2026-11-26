import { redirect } from "react-router";

import { contextoDaSessao } from "../contexto";
import { cookieTransacaoApple, desafioPkceS256, gerarVerifierPkce } from "../servidor/apple";
import { appleEntrarLigado, authDesteAmbiente } from "../servidor/deste-ambiente";
import { BASE } from "../servidor/porteiro";
import { ehPedidoSeguro, visitanteDoPedido } from "../servidor/sessao";
import type { Route } from "./+types/entrar-apple";

export async function loader({ request, context }: Route.LoaderArgs) {
  if (!appleEntrarLigado()) {
    return new Response(null, { status: 404, headers: { "Cache-Control": "no-store" } });
  }
  if (context.get(contextoDaSessao)) {
    throw redirect("/");
  }

  const auth = authDesteAmbiente();
  if (!auth) {
    throw redirect("/entrar?erro=indisponivel");
  }

  const seguro = ehPedidoSeguro(request);
  const visitante = visitanteDoPedido(request);
  const verifier = gerarVerifierPkce();
  const codeChallenge = await desafioPkceS256(verifier);
  const urlRetorno = new URL(`${BASE}/entrar/apple/retorno`, new URL(request.url).origin).toString();

  const inicio = await auth.iniciarLoginSocialPkce({
    provedor: "apple",
    codeChallenge,
    redirectTo: urlRetorno,
    visitante,
  });
  if (!inicio.ok) {
    throw redirect(`/entrar?erro=${inicio.motivo}`);
  }

  return new Response(null, {
    status: 302,
    headers: {
      Location: inicio.urlAutorizacao,
      "Cache-Control": "no-store",
      "Set-Cookie": cookieTransacaoApple({ transacaoId: inicio.transacaoId, verifier }, seguro),
    },
  });
}
