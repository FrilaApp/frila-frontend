import { redirect } from "react-router";

import { contextoDaSessao } from "../contexto";
import { cookieVerifierApple, desafioPkceS256, gerarVerifierPkce, montarUrlAutorizacaoApple } from "../servidor/apple";
import { appleEntrarLigado, urlDoSupabaseDesteAmbiente } from "../servidor/deste-ambiente";
import { BASE } from "../servidor/porteiro";
import { ehPedidoSeguro } from "../servidor/sessao";
import type { Route } from "./+types/entrar-apple";

export async function loader({ request, context }: Route.LoaderArgs) {
  if (!appleEntrarLigado()) {
    return new Response(null, { status: 404, headers: { "Cache-Control": "no-store" } });
  }
  if (context.get(contextoDaSessao)) {
    throw redirect("/");
  }

  const supabaseUrl = urlDoSupabaseDesteAmbiente();
  if (!supabaseUrl) {
    throw redirect("/entrar?erro=indisponivel");
  }

  const seguro = ehPedidoSeguro(request);
  const verifier = gerarVerifierPkce();
  const codeChallenge = await desafioPkceS256(verifier);
  const urlRetorno = new URL(`${BASE}/entrar/apple/retorno`, new URL(request.url).origin).toString();
  const destino = montarUrlAutorizacaoApple({ supabaseUrl, urlRetorno, codeChallenge });

  return new Response(null, {
    status: 302,
    headers: {
      Location: destino,
      "Cache-Control": "no-store",
      "Set-Cookie": cookieVerifierApple(verifier, seguro),
    },
  });
}
