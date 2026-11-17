import { env } from "cloudflare:workers";
import { Form, Link, redirect } from "react-router";

import { contextoDaSessao } from "../contexto";
import { lerConfiguracaoDesteAmbiente, lerLinkDaAppStore } from "../servidor/abertura";
import { lerMinhaConta } from "../servidor/conta";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { condicoesPublicas } from "../servidor/publico";
import { textos } from "../textos/pt-BR";
import { VERSAO_DOS_TERMOS } from "../versao";
import type { Route } from "./+types/inicio";
import { InicioPublico } from "./publico/inicio-publico";

export async function loader({ context, request }: Route.LoaderArgs) {
  if (env.WEB_LIGADA !== "1") {
    return { webLigada: false as const };
  }
  const sessao = context.get(contextoDaSessao);
  const [leitura, conta, linkDaAppStore] = await Promise.all([
    lerConfiguracaoDesteAmbiente(),
    sessao ? lerMinhaConta(apiDoUsuario(sessao.acesso)) : null,
    // Só quem não entrou vê a página pública com o botão da loja.
    sessao ? null : lerLinkDaAppStore(),
  ]);
  const url = new URL(request.url);
  // As versões são datas (AAAA-MM-DD): comparar o texto compara a data.
  const termosPendentes = conta?.estado === "ok" && (conta.termosVersao ?? "") < VERSAO_DOS_TERMOS;
  const sairFalhou = url.searchParams.get("sair") === "falhou";
  // Com a conta pronta, cada lado começa no seu início: a casa no painel (que oferece cadastrar a casa, se faltar), a
  // profissional nas vagas. Fica aqui só o que o início resolve: aceitar os termos, criar a conta, servidor fora, sair que
  // falhou. Ambiente e versão não aparecem a ninguém (só no /app/saude).
  if (conta?.estado === "ok" && !termosPendentes && !sairFalhou) {
    throw redirect(conta.perfil === "contratante" ? "/painel" : "/vagas");
  }
  return {
    webLigada: true as const,
    // Só o que a tela mostra: o token fica no servidor.
    entrou: sessao ? { email: sessao.email, conta } : null,
    // Para a página de quem não entrou: o que o marketing deixa mostrar com os recursos ligados.
    condicoes: condicoesPublicas(leitura, linkDaAppStore),
    termosPendentes,
    termosVersao: VERSAO_DOS_TERMOS,
    aceiteFalhou: url.searchParams.get("termos") === "falhou",
    termosMudaramNaTela: url.searchParams.get("termos") === "mudou",
    // O sair não se confirmou no Auth: os cookies ficaram, e a pessoa tenta de novo.
    sairFalhou,
  };
}

export function meta({ loaderData }: Route.MetaArgs) {
  if (!loaderData?.webLigada) {
    return [{ title: textos.emBreve.tituloDaAba }, { name: "description", content: textos.emBreve.descricao }];
  }
  if (!loaderData.entrou) {
    return [{ title: textos.publico.inicio.tituloDaAba }, { name: "description", content: textos.publico.inicio.descricao }];
  }
  return [{ title: textos.inicio.tituloDaAba }, { name: "robots", content: "noindex" }];
}

const classeDoBotao = "min-h-12 rounded-controle border border-borda bg-superficie px-4 text-lg font-bold";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Inicio({ loaderData }: Route.ComponentProps) {
  const bloco = loaderData.webLigada ? textos.inicio : textos.emBreve;
  const entrou = loaderData.webLigada ? loaderData.entrou : null;
  // Quem não entrou vê a página pública (a não ser que o sair tenha falhado: aí a tela oferece tentar de novo).
  if (loaderData.webLigada && !entrou && !loaderData.sairFalhou) {
    return <InicioPublico condicoes={loaderData.condicoes} />;
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-center gap-4 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{bloco.titulo}</h1>
      {/* O corpo é só da página "em breve": com a web ligada, quem fica no início vê só o que falta resolver. */}
      {loaderData.webLigada ? null : <p className="text-tinta-suave">{textos.emBreve.corpo}</p>}

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
          {entrou.conta?.estado === "ok" && entrou.conta.perfil === "profissional" ? (
            <p>
              <Link to="/vagas" className="inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao">
                {textos.conta.verVagas}
              </Link>{" "}
              <Link to="/turnos" className="inline-flex min-h-12 items-center px-4 text-lg font-bold underline underline-offset-4">
                {textos.profissional.turnos.titulo}
              </Link>{" "}
              <Link to="/perfil" className="inline-flex min-h-12 items-center px-4 text-lg font-bold underline underline-offset-4">
                {textos.profissional.perfil.verPerfil}
              </Link>{" "}
              <Link to="/chamadas" className="inline-flex min-h-12 items-center px-4 text-lg font-bold underline underline-offset-4">
                {textos.profissional.chamadas.titulo}
              </Link>
            </p>
          ) : null}
          {entrou.conta?.estado === "sem_conta" ? (
            <p>
              <Link to="/cadastro" className="inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao">
                {textos.conta.completarCadastro}
              </Link>
            </p>
          ) : null}
          {loaderData.webLigada && loaderData.termosPendentes ? (
            <Form method="post" action="/aceitar-termos" className="flex flex-col gap-3 border-t border-borda pt-3">
              <input type="hidden" name="termos_versao" value={loaderData.termosVersao} />
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
              {loaderData.termosMudaramNaTela ? <p role="alert">{textos.conta.termosMudaramNaTela}</p> : null}
              <button type="submit" className={classeDoBotao}>
                {textos.conta.aceitarTermos}
              </button>
            </Form>
          ) : null}
          <Link to="/conta" className="inline-flex min-h-12 items-center text-lg font-bold underline underline-offset-4">
            {textos.contaDados.abrir}
          </Link>
          <p>
            <Link to="/instalar" className="inline-flex min-h-12 items-center font-semibold underline underline-offset-4">
              {textos.pwa.instalar.link}
            </Link>{" "}
            <Link to="/avisos" className="inline-flex min-h-12 items-center px-4 font-semibold underline underline-offset-4">
              {textos.pwa.avisos.link}
            </Link>
          </p>
          <Form method="post" action="/sair">
            <button type="submit" className={classeDoBotao}>
              {textos.conta.sair}
            </button>
          </Form>
        </section>
      ) : loaderData.webLigada ? (
        <p>
          <Link to="/entrar" className="inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao">
            {textos.conta.entrar}
          </Link>
        </p>
      ) : null}
    </main>
  );
}
