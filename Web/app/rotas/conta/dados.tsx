import { Form, Link, redirect, useNavigation } from "react-router";

import { excluirConta } from "../../servidor/conta/dados";
import { funcoesDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { cookieDoAparelho } from "../../servidor/push";
import { cookiesDeSaida, ehPedidoSeguro } from "../../servidor/sessao";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/dados";

const t = textos.contaDados;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export function loader({ context, request }: Route.LoaderArgs) {
  exigirSessao(context);
  const exportar = new URL(request.url).searchParams.get("exportar");
  return { exportar: exportar === "sem_conta" ? t.exportar.semConta : exportar === "falhou" ? t.exportar.falhou : null };
}

/**
 * Excluir é definitivo: só com a caixa de ciência marcada. Deu certo (202, ou 401 de conta já excluída): a sessão
 * deixa de valer no servidor, os cookies (da sessão e do aparelho do push) saem e a pessoa vai para a entrada.
 */
export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  if (formulario.get("ciente") !== "sim") return { falha: "sem_confirmacao" as const };
  const exclusao = await excluirConta(funcoesDoUsuario(sessao.acesso));
  if (!exclusao.ok && exclusao.motivo !== "sem_sessao") return { falha: exclusao.motivo };
  const cabecalhos = new Headers();
  for (const linha of cookiesDeSaida(ehPedidoSeguro(request))) cabecalhos.append("Set-Cookie", linha);
  // O cookie do aparelho do push também sai (achado A7 do Juiz): a conta não existe mais.
  cabecalhos.append("Set-Cookie", cookieDoAparelho(null, ehPedidoSeguro(request)));
  throw redirect("/entrar", { headers: cabecalhos });
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoSecundario = "min-h-12 w-full rounded-controle border border-borda px-4 text-lg font-semibold disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function MinhaConta({ loaderData, actionData }: Route.ComponentProps) {
  const excluindo = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>

      <Link to="/conta/aparencia" className={classeDoLink}>
        {textos.aparencia.titulo}
      </Link>

      <Link to="/definir-senha" className={classeDoLink}>
        {textos.definirSenha.alterarSenha}
      </Link>

      <section className="flex flex-col gap-3 rounded-cartao border border-borda bg-superficie p-4" aria-labelledby="titulo-exportar">
        <h2 id="titulo-exportar" className="font-titulo text-xl font-bold">
          {t.exportar.titulo}
        </h2>
        <p>{t.exportar.corpo}</p>
        {loaderData.exportar ? <p role="alert" className="font-semibold">{loaderData.exportar}</p> : null}
        {/* Recarrega a página de propósito: o navegador baixa o arquivo que a resposta traz. */}
        <Form method="post" action="/conta/meus-dados" reloadDocument>
          <button type="submit" className={classeDoSecundario}>
            {t.exportar.botao}
          </button>
        </Form>
      </section>

      <Link to="/conta/relatorio" className={classeDoLink}>
        {textos.relatorioTurnos.abrir}
      </Link>

      <section className="flex flex-col gap-3 rounded-cartao border border-borda p-4" aria-labelledby="titulo-excluir">
        <h2 id="titulo-excluir" className="font-titulo text-xl font-bold">
          {t.excluir.titulo}
        </h2>
        <p className="font-semibold">{t.excluir.aviso}</p>
        <p>{t.excluir.oQueAcontece}</p>
        <ul className="list-disc pl-6">
          <li>{t.excluir.anonimizacao}</li>
          <li>{t.excluir.turnos}</li>
          <li>{t.excluir.prazo}</li>
        </ul>
        {actionData ? (
          <p role="alert" className="font-semibold">
            {t.excluir.erros[actionData.falha]}
          </p>
        ) : null}
        <Form method="post" className="flex flex-col gap-3">
          <label className="flex min-h-12 items-center gap-3">
            <input type="checkbox" name="ciente" value="sim" required className="size-5 shrink-0" />
            <span>{t.excluir.confirmacao}</span>
          </label>
          <button type="submit" disabled={excluindo} className={classeDoSecundario}>
            {excluindo ? t.excluir.excluindo : t.excluir.botao}
          </button>
        </Form>
      </section>

      {/* O mesmo Sair do início: se falhar, o /sair leva a /?sair=falhou, que mostra o aviso e oferece tentar de novo. */}
      <Form method="post" action="/sair">
        <button type="submit" className={classeDoSecundario}>
          {textos.conta.sair}
        </button>
      </Form>

      <Link to="/" className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
