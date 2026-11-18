/**
 * Com o `/app` logado levando ao painel (casa) ou às vagas (profissional), o Sair e a conta continuam alcançáveis
 * (achado 6 do P5): a `/conta` tem o Sair, e o painel e as vagas têm o link para a `/conta`. Dados sintéticos.
 */
import { createElement, type ComponentType } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createStaticHandler, createStaticRouter, StaticRouterProvider } from "react-router";
import { describe, expect, it, vi } from "vitest";

import MinhaConta from "../app/rotas/conta/dados";
import PainelDaCasa from "../app/rotas/contratante/painel";
import Vagas from "../app/rotas/profissional/vagas";
import { textos } from "../app/textos/pt-BR";
import { CASA } from "./contratante-apoio";

vi.mock("cloudflare:workers", () => ({ env: { WEB_LIGADA: "1" } }));

/** O HTML que o servidor manda, pelo roteador estático (o `<Form>` e o `<Link>` precisam de um roteador de dados). */
async function html(Tela: ComponentType<never>, dados: unknown, actionData?: unknown) {
  const handler = createStaticHandler([
    { id: "tela", path: "/", loader: () => dados, Component: () => createElement(Tela, { loaderData: dados, actionData } as never) },
  ]);
  const contexto = await handler.query(new Request("https://frilabr.com/"));
  if (contexto instanceof Response) throw contexto;
  const router = createStaticRouter(handler.dataRoutes, contexto);
  return renderToStaticMarkup(createElement(StaticRouterProvider, { router, context: contexto, hydrate: false }));
}

const PAINEL = {
  estado: "ok",
  casa: { id: CASA, nome: "Bar Sintético" },
  outrasCasas: [],
  grupos: [],
  checkinsPendentes: 0,
  publicada: false,
};
const VAGAS = { estado: "ok", vagas: [], filtros: { data: null, distanciaMaxKm: null, deslocamento: 0 }, proximo: null };

/** O `<form>` que posta em /sair, com o botão "Sair" dentro. */
const FORM_DO_SAIR = new RegExp(`<form[^>]*action="/sair"[^>]*>(?:(?!</form>).)*${textos.conta.sair}(?:(?!</form>).)*</form>`);
const LINK_DA_CONTA = new RegExp(`<a[^>]*href="/conta"[^>]*>${textos.contaDados.abrir}</a>`);

describe("Sair e Minha conta alcançáveis depois do redirecionamento do /app", () => {
  it("a /conta tem o Sair (o mesmo Form que posta em /sair)", async () => {
    const pagina = await html(MinhaConta as never, { exportar: null });
    expect(pagina).toMatch(FORM_DO_SAIR);
  });

  it("o painel da casa tem o link para a /conta", async () => {
    expect(await html(PainelDaCasa as never, PAINEL)).toMatch(LINK_DA_CONTA);
  });

  it("o painel da casa sem casa cadastrada também tem o link para a /conta", async () => {
    expect(await html(PainelDaCasa as never, { estado: "sem_casa" })).toMatch(LINK_DA_CONTA);
  });

  it("as vagas da profissional têm o link para a /conta", async () => {
    expect(await html(Vagas as never, VAGAS)).toMatch(LINK_DA_CONTA);
  });

  it("as vagas com aviso de estado (sem ponto base) também têm o link para a /conta", async () => {
    expect(await html(Vagas as never, { ...VAGAS, estado: "sem_ponto_base" })).toMatch(LINK_DA_CONTA);
  });
});
