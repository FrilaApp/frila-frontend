import { redirect } from "react-router";

import { exportarTurnos, lerPedido } from "../../servidor/conta/relatorio";
import { funcoesDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import type { Route } from "./+types/relatorio-arquivo";

/**
 * O arquivo do relatório: sempre um envio, num formulário que recarrega a página, para o navegador baixar. O arquivo
 * do servidor passa direto, sem ficar guardado. Sem turnos no período, ou recusa, volta à página com o aviso.
 */
export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const campo = (nome: string) => String(formulario.get(nome) ?? "").trim();
  const casa = campo("casa");
  const casaNaVolta = /^[0-9a-f-]{36}$/i.test(casa) ? `&casa=${casa}` : "";
  const volta = (erro: string) => redirect(`/conta/relatorio?erro=${erro}${casaNaVolta}`);
  const pedido = lerPedido({ de: campo("de"), ate: campo("ate"), formato: campo("formato"), casa });
  if (!pedido) throw volta("datas");
  const relatorio = await exportarTurnos(funcoesDoUsuario(sessao.acesso), pedido);
  if (!relatorio.ok) {
    if (relatorio.motivo === "sem_sessao") throw redirect("/entrar");
    throw volta(relatorio.motivo);
  }
  const nome = `frila-turnos-${campo("de")}-a-${campo("ate")}.${pedido.formato}`;
  return new Response(relatorio.corpo, {
    headers: { "Content-Type": relatorio.tipo, "Content-Disposition": `attachment; filename="${nome}"`, "Cache-Control": "no-store" },
  });
}

export function loader() {
  throw redirect("/conta/relatorio");
}
