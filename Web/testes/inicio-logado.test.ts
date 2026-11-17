/**
 * O `/app` com sessão continua sendo o início de cada lado (menu: o Sair, a conta, instalar, avisos e os atalhos de cada
 * perfil), sem redirecionar (achado do Lince no #924). Nenhuma tela de início mostra ambiente, configuração nem versão:
 * isso é só do `/app/saude`. Dados sintéticos.
 */
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createStaticHandler, createStaticRouter, StaticRouterProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import Inicio, { loader } from "../app/rotas/inicio";
import { textos } from "../app/textos/pt-BR";
import { VERSAO_DOS_TERMOS } from "../app/versao";
import { argumentos, ok, recusa } from "./contratante-apoio";

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

describe("início com sessão: é o menu de cada lado, sem redirecionar", () => {
  const PROIBIDOS = ["Ambiente", "Configuração do app no servidor", "Versão mínima", AMBIENTE, VERSAO_MINIMA];
  const temLink = (pagina: string, caminho: string) => pagina.includes(`href="${caminho}"`);

  it("a casa (contratante) com os termos em dia fica no início e vê o painel, a conta, instalar, avisos e o Sair", async () => {
    minhaConta(conta("contratante"));
    const dados = await loader(argumentos("/"));
    const pagina = await html(dados);
    for (const caminho of ["/painel", "/conta", "/instalar", "/avisos"]) expect(temLink(pagina, caminho), caminho).toBe(true);
    expect(pagina).toContain('action="/sair"');
    expect(pagina).toContain(textos.conta.verPainel);
    for (const proibido of PROIBIDOS) expect(pagina).not.toContain(proibido);
  });

  it("a profissional com os termos em dia fica no início e vê vagas, turnos, perfil, chamadas, a conta, instalar, avisos e o Sair", async () => {
    minhaConta(conta("profissional"));
    const dados = await loader(argumentos("/"));
    const pagina = await html(dados);
    for (const caminho of ["/vagas", "/turnos", "/perfil", "/chamadas", "/conta", "/instalar", "/avisos"]) {
      expect(temLink(pagina, caminho), caminho).toBe(true);
    }
    expect(pagina).toContain('action="/sair"');
    expect(temLink(pagina, "/painel")).toBe(false);
    for (const proibido of PROIBIDOS) expect(pagina).not.toContain(proibido);
  });

  it("a profissional não vê o link do painel da casa, e a casa não vê o das vagas", async () => {
    minhaConta(conta("contratante"));
    expect(temLink(await html(await loader(argumentos("/"))), "/vagas")).toBe(false);
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
