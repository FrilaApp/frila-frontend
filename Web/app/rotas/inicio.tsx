import { env } from "cloudflare:workers";
import { Form, Link } from "react-router";

import { contextoDaSessao } from "../contexto";
import { lerConfiguracaoDesteAmbiente } from "../servidor/abertura";
import { lerMinhaConta } from "../servidor/conta";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { textos } from "../textos/pt-BR";
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
    // O sair não se confirmou no Auth: os cookies ficaram, e a pessoa tenta de novo.
    sairFalhou: new URL(request.url).searchParams.get("sair") === "falhou",
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

      {loaderData.webLigada && loaderData.sairFalhou ? (
        <div className="flex flex-col gap-3">
          <p role="alert" className="font-semibold">
            {textos.conta.sairFalhou}
          </p>
          {entrou ? null : (
            <Form method="post" action="/sair">
              <button type="submit" className={classeDoBotao}>
                {textos.conta.sair}
              </button>
            </Form>
          )}
        </div>
      ) : null}
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
