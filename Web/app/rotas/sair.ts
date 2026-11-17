import { redirect } from "react-router";

import { contextoDaSessao, contextoDoAuth } from "../contexto";
import { apiDoUsuario, authDesteAmbiente } from "../servidor/deste-ambiente";
import { cookieDoAparelho, lerTokenDoAparelho, removerAparelho } from "../servidor/push";
import { cookiesDeSaida, ehPedidoSeguro } from "../servidor/sessao";
import type { Route } from "./+types/sair";

/**
 * Sair é sempre um envio (POST): um link de outro site não desloga ninguém. Só se dá por concluído com a sessão
 * encerrada no Auth (revogação confirmada) ou já inexistente. Se o Auth falhar, os cookies ficam e a pessoa tenta de
 * novo: apagar só os cookies deixaria a sessão viva no Auth, e uma resposta atrasada a traria de volta.
 */
export async function action({ request, context }: Route.ActionArgs) {
  const sessao = context.get(contextoDaSessao);
  const respostaDoAuth = context.get(contextoDoAuth);
  // Push na web (RN15): antes de encerrar, o token deste navegador deixa de ser da conta. Se falhar, o sair segue: o
  // push da web mostra sempre só o texto neutro (sw.js), então nenhum conteúdo da conta aparece depois do sair.
  const tokenDoAparelho = lerTokenDoAparelho(request);
  if (sessao && tokenDoAparelho) await removerAparelho(apiDoUsuario(sessao.acesso), tokenDoAparelho);
  const encerrada = sessao
    ? (await authDesteAmbiente()?.encerrar(sessao.acesso))?.ok === true
    : respostaDoAuth === "recusou" || respostaDoAuth === "sem_cookie";
  if (!encerrada) {
    throw redirect("/?sair=falhou");
  }
  const cabecalhos = new Headers();
  for (const linha of cookiesDeSaida(ehPedidoSeguro(request))) cabecalhos.append("Set-Cookie", linha);
  if (tokenDoAparelho) cabecalhos.append("Set-Cookie", cookieDoAparelho(null, ehPedidoSeguro(request)));
  throw redirect("/entrar", { headers: cabecalhos });
}

export function loader() {
  throw redirect("/");
}
