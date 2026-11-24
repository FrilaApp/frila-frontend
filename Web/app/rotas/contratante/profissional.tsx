import type { ReactNode } from "react";
import { data, Link } from "react-router";

import { caminhoDeVolta, lerPerfilDoProfissional } from "../../servidor/contratante/perfil-profissional";
import { apiDoUsuario, fotoDoProfissional } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/profissional";

const t = textos.contratantePerfil;
const preencher = (modelo: string, valores: Record<string, number | string>) =>
  Object.entries(valores).reduce((texto, [chave, valor]) => texto.replace(`{${chave}}`, String(valor)), modelo);

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/**
 * O perfil do profissional, para a casa decidir (pelo candidato, pelo turno ou pela equipe). O nome inteiro e os
 * campos de apresentação só vêm para a casa com vínculo; o servidor decide e a tela mostra o que vier.
 */
export async function loader({ context, params, request }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const volta = caminhoDeVolta(new URL(request.url).searchParams.get("volta"));
  // A foto vem por outro caminho (perfil por POST + miniatura no servidor), em paralelo com o perfil.
  const [leitura, foto] = await Promise.all([
    lerPerfilDoProfissional(apiDoUsuario(sessao), params.profissionalId),
    fotoDoProfissional(sessao, params.profissionalId),
  ]);
  if (leitura.estado === "nao_encontrado") return data({ estado: "nao_encontrado" as const, volta, perfil: null }, { status: 404 });
  if (leitura.estado !== "ok") return { estado: "indisponivel" as const, volta, perfil: null };
  const p = leitura.perfil;
  const r = p.reputacao;
  return {
    estado: "ok" as const,
    volta,
    perfil: {
      nome: p.nome,
      foto,
      funcoes: p.funcoes ?? [],
      chamariamDeNovo: r.total > 0 ? preencher(t.chamariamDeNovo, { positivas: r.positivas, total: r.total }) : t.semHistorico,
      turnosRealizados: preencher(t.turnosRealizados, { n: r.turnos_realizados }),
      comparecimento:
        r.taxa_comparecimento != null && r.turnos_considerados > 0
          ? preencher(t.comparecimento, { porcento: Math.round(r.taxa_comparecimento * 100), n: r.turnos_considerados })
          : null,
      apresentacao: p.apresentacao ?? null,
      experiencia: p.experiencia_faixa ? t.faixas[p.experiencia_faixa] : null,
      ondeTrabalhei: p.onde_trabalhei ?? null,
      cursos: p.cursos ?? [],
      idiomas: (p.idiomas ?? []).map((idioma) => t.nomesDosIdiomas[idioma]),
      regioes: (p.regioes ?? []).map((regiao) => regiao.nome),
      todoDF: p.atende_todo_df === true,
    },
  };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

function Campo({ rotulo, children }: { rotulo: string; children: ReactNode }) {
  return (
    <>
      <dt className="font-semibold">{rotulo}</dt>
      <dd className="mb-2">{children}</dd>
    </>
  );
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function PerfilDoProfissional({ loaderData }: Route.ComponentProps) {
  const { estado, volta, perfil } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      {estado === "nao_encontrado" ? (
        <>
          <h1 className="font-titulo text-3xl font-bold">{t.indisponivelTitulo}</h1>
          <p>{t.indisponivelCorpo}</p>
        </>
      ) : estado !== "ok" || !perfil ? (
        <p role="alert">{t.falhou}</p>
      ) : (
        <>
          {perfil.foto ? (
            <img src={perfil.foto} alt={t.fotoDe.replace("{nome}", perfil.nome)} width={96} height={96} className="size-24 rounded-full object-cover" />
          ) : null}
          <h1 className="font-titulo text-3xl font-bold">{perfil.nome}</h1>
          <dl className="rounded-cartao border border-borda bg-superficie p-4">
            {perfil.funcoes.length > 0 ? <Campo rotulo={t.funcoes}>{perfil.funcoes.join(", ")}</Campo> : null}
            <Campo rotulo={t.reputacao}>
              {perfil.chamariamDeNovo}
              <br />
              <span className="text-tinta-suave">
                {perfil.turnosRealizados}
                {perfil.comparecimento ? ` · ${perfil.comparecimento}` : ""}
              </span>
            </Campo>
            {perfil.apresentacao ? <Campo rotulo={t.sobreMim}>{perfil.apresentacao}</Campo> : null}
            {perfil.experiencia ? <Campo rotulo={t.experiencia}>{perfil.experiencia}</Campo> : null}
            {perfil.ondeTrabalhei ? <Campo rotulo={t.ondeTrabalhei}>{perfil.ondeTrabalhei}</Campo> : null}
            {perfil.cursos.length > 0 ? <Campo rotulo={t.cursos}>{perfil.cursos.join(", ")}</Campo> : null}
            {perfil.idiomas.length > 0 ? <Campo rotulo={t.idiomas}>{perfil.idiomas.join(", ")}</Campo> : null}
            {perfil.todoDF || perfil.regioes.length > 0 ? (
              <Campo rotulo={t.ondeAtende}>{perfil.todoDF ? t.todoDF : perfil.regioes.join(", ")}</Campo>
            ) : null}
          </dl>
          <p className="text-sm text-tinta-suave">{t.semContato}</p>
        </>
      )}
      <Link to={volta} className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
