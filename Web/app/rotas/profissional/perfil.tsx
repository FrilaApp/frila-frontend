import { Form, Link, redirect, useNavigation } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { LIMITE_DA_APRESENTACAO, LIMITE_DE_ONDE_TRABALHEI, lerMeuPerfil, salvarApresentacao } from "../../servidor/profissional/perfil";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/perfil";

const t = textos.profissional.perfil;
const tv = textos.profissional.vagas;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await lerMeuPerfil(apiDoUsuario(sessao.acesso));
  if (leitura.estado !== "ok") return { estado: leitura.estado, perfil: null };
  const { perfil } = leitura;
  // Só o que a tela mostra: nada de ponto base nem de disponibilidade no navegador.
  return {
    estado: "ok" as const,
    perfil: {
      funcoes: perfil.funcoes.map((funcao) => funcao.nome),
      regioes: perfil.atende_todo_df ? null : perfil.regioes.map((regiao) => regiao.nome),
      positivas: perfil.reputacao.positivas,
      total: perfil.reputacao.total,
      apresentacao: perfil.apresentacao ?? "",
      ondeTrabalhei: perfil.onde_trabalhei ?? "",
    },
  };
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const resultado = await salvarApresentacao(apiDoUsuario(sessao.acesso), {
    apresentacao: String(formulario.get("apresentacao") ?? ""),
    onde_trabalhei: String(formulario.get("onde_trabalhei") ?? ""),
  });
  if (!resultado.ok && resultado.motivo === "sem_sessao") throw redirect("/entrar");
  return resultado.ok
    ? { resultado: "salvo" as const, campo: null }
    : { resultado: resultado.motivo === "sem_sessao" ? ("indisponivel" as const) : resultado.motivo, campo: "campo" in resultado ? resultado.campo : null };
}

const classeDoCampo = "w-full rounded-controle border border-borda bg-superficie p-3 text-lg";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-lg font-bold text-tinta disabled:opacity-60";
const AVISO_DO_ESTADO = {
  sem_perfil: t.semPerfil,
  perfil_incompativel: tv.perfilIncompativel,
  conta_suspensa: tv.contaSuspensa,
  indisponivel: tv.indisponivel,
} as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Perfil({ loaderData, actionData }: Route.ComponentProps) {
  const { estado, perfil } = loaderData;
  const salvando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {estado !== "ok" || !perfil ? (
        <p role="alert">{AVISO_DO_ESTADO[estado]}</p>
      ) : (
        <>
          <dl className="rounded-cartao border border-borda bg-superficie p-4">
            <dt className="font-semibold">{t.funcoes}</dt>
            <dd className="mb-2">{perfil.funcoes.join(", ")}</dd>
            <dt className="font-semibold">{t.regioes}</dt>
            <dd className="mb-2">{perfil.regioes ? perfil.regioes.join(", ") : t.todoDF}</dd>
            <dt className="font-semibold">{t.reputacao}</dt>
            <dd>
              {perfil.total > 0
                ? t.avaliacoes.replace("{positivas}", String(perfil.positivas)).replace("{total}", String(perfil.total))
                : t.semAvaliacoes}
            </dd>
          </dl>
          <p className="text-sm text-tinta-suave">{t.noApp}</p>
          <Form method="post" className="flex flex-col gap-4">
            {actionData ? (
              <p role={actionData.resultado === "salvo" ? "status" : "alert"} className="font-semibold">
                {t.resultado[actionData.resultado]}
              </p>
            ) : null}
            <label className="flex flex-col gap-2 font-semibold" htmlFor="apresentacao">
              {t.sobreMim}
              <span id="ajuda-sobre-mim" className="text-sm font-normal text-tinta-suave">
                {t.ajudaDoSobreMim}
              </span>
              <textarea
                id="apresentacao"
                name="apresentacao"
                rows={5}
                maxLength={LIMITE_DA_APRESENTACAO}
                defaultValue={perfil.apresentacao}
                aria-invalid={actionData?.campo === "apresentacao" ? true : undefined}
                aria-describedby="ajuda-sobre-mim"
                className={classeDoCampo}
              />
            </label>
            <label className="flex flex-col gap-2 font-semibold" htmlFor="onde_trabalhei">
              {t.ondeTrabalhei}
              <span id="ajuda-onde-trabalhei" className="text-sm font-normal text-tinta-suave">
                {t.ajudaDeOndeTrabalhei}
              </span>
              <textarea
                id="onde_trabalhei"
                name="onde_trabalhei"
                rows={4}
                maxLength={LIMITE_DE_ONDE_TRABALHEI}
                defaultValue={perfil.ondeTrabalhei}
                aria-invalid={actionData?.campo === "onde_trabalhei" ? true : undefined}
                aria-describedby="ajuda-onde-trabalhei"
                className={classeDoCampo}
              />
            </label>
            <button type="submit" disabled={salvando} className={classeDoBotao}>
              {salvando ? t.salvando : t.salvar}
            </button>
          </Form>
        </>
      )}
      <Link to="/" className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">
        {tv.voltarAoInicio}
      </Link>
    </main>
  );
}
