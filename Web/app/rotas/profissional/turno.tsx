import { data, Form, Link, redirect, useNavigation } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { avisarACaminho, desistirDoTurno, listarMeusTurnos } from "../../servidor/profissional/turnos";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/turno";

const t = textos.profissional.turno;
const tt = textos.profissional.turnos;
const tv = textos.profissional.vagas;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** O turno sai da lista do servidor (não há leitura de um turno só); o que não é da pessoa responde 404. */
export async function loader({ context, params }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await listarMeusTurnos(apiDoUsuario(sessao.acesso));
  if (leitura.estado !== "ok") return { estado: leitura.estado, turno: null };
  const turno = leitura.turnos.find((item) => item.id === params.turnoId);
  if (!turno) return data({ estado: "nao_encontrado" as const, turno: null }, { status: 404 });
  const confirmado = turno.estado === "confirmada";
  return {
    estado: "ok" as const,
    turno: {
      id: turno.id,
      posicaoId: turno.posicao_id,
      funcao: turno.vaga.funcao,
      casa: turno.contraparte.nome,
      periodo: formatarPeriodo(turno.vaga.inicio_em, turno.vaga.fim_em),
      local: `${turno.vaga.local} · ${turno.vaga.regiao_administrativa}`,
      valor: formatarValor(turno.valor_acordado_centavos),
      estado: turno.estado ?? null,
      aCaminho: turno.a_caminho_em !== null,
      presenca: turno.checkin_em !== null,
      // Os botões seguem o estado do turno; a janela e a regra da falta são do servidor.
      podeAvisar: confirmado && turno.a_caminho_em === null && turno.checkin_em === null,
      podeDesistir: confirmado && turno.checkin_em === null,
    },
  };
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const formulario = await request.formData();
  if (formulario.get("intencao") === "desistir") {
    const desistencia = await desistirDoTurno(api, String(formulario.get("posicao_id") ?? ""), String(formulario.get("motivo") ?? ""));
    const resultado = desistencia.ok ? (desistencia.falta ? ("desistiu_com_falta" as const) : ("desistiu" as const)) : desistencia.motivo;
    if (resultado === "sem_sessao") throw redirect("/entrar");
    return { resultado };
  }
  const aviso = await avisarACaminho(api, String(formulario.get("turno_id") ?? ""));
  const resultado = aviso.ok ? ("a_caminho" as const) : aviso.motivo;
  if (resultado === "sem_sessao") throw redirect("/entrar");
  return { resultado };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-lg font-bold text-tinta disabled:opacity-60";
const classeDoBotaoSecundario = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-6 text-lg font-bold disabled:opacity-60";
const AVISO_DO_ESTADO = {
  perfil_incompativel: tv.perfilIncompativel,
  conta_suspensa: tv.contaSuspensa,
  indisponivel: tv.indisponivel,
} as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function DetalheDoTurno({ loaderData, actionData }: Route.ComponentProps) {
  const { estado, turno } = loaderData;
  const enviando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      {estado === "nao_encontrado" ? (
        <>
          <h1 className="font-titulo text-3xl font-bold">{t.naoEncontradoTitulo}</h1>
          <p>{t.naoEncontradoCorpo}</p>
        </>
      ) : estado !== "ok" || !turno ? (
        <p role="alert">{AVISO_DO_ESTADO[estado]}</p>
      ) : (
        <>
          <h1 className="font-titulo text-3xl font-bold">{turno.funcao}</h1>
          {actionData ? (
            <p role="status" className="font-semibold">
              {t.resultado[actionData.resultado]}
            </p>
          ) : null}
          <dl className="rounded-cartao border border-borda bg-superficie p-4">
            <dt className="font-semibold">{t.quando}</dt>
            <dd className="mb-2">{turno.periodo}</dd>
            <dt className="font-semibold">{t.casa}</dt>
            <dd className="mb-2">{turno.casa}</dd>
            <dt className="font-semibold">{t.onde}</dt>
            <dd className="mb-2">{turno.local}</dd>
            <dt className="font-semibold">{t.valor}</dt>
            <dd className="mb-2">{turno.valor}</dd>
            {turno.estado ? (
              <>
                <dt className="font-semibold">{t.situacao}</dt>
                <dd>
                  {tt.estado[turno.estado]}
                  {turno.presenca ? ` · ${tt.presencaRegistrada}` : turno.aCaminho ? ` · ${tt.aCaminhoDesde}` : ""}
                </dd>
              </>
            ) : null}
          </dl>
          {turno.podeAvisar ? (
            <Form method="post">
              <input type="hidden" name="intencao" value="a_caminho" />
              <input type="hidden" name="turno_id" value={turno.id} />
              <button type="submit" disabled={enviando} className={classeDoBotao}>
                {enviando ? t.enviando : t.aCaminho}
              </button>
            </Form>
          ) : null}
          {turno.podeDesistir ? (
            <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
              <h2 className="font-semibold">{t.desistirTitulo}</h2>
              <p id="regra-da-desistencia">{t.regraDaDesistencia}</p>
              <input type="hidden" name="intencao" value="desistir" />
              <input type="hidden" name="posicao_id" value={turno.posicaoId} />
              <label className="flex flex-col gap-2 font-semibold" htmlFor="motivo">
                {t.motivo}
                <span className="text-sm font-normal text-tinta-suave">{t.ajudaDoMotivo}</span>
                <textarea
                  id="motivo"
                  name="motivo"
                  required
                  minLength={3}
                  rows={3}
                  aria-describedby="regra-da-desistencia"
                  className="w-full rounded-controle border border-borda bg-superficie p-3 text-lg"
                />
              </label>
              <button type="submit" disabled={enviando} className={classeDoBotaoSecundario}>
                {enviando ? t.enviando : t.desistir}
              </button>
            </Form>
          ) : null}
        </>
      )}
      <Link to="/turnos" className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
