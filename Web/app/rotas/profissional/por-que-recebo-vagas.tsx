import { Form, Link, redirect, useNavigation } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { dataCivil, dataDoInstante, protocoloCurto } from "../../servidor/protocolo";
import {
  descreverJanela,
  formatarKm,
  lerCriteriosDeNotificacao,
  pedirRevisaoDoDespacho,
  RELATO_MINIMO,
} from "../../servidor/profissional/por-que-recebo-vagas";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/por-que-recebo-vagas";

const t = textos.profissional.porQueRecebo;
const tv = textos.profissional.vagas;
const tc = textos.profissionalCadastro.horarios;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** Só o que a tela mostra: as frases já montadas e o protocolo curto. O relato nunca passa por aqui. */
export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await lerCriteriosDeNotificacao(apiDoUsuario(sessao.acesso));
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  if (leitura.estado !== "ok") return { estado: leitura.estado, criterios: null };
  const c = leitura.criterios;
  return {
    estado: "ok" as const,
    criterios: {
      funcoes: c.funcoes.map((funcao) => funcao.nome),
      horarios: c.disponibilidades.map((janela) => descreverJanela(janela, tc.nomesDosDias, tc)),
      distancia: t.distancia.replace("{km}", formatarKm(c.distancia_maxima_km)),
      equipes: c.equipes_de_confianca.map((equipe) => equipe.nome),
      frequencia: t.frequencia.replace("{minutos}", String(c.notificacoes_no_maximo_a_cada_min)),
      contestacao: c.contestacao
        ? { numero: protocoloCurto(c.contestacao.ocorrencia_id), enviadoEm: dataDoInstante(c.contestacao.criada_em), prazo: dataCivil(c.contestacao.prazo_resposta_ate) }
        : null,
    },
  };
}

/** Não devolve o relato: depois de enviado (ou no reenvio, 409), a tela relê os critérios e mostra o protocolo. */
export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const resultado = await pedirRevisaoDoDespacho(apiDoUsuario(sessao.acesso), String(formulario.get("relato") ?? ""));
  if (!resultado.ok && resultado.motivo === "sem_sessao") throw redirect("/entrar");
  return { resultado: resultado.ok ? ("enviado" as const) : resultado.motivo === "sem_sessao" ? ("indisponivel" as const) : resultado.motivo };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoCartao = "flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4";
const AVISO_DO_ESTADO = {
  sem_perfil: textos.profissional.perfil.semPerfil,
  perfil_incompativel: tv.perfilIncompativel,
  conta_suspensa: tv.contaSuspensa,
  indisponivel: t.erroCarregar,
} as const;

function Lista({ itens, vazio }: { itens: string[]; vazio: string }) {
  return itens.length === 0 ? (
    <p>{vazio}</p>
  ) : (
    <ul className="list-disc pl-5">
      {itens.map((item) => (
        <li key={item}>{item}</li>
      ))}
    </ul>
  );
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function PorQueReceboVagas({ loaderData, actionData }: Route.ComponentProps) {
  const { estado, criterios } = loaderData;
  const enviando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {estado !== "ok" || !criterios ? (
        <>
          <p role="alert">{AVISO_DO_ESTADO[estado]}</p>
          {estado === "sem_perfil" ? (
            <Link to="/perfil/cadastro" className={`${classeDoBotao} inline-flex items-center justify-center`}>
              {textos.profissionalCadastro.abrir}
            </Link>
          ) : null}
        </>
      ) : (
        <>
          <p>{t.explicacao}</p>
          <section className={classeDoCartao} aria-labelledby="criterio-funcao">
            <h2 id="criterio-funcao" className="font-semibold">
              {t.secaoFuncao}
            </h2>
            <Lista itens={criterios.funcoes} vazio={t.semFuncao} />
          </section>
          <section className={classeDoCartao} aria-labelledby="criterio-horarios">
            <h2 id="criterio-horarios" className="font-semibold">
              {t.secaoHorarios}
            </h2>
            <Lista itens={criterios.horarios} vazio={t.semHorarios} />
            {criterios.horarios.length > 0 ? <p className="text-sm text-tinta-suave">{t.horariosExplicacao}</p> : null}
          </section>
          <section className={classeDoCartao} aria-labelledby="criterio-distancia">
            <h2 id="criterio-distancia" className="font-semibold">
              {t.secaoDistancia}
            </h2>
            <p>{criterios.distancia}</p>
          </section>
          <section className={classeDoCartao} aria-labelledby="criterio-equipes">
            <h2 id="criterio-equipes" className="font-semibold">
              {t.secaoEquipes}
            </h2>
            <Lista itens={criterios.equipes} vazio={t.semEquipes} />
            {criterios.equipes.length > 0 ? <p className="text-sm text-tinta-suave">{t.equipesExplicacao}</p> : null}
          </section>
          <section className={classeDoCartao} aria-labelledby="criterio-frequencia">
            <h2 id="criterio-frequencia" className="font-semibold">
              {t.secaoFrequencia}
            </h2>
            <p>{criterios.frequencia}</p>
          </section>
          <section className="flex flex-col gap-3 rounded-cartao border border-borda p-4" aria-labelledby="contestar">
            <h2 id="contestar" className="font-semibold">
              {t.secaoContestar}
            </h2>
            {actionData && actionData.resultado !== "enviado" ? (
              <p role="alert" className="font-semibold">
                {actionData.resultado === "ja_aberta" ? t.jaAberta : t.resultado[actionData.resultado]}
              </p>
            ) : null}
            {criterios.contestacao ? (
              <>
                <p role="status" className="font-semibold">
                  {t.pedidoEnviado}
                </p>
                <dl>
                  <dt className="font-semibold">{t.numero}</dt>
                  <dd className="mb-2">#{criterios.contestacao.numero}</dd>
                  <dt className="font-semibold">{t.enviadoEm}</dt>
                  <dd className="mb-2">{criterios.contestacao.enviadoEm}</dd>
                  <dt className="font-semibold">{t.prazo}</dt>
                  <dd>{criterios.contestacao.prazo}</dd>
                </dl>
                <p>{t.mensagemEnviado}</p>
                <p>{t.jaAberta}</p>
              </>
            ) : (
              <Form method="post" className="flex flex-col gap-3">
                <p>{t.contestarExplicacao}</p>
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
                    aria-invalid={actionData?.resultado === "relato_curto" ? true : undefined}
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
      )}
      <Link to="/perfil" className={classeDoLink}>
        {textos.profissional.perfil.verPerfil}
      </Link>
    </main>
  );
}
