/**
 * O `/app` com sessão leva cada lado ao seu início (achado 1 do P5): a casa ao painel, a profissional às vagas. O que
 * fica na tela de início (termos a aceitar, conta a criar, servidor fora, sair que falhou) não mostra ambiente,
 * configuração nem versão a ninguém: isso é só do `/app/saude`. Dados sintéticos.
 */
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createStaticHandler, createStaticRouter, StaticRouterProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import Inicio, { loader } from "../app/rotas/inicio";
import { VERSAO_DOS_TERMOS } from "../app/versao";
import { argumentos, ok, recusa, redirecionamento } from "./contratante-apoio";

const AMBIENTE = "ambiente-sintetico";
const VERSAO_MINIMA = "9.8.7";

vi.mock("cloudflare:workers", () => ({ env: { WEB_LIGADA: "1", AMBIENTE: "ambiente-sintetico" } }));
const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
vi.mock("../app/servidor/abertura", () => ({
  lerConfiguracaoDesteAmbiente: async () => ({
    estado: "ok",
    configuracao: { plataforma: "web", versao_minima: "9.8.7", versao_recomendada: "9.8.7", url_da_loja: "https://example.com" },
  }),
  lerLinkDaAppStore: async () => null,
}));

const conta = (perfil: "contratante" | "profissional", termos = VERSAO_DOS_TERMOS) =>
  ok({ nome: "Pessoa Sintética", perfil, termos_versao: termos });

function minhaConta(resposta: unknown) {
  api.GET.mockImplementation(async (caminho: string) => (caminho === "/rpc/minha_conta" ? resposta : recusa(500)));
}

/** O HTML que o servidor manda, pelo roteador estático (o `<Form>` precisa de um roteador de dados). */
async function html(dados: unknown) {
  const handler = createStaticHandler([
    { id: "inicio", path: "/", loader: () => dados, Component: () => createElement(Inicio, { loaderData: dados } as never) },
  ]);
  const contexto = await handler.query(new Request("https://frilabr.com/"));
  if (contexto instanceof Response) throw contexto;
  const router = createStaticRouter(handler.dataRoutes, contexto);
  return renderToStaticMarkup(createElement(StaticRouterProvider, { router, context: contexto, hydrate: false }));
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("início com sessão: cada lado vai ao seu início", () => {
  it("a casa (contratante) com os termos em dia vai ao painel", async () => {
    minhaConta(conta("contratante"));
    expect(await redirecionamento(loader(argumentos("/")))).toBe("/painel");
  });

  it("a profissional com os termos em dia vai às vagas", async () => {
    minhaConta(conta("profissional"));
    expect(await redirecionamento(loader(argumentos("/")))).toBe("/vagas");
  });

  it("sem sessão, o /app segue com a página pública (sem redirecionar)", async () => {
    const dados = await loader(argumentos("/", undefined, false));
    expect(dados.webLigada && dados.entrou).toBe(null);
    expect(api.GET).not.toHaveBeenCalled();
  });
});

describe("início com sessão que fica na tela: sem ambiente nem versão", () => {
  const casos: [string, () => void, string][] = [
    ["termos pendentes (casa)", () => minhaConta(conta("contratante", "2000-01-01")), "/"],
    ["termos pendentes (profissional)", () => minhaConta(conta("profissional", "2000-01-01")), "/"],
    ["sem conta no produto", () => minhaConta(recusa(404)), "/"],
    ["servidor fora ao ler a conta", () => minhaConta(recusa(500)), "/"],
    ["o sair falhou", () => minhaConta(conta("contratante")), "/?sair=falhou"],
  ];

  it.each(casos)("%s: não redireciona e o HTML não fala de ambiente, configuração nem versão", async (_, preparar, caminho) => {
    preparar();
    const dados = await loader(argumentos(caminho));
    expect(dados.webLigada && dados.entrou).toBeTruthy();
    expect(dados).not.toHaveProperty("ambiente");
    expect(dados).not.toHaveProperty("versaoMinima");
    expect(dados).not.toHaveProperty("configuracao");
    const pagina = await html(dados);
    expect(pagina).toContain("<main");
    for (const proibido of ["Ambiente", "Configuração do app no servidor", "Versão mínima", AMBIENTE, VERSAO_MINIMA]) {
      expect(pagina).not.toContain(proibido);
    }
  });

  it("com termos pendentes, a tela ainda oferece o aceite (o painel não leva os termos)", async () => {
    minhaConta(conta("contratante", "2000-01-01"));
    const pagina = await html(await loader(argumentos("/")));
    expect(pagina).toContain('action="/aceitar-termos"');
  });
});
