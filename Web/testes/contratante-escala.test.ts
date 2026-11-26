import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createRoutesStub } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import PublicarEscala, { action, loader } from "../app/rotas/contratante/publicar-escala";
import { ITEM_VAZIO } from "../app/servidor/contratante/escala";
import { textos } from "../app/textos/pt-BR";
import { argumentos, CASA, CHAVE, GARCOM, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const te = textos.contratanteEscala.erros;
const tv = textos.contratante.publicar.erros;
const BARTENDER = "0b7c9a1e-2f3d-4e5a-8b6c-7d8e9f0a1b2c";
const cadastro = {
  id: CASA,
  nome: "Bar Sintético",
  tipo: "food_service",
  endereco: "Rua Sintética, 1",
  regiao_administrativa: "Plano Piloto",
  ponto: { latitude: -15.7942, longitude: -47.8822 },
  papel: "administrador",
};

/** Campos de um item no formulário, com o prefixo `vagas.<i>.`. */
const item = (i: number, campos: Record<string, string>) => Object.fromEntries(Object.entries(campos).map(([campo, valor]) => [`vagas.${i}.${campo}`, valor]));
const garcom = { funcao_id: GARCOM, dia: "2026-12-12", inicio: "18:00", fim: "02:00", valor: "150", posicoes: "4", modo: "urgencia", responsavel_local: "Gerente Sintético", inclui_refeicao: "sim" };
const bartender = { funcao_id: BARTENDER, dia: "2026-12-12", inicio: "17:00", fim: "23:30", valor: "200,50", posicoes: "2", modo: "selecao", responsavel_local: "Gerente Sintético", traje: "Preto" };
const formulario = { casa: CASA, chave: CHAVE, itens: "2", nome: "Formatura Sintética", data: "2026-12-12", intencao: "publicar", ...item(0, garcom), ...item(1, bartender) };

const publicada = ok({ evento_id: "e1", vagas: [{ vaga_id: "v1", posicoes: [] }, { vaga_id: "v2", posicoes: [] }] });
function servidor(get: Record<string, unknown>, post: unknown = publicada) {
  api.GET.mockImplementation(async (caminho: string) => get[caminho] ?? recusa(500));
  api.POST.mockResolvedValue(post);
}
const casaOk = { "/rpc/meu_estabelecimento": ok(cadastro) };

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("escala em lote: loader", () => {
  it("traz a casa, as funções e uma chave nova para a escala", async () => {
    servidor({
      "/rpc/meus_estabelecimentos": ok([{ id: CASA, nome: "Bar Sintético", papel: "administrador" }]),
      ...casaOk,
      "/funcao": ok([{ id: GARCOM, nome: "garçom", categoria: "Salão" }]),
    });
    const dados = await loader(argumentos(`/painel/escala?casa=${CASA}`));
    expect(dados.casa).toEqual({ id: CASA, nome: "Bar Sintético", endereco: "Rua Sintética, 1", regiao: "Plano Piloto" });
    expect(dados.grupos).toHaveLength(1);
    expect(dados.chave).toMatch(/^[0-9a-f-]{36}$/);
    expect(JSON.stringify(dados)).not.toContain("latitude");
  });

  it("sem casa volta ao painel; 401 manda entrar", async () => {
    servidor({ "/rpc/meus_estabelecimentos": ok([]) });
    expect(await redirecionamento(loader(argumentos("/painel/escala")))).toBe("/painel");
    servidor({ "/rpc/meus_estabelecimentos": recusa(401, "PGRST301") });
    expect(await redirecionamento(loader(argumentos("/painel/escala")))).toBe("/entrar");
  });
});

describe("escala em lote: action", () => {
  it("publica o evento no endereço da casa, as vagas na ordem da tela e uma chave só", async () => {
    servidor(casaOk);
    const retorno = await action(argumentos("/painel/escala", formulario));
    expect(retorno).toEqual({ publicada: 2, casaId: CASA });
    expect(api.POST).toHaveBeenCalledTimes(1);
    const [caminho, { body }] = api.POST.mock.calls[0] ?? [];
    expect(caminho).toBe("/rpc/publicar_escala");
    expect(body).toEqual({
      estabelecimento_id: CASA,
      evento: { nome: "Formatura Sintética", data: "2026-12-12", local: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto", ponto: cadastro.ponto },
      vagas: [
        {
          funcao_id: GARCOM, inicio_em: "2026-12-12T21:00:00.000Z", fim_em: "2026-12-13T05:00:00.000Z", valor_centavos: 15000, posicoes: 4,
          modo: "urgencia", responsavel_local: "Gerente Sintético", inclui_refeicao: true, inclui_transporte: false, exige_material_proprio: false,
          traje: null, observacoes: null, alerta_antecedencia_min: 180,
        },
        {
          funcao_id: BARTENDER, inicio_em: "2026-12-12T20:00:00.000Z", fim_em: "2026-12-13T02:30:00.000Z", valor_centavos: 20050, posicoes: 2,
          modo: "selecao", responsavel_local: "Gerente Sintético", inclui_refeicao: false, inclui_transporte: false, exige_material_proprio: false,
          traje: "Preto", observacoes: null, alerta_antecedencia_min: 180,
        },
      ],
      chave: CHAVE,
    });
  });

  it("adicionar e remover vaga não publicam, guardam o que foi digitado e a mesma chave", async () => {
    servidor(casaOk);
    const mais = await action(argumentos("/painel/escala", { ...formulario, intencao: "adicionar" }));
    if (mais.publicada !== undefined) throw new Error("não devia publicar");
    expect(mais.valores.itens).toHaveLength(3);
    expect(mais.valores.itens[2]?.dia).toBe("2026-12-12");
    expect(mais.valores.itens[0]?.valor).toBe("150");
    expect(mais.chave).toBe(CHAVE);

    const menos = await action(argumentos("/painel/escala", { ...formulario, intencao: "remover:0" }));
    if (menos.publicada !== undefined) throw new Error("não devia publicar");
    expect(menos.valores.itens.map((v) => v.funcao_id)).toEqual([BARTENDER]);
    expect(menos.versao).not.toBe(mais.versao);

    const ultima = await action(argumentos("/painel/escala", { ...formulario, itens: "1", intencao: "remover:0" }));
    if (ultima.publicada !== undefined) throw new Error("não devia publicar");
    expect(ultima.valores.itens).toHaveLength(1);

    const cheia = await action(argumentos("/painel/escala", { ...formulario, itens: "10", intencao: "adicionar" }));
    if (cheia.publicada !== undefined) throw new Error("não devia publicar");
    expect(cheia.valores.itens).toHaveLength(10);
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("campo faltando não chega ao servidor e marca o campo da vaga certa; mais de 100 pessoas numa vaga também", async () => {
    servidor(casaOk);
    const retorno = await action(argumentos("/painel/escala", { ...formulario, nome: "", ...item(1, { ...bartender, valor: "abc", posicoes: "101" }) }));
    if (retorno.publicada !== undefined) throw new Error("não devia publicar");
    expect(api.POST).not.toHaveBeenCalled();
    expect(retorno.erros.geral).toBe(te.temErro);
    expect(retorno.erros.evento).toEqual({ nome: te.nome });
    expect(retorno.erros.itens).toEqual([{}, { valor: tv.valor, posicoes: te.posicoes }]);
    expect(retorno.valores.itens[1]?.valor).toBe("abc");
  });

  it("formulário sem casa ou sem chave não publica", async () => {
    servidor(casaOk);
    const semChave = await action(argumentos("/painel/escala", { ...formulario, chave: "" }));
    expect(semChave.publicada === undefined && semChave.erros.geral).toBe(tv.formularioVelho);
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("traduz cada recusa do servidor para o campo e a vaga certos, com a mesma chave", async () => {
    const com = async (resposta: unknown) => {
      servidor(casaOk, resposta);
      const retorno = await action(argumentos("/painel/escala", formulario));
      if (retorno.publicada !== undefined) throw new Error("não devia publicar");
      expect(retorno.chave).toBe(CHAVE);
      return retorno.erros;
    };
    expect((await com(recusa(422, "campo_invalido", "vagas[1].valor_centavos"))).itens[1]).toEqual({ valor: tv.valor });
    expect((await com(recusa(422, "campo_invalido", "vagas[0].observacoes"))).itens[0]).toEqual({ observacoes: tv.observacoes });
    expect((await com(recusa(422, "campo_invalido", "vagas[1].posicoes"))).itens[1]).toEqual({ posicoes: te.posicoes });
    expect((await com(recusa(422, "horario_invalido", "vagas[0]"))).itens[0]).toEqual({ dia: tv.horarioInvalido });
    expect((await com(recusa(422, "selecao_sem_antecedencia", "vagas[1]"))).itens[1]).toEqual({ modo: tv.selecaoSemAntecedencia });
    expect((await com(recusa(422, "campo_invalido", "evento.nome"))).evento).toEqual({ nome: te.nome });
    expect((await com(recusa(422, "campo_invalido", "evento.local"))).geral).toBe(tv.cadastroDaCasa);
    expect((await com(recusa(422, "campo_invalido", "vagas"))).geral).toBe(te.quantidade);
    expect((await com(recusa(422, "campo_invalido", "posicoes"))).geral).toBe(te.somaDePosicoes);
    expect((await com(recusa(422, "campo_invalido", "vagas[0].campo_que_a_web_nao_tem"))).geral).toBe(tv.indisponivel);
    expect((await com(recusa(422, "perfil_incompativel"))).geral).toBe(tv.perfilIncompativel);
    expect((await com(recusa(403, "sem_permissao", "conta_suspensa"))).geral).toBe(tv.contaSuspensa);
    expect((await com(recusa(403, "sem_permissao"))).geral).toBe(tv.semPermissao);
    expect((await com(recusa(500, "XX000"))).geral).toBe(tv.indisponivel);
    servidor(casaOk, recusa(401, "PGRST301"));
    expect(await redirecionamento(action(argumentos("/painel/escala", formulario)))).toBe("/entrar");
  });

  it("quem não é membro da casa não publica", async () => {
    servidor({ "/rpc/meu_estabelecimento": recusa(403, "sem_permissao") });
    const retorno = await action(argumentos("/painel/escala", formulario));
    expect(retorno.publicada === undefined && retorno.erros.geral).toBe(tv.semPermissao);
    expect(api.POST).not.toHaveBeenCalled();
  });
});

describe("escala em lote: aviso não bloqueante da faixa (B-124)", () => {
  const renderizar = (valoresDosItens: string[]) => {
    const loaderData = {
      casa: { id: CASA, nome: "Bar Sintético", endereco: "Rua Sintética, 1", regiao: "Plano Piloto" },
      grupos: [],
      funcoesIndisponiveis: false,
      chave: CHAVE,
    };
    const actionData = {
      erros: { evento: {}, itens: valoresDosItens.map(() => ({})) },
      valores: { nome: "Formatura Sintética", data: "2026-12-12", itens: valoresDosItens.map((valor) => ({ ...ITEM_VAZIO, valor })) },
      chave: CHAVE,
      versao: "v1",
    };
    const Stub = createRoutesStub([{ path: "/painel/escala", Component: () => createElement(PublicarEscala, { loaderData, actionData } as never) }]);
    return renderToStaticMarkup(createElement(Stub, { initialEntries: ["/painel/escala"] }));
  };

  it("publica escala com valor positivo fora da faixa e mantém recusa para 0 e negativo", async () => {
    for (const valor of ["0,01", "2000,01", "1000000"]) {
      api.POST.mockReset();
      servidor(casaOk);
      const retorno = await action(argumentos("/painel/escala", { ...formulario, ...item(0, { ...garcom, valor }) }));
      expect(retorno).toEqual({ publicada: 2, casaId: CASA });
      expect(api.POST).toHaveBeenCalledTimes(1);
    }
    for (const valor of ["0", "-10"]) {
      api.POST.mockReset();
      servidor(casaOk);
      const retorno = await action(argumentos("/painel/escala", { ...formulario, ...item(0, { ...garcom, valor }) }));
      expect(retorno.publicada === undefined && retorno.erros.itens[0]).toEqual({ valor: tv.valor });
      expect(api.POST).not.toHaveBeenCalled();
    }
  });

  it("mostra o aviso exato nos itens fora da faixa sem desabilitar o botão de publicar escala", () => {
    const htmlComAviso = renderizar(["49,99", "2000,01"]);
    expect(htmlComAviso).toContain("Valor muito baixo.");
    expect(htmlComAviso).toContain("Valor muito alto, confira.");
    const botoes = [...htmlComAviso.matchAll(new RegExp(`<button[^>]*value="publicar"[^>]*>${textos.contratanteEscala.publicar}</button>`, "g"))].map((m) => m[0]);
    const botaoVisivel = botoes.find((b) => !b.includes("sr-only"));
    expect(botaoVisivel).toBeTruthy();
    expect(botaoVisivel).not.toMatch(/\sdisabled(?=[\s=>])/);

    const htmlSemAviso = renderizar(["50", "2000", "", "0"]);
    expect(htmlSemAviso).not.toContain("Valor muito baixo.");
    expect(htmlSemAviso).not.toContain("Valor muito alto, confira.");
  });
});
