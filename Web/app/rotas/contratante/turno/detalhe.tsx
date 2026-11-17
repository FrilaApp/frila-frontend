import { data, Form, Link, redirect, useNavigation } from "react-router";

import { avaliarOProfissional } from "../../../servidor/contratante/turno/avaliacao";
import { confirmarPresenca, gerarCodigo, reabrirPorAtraso } from "../../../servidor/contratante/turno/presenca";
import { casaDaTela, chegadaDo, listarMinhasCasas, listarTurnosDaCasa } from "../../../servidor/contratante/turno/turnos";
import { apiDoUsuario } from "../../../servidor/deste-ambiente";
import { exigirSessao } from "../../../servidor/guarda";
import { formatarPeriodo, formatarValor } from "../../../servidor/profissional/formato";
import { textos } from "../../../textos/pt-BR";
import { FormularioDaAvaliacao } from "../../avaliacao-do-turno";
import type { Route } from "./+types/detalhe";

const t = textos.contratanteTurno;
const TOLERANCIA_MS = 15 * 60 * 1000;

export function meta() {
  return [{ title: t.turno.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** Não há leitura de um turno só: ele sai da lista da casa; o que não é da casa responde 404. */
export async function loader({ context, params, request }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const casas = await listarMinhasCasas(api);
  if (casas.estado !== "ok") return { estado: casas.estado, casaId: null, turno: null };
  const casa = casaDaTela(casas.casas, new URL(request.url).searchParams.get("casa"));
  const leitura = casa ? await listarTurnosDaCasa(api, casa.id) : ({ estado: "ok", turnos: [] } as const);
  if (leitura.estado !== "ok") return { estado: leitura.estado, casaId: casa?.id ?? null, turno: null };
  const turno = leitura.turnos.find((item) => item.id === params.turnoId);
  if (!casa || !turno) return data({ estado: "nao_encontrado" as const, casaId: casa?.id ?? null, turno: null }, { status: 404 });
  const confirmado = turno.estado === "confirmada";
  const presencaPendente = turno.estado !== "cancelada" && turno.checkin_em !== null && turno.verificacao === "pendente";
  return {
    estado: "ok" as const,
    casaId: casa.id,
    turno: {
      id: turno.id,
      posicaoId: turno.posicao_id,
      funcao: turno.vaga.funcao,
      profissional: turno.contraparte.nome,
      periodo: formatarPeriodo(turno.vaga.inicio_em, turno.vaga.fim_em),
      valor: formatarValor(turno.valor_acordado_centavos),
      estado: turno.estado ?? null,
      chegada: chegadaDo(turno),
      // O código e a confirmação manual só fazem sentido com a chegada registrada e a presença em aberto.
      podeVerCodigo: presencaPendente,
      podeConfirmar: presencaPendente,
      // A tolerância é do servidor (422 antes dela); a tela só não oferece o botão antes da hora.
      podeReabrir: confirmado && turno.checkin_em === null && Date.now() >= Date.parse(turno.vaga.inicio_em) + TOLERANCIA_MS,
      // Avaliar abre depois do fim, com presença verificada (o servidor diz em pode_avaliar). Ausente não é nulo.
      podeAvaliar: turno.pode_avaliar,
      respostaDada: turno.avaliacao ? turno.avaliacao.resposta : null,
      // Equipe de confiança (3.9): só quem cumpriu o turno com presença verificada (UC11); o servidor confere de novo.
      profissionalId: turno.contraparte.id,
      podeIncluirNaEquipe: turno.verificacao === "verificado",
    },
  };
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const formulario = await request.formData();
  const intencao = formulario.get("intencao");
  const turnoId = String(formulario.get("turno_id") ?? "");
  if (intencao === "avaliar") {
    const resposta = formulario.get("resposta");
    const resultado =
      resposta === "sim" || resposta === "nao"
        ? await avaliarOProfissional(api, turnoId, resposta === "sim")
        : ({ ok: false, motivo: "indisponivel" } as const);
    const avaliacao = resultado.ok ? ("registrada" as const) : resultado.motivo;
    if (avaliacao === "sem_sessao") throw redirect("/entrar");
    return { avaliacao };
  }
  if (intencao === "codigo") {
    const gerado = await gerarCodigo(api, turnoId);
    if (!gerado.ok && gerado.motivo === "sem_sessao") throw redirect("/entrar");
    // O código vai só no corpo desta resposta: nada de URL, cookie ou log.
    return gerado.ok
      ? { codigo: gerado.codigo, minutos: Math.max(1, Math.ceil(gerado.segundosRestantes / 60)) }
      : { resultado: gerado.motivo };
  }
  const feito =
    intencao === "confirmar"
      ? await confirmarPresenca(api, turnoId)
      : intencao === "reabrir"
        ? await reabrirPorAtraso(api, String(formulario.get("posicao_id") ?? ""))
        : ({ ok: false, motivo: "indisponivel" } as const);
  if (!feito.ok && feito.motivo === "sem_sessao") throw redirect("/entrar");
  if (!feito.ok) return { resultado: feito.motivo };
  if ("reaberta" in feito) return { resultado: feito.reaberta ? ("reaberta" as const) : ("falta_sem_reabertura" as const) };
  return { resultado: "confirmada" as const };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoBotaoSecundario = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-6 text-lg font-bold disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function TurnoDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const { estado, casaId, turno } = loaderData;
  const enviando = useNavigation().state !== "idle";
  const codigo = actionData && "codigo" in actionData && actionData.codigo ? { codigo: actionData.codigo, minutos: actionData.minutos ?? 1 } : null;
  const resultado = actionData && "resultado" in actionData ? actionData.resultado : null;
  const avaliacao = actionData && "avaliacao" in actionData ? actionData.avaliacao : null;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{turno ? turno.funcao : t.turno.titulo}</h1>
      {estado === "nao_encontrado" ? <p>{t.turno.naoEncontrado}</p> : estado !== "ok" ? <p role="alert">{t.avisos[estado]}</p> : null}
      {resultado ? (
        <p role="status" className="font-semibold">
          {t.resultado[resultado]}
        </p>
      ) : null}
      {avaliacao ? (
        <p role="status" className="font-semibold">
          {t.avaliacao.resultado[avaliacao]}
        </p>
      ) : null}
      {turno ? (
        <>
          <dl className="rounded-cartao border border-borda bg-superficie p-4">
            <dt className="font-semibold">{t.turno.profissional}</dt>
            <dd className="mb-2">
              <Link
                to={`/casa/profissionais/${turno.profissionalId}?volta=${encodeURIComponent(`/casa/turnos/${turno.id}?casa=${casaId ?? ""}`)}`}
                className="font-semibold underline underline-offset-4"
              >
                {turno.profissional}
              </Link>
            </dd>
            <dt className="font-semibold">{t.turno.quando}</dt>
            <dd className="mb-2">{turno.periodo}</dd>
            <dt className="font-semibold">{t.turno.valor}</dt>
            <dd className="mb-2">{turno.valor}</dd>
            {turno.estado ? (
              <>
                <dt className="font-semibold">{t.turno.situacao}</dt>
                <dd className="mb-2">{t.estado[turno.estado]}</dd>
              </>
            ) : null}
            <dt className="font-semibold">{t.turno.chegada}</dt>
            <dd>{t.chegada[turno.chegada]}</dd>
          </dl>
          {turno.podeVerCodigo ? (
            <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
              <h2 className="font-semibold">{t.codigo.titulo}</h2>
              <p>{t.codigo.explicacao}</p>
              {codigo ? (
                <>
                  <p
                    className="font-titulo text-5xl font-bold tracking-[0.3em]"
                    aria-label={t.codigo.porExtenso.replace("{digitos}", codigo.codigo.split("").join(" "))}
                  >
                    {codigo.codigo}
                  </p>
                  <p>{t.codigo.validade.replace("{minutos}", String(codigo.minutos))}</p>
                </>
              ) : null}
              <input type="hidden" name="intencao" value="codigo" />
              <input type="hidden" name="turno_id" value={turno.id} />
              <button type="submit" disabled={enviando} className={codigo ? classeDoBotaoSecundario : classeDoBotao}>
                {enviando ? t.turno.enviando : codigo ? t.codigo.deNovo : t.codigo.mostrar}
              </button>
            </Form>
          ) : null}
          {turno.podeConfirmar ? (
            <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
              <p>{t.manual.explicacao}</p>
              <input type="hidden" name="intencao" value="confirmar" />
              <input type="hidden" name="turno_id" value={turno.id} />
              <button type="submit" disabled={enviando} className={classeDoBotaoSecundario}>
                {enviando ? t.turno.enviando : t.manual.confirmar}
              </button>
            </Form>
          ) : null}
          {turno.podeReabrir ? (
            <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
              <p>{t.atraso.aviso}</p>
              <h2 className="font-semibold">{t.atraso.pergunta}</h2>
              <p id="regra-da-reabertura">{t.atraso.regra.replace("{nome}", turno.profissional)}</p>
              <input type="hidden" name="intencao" value="reabrir" />
              <input type="hidden" name="posicao_id" value={turno.posicaoId} />
              <button type="submit" disabled={enviando} aria-describedby="regra-da-reabertura" className={classeDoBotaoSecundario}>
                {enviando ? t.turno.enviando : t.atraso.reabrir}
              </button>
            </Form>
          ) : null}
          {turno.respostaDada !== null ? (
            <p>
              {t.avaliacao.respondeu} <strong>{turno.respostaDada ? t.avaliacao.sim : t.avaliacao.nao}</strong>
            </p>
          ) : turno.podeAvaliar ? (
            <FormularioDaAvaliacao turnoId={turno.id} enviando={enviando} textos={{ ...t.avaliacao, enviando: t.turno.enviando }} />
          ) : null}
        </>
      ) : null}
      {turno?.podeIncluirNaEquipe && casaId ? (
        <Form method="post" action="/casa/equipe">
          <input type="hidden" name="casa" value={casaId} />
          <input type="hidden" name="profissional_id" value={turno.profissionalId} />
          <button type="submit" name="intencao" value="incluir" disabled={enviando} className="min-h-11 rounded-controle border border-borda px-4 font-semibold disabled:opacity-60">
            {textos.contratanteEquipe.incluir}
          </button>
        </Form>
      ) : null}
      {turno && casaId ? (
        // O suporte (#861) lê o turno pela lista da casa: por isso leva o ?casa=.
        <Link to={`/suporte/${turno.id}?casa=${casaId}`} className={classeDoLink}>
          {t.turno.ajuda}
        </Link>
      ) : null}
      {turno && casaId ? (
        <Link to={`/casa/denunciar?alvo=${turno.profissionalId}&turno=${turno.id}&casa=${casaId}`} className={classeDoLink}>
          {textos.contratanteModeracao.link}
        </Link>
      ) : null}
      <Link to={casaId ? `/casa/turnos?casa=${casaId}` : "/casa/turnos"} className={classeDoLink}>
        {t.turno.voltar}
      </Link>
    </main>
  );
}
