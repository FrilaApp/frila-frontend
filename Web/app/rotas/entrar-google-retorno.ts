import { redirect } from "react-router";

import { contextoDaSessao } from "../contexto";
import { authDesteAmbiente, googleLigadoNesteAmbiente } from "../servidor/deste-ambiente";
import { verifierValido } from "../servidor/google";
import { cookieDoGoogle, cookiesDaSessao, ehPedidoSeguro, lerCookieDoGoogle } from "../servidor/sessao";
import type { Route } from "./+types/entrar-google-retorno";

/** Tamanho máximo aceito para o `code` (o do Supabase tem um UUID); evita mandar lixo ao Auth. */
const MAXIMO_DO_CODIGO = 512;

/**
 * Volta do Google (pelo Supabase): troca o `code` pela sessão com o verifier do cookie e grava a sessão pelo mesmo
 * caminho do login por senha. Qualquer falha (erro do Google, `code` ou verifier ausente, troca recusada) volta a
 * /entrar com uma mensagem curta fixa: nada do que veio na URL é repetido na tela nem logado. O cookie do verifier é
 * apagado em todos os desfechos.
 */
export async function loader({ request, context }: Route.LoaderArgs) {
  const seguro = ehPedidoSeguro(request);
  const apagarVerifier = cookieDoGoogle(null, seguro);
  const voltar = (destino: string, ...gravar: string[]) => {
    const cabecalhos = new Headers({ "Cache-Control": "no-store" });
    for (const linha of [...gravar, apagarVerifier]) cabecalhos.append("Set-Cookie", linha);
    return redirect(destino, { headers: cabecalhos });
  };

  if (!googleLigadoNesteAmbiente()) throw voltar("/entrar");
  if (context.get(contextoDaSessao)) throw voltar("/");

  const parametros = new URL(request.url).searchParams;
  if (parametros.has("error")) {
    throw voltar(`/entrar?erro=${parametros.get("error") === "access_denied" ? "google_cancelado" : "google_falhou"}`);
  }

  const codigo = parametros.get("code");
  const verifier = lerCookieDoGoogle(request);
  const auth = authDesteAmbiente();
  if (!auth || !codigo || codigo.length > MAXIMO_DO_CODIGO || !verifierValido(verifier)) {
    throw voltar("/entrar?erro=google_falhou");
  }

  const troca = await auth.trocarCodigoPkce(codigo, verifier);
  if (!troca.ok) throw voltar("/entrar?erro=google_falhou");

  // Mesmo destino do login atual: o início decide o papel; se a conta precisa definir senha, o middleware leva até lá.
  throw voltar("/", ...cookiesDaSessao(troca.sessao, seguro));
}
