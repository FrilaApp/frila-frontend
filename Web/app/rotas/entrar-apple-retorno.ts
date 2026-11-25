import {
  classificarErroCallbackApple,
  cookieVerifierApple,
  ehCodigoOauthValido,
  ehVerifierPkceValido,
  lerCookieVerifierApple,
} from "../servidor/apple";
import { appleEntrarLigado, authDesteAmbiente } from "../servidor/deste-ambiente";
import { BASE } from "../servidor/porteiro";
import { cookiesDaSessao, ehPedidoSeguro, lerClaimsDoToken } from "../servidor/sessao";
import type { Route } from "./+types/entrar-apple-retorno";

function redirecionarLimpandoCookie(destino: string, seguro: boolean, cookiesExtras: string[] = []): Response {
  const cabecalhos = new Headers({
    Location: destino,
    "Cache-Control": "no-store",
  });
  cabecalhos.append("Set-Cookie", cookieVerifierApple(null, seguro));
  for (const linha of cookiesExtras) cabecalhos.append("Set-Cookie", linha);
  return new Response(null, { status: 302, headers: cabecalhos });
}

export async function loader({ request }: Route.LoaderArgs) {
  const seguro = ehPedidoSeguro(request);

  if (!appleEntrarLigado()) {
    return new Response(null, {
      status: 404,
      headers: {
        "Cache-Control": "no-store",
        "Set-Cookie": cookieVerifierApple(null, seguro),
      },
    });
  }

  const url = new URL(request.url);
  const erroCallback = url.searchParams.get("error");
  const erroCodigo = url.searchParams.get("error_code");
  const erroDescricao = url.searchParams.get("error_description");
  if (erroCallback || erroCodigo) {
    const motivo = classificarErroCallbackApple(erroCallback, erroCodigo, erroDescricao);
    return redirecionarLimpandoCookie(`${BASE}/entrar?erro=${motivo}`, seguro);
  }

  const codigo = url.searchParams.get("code");
  const verifier = lerCookieVerifierApple(request, seguro);
  if (!ehCodigoOauthValido(codigo) || !ehVerifierPkceValido(verifier)) {
    return redirecionarLimpandoCookie(`${BASE}/entrar?erro=apple_recusado`, seguro);
  }

  const auth = authDesteAmbiente();
  if (!auth) {
    return redirecionarLimpandoCookie(`${BASE}/entrar?erro=indisponivel`, seguro);
  }

  const troca = await auth.trocarCodigoPkce(codigo, verifier);
  if (!troca.ok) {
    return redirecionarLimpandoCookie(`${BASE}/entrar?erro=${troca.motivo}`, seguro);
  }

  const destino = lerClaimsDoToken(troca.sessao.access_token).precisaDefinirSenha
    ? `${BASE}/definir-senha?origem=pendente`
    : `${BASE}/`;
  return redirecionarLimpandoCookie(destino, seguro, cookiesDaSessao(troca.sessao, seguro));
}
