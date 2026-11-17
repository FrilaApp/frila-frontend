import { type ComponentType, createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createRoutesStub } from "react-router";
import { describe, expect, it, vi } from "vitest";

import Cadastro from "../app/rotas/profissional/cadastro";
import Perfil from "../app/rotas/profissional/perfil";
import Preferencias from "../app/rotas/profissional/preferencias";
import { VAZIO } from "../app/servidor/profissional/cadastro";
import { textos } from "../app/textos/pt-BR";

vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => null }));

const t = textos.profissionalCadastro;
const GARCOM = "365ace5a-c202-4969-ad70-7f3f4dfa57a3";
const COZINHEIRO = "365ace5a-c202-4969-ad70-7f3f4dfa57a4";
const dados = {
  situacao: "pode_criar",
  funcoes: [
    { categoria: "Cozinha", funcoes: [{ id: COZINHEIRO, nome: "Cozinheiro" }] },
    { categoria: "Salão", funcoes: [{ id: GARCOM, nome: "Garçom" }] },
  ],
  regioes: [{ id: 1, nome: "Plano Piloto", comCentro: true }, { id: 3, nome: "Taguatinga", comCentro: true }, { id: 37, nome: "Ponte Alta", comCentro: false }],
};

/** O HTML da tela, como o servidor a manda (sem JavaScript): é assim que os passos têm de funcionar. */
function html(Tela: unknown, props: Record<string, unknown>) {
  const Rota = () => createElement(Tela as ComponentType<Record<string, unknown>>, props);
  const Stub = createRoutesStub([{ path: "/perfil/cadastro", Component: Rota }]);
  return renderToStaticMarkup(createElement(Stub, { initialEntries: ["/perfil/cadastro"] })).replace(/&quot;/g, '"');
}
const noPasso = (passo: string, valores: Record<string, unknown>, erro: string | null = null, loaderData: unknown = dados) =>
  html(Cadastro, { loaderData, actionData: { passo, erro, valores: { ...VAZIO, ...valores } } });
const escondido = (nome: string, valor: string) => `<input type="hidden" name="${nome}" value="${valor}"/>`;

