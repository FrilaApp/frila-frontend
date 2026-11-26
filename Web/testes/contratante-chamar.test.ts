import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createRoutesStub } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import BuscaDaCasa, { action } from "../app/rotas/contratante/busca";
import { textos } from "../app/textos/pt-BR";
import { argumentos, CASA, GARCOM, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const tc = textos.contratanteBusca.chamada;
const MARIA = "5d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d";
const JOAO = "6e2d3c4b-5f6a-4b7c-9d8e-0f1a2b3c4d5e";
const CHAVE_MARIA = "7b84c3e2-8e3b-4f9e-a0e2-1a2b3c4d5e6f";
const CHAVE_JOAO = "8c95d4f3-9f4c-4a0f-b1f3-2b3c4d5e6f7a";
const VAGA = "9da6e5a4-0a5d-4b1a-82a4-3c4d5e6f7a8b";
const cadastro = {
  id: CASA, nome: "Bar Sintético", tipo: "food_service", endereco: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto",
  ponto: { latitude: -15.7942, longitude: -47.8822 }, papel: "administrador",
};
const cartao = (id: string, chave: string, extra: Record<string, unknown> = {}) => ({
  id, nome: "Pessoa S.", servico: "Garçom", preco: "R$ 30,00 por hora", regioes: "Atende todo o DF", distancia: "Até 5 km da casa",
  reputacao: "Sem avaliações ainda", disponivel: false, chave, ...extra,
});
const termos = { dia: "2026-12-12", inicio: "18:00", fim: "23:00", valor: "180", responsavel_local: "Gerente Sintético", total: "sim", inclui_refeicao: "sim", recado: "" };
const formulario = (intencao: string, extra: Record<string, string> = {}) => ({
  casa: CASA, funcao_id: GARCOM, regiao_id: "", intencao, proximo_cursor: "",
  cartoes: JSON.stringify([cartao(MARIA, CHAVE_MARIA), cartao(JOAO, CHAVE_JOAO)]),
  ...termos, ...extra,
});
const chamada = ok({ id: "c1", vaga_id: VAGA, profissional_id: MARIA, estabelecimento_id: CASA, estado: "aberta", expira_em: "x", criada_em: "x" });

function servidor(post: unknown = chamada, get: Record<string, unknown> = {}) {
  api.GET.mockImplementation(async (caminho: string) => ({ "/rpc/meu_estabelecimento": ok(cadastro), ...get })[caminho] ?? recusa(500));
  api.POST.mockResolvedValue(post);
}
async function lista(promessa: Promise<unknown>) {
  const retorno = (await promessa) as { estado: string; cartoes: Array<{ id: string; situacao?: { tipo: string; motivo?: string; termos?: string; vagaId?: string } }>; errosDosTermos: Record<string, true> };
  if (retorno.estado !== "ok") throw new Error("esperava a lista");
  return retorno;
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("chamar da busca", () => {
  it("chama com o trabalho completo no endereço da casa, a chave do cartão e a função da busca", async () => {
    servidor();
    const retorno = await lista(action(argumentos("/casa/busca", formulario(`chamar:${MARIA}`))));
    const [caminho, { body }] = api.POST.mock.calls[0] ?? [];
    expect(caminho).toBe("/rpc/chamar_profissional");
    expect(body).toEqual({
      chave: CHAVE_MARIA, profissional_id: MARIA, estabelecimento_id: CASA, funcao_id: GARCOM,
      local: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto", ponto: cadastro.ponto,
      inicio_em: "2026-12-12T21:00:00.000Z", fim_em: "2026-12-13T02:00:00.000Z", valor_centavos: 18000, responsavel_local: "Gerente Sintético",
      inclui_refeicao: true, inclui_transporte: false, exige_material_proprio: false,
    });
    expect(retorno.cartoes.find((c) => c.id === MARIA)?.situacao).toEqual({ tipo: "enviada" });
    expect(retorno.cartoes.find((c) => c.id === JOAO)?.situacao).toBeUndefined();
  });

  it("termos faltando não chegam ao servidor; o Enter (conferir) não chama ninguém", async () => {
    servidor();
    const retorno = await lista(action(argumentos("/casa/busca", formulario(`chamar:${MARIA}`, { valor: "", total: "", responsavel_local: "", recado: "x".repeat(301) }))));
    expect(retorno.errosDosTermos).toEqual({ valor: true, total: true, responsavel_local: true, recado: true });
    await lista(action(argumentos("/casa/busca", formulario("conferir"))));
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("trabalho já aberto: mostra os termos da vaga aberta e só repete pelo vaga_id quando a casa confirma", async () => {
    servidor(recusa(409, "trabalho_ja_aberto", VAGA), {
      "/rpc/minhas_chamadas": ok({ itens: [{ id: "c9", vaga_id: VAGA, funcao: { nome: "Garçom" }, inicio_em: "2026-12-12T21:00:00Z", fim_em: "2026-12-13T02:00:00Z", valor_centavos: 20000 }], proximo_cursor: null }),
      "/rpc/detalhe_chamada": ok({ inclui_refeicao: true, inclui_transporte: true, exige_material_proprio: false }),
    });
    const aviso = await lista(action(argumentos("/casa/busca", formulario(`chamar:${JOAO}`))));
    const situacao = aviso.cartoes.find((c) => c.id === JOAO)?.situacao;
    expect(situacao).toMatchObject({ tipo: "vaga_aberta", vagaId: VAGA });
    expect(situacao?.termos).toContain("refeição e transporte inclusos");
    expect(api.POST).toHaveBeenCalledTimes(1);

    servidor();
    const confirmado = await lista(action(argumentos("/casa/busca", formulario(`usar_vaga:${JOAO}:${VAGA}`, { valor: "" }))));
    expect(api.POST.mock.lastCall?.[1].body).toEqual({ chave: CHAVE_JOAO, profissional_id: JOAO, estabelecimento_id: CASA, vaga_id: VAGA });
    expect(confirmado.cartoes.find((c) => c.id === JOAO)?.situacao).toEqual({ tipo: "enviada" });
  });

  it("sem achar os termos da vaga aberta, nada se repete", async () => {
    servidor(recusa(409, "trabalho_ja_aberto", VAGA), { "/rpc/minhas_chamadas": ok({ itens: [], proximo_cursor: null }) });
    const retorno = await lista(action(argumentos("/casa/busca", formulario(`chamar:${JOAO}`))));
    expect(retorno.cartoes.find((c) => c.id === JOAO)?.situacao).toEqual({ tipo: "vaga_aberta_sem_termos" });
    expect(api.POST).toHaveBeenCalledTimes(1);
  });

  it("recorrência (J7): pede o aviso e reenvia com a confirmação e a mesma chave", async () => {
    servidor(recusa(409, "recorrencia_nao_confirmada"));
    const aviso = await lista(action(argumentos("/casa/busca", formulario(`chamar:${MARIA}`))));
    expect(aviso.cartoes.find((c) => c.id === MARIA)?.situacao).toEqual({ tipo: "recorrencia" });
    servidor();
    await lista(action(argumentos("/casa/busca", formulario(`confirmar:${MARIA}`))));
    expect(api.POST.mock.lastCall?.[1].body).toMatchObject({ chave: CHAVE_MARIA, confirmo_recorrencia: true });
  });

  it("traduz cada recusa; rede ou 5xx é envio incerto (a mesma chave conclui)", async () => {
    const com = async (resposta: unknown) => {
      servidor(resposta);
      const retorno = await lista(action(argumentos("/casa/busca", formulario(`chamar:${MARIA}`))));
      return retorno.cartoes.find((c) => c.id === MARIA)?.situacao;
    };
    expect(await com(recusa(409, "chamada_ja_aberta"))).toEqual({ tipo: "falha", motivo: "ja_aberta" });
    expect(await com(recusa(422, "profissional_indisponivel", "antecedencia_insuficiente"))).toEqual({ tipo: "falha", motivo: "antecedencia" });
    expect(await com(recusa(422, "profissional_indisponivel", "nao_aceita_chamadas"))).toEqual({ tipo: "falha", motivo: "indisponivel_para_chamada" });
    expect(await com(recusa(422, "limite_de_chamadas", "abertas"))).toEqual({ tipo: "falha", motivo: "limite" });
    expect(await com(recusa(403, "sem_permissao", "termos_pendentes"))).toEqual({ tipo: "falha", motivo: "termos_pendentes" });
    expect(await com(recusa(404, "nao_encontrado"))).toEqual({ tipo: "falha", motivo: "nao_encontrado" });
    expect(await com(recusa(422, "campo_invalido", "recado"))).toEqual({ tipo: "falha", motivo: "recado" });
    expect(await com(recusa(503, "XX000"))).toEqual({ tipo: "falha", motivo: "incerto" });
    expect(tc.erros.incerto).toContain("Chamar de novo");
    servidor(recusa(401));
    expect(await redirecionamento(action(argumentos("/casa/busca", formulario(`chamar:${MARIA}`))))).toBe("/entrar");
  });

  it("lista adulterada (id ou chave que não é uuid) não chama ninguém", async () => {
    servidor();
    const adulterada = formulario(`chamar:${MARIA}`, { cartoes: JSON.stringify([cartao(MARIA, "nao-e-chave")]) });
    expect(await action(argumentos("/casa/busca", adulterada))).toMatchObject({ estado: "erro", falha: "cursor_invalido" });
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("quem já recebeu a chamada não é chamado de novo pela tela", async () => {
    servidor();
    const enviada = formulario(`chamar:${MARIA}`, { cartoes: JSON.stringify([cartao(MARIA, CHAVE_MARIA, { situacao: { tipo: "enviada" } })]) });
    await lista(action(argumentos("/casa/busca", enviada)));
    expect(api.POST).not.toHaveBeenCalled();
  });
});

describe("chamar da busca: aviso não bloqueante da faixa (B-124)", () => {
  const renderizar = (valor: string) => {
    const loaderData = { casa: { id: CASA, nome: "Bar Sintético" }, grupos: [], regioes: [], catalogoIndisponivel: false };
    const actionData = {
      estado: "ok" as const,
      filtros: { funcao_id: GARCOM, regiao_id: "", dia: "", inicio: "", fim: "" },
      cartoes: [cartao(MARIA, CHAVE_MARIA)],
      proximoCursor: null,
      termos: {
        dia: "2026-12-12", inicio: "18:00", fim: "23:00", valor, responsavel_local: "Gerente Sintético",
        recado: "", total: true, inclui_refeicao: false, inclui_transporte: false, exige_material_proprio: false,
      },
      errosDosTermos: {},
    };
    const Stub = createRoutesStub([{ path: "/casa/busca", Component: () => createElement(BuscaDaCasa, { loaderData, actionData } as never) }]);
    return renderToStaticMarkup(createElement(Stub, { initialEntries: ["/casa/busca"] }));
  };

  it("chama com valor positivo fora da faixa de referência e continua recusando 0 e negativo", async () => {
    for (const valor of ["0,01", "49,99", "2000,01", "1000000"]) {
      api.POST.mockReset();
      servidor();
      const retorno = await lista(action(argumentos("/casa/busca", formulario(`chamar:${MARIA}`, { valor }))));
      expect(retorno.cartoes.find((c) => c.id === MARIA)?.situacao).toEqual({ tipo: "enviada" });
      expect(api.POST).toHaveBeenCalledTimes(1);
    }
    for (const valor of ["0", "-10"]) {
      api.POST.mockReset();
      servidor();
      const retorno = await lista(action(argumentos("/casa/busca", formulario(`chamar:${MARIA}`, { valor }))));
      expect(retorno.errosDosTermos).toEqual({ valor: true });
      expect(api.POST).not.toHaveBeenCalled();
    }
  });

  it("mostra o aviso exato para valor baixo/alto sem desabilitar o botão de chamar", () => {
    const botaoDeChamar = new RegExp(`<button[^>]*value="chamar:${MARIA}"[^>]*>Chamar Pessoa S\\.</button>`);
    for (const [valor, esperado] of [["49,99", "Valor muito baixo."], ["2000,01", "Valor muito alto, confira."]] as const) {
      const html = renderizar(valor);
      expect(html).toContain(esperado);
      const botao = html.match(botaoDeChamar)?.[0];
      expect(botao).toBeTruthy();
      expect(botao).not.toMatch(/\sdisabled(?=[\s=>])/);
    }
    for (const valor of ["50", "2000", "", "0"]) {
      const html = renderizar(valor);
      expect(html).not.toContain("Valor muito baixo.");
      expect(html).not.toContain("Valor muito alto, confira.");
    }
  });
});
