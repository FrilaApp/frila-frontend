import { Form, Link, redirect, useNavigation } from "react-router";

import { escolherCandidato, lerCandidatos, candidatosParaATela } from "../../servidor/contratante/candidatos";
import { escolherCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { detalheDaVaga, lerPainel, podeCancelarVaga } from "../../servidor/contratante/painel";
import { ehUuid, horarioEmUtc } from "../../servidor/contratante/publicar-vaga";
import { cancelarVaga, republicarRestantes, republicarVaga } from "../../servidor/contratante/vagas";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/vaga";
import { enviandoEste, preencher, rotuloDosRestantes } from "./comum";

const t = textos.contratante.vaga;
const tp = textos.contratante.painel;
const ta = textos.contratante.acoes;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ request, params, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const endereco = new URL(request.url);

  const leitura = await lerMinhasCasas(api);
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  const casa = leitura.estado === "ok" ? escolherCasa(leitura.casas, endereco.searchParams.get("casa")) : null;
  if (!casa) throw redirect("/painel");

  const agora = new Date();
  const painel = await lerPainel(api, casa.id, agora);
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
    cancelada: endereco.searchParams.get("cancelada") === "1",
    podeCancelar: podeCancelarVaga(vaga, agora),
    // Uma chave por formulário de republicação: o reenvio devolve a mesma vaga nova.
    chaves: { repetir: crypto.randomUUID(), restantes: crypto.randomUUID() },
  } as const;
}

type Onde = "escolher" | "cancelar" | "repetir" | "restantes";
// `campos` é o dia e o horário que a `chave` levou ao servidor: se a casa mudar um deles depois de um "indisponível",
// a chave antiga já pode ter gravado a vaga com o horário velho, e reenviá-la devolveria aquela cópia.
type Retorno = { erro: string; onde: Onde; chave?: string; campos?: string; motivo?: string };

export async function action({ request, params, context }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const formulario = await request.formData();
  const campo = (nome: string) => String(formulario.get(nome) ?? "").trim();
  const casaId = campo("casa");
  const intencao = campo("intencao") as Onde;
  const chave = campo("chave");
  const vaga = params.vagaId;
  const aqui = `/painel/vagas/${vaga}?casa=${casaId}`;
  if (!ehUuid(casaId) || !ehUuid(vaga)) return { erro: ta.erros.formularioVelho, onde: intencao };

  if (intencao === "cancelar") {
    const motivo = campo("motivo");
    if (motivo.length < 3) return { erro: ta.erros.motivo_curto, onde: "cancelar", motivo };
    const cancelamento = await cancelarVaga(api, vaga, motivo);
    if (cancelamento.ok) throw redirect(`${aqui}&cancelada=1`);
    if (cancelamento.motivo === "sem_sessao") throw redirect("/entrar");
    return { erro: ta.erros[cancelamento.motivo], onde: "cancelar", motivo };
  }

  if (intencao === "repetir" || intencao === "restantes") {
    if (!ehUuid(chave)) return { erro: ta.erros.formularioVelho, onde: intencao };
    let resultado;
    if (intencao === "repetir") {
      const campos = [campo("dia"), campo("inicio"), campo("fim")].join("|");
      const anteriores = campo("campos_da_chave");
      const horario = horarioEmUtc(campo("dia"), campo("inicio"), campo("fim"));
      if (!horario) return { erro: ta.erros.dia, onde: "repetir", chave, campos: anteriores || undefined };
      const chaveDoEnvio = anteriores && anteriores !== campos ? crypto.randomUUID() : chave;
      resultado = await republicarVaga(api, { vaga_id: vaga, ...horario, chave: chaveDoEnvio });
      if (!resultado.ok && resultado.motivo !== "sem_sessao") return { erro: ta.erros[resultado.motivo], onde: "repetir", chave: chaveDoEnvio, campos };
    } else {
      resultado = await republicarRestantes(api, vaga, chave);
    }
    if (resultado.ok) throw redirect(`/painel?casa=${casaId}&publicada=1`);
    if (resultado.motivo === "sem_sessao") throw redirect("/entrar");
    // A mesma chave volta para o formulário: o reenvio depois de uma queda não publica duas cópias.
    return { erro: ta.erros[resultado.motivo], onde: intencao, chave };
  }

  const candidatura = campo("candidatura_id");
  if (!ehUuid(candidatura)) return { erro: t.erros.formularioVelho, onde: "escolher" };
  const escolha = await escolherCandidato(api, candidatura);
  if (escolha.ok) throw redirect(`${aqui}&escolhido=1`);
  if (escolha.motivo === "sem_sessao") throw redirect("/entrar");
  return { erro: t.erros[escolha.motivo], onde: "escolher" };
}

