import { redirect } from "react-router";

import { contextoDaSessao } from "../contexto";
import { authDesteAmbiente } from "../servidor/deste-ambiente";
import { cookiesDeSaida, ehPedidoSeguro } from "../servidor/sessao";
import type { Route } from "./+types/sair";

/** Sair é sempre um envio (POST): um link de outro site não desloga ninguém. */
export async function action({ request, context }: Route.ActionArgs) {
  const sessao = context.get(contextoDaSessao);
  if (sessao) {
    await authDesteAmbiente()?.encerrar(sessao.acesso);
  }
  const cabecalhos = new Headers();
  for (const linha of cookiesDeSaida(ehPedidoSeguro(request))) cabecalhos.append("Set-Cookie", linha);
  throw redirect("/entrar", { headers: cabecalhos });
}

export function loader() {
  throw redirect("/");
}