describe("cadastro do profissional: a tela de cada passo", () => {
  it("abre no passo das funções, com uma caixa por função do catálogo e sem botão de voltar", () => {
    const tela = html(Cadastro, { loaderData: dados });
    expect(tela).toContain(escondido("passo", "funcoes"));
    expect(tela).toContain(t.passoDe.replace("{atual}", "1").replace("{total}", "5"));
    expect(tela).toContain(`<input type="checkbox" class="size-5 shrink-0" name="funcoes" value="${GARCOM}"/>`);
    expect(tela).toContain(`name="funcoes" value="${COZINHEIRO}"`);
    expect(tela).toContain(t.continuar);
    expect(tela).not.toContain('value="voltar"');
  });

  it("no ponto base, as funções viajam escondidas e só entra na lista a região que tem centro", () => {
    const tela = noPasso("ponto", { funcoes: [GARCOM] });
    expect(tela).toContain(escondido("passo", "ponto"));
    expect(tela).toContain(escondido("funcoes", GARCOM));
    expect(tela).toContain('<option value="3">Taguatinga</option>');
    expect(tela).not.toContain("Ponte Alta");
    expect(tela).toContain('value="voltar"');
    expect(tela).not.toContain('type="checkbox"');
  });

  it("nos horários, cada horário marcado aparece com o seu botão de remover, e o formulário de um novo vem com os sete dias", () => {
    const tela = noPasso("horarios", { funcoes: [GARCOM], ponto_regiao: "3", janelas: ["1-08:00-12:00", "5-18:00-02:00"] });
    expect(tela).toContain(escondido("funcoes", GARCOM));
    expect(tela).toContain(escondido("ponto_regiao", "3"));
    expect(tela).toContain(escondido("janelas", "1-08:00-12:00"));
    expect(tela).toContain("Segunda-feira: 08:00 até 12:00<");
    expect(tela).toContain("Sexta-feira: 18:00 até 02:00 (dia seguinte)");
    expect(tela).toMatch(/<button[^>]*value="5-18:00-02:00"[^>]*name="remover"/);
    expect(tela.match(/type="checkbox"[^>]*name="dias"/g)).toHaveLength(7);
    expect(tela).toContain('<input type="time" class="min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg" name="inicio" value="18:00"/>');
    expect(tela).toContain('name="fim" value="00:00"');
    expect(tela).not.toContain(t.horarios.nenhum);
    // A tecla Enter aciona o primeiro botão de envio do formulário: aqui é o de adicionar, nunca um "Remover".
    expect(tela.slice(tela.indexOf("<form")).match(/<button[^>]*type="submit"[^>]*>/)?.[0]).toContain('value="adicionar_horario"');
  });

  it("sem horário marcado, a tela avisa que o aviso de vaga não chega; o que estava no formulário volta depois de um erro", () => {
    const tela = noPasso("horarios", { funcoes: [GARCOM], novo_horario: { dias: ["5"], inicio: "18:00", fim: "18:00" } }, t.erros.horarioIgual);
    expect(tela).toContain(t.horarios.nenhum);
    expect(tela).toContain('name="dias" checked="" value="5"');
    expect(tela).toContain('name="fim" value="18:00"');
    expect(tela).toContain(t.erros.horarioIgual);
  });

  it("nas regiões, funções, ponto e horários viajam escondidos e todas as regiões do catálogo aparecem", () => {
    const tela = noPasso("regioes", { funcoes: [GARCOM, COZINHEIRO], ponto_regiao: "3", janelas: ["5-18:00-02:00"], regioes: ["37"] });
    expect(tela).toContain(escondido("funcoes", GARCOM));
    expect(tela).toContain(escondido("funcoes", COZINHEIRO));
    expect(tela).toContain(escondido("ponto_regiao", "3"));
    expect(tela).toContain(escondido("janelas", "5-18:00-02:00"));
    expect(tela).toContain('name="regioes" checked="" value="37"');
    expect(tela).toContain('name="regioes" value="1"');
    expect(tela).toContain('name="atende_todo_df" value="sim"');
    expect(tela).toContain(`>${t.continuar}</button>`);
  });

  it("nos serviços, só as funções marcadas ganham bloco, o que já foi preenchido volta e o botão cria o perfil", () => {
    const tela = noPasso("servicos", { funcoes: [GARCOM], ponto_regiao: "3", janelas: ["5-18:00-02:00"], regioes: ["1"], servicos: { [GARCOM]: { unidade: "diaria", valor: "180", horas: "10", pessoas: "", pacote: "" } } });
    expect(tela).toContain(escondido("janelas", "5-18:00-02:00"));
    expect(tela).toContain(escondido("regioes", "1"));
    expect(tela).toContain(`<select name="unidade:${GARCOM}"`);
    expect(tela).not.toContain(`unidade:${COZINHEIRO}`);
    expect(tela).toContain(`<option value="nao">${t.servicos.naoOferecer}</option>`);
    expect(tela).toContain('<option value="diaria" selected="">Diária</option>');
    expect(tela).toMatch(new RegExp(`name="valor:${GARCOM}"[^>]*value="180"`));
    expect(tela).toMatch(new RegExp(`name="horas:${GARCOM}"[^>]*value="10"`));
    expect(tela).toMatch(new RegExp(`name="pessoas:${GARCOM}"[^>]*value="1"`));
    expect(tela).toContain(`>${t.criar}</button>`);
    // Sem nada preenchido, o bloco abre em "não oferecer", com a diária de 8 horas sugerida (como no app).
    const vazia = noPasso("servicos", { funcoes: [GARCOM, COZINHEIRO] });
    expect(vazia).toContain(`<option value="nao" selected="">${t.servicos.naoOferecer}</option>`);
    expect(vazia).toMatch(new RegExp(`name="horas:${COZINHEIRO}"[^>]*value="8"`));
  });

  it("ao voltar, o que foi marcado nos passos seguintes continua no formulário", () => {
    const tela = noPasso("funcoes", { funcoes: [GARCOM], ponto_regiao: "3", janelas: ["5-18:00-02:00"], atende_todo_df: true, regioes: ["1"], servicos: { [GARCOM]: { unidade: "pacote", valor: "300", horas: "", pessoas: "", pacote: "Jantar" } } });
    expect(tela).toContain(`name="funcoes" checked="" value="${GARCOM}"`);
    expect(tela).toContain(escondido("ponto_regiao", "3"));
    expect(tela).toContain(escondido("janelas", "5-18:00-02:00"));
    expect(tela).toContain(escondido("atende_todo_df", "sim"));
    expect(tela).toContain(escondido("regioes", "1"));
    expect(tela).toContain(escondido(`unidade:${GARCOM}`, "pacote"));
    expect(tela).toContain(escondido(`valor:${GARCOM}`, "300"));
    expect(tela).toContain(escondido(`pacote:${GARCOM}`, "Jantar"));
  });

  it("o aviso do passo aparece como alerta", () => {
    expect(noPasso("ponto", { funcoes: [GARCOM] }, t.erros.semPontoBase)).toContain(`<p role="alert" class="font-semibold">${t.erros.semPontoBase}</p>`);
  });

  it("quem já tem perfil vê o aviso e o caminho do perfil; depois de um envio, vê o passo (falta salvar as regiões)", () => {
    const jaTem = { ...dados, situacao: "ja_tem_perfil" };
    const aviso = html(Cadastro, { loaderData: jaTem });
    expect(aviso).toContain(t.avisos.ja_tem_perfil);
    expect(aviso).toContain('href="/perfil"');
    expect(aviso).not.toContain("<form");
    const depois = noPasso("servicos", { funcoes: [GARCOM], ponto_regiao: "3" }, t.erros.regioesNaoSalvas, jaTem);
    expect(depois).toContain("<form");
    expect(depois).toContain("O seu perfil foi criado, mas as regiões não foram salvas.");
    expect(html(Cadastro, { loaderData: { ...dados, situacao: "perfil_incompativel" } })).toContain(t.avisos.perfil_incompativel);
  });
});

