import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action, loader } from "../app/rotas/profissional/cadastro";
import { textos } from "../app/textos/pt-BR";
import { argumentos, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const t = textos.profissionalCadastro.erros;
const GARCOM = "365ace5a-c202-4969-ad70-7f3f4dfa57a3";
const COZINHEIRO = "365ace5a-c202-4969-ad70-7f3f4dfa57a4";
const FORA_DO_CATALOGO = "365ace5a-c202-4969-ad70-7f3f4dfa57ff";
// Centro de Taguatinga (RA III) na tabela da web: é o ponto base de quem escolhe a região 3.
const CENTRO_DE_TAGUATINGA = { latitude: -15.833333, longitude: -48.056944 };

type Respostas = { conta?: unknown; perfil?: unknown; criar?: unknown; regioes?: unknown };

function servidor({ conta = ok({ nome: "Pessoa Sintética", perfil: "profissional" }), perfil = recusa(404, "nao_encontrado"), criar = ok({ id: "p1" }), regioes = ok({ id: "p1" }) }: Respostas = {}) {
  api.GET.mockImplementation(async (caminho: string) => {
    if (caminho === "/funcao") return ok([{ id: GARCOM, nome: "Garçom", categoria: "Salão" }, { id: COZINHEIRO, nome: "Cozinheiro", categoria: "Cozinha" }]);
    // A 37 existe no catálogo, mas a tabela de centros ainda não a tem: não serve de ponto base.
    if (caminho === "/regiao_administrativa") return ok([{ id: 1, numero: "I", nome: "Plano Piloto" }, { id: 3, numero: "III", nome: "Taguatinga" }, { id: 37, numero: "XXXVII", nome: "Ponte Alta" }]);
    if (caminho === "/rpc/minha_conta") return conta;
    if (caminho === "/rpc/meu_perfil_profissional") return perfil;
    return recusa(500);
  });
  api.POST.mockImplementation(async (caminho: string) => (caminho === "/rpc/criar_perfil_profissional" ? criar : caminho === "/rpc/definir_regioes_atendidas" ? regioes : recusa(500)));
}

/** Formulário com campo repetido (funções e regiões são caixas de marcar). */
function envio(pares: Array<[string, string]>) {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, { acesso: "sintetico", usuarioId: "u1", email: "pro@example.com" });
  const request = new Request("https://frilabr.com/app/perfil/cadastro", { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(pares) });
  return { request, context, params: {}, url: new URL(request.url), matches: [] } as never;
}

const corpos = () => api.POST.mock.calls.map(([caminho, opcoes]) => [caminho, (opcoes as { body: unknown }).body]);
const COMPLETO: Array<[string, string]> = [["passo", "regioes"], ["ir", "avancar"], ["funcoes", GARCOM], ["funcoes", COZINHEIRO], ["ponto_regiao", "3"], ["regioes", "1"], ["regioes", "3"]];

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("cadastro do profissional: loader", () => {
  it("traz as funções por categoria e as regiões, dizendo quais servem de ponto base, sem nenhuma coordenada", async () => {
    servidor();
    const dados = await loader(argumentos("/perfil/cadastro"));
    expect(dados).toEqual({
      situacao: "pode_criar",
      funcoes: [
        { categoria: "Cozinha", funcoes: [{ id: COZINHEIRO, nome: "Cozinheiro" }] },
        { categoria: "Salão", funcoes: [{ id: GARCOM, nome: "Garçom" }] },
      ],
      regioes: [{ id: 1, nome: "Plano Piloto", comCentro: true }, { id: 3, nome: "Taguatinga", comCentro: true }, { id: 37, nome: "Ponte Alta", comCentro: false }],
    });
    expect(JSON.stringify(dados)).not.toMatch(/-1[56]\.\d|-4[78]\.\d|latitude|longitude/);
  });

  it("quem já tem perfil e a conta de contratante veem o aviso, e não o formulário", async () => {
    servidor({ perfil: ok({ id: "p1" }) });
    expect((await loader(argumentos("/perfil/cadastro"))).situacao).toBe("ja_tem_perfil");
    servidor({ conta: ok({ nome: "Casa Sintética", perfil: "contratante" }) });
    expect((await loader(argumentos("/perfil/cadastro"))).situacao).toBe("perfil_incompativel");
  });

  it("sem sessão vai entrar; sem conta no produto vai criar a conta; catálogo fora do ar vira lista vazia", async () => {
    await expect(loader(argumentos("/perfil/cadastro", undefined, false))).rejects.toHaveProperty("status", 302);
    servidor({ perfil: recusa(401) });
    expect(await redirecionamento(loader(argumentos("/perfil/cadastro")))).toBe("/entrar");
    servidor({ conta: recusa(404, "nao_encontrado") });
    expect(await redirecionamento(loader(argumentos("/perfil/cadastro")))).toBe("/cadastro");
    api.GET.mockImplementation(async (caminho: string) => (caminho === "/rpc/meu_perfil_profissional" ? recusa(404) : recusa(500)));
    expect(await loader(argumentos("/perfil/cadastro"))).toEqual({ situacao: "pode_criar", funcoes: [], regioes: [] });
  });
});

