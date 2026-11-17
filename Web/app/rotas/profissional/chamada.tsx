import { data, Form, Link, redirect, useNavigation } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { lerChamada, MOTIVOS_DA_RECUSA, type MotivoDaRecusa, responderChamada } from "../../servidor/profissional/chamadas";
import { formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/chamada";

const t = textos.profissional.chamadas;
const tv = textos.profissional.vaga;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

const hora = new Intl.DateTimeFormat("pt-BR", { timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });

/** A chamada como o servidor a mostra a esta pessoa: sem endereço antes do aceite. */
export async function loader({ context, params }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await lerChamada(apiDoUsuario(sessao.acesso), params.chamadaId);
  if (leitura.estado === "nao_encontrada") return data({ estado: "nao_encontrada" as const, chamada: null }, { status: 404 });
  if (leitura.estado !== "ok") return { estado: leitura.estado, chamada: null };
  const c = leitura.chamada;
  const inclusos: Array<string | null> = [c.inclui_refeicao ? tv.refeicao : null, c.inclui_transporte ? tv.transporte : null, c.exige_material_proprio ? tv.materialProprio : null];
  return {
    estado: "ok" as const,
    chamada: {
      id: c.id,
      funcao: c.funcao.nome,
      casa: c.outra_parte.nome,
      periodo: formatarPeriodo(c.inicio_em, c.fim_em),
      valor: formatarValor(c.valor_centavos),
      regiao: c.regiao_administrativa,
      distancia: c.distancia_faixa ?? null,
      local: c.local ?? null,
      recado: c.recado ?? null,
      inclusos: inclusos.filter((item): item is string => item !== null),
      estado: c.estado,
      respondaAte: hora.format(new Date(c.expira_em)),
      turnoId: c.turno_id ?? null,
    },
  };
}

export async function action({ context, params, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const resposta = formulario.get("resposta");
  const motivo = String(formulario.get("motivo_recusa") ?? "");
  const escolhido = (MOTIVOS_DA_RECUSA as readonly string[]).includes(motivo) ? (motivo as MotivoDaRecusa) : null;
  const resultado =
    resposta === "aceitar" || resposta === "recusar"
      ? await responderChamada(apiDoUsuario(sessao.acesso), params.chamadaId, resposta, escolhido)
      : ({ ok: false, motivo: "indisponivel" } as const);
  const chave = resultado.ok ? (resultado.aceita ? ("aceita" as const) : ("recusada" as const)) : resultado.motivo;
  if (chave === "sem_sessao") throw redirect("/entrar");
  // Chamada alheia ou inexistente: 404, como a leitura, para ninguém distinguir "existe e não é sua" de "não existe".
  if (chave === "nao_encontrada") return data({ resultado: chave }, { status: 404 });
  return { resultado: chave };
}

const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoBotaoSecundario = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-6 text-lg font-bold disabled:opacity-60";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const AVISO_DO_ESTADO = {
  recurso_desligado: t.desligado,
  perfil_incompativel: textos.profissional.vagas.perfilIncompativel,
  conta_suspensa: textos.profissional.vagas.contaSuspensa,
  indisponivel: textos.profissional.vagas.indisponivel,
} as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function DetalheDaChamada({ loaderData, actionData }: Route.ComponentProps) {
  const { estado, chamada } = loaderData;
  const enviando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      {estado === "nao_encontrada" ? (
        <>
          <h1 className="font-titulo text-3xl font-bold">{t.naoEncontradaTitulo}</h1>
          <p>{t.naoEncontradaCorpo}</p>
        </>
      ) : estado !== "ok" || !chamada ? (
        <p role="status">{AVISO_DO_ESTADO[estado]}</p>
      ) : (
        <>
          <h1 className="font-titulo text-3xl font-bold">
            {chamada.funcao} · {chamada.valor}
          </h1>
          {actionData ? (
            <p role="status" className="font-semibold">
              {t.resultado[actionData.resultado]}
            </p>
          ) : null}
          <dl className="rounded-cartao border border-borda bg-superficie p-4">
            <dt className="font-semibold">{tv.casa}</dt>
            <dd className="mb-2">{chamada.casa}</dd>
            <dt className="font-semibold">{tv.quando}</dt>
            <dd className="mb-2">{chamada.periodo}</dd>
            <dt className="font-semibold">{tv.onde}</dt>
            <dd className="mb-2">
              {[chamada.local, chamada.regiao, chamada.distancia ? t.distancia[chamada.distancia] : null].filter(Boolean).join(" · ")}
            </dd>
            <dt className="font-semibold">{tv.inclusos}</dt>
            <dd className="mb-2">{chamada.inclusos.length > 0 ? chamada.inclusos.join(", ") : tv.nadaIncluso}</dd>
            {chamada.recado ? (
              <>
                <dt className="font-semibold">{t.recado}</dt>
                <dd className="mb-2">{chamada.recado}</dd>
              </>
            ) : null}
            <dt className="font-semibold">{t.situacao}</dt>
            <dd>{t.estado[chamada.estado]}</dd>
          </dl>
          {chamada.estado === "aberta" ? (
            <>
              <p>{t.respondaAte.replace("{hora}", chamada.respondaAte)}</p>
              {chamada.local ? null : <p className="text-sm text-tinta-suave">{t.enderecoDepois}</p>}
              <Form method="post">
                <input type="hidden" name="resposta" value="aceitar" />
                <button type="submit" disabled={enviando} className={classeDoBotao}>
                  {enviando ? t.enviando : t.aceitar}
                </button>
              </Form>
              <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
                <input type="hidden" name="resposta" value="recusar" />
                <label className="flex flex-col gap-2 font-semibold" htmlFor="motivo_recusa">
                  {t.motivo}
                  <select id="motivo_recusa" name="motivo_recusa" defaultValue="" className="min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg">
                    <option value="">{t.semMotivo}</option>
                    {MOTIVOS_DA_RECUSA.map((motivo) => (
                      <option key={motivo} value={motivo}>
                        {t.motivos[motivo]}
                      </option>
                    ))}
                  </select>
                </label>
                <button type="submit" disabled={enviando} className={classeDoBotaoSecundario}>
                  {enviando ? t.enviando : t.recusar}
                </button>
              </Form>
            </>
          ) : null}
          {chamada.turnoId ? (
            <Link to={`/turnos/${chamada.turnoId}`} className={classeDoLink}>
              {t.verTurno}
            </Link>
          ) : null}
        </>
      )}
      <Link to="/chamadas" className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