describe("perfil sem cadastro: a tela leva ao cadastro", () => {
  it("mostra o botão de criar o perfil e, se houver, o link da App Store", () => {
    const tela = html(Perfil, { loaderData: { estado: "sem_perfil", perfil: null, linkDaAppStore: "https://apps.apple.com/br/app/frila/id0000000000" } });
    expect(tela).toContain(textos.profissional.perfil.semPerfil);
    expect(tela).not.toContain("Termine o cadastro no app");
    expect(tela).toContain(`href="/perfil/cadastro"`);
    expect(tela).toContain(t.abrir);
    expect(tela).toContain('href="https://apps.apple.com/br/app/frila/id0000000000"');
  });

  it("as outras recusas do perfil não oferecem o cadastro", () => {
    expect(html(Perfil, { loaderData: { estado: "perfil_incompativel", perfil: null, linkDaAppStore: null } })).not.toContain("/perfil/cadastro");
  });

  it("as preferências de quem não tem perfil mostram o mesmo texto e o mesmo botão", () => {
    const tela = html(Preferencias, { loaderData: { estado: "sem_perfil", preferencias: null } });
    expect(tela).toContain(textos.profissional.perfil.semPerfil);
    expect(tela).toContain(`href="/perfil/cadastro"`);
    expect(tela).toContain(t.abrir);
    expect(html(Preferencias, { loaderData: { estado: "conta_suspensa", preferencias: null } })).not.toContain("/perfil/cadastro");
  });
});
