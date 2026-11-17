import { beforeEach, describe, expect, it, vi } from "vitest";

import { action, loader } from "../app/rotas/contratante/cadastro-casa";
import { avaliarLeitura, estadoDoErro } from "../app/rotas/contratante/ponto-da-casa";
import { textos } from "../app/textos/pt-BR";
import { argumentos, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const t = textos.contratanteCadastro.erros;
const CASA_NOVA = "c0ffee00-1111-4222-8333-444455556666";
const NO_DF = { latitude: "-15.794229", longitude: "-47.882166" };
const formulario = { nome: "Bar Sintético", documento: "12.345.678/0001-90", tipo: "food_service", endereco: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto", ...NO_DF };

function servidor(post: unknown = ok({ id: CASA_NOVA })) {
  api.GET.mockImplementation(async (caminho: string) =>
    caminho === "/regiao_administrativa" ? ok([{ id: 1, numero: "I", nome: "Plano Piloto" }]) : caminho === "/rpc/meus_estabelecimentos" ? ok([]) : recusa(500),
  );
  api.POST.mockResolvedValue(post);
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("ponto da casa: a leitura do navegador no toque", () => {
  it("aceitar: a leitura precisa no Brasil vira o ponto, com seis casas decimais", () => {
    expect(avaliarLeitura({ latitude: -15.79422912345, longitude: -47.88216654321, accuracy: 25 })).toEqual({ estado: "marcado", ponto: { latitude: -15.794229, longitude: -47.882167 } });
  });
  it("negar a permissão e ficar sem sinal não marcam ponto", () => {
    expect(estadoDoErro(1)).toBe("negado");
    expect(estadoDoErro(2)).toBe("sem_sinal");
    expect(estadoDoErro(3)).toBe("sem_sinal");
  });
  it("fora do Brasil ou imprecisa demais (mais de 1 km) não vira ponto", () => {
    expect(avaliarLeitura({ latitude: 38.7223, longitude: -9.1393, accuracy: 20 })).toEqual({ estado: "fora_do_brasil", ponto: null });
    expect(avaliarLeitura({ latitude: -15.79, longitude: -47.88, accuracy: 5000 })).toEqual({ estado: "impreciso", ponto: null });
  });
});

describe("cadastro da casa: loader", () => {
  it("traz as regiões do catálogo; conta de profissional vê o aviso", async () => {
    servidor();
    expect(await loader(argumentos("/casa/cadastro"))).toEqual({ perfilProfissional: false, regioes: ["Plano Piloto"] });
    api.GET.mockImplementation(async (c: string) => (c === "/rpc/meus_estabelecimentos" ? recusa(422, "perfil_incompativel") : ok([])));
    expect((await loader(argumentos("/casa/cadastro"))).perfilProfissional).toBe(true);
  });
});

describe("cadastro da casa: action", () => {
  it("aceitar: cadastra com o ponto do toque e o documento só com os dígitos, e vai ao painel da casa nova", async () => {
    servidor();
    expect(await redirecionamento(action(argumentos("/casa/cadastro", formulario)))).toBe(`/painel?casa=${CASA_NOVA}`);
    expect(api.POST).toHaveBeenCalledWith("/rpc/cadastrar_estabelecimento", expect.objectContaining({
      body: { nome: "Bar Sintético", documento: "12345678000190", tipo: "food_service", endereco: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto", ponto: { latitude: -15.794229, longitude: -47.882166 } },
    }));
  });

  it("negou a permissão (sem ponto): não cadastra e diz para marcar o ponto", async () => {
    servidor();
    const retorno = await action(argumentos("/casa/cadastro", { ...formulario, latitude: "", longitude: "" }));
    expect(retorno.erros).toEqual({ geral: t.temErro, ponto: t.sem_ponto });
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("ponto fora do Brasil não chega ao servidor; fora do DF, no Brasil, cadastra (a tela só avisa)", async () => {
    servidor();
    expect((await action(argumentos("/casa/cadastro", { ...formulario, latitude: "38.7223", longitude: "-9.1393" }))).erros).toEqual({ geral: t.temErro, ponto: t.fora_do_brasil });
    expect(api.POST).not.toHaveBeenCalled();
    expect(await redirecionamento(action(argumentos("/casa/cadastro", { ...formulario, latitude: "-23.5505", longitude: "-46.6333" })))).toBe(`/painel?casa=${CASA_NOVA}`);
  });

  it("campos faltando, documento com tamanho errado e região fora do catálogo não chegam ao servidor", async () => {
    servidor();
    const retorno = await action(argumentos("/casa/cadastro", { ...formulario, nome: "", documento: "123", tipo: "bar", regiao_administrativa: "Atlântida" }));
    expect(retorno.erros).toEqual({ geral: t.temErro, nome: t.nome, documento: t.documento, tipo: t.tipo, regiao_administrativa: t.regiao_administrativa });
    expect(retorno.valores.nome).toBe("");
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("traduz as recusas do servidor e guarda o que foi digitado", async () => {
    const com = async (resposta: unknown) => {
      servidor(resposta);
      return action(argumentos("/casa/cadastro", formulario));
    };
    expect((await com(recusa(409, "documento_ja_cadastrado"))).erros.geral).toBe(t.documento_ja_cadastrado);
    expect((await com(recusa(422, "perfil_incompativel"))).erros.geral).toBe(t.perfil_incompativel);
    expect((await com(recusa(403, "sem_permissao", "conta_suspensa"))).erros.geral).toBe(t.conta_suspensa);
    expect((await com(recusa(422, "campo_invalido", "documento"))).erros).toEqual({ geral: t.temErro, documento: t.documento });
    expect((await com(recusa(422, "campo_invalido", "ponto"))).erros).toEqual({ geral: t.temErro, ponto: t.ponto });
    const caiu = await com(recusa(500));
    expect(caiu.erros.geral).toBe(t.indisponivel);
    expect(caiu.valores.latitude).toBe(NO_DF.latitude);
    servidor(recusa(401));
    expect(await redirecionamento(action(argumentos("/casa/cadastro", formulario)))).toBe("/entrar");
  });
});
