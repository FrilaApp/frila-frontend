import { redirect } from "react-router";

import { aceitarTermos } from "../servidor/conta";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { exigirSessao } from "../servidor/guarda";
import { VERSAO_DOS_TERMOS } from "../versao";
import type { Route } from "./+types/aceitar-termos";

/**
 * Aceite de uma versão nova dos Termos por quem já tem conta. Sempre um envio. Grava só a versão que a pessoa viu:
 * se o formulário veio de outra versão (ou sem ela), não grava e o início mostra os termos atuais de novo.
 */
export async function action({ request, context }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  if (formulario.get("termos_versao") !== VERSAO_DOS_TERMOS) {
    throw redirect("/?termos=mudou");
  }
  const aceite = await aceitarTermos(apiDoUsuario(sessao.acesso), VERSAO_DOS_TERMOS);
  throw redirect(aceite.ok ? "/" : "/?termos=falhou");
}

export function loader() {
  throw redirect("/");
}
