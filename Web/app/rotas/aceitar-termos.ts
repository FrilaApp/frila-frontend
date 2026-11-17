import { redirect } from "react-router";

import { aceitarTermos } from "../servidor/conta";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { exigirSessao } from "../servidor/guarda";
import { VERSAO_DOS_TERMOS } from "../versao";
import type { Route } from "./+types/aceitar-termos";

/** Aceite de uma versão nova dos Termos por quem já tem conta. Sempre um envio. */
export async function action({ context }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const aceite = await aceitarTermos(apiDoUsuario(sessao.acesso), VERSAO_DOS_TERMOS);
  throw redirect(aceite.ok ? "/" : "/?termos=falhou");
}

export function loader() {
  throw redirect("/");
}
