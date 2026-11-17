import { Form, Link, redirect, useNavigation } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { lerMeuPerfil } from "../../servidor/profissional/perfil";
import { type Antecedencia, ANTECEDENCIAS, salvarPreferencias } from "../../servidor/profissional/preferencias";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/preferencias";

const t = textos.profissional.preferencias;
const tv = textos.profissional.vagas;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await lerMeuPerfil(apiDoUsuario(sessao.acesso));
  if (leitura.estado !== "ok") return { estado: leitura.estado, preferencias: null };
  const p = leitura.perfil.preferencia_chamadas;
  // Sem preferência gravada, valem os padrões do contrato.
  return {
    estado: "ok" as const,
    preferencias: {
      aceitaChamadas: p?.aceita_chamadas ?? false,
      deQuemJaTrabalhou: p?.aceita_de_quem_ja_trabalhou ?? true,
      antecedencia: p?.antecedencia_minima_h ?? 6,
      pausadoAte: p?.pausado_ate ?? null,
    },
  };
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const antecedencia = Number(formulario.get("antecedencia"));
  const aceitaAgora = formulario.get("aceita_chamadas") === "sim";
  const aceitavaAntes = formulario.get("aceita_chamadas_antes") === "sim";
  const resultado = await salvarPreferencias(apiDoUsuario(sessao.acesso), {
    aceitaDeQuemJaTrabalhou: formulario.get("de_quem_ja_trabalhou") === "sim",
    antecedenciaMinimaH: (ANTECEDENCIAS as readonly number[]).includes(antecedencia) ? (antecedencia as Antecedencia) : 6,
    pausadoAte: formulario.get("pausar") === "sim" ? String(formulario.get("pausado_ate") ?? "") : null,
    // Só manda a chave quando a pessoa mexeu nela: cada vez que liga, o servidor registra o pedido.
    aceitaChamadas: aceitaAgora === aceitavaAntes ? null : aceitaAgora,
  });
  if (!resultado.ok && resultado.motivo === "sem_sessao") throw redirect("/entrar");
  return { erro: resultado.ok ? null : resultado.motivo === "sem_sessao" ? ("indisponivel" as const) : resultado.motivo };
}

const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDaCaixa = "flex min-h-12 items-start gap-3";
const AVISO_DO_ESTADO = {
  sem_perfil: textos.profissional.perfil.semPerfil,
  perfil_incompativel: tv.perfilIncompativel,
  conta_suspensa: tv.contaSuspensa,
  indisponivel: tv.indisponivel,
} as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function PreferenciasDeChamadas({ loaderData, actionData }: Route.ComponentProps) {
  const { estado, preferencias } = loaderData;
  const salvando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {actionData ? <p role={actionData.erro ? "alert" : "status"}>{actionData.erro ? t.resultado[actionData.erro] : t.salvas}</p> : null}
      {estado !== "ok" || !preferencias ? (
        <>
          <p role="alert">{AVISO_DO_ESTADO[estado]}</p>
          {estado === "sem_perfil" ? (
            <Link to="/perfil/cadastro" className={`${classeDoBotao} inline-flex items-center justify-center`}>
              {textos.profissionalCadastro.abrir}
            </Link>
          ) : null}
        </>
      ) : (
        <Form method="post" className="flex flex-col gap-5">
          <input type="hidden" name="aceita_chamadas_antes" value={preferencias.aceitaChamadas ? "sim" : "nao"} />
          <label className={classeDaCaixa}>
            <input type="checkbox" name="aceita_chamadas" value="sim" defaultChecked={preferencias.aceitaChamadas} className="mt-1 size-5 shrink-0" aria-describedby="explicacao-da-busca" />
            <span className="flex flex-col gap-1">
              <strong>{t.aceitoChamadas}</strong>
              <span id="explicacao-da-busca" className="text-tinta-suave">
                {t.aceitoChamadasExplicacao}
              </span>
            </span>
          </label>
          <label className={classeDaCaixa}>
            <input type="checkbox" name="de_quem_ja_trabalhou" value="sim" defaultChecked={preferencias.deQuemJaTrabalhou} className="mt-1 size-5 shrink-0" aria-describedby="sub-de-quem" />
            <span className="flex flex-col gap-1">
              <strong>{t.deQuemJaTrabalhou}</strong>
              <span id="sub-de-quem" className="text-tinta-suave">
                {t.deQuemJaTrabalhouSubtitulo}
              </span>
            </span>
          </label>
          <label className="flex flex-col gap-2 font-semibold" htmlFor="antecedencia">
            {t.antecedencia}
            <select id="antecedencia" name="antecedencia" defaultValue={preferencias.antecedencia} className="min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg">
              {ANTECEDENCIAS.map((h) => (
                <option key={h} value={h}>
                  {t.horas[h]}
                </option>
              ))}
            </select>
          </label>
          <label className={classeDaCaixa}>
            <input type="checkbox" name="pausar" value="sim" defaultChecked={preferencias.pausadoAte !== null} className="mt-1 size-5 shrink-0" />
            <strong>{t.pausar}</strong>
          </label>
          <label className="flex flex-col gap-2 font-semibold" htmlFor="pausado_ate">
            {t.pausarAte}
            <input id="pausado_ate" name="pausado_ate" type="date" defaultValue={preferencias.pausadoAte ?? ""} className="min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg" />
          </label>
          <p className="text-sm text-tinta-suave">{t.avisoChamadasExistentes}</p>
          <button type="submit" disabled={salvando} className={classeDoBotao}>
            {salvando ? t.salvando : t.salvar}
          </button>
        </Form>
      )}
      <Link to="/chamadas" className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">
        {textos.profissional.chamadas.voltar}
      </Link>
    </main>
  );
}
