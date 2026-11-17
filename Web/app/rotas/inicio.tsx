import { env } from "cloudflare:workers";
import { Form, Link } from "react-router";

import { contextoDaSessao } from "../contexto";
import { lerConfiguracaoDesteAmbiente } from "../servidor/abertura";
import { lerMinhaConta } from "../servidor/conta";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { textos } from "../textos/pt-BR";
import { VERSAO_DOS_TERMOS } from "../versao";
import type { Route } from "./+types/inicio";

export async function loader({ context, request }: Route.LoaderArgs) {
  if (env.WEB_LIGADA !== "1") {
    return { webLigada: false as const };
  }
  const sessao = context.get(contextoDaSessao);
  const [leitura, conta] = await Promise.all([
    lerConfiguracaoDesteAmbiente(),
    sessao ? lerMinhaConta(apiDoUsuario(sessao.acesso)) : null,
  ]);
  return {
    webLigada: true as const,
    ambiente: env.AMBIENTE,
    configuracao: leitura.estado,
    versaoMinima: leitura.estado === "ok" ? leitura.configuracao.versao_minima : null,
    // Só o que a tela mostra: o token fica no servidor.
    entrou: sessao ? { email: sessao.email, conta } : null,
    // As versões são datas (AAAA-MM-DD): comparar o texto compara a data.
    termosPendentes: conta?.estado === "ok" && (conta.termosVersao ?? "") < VERSAO_DOS_TERMOS,
    aceiteFalhou: new URL(request.url).searchParams.get("termos") === "falhou",
  };
}

export function meta({ loaderData }: Route.MetaArgs) {
  if (!loaderData?.webLigada) {
    return [{ title: textos.emBreve.tituloDaAba }, { name: "description", content: textos.emBreve.descricao }];
  }
  return [{ title: textos.inicio.tituloDaAba }, { name: "robots", content: "noindex" }];
}

const classeDoBotao = "min-h-12 rounded-controle border border-borda bg-superficie px-4 text-lg font-bold";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Inicio({ loaderData }: Route.ComponentProps) {
  const bloco = loaderData.webLigada ? textos.inicio : textos.emBreve;
  const entrou = loaderData.webLigada ? loaderData.entrou : null;

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-center gap-4 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{bloco.titulo}</h1>
      <p className="text-tinta-suave">{bloco.corpo}</p>

      {entrou ? (
        <section className="flex flex-col gap-3 rounded-cartao border border-borda bg-superficie p-4">
          <p>
            {textos.conta.entrou} <strong className="break-all">{entrou.email ?? textos.conta.semEmail}</strong>.
          </p>
          {entrou.conta?.estado === "ok" ? (
            <p>
              {textos.conta.estado.ok}: <strong>{entrou.conta.nome}</strong> ({textos.conta.perfil[entrou.conta.perfil]})
            </p>
          ) : entrou.conta ? (
            <p>{textos.conta.estado[entrou.conta.estado]}</p>
          ) : null}
          {entrou.conta?.estado === "sem_conta" ? (
            <p>
              <Link to="/cadastro" className="inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-lg font-bold text-tinta">
                {textos.conta.completarCadastro}
              </Link>
            </p>
          ) : null}
          {loaderData.webLigada && loaderData.termosPendentes ? (
            <Form method="post" action="/aceitar-termos" className="flex flex-col gap-3 border-t border-borda pt-3">
              <p>{textos.conta.termosMudaram}</p>
              <p className="text-sm text-tinta-suave">
                <a href="https://frilabr.com/termos" target="_blank" rel="noreferrer" className="underline underline-offset-4">
                  {textos.entrar.linkDosTermos}
                </a>{" "}
                ·{" "}
                <a href="https://frilabr.com/privacidade" target="_blank" rel="noreferrer" className="underline underline-offset-4">
                  {textos.entrar.linkDaPrivacidade}
                </a>
              </p>
              {loaderData.aceiteFalhou ? <p role="alert">{textos.conta.aceiteFalhou}</p> : null}
              <button type="submit" className={classeDoBotao}>
                {textos.conta.aceitarTermos}
              </button>
            </Form>
          ) : null}
          <Form method="post" action="/sair">
            <button type="submit" className={classeDoBotao}>
              {textos.conta.sair}
            </button>
          </Form>
        </section>
      ) : loaderData.webLigada ? (
        <p>
          <Link to="/entrar" className="inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-lg font-bold text-tinta">
            {textos.conta.entrar}
          </Link>
        </p>
      ) : null}

      {loaderData.webLigada ? (
        <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm text-tinta-suave">
          <dt>{textos.inicio.ambiente}</dt>
          <dd>{loaderData.ambiente}</dd>
          <dt>{textos.inicio.configuracao}</dt>
          <dd>{textos.inicio.estadoDaConfiguracao[loaderData.configuracao]}</dd>
          {loaderData.versaoMinima ? (
            <>
              <dt>{textos.inicio.versaoMinima}</dt>
              <dd>{loaderData.versaoMinima}</dd>
            </>
          ) : null}
        </dl>
      ) : null}
    </main>
  );
}
