import { beforeEach, describe, expect, it, vi } from "vitest";

import { action, loader } from "../app/rotas/contratante/publicar-vaga";
import { horarioEmUtc, valorEmCentavos } from "../app/servidor/contratante/publicar-vaga";
import { textos } from "../app/textos/pt-BR";
import { argumentos, CASA, CHAVE, GARCOM, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const t = textos.contratante.publicar.erros;
const cadastro = {
  id: CASA,
  nome: "Bar Sintético",
  tipo: "food_service",
  endereco: "Rua Sintética, 1",
  regiao_administrativa: "Plano Piloto",
  ponto: { latitude: -15.7942, longitude: -47.8822 },
  papel: "administrador",
};
const formulario = {
  casa: CASA,
  chave: CHAVE,
  funcao_id: GARCOM,
  dia: "2026-11-21",
  inicio: "18:00",
  fim: "02:00",
  valor: "1.200,50",
  posicoes: "3",
  modo: "selecao",
  responsavel_local: "Gerente Sintético",
  inclui_refeicao: "sim",
  traje: "",
  observacoes: "",
};

function servidor(get: Record<string, unknown>, post: unknown = ok({ vaga_id: "v1", posicoes: ["p1", "p2", "p3"] })) {
  api.GET.mockImplementation(async (caminho: string) => get[caminho] ?? recusa(500));
  api.POST.mockResolvedValue(post);
}
const casaOk = { "/rpc/meu_estabelecimento": ok(cadastro) };

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("publicar vaga: loader", () => {
  it("traz a casa, as funções por categoria e uma chave nova por formulário", async () => {
    servidor({
      "/rpc/meus_estabelecimentos": ok([{ id: CASA, nome: "Bar Sintético", papel: "administrador" }]),
      ...casaOk,
      "/funcao": ok([
        { id: GARCOM, nome: "garçom", categoria: "Salão" },
        { id: "f2", nome: "bartender", categoria: "Bar" },
      ]),
    });
    const dados = await loader(argumentos(`/painel/publicar?casa=${CASA}`));
    expect(dados.casa).toEqual({ id: CASA, nome: "Bar Sintético", endereco: "Rua Sintética, 1", regiao: "Plano Piloto" });
    expect(dados.grupos.map((g) => g.categoria)).toEqual(["Bar", "Salão"]);
    expect(dados.funcoesIndisponiveis).toBe(false);
    expect(dados.chave).toMatch(/^[0-9a-f-]{36}$/);
    expect(JSON.stringify(dados)).not.toContain("latitude");
    const consulta = api.GET.mock.calls.find(([caminho]) => caminho === "/funcao")?.[1];
    expect(consulta.params.query).toEqual({ select: "id,nome,categoria", ativo: "eq.true" });
  });

  it("sem casa (ou conta de profissional) volta ao painel, que explica; 401 manda entrar", async () => {
    servidor({ "/rpc/meus_estabelecimentos": ok([]) });
    expect(await redirecionamento(loader(argumentos("/painel/publicar")))).toBe("/painel");
    servidor({ "/rpc/meus_estabelecimentos": recusa(422, "perfil_incompativel") });
    expect(await redirecionamento(loader(argumentos("/painel/publicar")))).toBe("/painel");
    servidor({ "/rpc/meus_estabelecimentos": recusa(401, "PGRST301") });
    expect(await redirecionamento(loader(argumentos("/painel/publicar")))).toBe("/entrar");
  });
});

describe("publicar vaga: action", () => {
  it("publica com o endereço e o ponto do cadastro, a chave da tela e o horário em UTC", async () => {
    servidor(casaOk);
    expect(await redirecionamento(action(argumentos("/painel/publicar", formulario)))).toBe(`/painel?casa=${CASA}&publicada=1`);
    const [caminho, { body }] = api.POST.mock.calls[0] ?? [];
    expect(caminho).toBe("/rpc/publicar_vaga");
    expect(body).toEqual({
      estabelecimento_id: CASA,
      funcao_id: GARCOM,
      inicio_em: "2026-11-21T21:00:00.000Z",
      fim_em: "2026-11-22T05:00:00.000Z",
      local: "Rua Sintética, 1",
      regiao_administrativa: "Plano Piloto",
      ponto: { latitude: -15.7942, longitude: -47.8822 },
      valor_centavos: 120050,
      posicoes: 3,
      modo: "selecao",
      responsavel_local: "Gerente Sintético",
      inclui_refeicao: true,
      inclui_transporte: false,
      exige_material_proprio: false,
      traje: null,
      observacoes: null,
      alerta_antecedencia_min: 180,
      chave: CHAVE,
    });
  });

  it("campo faltando ou estranho não chega ao servidor e volta com o que a pessoa digitou", async () => {
    servidor(casaOk);
    const retorno = await action(argumentos("/painel/publicar", { ...formulario, funcao_id: "", valor: "abc", posicoes: "0", responsavel_local: " " }));
    expect(api.POST).not.toHaveBeenCalled();
    expect(retorno.erros).toEqual({ funcao_id: t.funcao_id, valor: t.valor, posicoes: t.posicoes, responsavel_local: t.responsavel_local });
    expect(retorno.valores.valor).toBe("abc");
    expect(retorno.chave).toBe(CHAVE);
  });

  it("formulário sem casa ou sem chave não publica", async () => {
    servidor(casaOk);
    expect((await action(argumentos("/painel/publicar", { ...formulario, chave: "" }))).erros).toEqual({ geral: t.formularioVelho });
    expect((await action(argumentos("/painel/publicar", { ...formulario, casa: "outra" }))).erros).toEqual({ geral: t.formularioVelho });
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("traduz cada recusa do servidor e mantém a mesma chave para o reenvio", async () => {
    const com = async (resposta: unknown) => {
      servidor(casaOk, resposta);
      return action(argumentos("/painel/publicar", formulario));
    };
    expect((await com(recusa(422, "horario_invalido"))).erros).toEqual({ dia: t.horarioInvalido });
    expect((await com(recusa(422, "selecao_sem_antecedencia"))).erros).toEqual({ modo: t.selecaoSemAntecedencia });
    expect((await com(recusa(422, "campo_invalido", "observacoes"))).erros).toEqual({ observacoes: t.observacoes });
    expect((await com(recusa(422, "campo_invalido", "valor_centavos"))).erros).toEqual({ valor: t.valor });
    expect((await com(recusa(422, "campo_invalido", "local"))).erros).toEqual({ geral: t.cadastroDaCasa });
    expect((await com(recusa(422, "campo_invalido", "campo_que_a_web_nao_tem"))).erros).toEqual({ geral: t.indisponivel });
    expect((await com(recusa(422, "perfil_incompativel"))).erros).toEqual({ geral: t.perfilIncompativel });
    expect((await com(recusa(403, "sem_permissao", "conta_suspensa"))).erros).toEqual({ geral: t.contaSuspensa });
    expect((await com(recusa(403, "sem_permissao"))).erros).toEqual({ geral: t.semPermissao });
    const caiu = await com(recusa(500, "XX000"));
    expect(caiu.erros).toEqual({ geral: t.indisponivel });
    expect(caiu.chave).toBe(CHAVE);
    servidor(casaOk, recusa(401, "PGRST301"));
    expect(await redirecionamento(action(argumentos("/painel/publicar", formulario)))).toBe("/entrar");
  });

  it("quem não é membro da casa não publica", async () => {
    servidor({ "/rpc/meu_estabelecimento": recusa(403, "sem_permissao") });
    expect((await action(argumentos("/painel/publicar", formulario))).erros).toEqual({ geral: t.semPermissao });
    expect(api.POST).not.toHaveBeenCalled();
  });
});

describe("publicar vaga: conversões", () => {
  it("valor em reais vira centavos", () => {
    expect(valorEmCentavos("150")).toBe(15000);
    expect(valorEmCentavos("150,5")).toBe(15050);
    expect(valorEmCentavos("R$ 1.200,00")).toBe(120000);
    expect(valorEmCentavos("0")).toBeNull();
    expect(valorEmCentavos("150.50")).toBeNull();
    expect(valorEmCentavos("-10")).toBeNull();
  });

  it("horário do DF em UTC; o turno que vira a noite termina no dia seguinte", () => {
    expect(horarioEmUtc("2026-11-21", "18:00", "22:00")).toEqual({ inicio_em: "2026-11-21T21:00:00.000Z", fim_em: "2026-11-22T01:00:00.000Z" });
    expect(horarioEmUtc("2026-11-21", "22:00", "02:00")?.fim_em).toBe("2026-11-22T05:00:00.000Z");
    expect(horarioEmUtc("21/11/2026", "18:00", "22:00")).toBeNull();
  });
});
