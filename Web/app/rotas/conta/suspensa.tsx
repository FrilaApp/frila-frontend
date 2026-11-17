import { Form, Link, redirect, useNavigation } from "react-router";

import { contestarSuspensao, lerSituacaoDaConta, RELATO_MINIMO } from "../../servidor/conta/suspensao";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { dataCivil, dataDoInstante, protocoloCurto } from "../../servidor/protocolo";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/suspensa";

const t = textos.suspensao;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** O resultado da análise não aparece aqui (RN07): só o protocolo e o prazo, e o recurso é por e-mail. */
export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await lerSituacaoDaConta(apiDoUsuario(sessao.acesso));
  if (leitura.estado !== "ok") return { estado: "indisponivel" as const };
  const { suspensao } = leitura.situacao;
  if (leitura.situacao.estado !== "suspensa" || !suspensao) return { estado: "ativa" as const };
  const contestacao = suspensao.contestacao;
  return {
    estado: "suspensa" as const,
    motivo: suspensao.motivo,
    desde: dataDoInstante(suspensao.desde),
    contestacao: contestacao
      ? { numero: protocoloCurto(contestacao.ocorrencia_id), enviadaEm: dataDoInstante(contestacao.criada_em), prazo: dataCivil(contestacao.prazo_resposta_ate) }
      : null,
  };
}

/** Não devolve o relato: depois de enviada (ou no reenvio, 409), a tela relê a situação e mostra o protocolo. */
export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const resultado = await contestarSuspensao(apiDoUsuario(sessao.acesso), String(formulario.get("relato") ?? ""));
  if (!resultado.ok && resultado.motivo === "sem_sessao") throw redirect("/entrar");
  return { resultado: resultado.ok ? ("enviada" as const) : resultado.motivo === "sem_sessao" ? ("indisponivel" as const) : resultado.motivo };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function ContaSuspensa({ loaderData, actionData }: Route.ComponentProps) {
  const enviando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {actionData?.resultado ? (
        <p role="status" className="font-semibold">
          {t.resultado[actionData.resultado]}
        </p>
      ) : null}
      {loaderData.estado === "indisponivel" ? <p role="alert">{t.indisponivel}</p> : null}
      {loaderData.estado === "ativa" ? <p>{t.ativa}</p> : null}
      {loaderData.estado === "suspensa" ? (
        <>
          <p className="text-lg font-semibold">{t.subtitulo}</p>
          <p>{t.avisoPrincipal}</p>
          <dl className="rounded-cartao border border-borda bg-superficie p-4">
            <dt className="font-semibold">{t.motivo}</dt>
            <dd className="mb-2">{loaderData.motivo}</dd>
            <dt className="font-semibold">{t.desde}</dt>
            <dd>{loaderData.desde}</dd>
          </dl>
          <section className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
            <h2 className="font-semibold">{t.contestacao}</h2>
            {loaderData.contestacao ? (
              <>
                <p className="font-semibold">{t.emAnalise}</p>
                <dl>
                  <dt className="font-semibold">{t.numero}</dt>
                  <dd className="mb-2">#{loaderData.contestacao.numero}</dd>
                  <dt className="font-semibold">{t.enviadaEm}</dt>
                  <dd className="mb-2">{loaderData.contestacao.enviadaEm}</dd>
                  <dt className="font-semibold">{t.prazo}</dt>
                  <dd>{loaderData.contestacao.prazo}</dd>
                </dl>
                <p>{t.mensagemEmAnalise}</p>
                <p>{t.recurso}</p>
              </>
            ) : (
              <Form method="post" className="flex flex-col gap-3">
                <p>{t.prazoDaAnalise}</p>
                <label className="flex flex-col gap-2 font-semibold" htmlFor="relato">
                  {t.rotuloDoRelato}
                  <span id="dica-do-relato" className="text-sm font-normal text-tinta-suave">
                    {t.dicaDoRelato}
                  </span>
                  <textarea
                    id="relato"
                    name="relato"
                    required
                    minLength={RELATO_MINIMO}
                    rows={5}
                    autoComplete="off"
                    aria-describedby="dica-do-relato"
                    className="w-full rounded-controle border border-borda bg-superficie p-3 text-lg"
                  />
                </label>
                <button type="submit" disabled={enviando} className={classeDoBotao}>
                  {enviando ? t.enviando : t.enviar}
                </button>
              </Form>
            )}
          </section>
        </>
      ) : null}
      <Link to="/" className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
