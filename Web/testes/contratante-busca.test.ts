import { beforeEach, describe, expect, it, vi } from "vitest";

import { action, loader } from "../app/rotas/contratante/busca";
import { formatarValor as r } from "../app/servidor/profissional/formato";
import { argumentos, CASA, GARCOM, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const MARIA = "5d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d";
const cartao = {
  id: MARIA,
  nome: "Maria S.",
  servico: { funcao: { id: GARCOM, nome: "Garçom", categoria: "Salão" }, unidade: "hora", valor_centavos: 3000, valor_max_centavos: null },
  regioes: [{ id: 1, numero: "I", nome: "Plano Piloto" }],
  atende_todo_df: false,
  distancia_faixa: "ate_5_km",
  reputacao: { positivas: 4, total: 5, taxa_comparecimento: 1, turnos_considerados: 5, turnos_realizados: 5 },
  disponivel_no_horario: true,
};
const filtros = { casa: CASA, funcao_id: GARCOM, regiao_id: "", dia: "", inicio: "", fim: "" };

function servidor(get: Record<string, unknown>, post: unknown = ok({ itens: [cartao], proximo_cursor: "c2" })) {
  api.GET.mockImplementation(async (caminho: string) => get[caminho] ?? recusa(500));
  api.POST.mockResolvedValue(post);
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("busca da casa: loader", () => {
  it("traz a casa, os serviços e as regiões do catálogo", async () => {
    servidor({
      "/rpc/meus_estabelecimentos": ok([{ id: CASA, nome: "Bar Sintético", papel: "operador" }]),
      "/funcao": ok([{ id: GARCOM, nome: "Garçom", categoria: "Salão" }]),
      "/regiao_administrativa": ok([{ id: 1, numero: "I", nome: "Plano Piloto" }]),
    });
    const dados = await loader(argumentos(`/casa/busca?casa=${CASA}`));
    expect(dados.casa).toEqual({ id: CASA, nome: "Bar Sintético" });
    expect(dados.regioes).toEqual([{ id: 1, nome: "Plano Piloto" }]);
    expect(dados.catalogoIndisponivel).toBe(false);
    const regioes = api.GET.mock.calls.find(([caminho]) => caminho === "/regiao_administrativa")?.[1];
    expect(regioes.params.query).toEqual({ select: "id,numero,nome", ativo: "eq.true", order: "id.asc" });
  });

  it("sem casa volta ao painel", async () => {
    servidor({ "/rpc/meus_estabelecimentos": ok([]) });
    expect(await redirecionamento(loader(argumentos("/casa/busca")))).toBe("/painel");
  });
});

describe("busca da casa: action", () => {
  it("busca pelo POST, sem região (a da casa) e sem horário, e mostra só o que ajuda a decidir", async () => {
    servidor({});
    const retorno = await action(argumentos("/casa/busca", filtros));
    expect(api.POST).toHaveBeenCalledWith("/rpc/buscar_profissionais", expect.objectContaining({ body: { estabelecimento_id: CASA, funcao_id: GARCOM } }));
    if (retorno.estado !== "ok") throw new Error("esperava a lista");
    expect(retorno.cartoes).toEqual([
      {
        id: MARIA,
        nome: "Maria S.",
        servico: "Garçom",
        preco: `${r(3000)} por hora`,
        regioes: "Atende: Plano Piloto",
        distancia: "Até 5 km da casa",
        reputacao: "4 de 5 chamariam de novo",
        disponivel: true,
        chave: expect.stringMatching(/^[0-9a-f-]{36}$/),
      },
    ]);
    expect(retorno.proximoCursor).toBe("c2");
  });

  it("com região e horário manda os dois; a página seguinte leva o cursor", async () => {
    servidor({});
    await action(argumentos("/casa/busca", { ...filtros, regiao_id: "5", dia: "2026-12-12", inicio: "18:00", fim: "02:00", cursor: "c2" }));
    const { body } = api.POST.mock.calls[0]?.[1] ?? {};
    expect(body).toEqual({
      estabelecimento_id: CASA, funcao_id: GARCOM, regiao_id: 5, inicio_em: "2026-12-12T21:00:00.000Z", fim_em: "2026-12-13T05:00:00.000Z", cursor: "c2",
    });
  });

  it("filtro faltando ou pela metade não chega ao servidor", async () => {
    servidor({});
    expect(await action(argumentos("/casa/busca", { ...filtros, funcao_id: "" }))).toMatchObject({ estado: "erro", campo: "funcao_id" });
    expect(await action(argumentos("/casa/busca", { ...filtros, dia: "2026-12-12" }))).toMatchObject({ estado: "erro", campo: "horario" });
    expect(await action(argumentos("/casa/busca", { ...filtros, regiao_id: "x" }))).toMatchObject({ estado: "erro", campo: "regiao_id" });
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("traduz cada recusa do servidor", async () => {
    const com = async (resposta: unknown) => {
      servidor({}, resposta);
      return action(argumentos("/casa/busca", filtros));
    };
    expect(await com(recusa(403, "sem_permissao", "termos_pendentes"))).toMatchObject({ falha: "termos_pendentes" });
    expect(await com(recusa(403, "sem_permissao", "recurso_desligado"))).toMatchObject({ falha: "recurso_desligado" });
    expect(await com(recusa(403, "sem_permissao", "conta_suspensa"))).toMatchObject({ falha: "conta_suspensa" });
    expect(await com(recusa(403, "sem_permissao"))).toMatchObject({ falha: "sem_permissao" });
    expect(await com(recusa(429, "limite_excedido"))).toMatchObject({ falha: "limite" });
    expect(await com(recusa(422, "cursor_invalido"))).toMatchObject({ falha: "cursor_invalido" });
    expect(await com(recusa(422, "campo_obrigatorio", "regiao_id"))).toMatchObject({ falha: "sem_regiao_da_casa" });
    expect(await com(recusa(422, "campo_invalido", "inicio_em"))).toMatchObject({ campo: "horario" });
    expect(await com(recusa(500, "XX000"))).toMatchObject({ falha: "indisponivel" });
    servidor({}, recusa(401));
    expect(await redirecionamento(action(argumentos("/casa/busca", filtros)))).toBe("/entrar");
  });

  it("valor a combinar, faixa de preço, todo o DF e sem avaliações", async () => {
    const outros = [
      { ...cartao, servico: { ...cartao.servico, unidade: "a_combinar", valor_centavos: null }, atende_todo_df: true, reputacao: { ...cartao.reputacao, positivas: 0, total: 0 }, disponivel_no_horario: undefined },
      { ...cartao, servico: { ...cartao.servico, unidade: "diaria", valor_centavos: 15000, valor_max_centavos: 20000 } },
    ];
    servidor({}, ok({ itens: outros, proximo_cursor: null }));
    const retorno = await action(argumentos("/casa/busca", filtros));
    if (retorno.estado !== "ok") throw new Error("esperava a lista");
    expect(retorno.cartoes[0]).toMatchObject({ preco: "Valor a combinar", regioes: "Atende todo o DF", reputacao: "Sem avaliações ainda", disponivel: false });
    expect(retorno.cartoes[1]?.preco).toBe(`${r(15000)} a ${r(20000)} por diária`);
    expect(retorno.proximoCursor).toBeNull();
  });
});
