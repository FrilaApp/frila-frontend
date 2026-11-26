import { redirect } from "react-router";

import { authDesteAmbiente, googleLigadoNesteAmbiente } from "../servidor/deste-ambiente";
import { desafioS256, enderecoDeRetorno, novoVerifier } from "../servidor/google";
import { cookieDoGoogle, ehPedidoSeguro } from "../servidor/sessao";
import type { Route } from "./+types/entrar-google";

/**
 * Início do "Entrar com Google" (PKCE): guarda o verifier num cookie HttpOnly de 10 minutos e manda a pessoa ao Google
 * pelo Supabase. É um link (GET), não um formulário: o `form-action 'self'` da política de conteúdo barraria o
 * redirecionamento para fora. Sem `GOOGLE_ENTRAR = "ligado"` (o Prod), recusa e volta para /entrar sem cookie.
 * Nada é logado.
 */
export async function loader({ request }: Route.LoaderArgs) {
  if (!googleLigadoNesteAmbiente()) throw redirect("/entrar");
  const auth = authDesteAmbiente();
  if (!auth) throw redirect("/entrar?erro=google_falhou");

  const verifier = novoVerifier();
  const destino = auth.urlDeAutorizacaoGoogle(enderecoDeRetorno(request), await desafioS256(verifier));
  throw redirect(destino, {
    headers: { "Set-Cookie": cookieDoGoogle(verifier, ehPedidoSeguro(request)), "Cache-Control": "no-store" },
  });
}
