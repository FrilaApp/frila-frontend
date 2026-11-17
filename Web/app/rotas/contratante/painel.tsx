import { Link, redirect } from "react-router";

import { escolherCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { lerPainel, porSituacao, vagasParaATela } from "../../servidor/contratante/painel";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/painel";
import { preencher } from "./comum";

const t = textos.contratante.painel;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ request, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const endereco = new URL(request.url);

  const leitura = await lerMinhasCasas(api);
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  if (leitura.estado !== "ok") return { estado: leitura.estado } as const;
  const casa = escolherCasa(leitura.casas, endereco.searchParams.get("casa"));
  if (!casa) return { estado: "sem_casa" } as const;

  const painel = await lerPainel(api, casa.id, new Date());
  if (painel.estado === "sem_sessao") throw redirect("/entrar");
  if (painel.estado !== "ok") return { estado: painel.estado } as const;

  return {
    estado: "ok",
    casa: { id: casa.id, nome: casa.nome },
    outrasCasas: leitura.casas.filter((outra) => outra.id !== casa.id).map(({ id, nome }) => ({ id, nome })),
    grupos: porSituacao(vagasParaATela(painel.painel)),
    checkinsPendentes: painel.painel.checkins_pendentes.length,
    publicada: endereco.searchParams.get("publicada") === "1",
  } as const;
}

const MENSAGEM = {
  sem_casa: t.semCasa,
  perfil_profissional: t.perfilProfissional,
  conta_suspensa: t.contaSuspensa,
  sem_permissao: t.semPermissao,
  indisponivel: t.indisponivel,
} as const;

const classeDoBotao = "inline-flex min-h-12 items-center justify-center rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function PainelDaCasa({ loaderData }: Route.ComponentProps) {
  if (loaderData.estado !== "ok") {
    return (
      <main className="mx-auto flex min-h-dvh max-w-2xl flex-col justify-center gap-6 p-6">
        <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
        <p role="status">{MENSAGEM[loaderData.estado]}</p>
        <Link to="/" className="min-h-11 font-semibold underline underline-offset-4">
          {t.voltarAoInicio}
        </Link>
      </main>
    );
  }

  const { casa, outrasCasas, grupos, checkinsPendentes, publicada } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-2xl flex-col gap-6 p-6">
      <header className="flex flex-col gap-2">
        <p className="font-titulo text-xl font-bold">{casa.nome}</p>
        <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
        <p className="text-tinta-suave">{t.subtitulo}</p>
      </header>

      {publicada ? <p role="status" className="font-semibold">{t.publicada}</p> : null}
      {checkinsPendentes > 0 ? <p className="font-semibold">{preencher(t.checkinsPendentes, { n: checkinsPendentes })}</p> : null}

      <Link to={`/painel/publicar?casa=${casa.id}`} className={classeDoBotao}>
        {t.publicar}
      </Link>
      <Link to={`/casa/busca?casa=${casa.id}`} className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">
        {textos.contratanteBusca.abrir}
      </Link>
      <Link to={`/casa/equipe?casa=${casa.id}`} className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">
        {textos.contratanteEquipe.abrir}
      </Link>

      {grupos.length === 0 ? <p>{t.vazio}</p> : null}
      {grupos.map((grupo) => (
        <section key={grupo.situacao} className="flex flex-col gap-3" aria-labelledby={`situacao-${grupo.situacao}`}>
          <h2 id={`situacao-${grupo.situacao}`} className="font-titulo text-xl font-bold">
            {t.situacao[grupo.situacao]} ({grupo.vagas.length})
          </h2>
          <ul className="flex flex-col gap-3">
            {grupo.vagas.map((vaga) => (
              <li key={vaga.id} className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4">
                <p className="flex flex-wrap items-baseline justify-between gap-2">
                  <Link to={`/painel/vagas/${vaga.id}?casa=${casa.id}`} className="text-lg font-bold underline underline-offset-4 first-letter:uppercase">
                    {vaga.funcao}
                  </Link>
                  <span className="text-sm font-semibold">{t.estado[vaga.estado]}</span>
                </p>
                <p>
                  {vaga.dia} · {vaga.horario} · {vaga.valor}
                </p>
                <p className="text-tinta-suave">{preencher(t.posicoes, { ocupadas: vaga.ocupadas, total: vaga.posicoes })}</p>
                {vaga.candidatosPendentes > 0 ? <p>{preencher(t.candidatos, { n: vaga.candidatosPendentes })}</p> : null}
                {vaga.alertaVagaVazia ? <p className="font-semibold">{t.alertaVagaVazia}</p> : null}
                {vaga.oculta ? <p className="font-semibold">{t.oculta}</p> : null}
              </li>
            ))}
          </ul>
        </section>
      ))}

      {outrasCasas.length > 0 ? (
        <nav aria-label={t.trocarDeCasa} className="flex flex-col gap-2">
          <p className="font-semibold">{t.trocarDeCasa}</p>
          {outrasCasas.map((outra) => (
            <Link key={outra.id} to={`/painel?casa=${outra.id}`} className="min-h-11 underline underline-offset-4">
              {outra.nome}
            </Link>
          ))}
        </nav>
      ) : null}
    </main>
  );
}
