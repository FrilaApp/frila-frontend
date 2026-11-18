import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action } from "../app/rotas/profissional/cadastro";
import { lerJanelas, lerServicos, type Unidade, type Valores, VAZIO } from "../app/servidor/profissional/cadastro";
import { textos } from "../app/textos/pt-BR";
import { ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const t = textos.profissionalCadastro.erros;
const GARCOM = "365ace5a-c202-4969-ad70-7f3f4dfa57a3";
const COZINHEIRO = "365ace5a-c202-4969-ad70-7f3f4dfa57a4";

function servidor({ criar = ok({ id: "p1" }), regioes = ok({ id: "p1" }), servicos = ok({ id: "p1" }) }: { criar?: unknown; regioes?: unknown; servicos?: unknown } = {}) {
  api.GET.mockImplementation(async (caminho: string) => {
    if (caminho === "/funcao") return ok([{ id: GARCOM, nome: "Garçom", categoria: "Salão" }, { id: COZINHEIRO, nome: "Cozinheiro", categoria: "Cozinha" }]);
    if (caminho === "/regiao_administrativa") return ok([{ id: 1, numero: "I", nome: "Plano Piloto" }, { id: 3, numero: "III", nome: "Taguatinga" }]);
    return recusa(500);
  });
  api.POST.mockImplementation(async (caminho: string) =>
    caminho === "/rpc/criar_perfil_profissional" ? criar : caminho === "/rpc/definir_regioes_atendidas" ? regioes : caminho === "/rpc/definir_servicos" ? servicos : recusa(500),
  );
}

function envio(pares: Array<[string, string]>) {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, { acesso: "sintetico", usuarioId: "u1", email: "pro@example.com" });
  const request = new Request("https://frilabr.com/app/perfil/cadastro", { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(pares) });
  return { request, context, params: {}, url: new URL(request.url), matches: [] } as never;
}

