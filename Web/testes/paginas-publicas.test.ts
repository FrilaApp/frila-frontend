import { createElement, type ComponentType, type ReactNode } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { MemoryRouter } from "react-router";
import { describe, expect, it, vi } from "vitest";

import ComoFuncionaCasa from "../app/rotas/publico/como-funciona-casa";
import ComoFuncionaProfissional from "../app/rotas/publico/como-funciona-profissional";
import { InicioPublico } from "../app/rotas/publico/inicio-publico";
import Perguntas from "../app/rotas/publico/perguntas";
import { condicoesPublicas } from "../app/servidor/publico";
import { textos } from "../app/textos/pt-BR";

vi.mock("cloudflare:workers", () => ({ env: {} }));

const p = textos.publico;
const configuracao = (recursos: Record<string, boolean>) =>
  ({ estado: "ok", configuracao: { plataforma: "web", versao_minima: "1.0.0", versao_recomendada: "1.0.0", url_da_loja: "x", recursos } }) as const;
const desligado = condicoesPublicas({ estado: "sem_configuracao" });
const ligado = condicoesPublicas(configuracao({ chamada_direta: true, busca_profissionais: true }));
// React escapa aspas e apóstrofos no HTML: compara com o texto escapado.
const html = (no: ReactNode) => renderToStaticMarkup(createElement(MemoryRouter, null, no)).replace(/&quot;/g, '"').replace(/&#x27;/g, "'");
const telas = (c: typeof desligado) =>
  [
    html(createElement(ComoFuncionaCasa as ComponentType<{ loaderData: typeof c }>, { loaderData: c })),
    html(createElement(ComoFuncionaProfissional as ComponentType<{ loaderData: typeof c }>, { loaderData: c })),
    html(createElement(Perguntas as ComponentType<{ loaderData: typeof c }>, { loaderData: c })),
    html(createElement(InicioPublico, { condicoes: c })),
  ].join("\n");

describe("condições de exibição do marketing", () => {
  it("chamada direta só com chamada_direta E busca_profissionais ligados na web", () => {
    expect(desligado.chamadaDireta).toBe(false);
    expect(condicoesPublicas(configuracao({ chamada_direta: true })).chamadaDireta).toBe(false);
    expect(ligado.chamadaDireta).toBe(true);
  });

  it("sem os recursos: nada de chamada direta, equipe, exclusão de conta nem Regras da Comunidade", () => {
    const tudo = telas(desligado);
    for (const escondido of [p.comoFuncionaCasa.passo6Titulo, p.comoFuncionaCasa.passo6CorpoChamada, p.comoFuncionaCasa.passo6CorpoEquipe, p.comoFuncionaProfissional.passo6Titulo, p.perguntas.chamadaDiretaPergunta, p.perguntas.dadosExclusao, p.rodape.comunidade]) {
      expect(tudo, escondido).not.toContain(escondido);
    }
    expect(tudo).toContain(p.perguntas.dadosResposta);
    expect(tudo).toContain(p.comoFuncionaCasa.passo5Titulo);
  });

  it("com a chamada direta ligada: o passo 6 e a pergunta aparecem; equipe e exclusão seguem escondidas", () => {
    const tudo = telas(ligado);
    expect(tudo).toContain(p.comoFuncionaCasa.passo6CorpoChamada);
    expect(tudo).toContain(p.comoFuncionaProfissional.passo6Corpo);
    expect(tudo).toContain(p.perguntas.chamadaDiretaPergunta);
    expect(tudo).not.toContain(p.comoFuncionaCasa.passo6CorpoEquipe);
    expect(tudo).not.toContain(p.perguntas.dadosExclusao);
  });

  it("App Store: só com link da apple vindo da configuração; nunca link inventado", () => {
    expect(telas(desligado)).not.toContain(p.inicio.iphoneAcao);
    expect(condicoesPublicas({ estado: "sem_configuracao" }, "https://outro.example/app").linkDaAppStore).toBeNull();
    const comLink = condicoesPublicas({ estado: "sem_configuracao" }, "https://apps.apple.com/br/app/frila/id1");
    expect(html(createElement(InicioPublico, { condicoes: comLink }))).toContain('href="https://apps.apple.com/br/app/frila/id1"');
  });
});
