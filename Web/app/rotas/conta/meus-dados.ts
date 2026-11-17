import { redirect } from "react-router";

import { exportarMeusDados } from "../../servidor/conta/dados";
import { funcoesDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import type { Route } from "./+types/meus-dados";

/**
 * O arquivo com os próprios dados (portabilidade, LGPD). Sempre um envio (POST), num formulário que recarrega a página:
 * o navegador baixa o arquivo e a pessoa fica onde estava. Nada fica guardado: a resposta é `no-store`.
 */
export async function action({ context }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const exportacao = await exportarMeusDados(funcoesDoUsuario(sessao.acesso));
  if (!exportacao.ok) {
    if (exportacao.motivo === "sem_sessao") throw redirect("/entrar");
    throw redirect(`/conta?exportar=${exportacao.motivo === "sem_conta" ? "sem_conta" : "falhou"}`);
  }
  const dia = new Date().toISOString().slice(0, 10);
  return new Response(JSON.stringify(exportacao.dados, null, 2), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Content-Disposition": `attachment; filename="frila-meus-dados-${dia}.json"`,
      "Cache-Control": "no-store",
    },
  });
}

export function loader() {
  throw redirect("/conta");
}