const corpos = () => api.POST.mock.calls.map(([caminho, opcoes]) => [caminho, (opcoes as { body: unknown }).body]);
const com = (mudancas: Partial<Valores>): Valores => ({ ...VAZIO, ...mudancas });
const NOS_HORARIOS: Array<[string, string]> = [["passo", "horarios"], ["funcoes", GARCOM], ["ponto_regiao", "3"]];
const FINAL: Array<[string, string]> = [["passo", "servicos"], ["ir", "avancar"], ["funcoes", GARCOM], ["funcoes", COZINHEIRO], ["ponto_regiao", "3"], ["janelas", "5-18:00-02:00"], ["regioes", "1"]];

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("horários: a grade semanal", () => {
  it("lê só as janelas válidas, sem repetir, na ordem do dia e do início", () => {
    expect(lerJanelas(["6-18:00-02:00", "5-18:00-02:00", "5-08:00-12:00", "5-18:00-02:00", "7-10:00-11:00", "1-25:00-26:00", "1-10:00-10:00", "lixo"])).toEqual([
      { dia_semana: 5, hora_inicio: "08:00", hora_fim: "12:00" },
      { dia_semana: 5, hora_inicio: "18:00", hora_fim: "02:00" },
      { dia_semana: 6, hora_inicio: "18:00", hora_fim: "02:00" },
    ]);
  });

  it("adicionar: um horário para cada dia marcado, e a tela fica no passo", async () => {
    servidor();
    const retorno = await action(envio([...NOS_HORARIOS, ["ir", "adicionar_horario"], ["dias", "5"], ["dias", "6"], ["inicio", "18:00"], ["fim", "02:00"]]));
    expect(retorno).toEqual({ passo: "horarios", erro: null, valores: com({ funcoes: [GARCOM], ponto_regiao: "3", janelas: ["5-18:00-02:00", "6-18:00-02:00"] }) });
    expect(api.GET).not.toHaveBeenCalled();
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("adicionar sem dia, com início igual ao fim ou com hora que não existe: avisa e guarda o que foi digitado", async () => {
    servidor();
    const tentar = (pares: Array<[string, string]>) => action(envio([...NOS_HORARIOS, ["janelas", "1-08:00-12:00"], ["ir", "adicionar_horario"], ...pares]));
    expect(await tentar([["inicio", "18:00"], ["fim", "02:00"]])).toMatchObject({ passo: "horarios", erro: t.horarioSemDia });
    const igual = await tentar([["dias", "5"], ["inicio", "18:00"], ["fim", "18:00"]]);
    expect(igual).toMatchObject({ passo: "horarios", erro: t.horarioIgual });
    expect(igual.valores.novo_horario).toEqual({ dias: ["5"], inicio: "18:00", fim: "18:00" });
    expect(igual.valores.janelas).toEqual(["1-08:00-12:00"]);
    expect(await tentar([["dias", "5"], ["inicio", "25:00"], ["fim", ""]])).toMatchObject({ erro: t.horarioInvalido });
    expect(await tentar([["dias", "9"], ["inicio", "18:00"], ["fim", "02:00"]])).toMatchObject({ erro: t.horarioSemDia });
  });

  it("remover tira só aquele horário", async () => {
    servidor();
    const retorno = await action(envio([...NOS_HORARIOS, ["janelas", "5-18:00-02:00"], ["janelas", "6-18:00-02:00"], ["remover", "5-18:00-02:00"]]));
    expect(retorno).toEqual({ passo: "horarios", erro: null, valores: com({ funcoes: [GARCOM], ponto_regiao: "3", janelas: ["6-18:00-02:00"] }) });
  });

  it("continuar leva junto o horário que estava marcado e ainda não adicionado; se ele não serve, fica no passo", async () => {
    servidor();
    const seguiu = await action(envio([...NOS_HORARIOS, ["ir", "avancar"], ["dias", "0"], ["inicio", "10:00"], ["fim", "16:00"]]));
    expect(seguiu).toEqual({ passo: "regioes", erro: null, valores: com({ funcoes: [GARCOM], ponto_regiao: "3", janelas: ["0-10:00-16:00"] }) });
    expect(await action(envio([...NOS_HORARIOS, ["ir", "avancar"], ["dias", "0"], ["inicio", "10:00"], ["fim", "10:00"]]))).toMatchObject({ passo: "horarios", erro: t.horarioIgual });
  });

  it("grade vazia é aceita (o contrato aceita; a tela avisa): continuar segue para as regiões", async () => {
    servidor();
    expect(await action(envio([...NOS_HORARIOS, ["ir", "avancar"], ["inicio", "18:00"], ["fim", "00:00"]]))).toMatchObject({ passo: "regioes", erro: null });
  });
});

describe("serviços e preço: a leitura do formulário", () => {
  const servico = (unidade: Unidade, mais: Partial<Record<"valor" | "horas" | "pessoas" | "pacote", string>> = {}) => ({ unidade, valor: "", horas: "", pessoas: "", pacote: "", ...mais });

  it("monta cada unidade só com os campos dela, em centavos", () => {
    const lido = lerServicos(
      {
        [GARCOM]: servico("hora", { valor: "25", horas: "8", pessoas: "3", pacote: "sobra" }),
        [COZINHEIRO]: servico("diaria", { valor: "180,50", horas: "8" }),
      },
      [GARCOM, COZINHEIRO],
    );
    expect(lido).toEqual({
      ok: true,
      servicos: [
        { funcao_id: GARCOM, unidade: "hora", valor_centavos: 2500 },
        { funcao_id: COZINHEIRO, unidade: "diaria", valor_centavos: 18050, horas_incluidas: 8 },
      ],
    });
    expect(lerServicos({ [GARCOM]: servico("por_pessoa", { valor: "40", pessoas: "10" }) }, [GARCOM])).toEqual({ ok: true, servicos: [{ funcao_id: GARCOM, unidade: "por_pessoa", valor_centavos: 4000, minimo_pessoas: 10 }] });
    expect(lerServicos({ [GARCOM]: servico("pacote", { valor: "300", pacote: "  Jantar para 20  " }) }, [GARCOM])).toEqual({ ok: true, servicos: [{ funcao_id: GARCOM, unidade: "pacote", valor_centavos: 30000, descricao_pacote: "Jantar para 20" }] });
    expect(lerServicos({ [GARCOM]: servico("evento", { valor: "10000" }) }, [GARCOM])).toEqual({ ok: true, servicos: [{ funcao_id: GARCOM, unidade: "evento", valor_centavos: 1000000 }] });
    // A combinar não leva valor, mesmo que venha um no formulário.
    expect(lerServicos({ [GARCOM]: servico("a_combinar", { valor: "50" }) }, [GARCOM])).toEqual({ ok: true, servicos: [{ funcao_id: GARCOM, unidade: "a_combinar" }] });
  });

  it("serviço de função que não está marcada é ignorado; nenhum serviço é resposta válida", () => {
    expect(lerServicos({ [COZINHEIRO]: servico("hora", { valor: "25" }) }, [GARCOM])).toEqual({ ok: true, servicos: [] });
    expect(lerServicos({}, [GARCOM])).toEqual({ ok: true, servicos: [] });
  });

  it("valor fora da faixa ou mal escrito, horas, pessoas e pacote fora da regra: diz a função e o campo", () => {
    for (const valor of ["", "9,99", "10000,01", "25.5", "1.000", "abc", "-20", "25,123"]) {
      expect(lerServicos({ [GARCOM]: servico("hora", { valor }) }, [GARCOM]), valor).toEqual({ ok: false, problema: "valor", funcaoId: GARCOM });
    }
    for (const horas of ["", "3", "13", "8,5"]) expect(lerServicos({ [GARCOM]: servico("diaria", { valor: "180", horas }) }, [GARCOM]), horas).toEqual({ ok: false, problema: "horas", funcaoId: GARCOM });
    for (const pessoas of ["", "0", "2001", "x"]) expect(lerServicos({ [GARCOM]: servico("por_pessoa", { valor: "40", pessoas }) }, [GARCOM]), pessoas).toEqual({ ok: false, problema: "pessoas", funcaoId: GARCOM });
    for (const pacote of ["", "   ", "a".repeat(121)]) expect(lerServicos({ [GARCOM]: servico("pacote", { valor: "300", pacote }) }, [GARCOM])).toEqual({ ok: false, problema: "pacote", funcaoId: GARCOM });
  });

  it("mais de 10 serviços não passa (limite do contrato)", () => {
    const funcoes = Array.from({ length: 11 }, (_, i) => `365ace5a-c202-4969-ad70-7f3f4dfa5${String(700 + i)}`);
    expect(lerServicos(Object.fromEntries(funcoes.map((id) => [id, servico("a_combinar")])), funcoes)).toEqual({ ok: false, problema: "muitos" });
  });
});

describe("serviços e preço: o último passo cria o perfil, grava as regiões e os serviços", () => {
  const SERVICOS: Array<[string, string]> = [[`unidade:${GARCOM}`, "hora"], [`valor:${GARCOM}`, "25"], [`unidade:${COZINHEIRO}`, "nao"], [`valor:${COZINHEIRO}`, "99"]];

  it("manda a grade no perfil e só os serviços oferecidos; vai às vagas", async () => {
    servidor();
    expect(await redirecionamento(action(envio([...FINAL, ...SERVICOS])))).toBe("/vagas");
    expect(corpos()).toEqual([
      ["/rpc/criar_perfil_profissional", { funcoes: [GARCOM, COZINHEIRO], ponto_base: { latitude: -15.833333, longitude: -48.056944 }, disponibilidades: [{ dia_semana: 5, hora_inicio: "18:00", hora_fim: "02:00" }] }],
      ["/rpc/definir_regioes_atendidas", { regioes: [1], atende_todo_df: false }],
      ["/rpc/definir_servicos", { servicos: [{ funcao_id: GARCOM, unidade: "hora", valor_centavos: 2500 }] }],
    ]);
  });

  it("sem serviço oferecido, definir_servicos nem é chamado (não apaga nada)", async () => {
    servidor();
    expect(await redirecionamento(action(envio(FINAL)))).toBe("/vagas");
    expect(corpos().map(([caminho]) => caminho)).toEqual(["/rpc/criar_perfil_profissional", "/rpc/definir_regioes_atendidas"]);
  });

  it("campo do serviço com problema: fica no passo, diz a função e nada é enviado", async () => {
    servidor();
    const retorno = await action(envio([...FINAL, [`unidade:${GARCOM}`, "diaria"], [`valor:${GARCOM}`, "180"], [`horas:${GARCOM}`, "2"]]));
    expect(retorno).toMatchObject({ passo: "servicos", erro: `Garçom: ${t.servico.horas}` });
    expect(retorno.valores.servicos).toEqual({ [GARCOM]: { unidade: "diaria", valor: "180", horas: "2", pessoas: "", pacote: "" } });
    expect((await action(envio([...FINAL, [`unidade:${COZINHEIRO}`, "hora"], [`valor:${COZINHEIRO}`, "5"]]))).erro).toBe(`Cozinheiro: ${t.servico.valor}`);
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("recusas do servidor nos serviços: o perfil já existe, e a tela diz o que rever", async () => {
    const tentar = async (servicos: unknown) => {
      servidor({ servicos });
      return action(envio([...FINAL, ...SERVICOS]));
    };
    expect(await tentar(recusa(422, "campo_invalido", "valor_centavos"))).toMatchObject({ passo: "servicos", erro: `${t.servicosNaoSalvos} ${t.servico.valor}` });
    expect(await tentar(recusa(422, "campo_invalido", "descricao_pacote"))).toMatchObject({ passo: "servicos", erro: `${t.servicosNaoSalvos} ${t.servico.pacote}` });
    expect(await tentar(recusa(422, "funcao_nao_marcada", GARCOM))).toMatchObject({ passo: "servicos", erro: `${t.servicosNaoSalvos} ${t.servico.outro}` });
    expect(await tentar(recusa(500))).toMatchObject({ passo: "servicos", erro: `${t.servicosNaoSalvos} ${t.tenteDeNovo}` });
    servidor({ servicos: recusa(401) });
    expect(await redirecionamento(action(envio([...FINAL, ...SERVICOS])))).toBe("/entrar");
    // Serviços desligados no servidor (chave do perfil rico): o perfil vale, e a pessoa segue.
    servidor({ servicos: recusa(403, "sem_permissao", "recurso_desligado") });
    expect(await redirecionamento(action(envio([...FINAL, ...SERVICOS])))).toBe("/vagas");
  });

  it("regiões não salvas: os serviços nem são tentados, e reenviar refaz tudo", async () => {
    servidor({ regioes: recusa(500) });
    expect(await action(envio([...FINAL, ...SERVICOS]))).toMatchObject({ passo: "servicos", erro: t.regioesNaoSalvas });
    expect(corpos().map(([caminho]) => caminho)).toEqual(["/rpc/criar_perfil_profissional", "/rpc/definir_regioes_atendidas"]);
  });
});
