import { Form, Link, redirect, useNavigation } from "react-router";

import { escolherCandidato, lerCandidatos, candidatosParaATela } from "../../servidor/contratante/candidatos";
import { escolherCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { detalheDaVaga, lerPainel } from "../../servidor/contratante/painel";
import { ehUuid } from "../../servidor/contratante/publicar-vaga";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/vaga";
import { preencher } from "./comum";

const t = textos.contratante.vaga;
const tp = textos.contratante.painel;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ request, params, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const endereco = new URL(request.url);

  const leitura = await lerMinhasCasas(api);
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  const casa = leitura.estado === "ok" ? escolherCasa(leitura.casas, endereco.searchParams.get("casa")) : null;
  if (!casa) throw redirect("/painel");

  const painel = await lerPainel(api, casa.id, new Date());
  if (painel.estado === "sem_sessao") throw redirect("/entrar");
  if (painel.estado !== "ok") return { estado: painel.estado, casaId: casa.id } as const;
  const vaga = detalheDaVaga(painel.painel, params.vagaId);
  if (!vaga) return { estado: "nao_encontrada", casaId: casa.id } as const;

  // Candidatos só no modo seleção e com a vaga aberta: no urgência quem aceita primeiro já fica com o lugar.
  const comCandidatos = vaga.modo === "selecao" && vaga.estado === "publicada";
  const candidatos = comCandidatos ? await lerCandidatos(api, vaga.id) : null;
  if (candidatos?.estado === "sem_sessao") throw redirect("/entrar");

  return {
    estado: "ok",
    casaId: casa.id,
    vaga,
    candidatos: candidatos?.estado === "ok" ? candidatosParaATela(candidatos.candidatos) : null,
    candidatosIndisponiveis: comCandidatos && candidatos?.estado !== "ok",
    escolhido: endereco.searchParams.get("escolhido") === "1",
  } as const;
}

export async function action({ request, params, context }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const candidatura = String(formulario.get("candidatura_id") ?? "");
  const casaId = String(formulario.get("casa") ?? "");
  if (!ehUuid(candidatura) || !ehUuid(casaId)) return { erro: t.erros.formularioVelho };

  const resultado = await escolherCandidato(apiDoUsuario(sessao.acesso), candidatura);
  if (resultado.ok) throw redirect(`/painel/vagas/${params.vagaId}?casa=${casaId}&escolhido=1`);
  if (resultado.motivo === "sem_sessao") throw redirect("/entrar");
  return { erro: t.erros[resultado.motivo] };
}

const MENSAGEM = { sem_permissao: tp.semPermissao, indisponivel: tp.indisponivel, nao_encontrada: t.naoEncontrada } as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function VagaDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const enviando = useNavigation().state !== "idle";
  const voltar = (
    <Link to={`/painel?casa=${loaderData.casaId}`} className="min-h-11 font-semibold underline underline-offset-4">
      {t.voltar}
    </Link>
  );
  if (loaderData.estado !== "ok") {
    return (
      <main className="mx-auto flex min-h-dvh max-w-2xl flex-col gap-6 p-6">
        {voltar}
        <p role="status">{MENSAGEM[loaderData.estado]}</p>
      </main>
    );
  }

  const { vaga, candidatos, casaId } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-2xl flex-col gap-6 p-6">
      {voltar}
      <header className="flex flex-col gap-1">
        <h1 className="font-titulo text-3xl font-bold first-letter:uppercase">{vaga.funcao}</h1>
        <p>
          {vaga.dia} · {vaga.horario} · {vaga.valor}
        </p>
        <p className="text-tinta-suave">
          {tp.estado[vaga.estado]} · {t.modo[vaga.modo]} · {t.onde}: {vaga.local}, {vaga.regiao}
        </p>
        {vaga.oculta ? <p className="font-semibold">{tp.oculta}</p> : null}
        {vaga.alertaVagaVazia ? <p className="font-semibold">{tp.alertaVagaVazia}</p> : null}
      </header>

      {loaderData.escolhido ? <p role="status" className="font-semibold">{t.escolhido}</p> : null}
      {actionData?.erro ? <p role="alert" className="font-semibold">{actionData.erro}</p> : null}

      <section className="flex flex-col gap-3" aria-labelledby="titulo-lugares">
        <h2 id="titulo-lugares" className="font-titulo text-xl font-bold">
          {t.posicoes} · {preencher(tp.posicoes, { ocupadas: vaga.ocupadas, total: vaga.posicoes })}
        </h2>
        <ul className="flex flex-col gap-2">
          {vaga.lista.map((posicao) => (
            <li key={posicao.id} className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4">
              <p className="flex flex-wrap justify-between gap-2">
                <strong>{posicao.profissional ?? t.vazia}</strong>
                <span className="text-sm font-semibold">{t.posicao[posicao.estado]}</span>
              </p>
              {posicao.aCaminho ? <p>{t.aCaminho}</p> : null}
              {posicao.emAtraso ? <p className="font-semibold">{t.emAtraso}</p> : null}
              {posicao.verificacao ? <p className="text-tinta-suave">{t.verificacao[posicao.verificacao]}</p> : null}
            </li>
          ))}
        </ul>
      </section>

      {candidatos || loaderData.candidatosIndisponiveis ? (
        <section className="flex flex-col gap-3" aria-labelledby="titulo-candidatos">
          <h2 id="titulo-candidatos" className="font-titulo text-xl font-bold">
            {t.candidatos}
          </h2>
          <p className="text-tinta-suave">{t.ordemDeChegada}</p>
          {loaderData.candidatosIndisponiveis ? <p role="status">{t.candidatosIndisponiveis}</p> : null}
          {candidatos?.length === 0 ? <p>{t.semCandidatos}</p> : null}
          <ol className="flex flex-col gap-2">
            {candidatos?.map((candidato) => (
              <li key={candidato.candidaturaId} className="flex flex-col gap-2 rounded-cartao border border-borda bg-superficie p-4">
                <p className="flex flex-wrap items-baseline justify-between gap-2">
                  <strong className="text-lg">{candidato.nome}</strong>
                  {candidato.daEquipe ? <span className="text-sm font-semibold">{t.daEquipe}</span> : null}
                </p>
                <p>{candidato.chamariamDeNovo ? preencher(t.chamariamDeNovo, candidato.chamariamDeNovo) : t.semHistorico}</p>
                <p className="text-tinta-suave">
                  {preencher(t.turnosRealizados, { n: candidato.turnosRealizados })}
                  {candidato.comparecimento
                    ? ` · ${preencher(t.comparecimento, { porcento: candidato.comparecimento.porcento, n: candidato.comparecimento.considerados })}`
                    : null}
                </p>
                <p className="text-sm text-tinta-suave">{preencher(t.chegouEm, { quando: candidato.chegouEm })}</p>
                <Form method="post">
                  <input type="hidden" name="casa" value={casaId} />
                  <input type="hidden" name="candidatura_id" value={candidato.candidaturaId} />
                  <button type="submit" disabled={enviando} className="min-h-12 w-full rounded-controle bg-acao px-4 text-lg font-bold text-tinta disabled:opacity-60">
                    {enviando ? t.escolhendo : t.escolher}
                  </button>
                </Form>
              </li>
            ))}
          </ol>
        </section>
      ) : null}
    </main>
  );
}