describe("cadastro do profissional: passo das funções", () => {
  it("sem função marcada, fica no passo e avisa; nada é enviado", async () => {
    servidor();
    expect(await action(envio([["passo", "funcoes"], ["ir", "avancar"]]))).toEqual({
      passo: "funcoes",
      erro: t.semFuncao,
      valores: { funcoes: [], ponto_regiao: "", atende_todo_df: false, regioes: [] },
    });
    expect((await action(envio([["passo", "funcoes"], ["ir", "avancar"], ["funcoes", FORA_DO_CATALOGO]]))).erro).toBe(t.semFuncao);
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("com função do catálogo, vai ao ponto base levando só as funções que existem, sem repetir", async () => {
    servidor();
    const retorno = await action(envio([["passo", "funcoes"], ["ir", "avancar"], ["funcoes", GARCOM], ["funcoes", GARCOM], ["funcoes", FORA_DO_CATALOGO]]));
    expect(retorno).toEqual({ passo: "ponto", erro: null, valores: { funcoes: [GARCOM], ponto_regiao: "", atende_todo_df: false, regioes: [] } });
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("catálogo fora do ar: avisa para recarregar, sem avançar", async () => {
    api.GET.mockImplementation(async () => recusa(500));
    expect(await action(envio([["passo", "funcoes"], ["ir", "avancar"], ["funcoes", GARCOM]]))).toMatchObject({ passo: "funcoes", erro: t.catalogo });
  });
});

describe("cadastro do profissional: passo do ponto base", () => {
  const noPonto = (regiao: string): Array<[string, string]> => [["passo", "ponto"], ["ir", "avancar"], ["funcoes", GARCOM], ["ponto_regiao", regiao]];

  it("sem região, região fora do catálogo ou sem centro conhecido: fica no passo e avisa", async () => {
    servidor();
    for (const regiao of ["", "abc", "99", "37", "3.5", "-3"]) {
      expect(await action(envio(noPonto(regiao))), regiao).toMatchObject({ passo: "ponto", erro: t.semPontoBase });
    }
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("com a região escolhida, vai às regiões atendidas, ainda sem enviar nada", async () => {
    servidor();
    expect(await action(envio(noPonto("3")))).toEqual({ passo: "regioes", erro: null, valores: { funcoes: [GARCOM], ponto_regiao: "3", atende_todo_df: false, regioes: [] } });
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("voltar leva ao passo anterior com tudo o que foi marcado, sem conferir nem chamar o servidor", async () => {
    servidor();
    expect(await action(envio([["passo", "ponto"], ["ir", "voltar"], ["funcoes", GARCOM], ["ponto_regiao", "abc"]]))).toEqual({
      passo: "funcoes",
      erro: null,
      valores: { funcoes: [GARCOM], ponto_regiao: "abc", atende_todo_df: false, regioes: [] },
    });
    expect((await action(envio([...COMPLETO.filter(([campo]) => campo !== "ir"), ["ir", "voltar"]]))).passo).toBe("ponto");
    expect(api.GET).not.toHaveBeenCalled();
    expect(api.POST).not.toHaveBeenCalled();
  });
});

describe("cadastro do profissional: passo das regiões e a criação", () => {
  it("cria o perfil com as funções, o centro da região como ponto base e a grade vazia; depois grava as regiões e vai às vagas", async () => {
    servidor();
    expect(await redirecionamento(action(envio(COMPLETO)))).toBe("/vagas");
    expect(corpos()).toEqual([
      ["/rpc/criar_perfil_profissional", { funcoes: [GARCOM, COZINHEIRO], ponto_base: CENTRO_DE_TAGUATINGA, disponibilidades: [] }],
      ["/rpc/definir_regioes_atendidas", { regioes: [1, 3], atende_todo_df: false }],
    ]);
  });

  it("\"todo o DF\" manda a lista vazia; sem nada marcado, o perfil é criado do mesmo jeito (como no app)", async () => {
    servidor();
    await redirecionamento(action(envio([...COMPLETO, ["atende_todo_df", "sim"]])));
    expect(corpos()[1]).toEqual(["/rpc/definir_regioes_atendidas", { regioes: [], atende_todo_df: true }]);
    api.POST.mockClear();
    expect(await redirecionamento(action(envio(COMPLETO.filter(([campo]) => campo !== "regioes"))))).toBe("/vagas");
    expect(corpos()[1]).toEqual(["/rpc/definir_regioes_atendidas", { regioes: [], atende_todo_df: false }]);
  });

  it("região atendida fora do catálogo não chega ao servidor", async () => {
    servidor();
    expect(await action(envio([...COMPLETO, ["regioes", "99"]]))).toMatchObject({ passo: "regioes", erro: t.regioes });
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("no envio final, o que veio dos passos anteriores é conferido de novo: volta ao passo com o problema", async () => {
    servidor();
    expect(await action(envio(COMPLETO.filter(([campo]) => campo !== "funcoes")))).toMatchObject({ passo: "funcoes", erro: t.semFuncao });
    expect(await action(envio(COMPLETO.map(([campo, valor]) => [campo, campo === "ponto_regiao" ? "37" : valor])))).toMatchObject({ passo: "ponto", erro: t.semPontoBase });
    expect(api.POST).not.toHaveBeenCalled();
  });
});

describe("cadastro do profissional: recusas do contrato viram texto do Frila", () => {
  const com = async (respostas: Respostas) => {
    servidor(respostas);
    api.POST.mockClear();
    return action(envio(COMPLETO));
  };

  it("recusas ao criar o perfil", async () => {
    expect(await com({ criar: recusa(422, "perfil_incompativel") })).toMatchObject({ passo: "regioes", erro: t.perfil_incompativel });
    expect(await com({ criar: recusa(403, "sem_permissao", "conta_suspensa") })).toMatchObject({ passo: "regioes", erro: t.conta_suspensa });
    expect(await com({ criar: recusa(422, "campo_invalido", "funcoes") })).toMatchObject({ passo: "funcoes", erro: t.funcoes });
    expect(await com({ criar: recusa(422, "campo_obrigatorio", "funcoes") })).toMatchObject({ passo: "funcoes", erro: t.funcoes });
    expect(await com({ criar: recusa(422, "campo_invalido", "ponto_base") })).toMatchObject({ passo: "ponto", erro: t.pontoBase });
    const caiu = await com({ criar: recusa(500) });
    expect(caiu).toMatchObject({ passo: "regioes", erro: t.indisponivel });
    expect(caiu.valores).toEqual({ funcoes: [GARCOM, COZINHEIRO], ponto_regiao: "3", atende_todo_df: false, regioes: ["1", "3"] });
    // Perfil não criado: as regiões nem são tentadas.
    expect(api.POST).toHaveBeenCalledTimes(1);
    servidor({ criar: recusa(401) });
    expect(await redirecionamento(action(envio(COMPLETO)))).toBe("/entrar");
  });

  it("perfil que já existe (o envio anterior gravou e a resposta se perdeu) segue para as regiões", async () => {
    servidor({ criar: recusa(409, "perfil_ja_existe") });
    expect(await redirecionamento(action(envio(COMPLETO)))).toBe("/vagas");
    expect(corpos()[1]).toEqual(["/rpc/definir_regioes_atendidas", { regioes: [1, 3], atende_todo_df: false }]);
  });

  it("recusas ao gravar as regiões: o perfil já existe, e a tela diz isso", async () => {
    expect(await com({ regioes: recusa(422, "campo_invalido", "regioes") })).toMatchObject({ passo: "regioes", erro: t.regioesNaoSalvas });
    expect(await com({ regioes: recusa(500) })).toMatchObject({ passo: "regioes", erro: t.regioesNaoSalvas });
    expect(await com({ regioes: recusa(403, "sem_permissao", "conta_suspensa") })).toMatchObject({ passo: "regioes", erro: t.regioesNaoSalvas });
    servidor({ regioes: recusa(401) });
    expect(await redirecionamento(action(envio(COMPLETO)))).toBe("/entrar");
  });

  it("regiões desligadas no servidor (recurso_desligado): o perfil foi criado, e a pessoa segue para as vagas", async () => {
    servidor({ regioes: recusa(403, "sem_permissao", "recurso_desligado") });
    expect(await redirecionamento(action(envio(COMPLETO)))).toBe("/vagas");
  });

  it("o servidor cair no meio (exceção de rede) não derruba a tela", async () => {
    servidor();
    api.POST.mockRejectedValue(new Error("rede"));
    expect(await action(envio(COMPLETO))).toMatchObject({ passo: "regioes", erro: t.indisponivel });
  });
});
