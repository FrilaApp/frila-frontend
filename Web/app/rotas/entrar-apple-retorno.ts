import {
  classificarErroCallbackApple,
  cookieTransacaoApple,
  ehCodigoOauthValido,
  lerCookieTransacaoApple,
} from "../servidor/apple";
import { appleEntrarLigado, authDesteAmbiente } from "../servidor/deste-ambiente";
import { BASE } from "../servidor/porteiro";
import { cookiesDaSessao, ehPedidoSeguro, lerClaimsDoToken, visitanteDoPedido } from "../servidor/sessao";
import type { Route } from "./+types/entrar-apple-retorno";

function redirecionar(
  destino: string,
  opcoes: { limparCookieApple: boolean; seguro: boolean; cookiesExtras?: string[] },
): Response {
  const cabecalhos = new Headers({
    Location: destino,
    "Cache-Control": "no-store",
  });
  if (opcoes.limparCookieApple) {
    cabecalhos.append("Set-Cookie", cookieTransacaoApple(null, opcoes.seguro));
  }
  for (const linha of opcoes.cookiesExtras ?? []) cabecalhos.append("Set-Cookie", linha);
  return new Response(null, { status: 302, headers: cabecalhos });
}

export async function loader({ request }: Route.LoaderArgs) {
  const seguro = ehPedidoSeguro(request);

  if (!appleEntrarLigado()) {
    return new Response(null, {
      status: 404,
      headers: { "Cache-Control": "no-store" },
    });
  }

  const url = new URL(request.url);
  const { presente, transacao } = lerCookieTransacaoApple(request, seguro);

  const erroCallback = url.searchParams.get("error");
  const erroCodigo = url.searchParams.get("error_code");
  const erroDescricao = url.searchParams.get("error_description");
  if (erroCallback || erroCodigo) {
    const motivo = classificarErroCallbackApple(erroCallback, erroCodigo, erroDescricao);
    // P2: callback com erro sem correspondência de `tx` (ex.: link forjado) NÃO limpa o cookie
    // de uma transação legítima em andamento. Só limpa se o cookie estiver corrompido ou se `tx` bater.
    const txCallback = url.searchParams.get("tx");
    const limparCookieApple =
      (presente && transacao === null) || (transacao !== null && txCallback === transacao.transacaoId);
    return redirecionar(`${BASE}/entrar?erro=${motivo}`, { limparCookieApple, seguro });
  }

  const codigo = url.searchParams.get("code");
  if (!ehCodigoOauthValido(codigo)) {
    // Hit sem código válido: limpa apenas se o cookie estiver corrompido; preserva transação válida em andamento.
    return redirecionar(`${BASE}/entrar?erro=apple_recusado`, {
      limparCookieApple: presente && transacao === null,
      seguro,
    });
  }

  if (!transacao) {
    return redirecionar(`${BASE}/entrar?erro=apple_recusado`, {
      limparCookieApple: presente,
      seguro,
    });
  }

  const auth = authDesteAmbiente();
  if (!auth) {
    return redirecionar(`${BASE}/entrar?erro=indisponivel`, { limparCookieApple: false, seguro });
  }

  const troca = await auth.concluirLoginSocialPkce({
    provedor: "apple",
    transacaoId: transacao.transacaoId,
    codigo,
    codeVerifier: transacao.verifier,
    visitante: visitanteDoPedido(request),
  });
  if (!troca.ok) {
    // Em indisponibilidade transitória mantém cookie; em recusa definitiva consome/limpa.
    const limparCookieApple = troca.motivo !== "indisponivel";
    return redirecionar(`${BASE}/entrar?erro=${troca.motivo}`, { limparCookieApple, seguro });
  }

  const precisaDefinirSenha =
    troca.precisaDefinirSenha || lerClaimsDoToken(troca.sessao.access_token).precisaDefinirSenha;
  const destino = precisaDefinirSenha ? `${BASE}/definir-senha?origem=pendente` : `${BASE}/`;
  return redirecionar(destino, {
    limparCookieApple: true,
    seguro,
    cookiesExtras: cookiesDaSessao(troca.sessao, seguro),
  });
}