const MENSAGEM = { sem_permissao: tp.semPermissao, indisponivel: tp.indisponivel, nao_encontrada: t.naoEncontrada } as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function VagaDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const enviando = navegacao.state !== "idle";
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
      {loaderData.cancelada ? <p role="status" className="font-semibold">{ta.cancelada}</p> : null}
      {actionData?.onde === "escolher" ? <p role="alert" className="font-semibold">{actionData.erro}</p> : null}

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
                  <Link
                    to={`/casa/profissionais/${candidato.profissionalId}?volta=${encodeURIComponent(`/painel/vagas/${vaga.id}?casa=${casaId}`)}`}
                    className="text-lg font-bold underline underline-offset-4"
                  >
                    {candidato.nome}
                  </Link>
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
                  <input type="hidden" name="intencao" value="escolher" />
                  <input type="hidden" name="casa" value={casaId} />
                  <input type="hidden" name="candidatura_id" value={candidato.candidaturaId} />
                  <button type="submit" disabled={enviando} className="min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60">
                    {enviandoEste(navegacao, "escolher", candidato.candidaturaId) ? t.escolhendo : t.escolher}
                  </button>
                </Form>
              </li>
            ))}
          </ol>
        </section>
      ) : null}
      <Acoes loaderData={loaderData} actionData={actionData} navegacao={navegacao} />
    </main>
  );
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotaoLaranja = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoBotaoDeBorda = "min-h-12 w-full rounded-controle border-2 border-tinta px-4 text-lg font-bold disabled:opacity-60";

type Dados = Extract<Route.ComponentProps["loaderData"], { estado: "ok" }>;

function Erro({ actionData, onde }: { actionData: Retorno | undefined; onde: Onde }) {
  return actionData?.onde === onde ? (
    <p role="alert" className="font-semibold">
      {actionData.erro}
    </p>
  ) : null;
}

function Acoes({ loaderData, actionData, navegacao }: { loaderData: Dados; actionData: Retorno | undefined; navegacao: ReturnType<typeof useNavigation> }) {
  const enviando = navegacao.state !== "idle";
  const { vaga, casaId, chaves, podeCancelar } = loaderData;
  const chaveDe = (onde: "repetir" | "restantes") => (actionData?.onde === onde && actionData.chave) || chaves[onde];
  return (
    <>
      {vaga.republicavelEmUrgencia > 0 ? (
        <section className="flex flex-col gap-3" aria-labelledby="titulo-restantes">
          <h2 id="titulo-restantes" className="font-titulo text-xl font-bold">
            {ta.restantesTitulo}
          </h2>
          <p className="text-tinta-suave">{ta.restantesAjuda}</p>
          <Form method="post">
            <input type="hidden" name="intencao" value="restantes" />
            <input type="hidden" name="casa" value={casaId} />
            <input type="hidden" name="chave" value={chaveDe("restantes")} />
            <button type="submit" disabled={enviando} className={classeDoBotaoLaranja}>
              {rotuloDosRestantes(vaga.republicavelEmUrgencia)}
            </button>
          </Form>
          <Erro actionData={actionData} onde="restantes" />
        </section>
      ) : null}

      <section className="flex flex-col gap-3" aria-labelledby="titulo-repetir">
        <h2 id="titulo-repetir" className="font-titulo text-xl font-bold">
          {ta.repetirTitulo}
        </h2>
        <p className="text-tinta-suave">{ta.repetirAjuda}</p>
        <Form method="post" className="flex flex-col gap-3">
          <input type="hidden" name="intencao" value="repetir" />
          <input type="hidden" name="casa" value={casaId} />
          <input type="hidden" name="chave" value={chaveDe("repetir")} />
          {actionData?.onde === "repetir" && actionData.campos ? <input type="hidden" name="campos_da_chave" value={actionData.campos} /> : null}
          <label className="flex flex-col gap-2 font-semibold">
            {textos.contratante.publicar.dia}
            <input name="dia" type="date" required className={classeDoCampo} />
          </label>
          <div className="grid grid-cols-2 gap-3">
            <label className="flex flex-col gap-2 font-semibold">
              {textos.contratante.publicar.inicio}
              <input name="inicio" type="time" required className={classeDoCampo} />
            </label>
            <label className="flex flex-col gap-2 font-semibold">
              {textos.contratante.publicar.fim}
              <input name="fim" type="time" required className={classeDoCampo} />
            </label>
          </div>
          <p className="text-sm text-tinta-suave">{textos.contratante.publicar.ajudaDoHorario}</p>
          <button type="submit" disabled={enviando} className={classeDoBotaoDeBorda}>
            {enviandoEste(navegacao, "repetir") ? ta.repetindo : ta.repetir}
          </button>
        </Form>
        <Erro actionData={actionData} onde="repetir" />
      </section>

      {podeCancelar ? (
        <section className="flex flex-col gap-3" aria-labelledby="titulo-cancelar">
          <h2 id="titulo-cancelar" className="font-titulo text-xl font-bold">
            {ta.cancelarTitulo}
          </h2>
          <p className="text-tinta-suave">{ta.cancelarAjuda}</p>
          <Form method="post" className="flex flex-col gap-3">
            <input type="hidden" name="intencao" value="cancelar" />
            <input type="hidden" name="casa" value={casaId} />
            <label className="flex flex-col gap-2 font-semibold">
              {ta.motivo}
              <input name="motivo" type="text" required minLength={3} defaultValue={actionData?.motivo ?? ""} className={classeDoCampo} />
            </label>
            <button type="submit" disabled={enviando} className={classeDoBotaoDeBorda}>
              {enviandoEste(navegacao, "cancelar") ? ta.cancelando : ta.cancelar}
            </button>
          </Form>
          <Erro actionData={actionData} onde="cancelar" />
        </section>
      ) : null}
    </>
  );
}
