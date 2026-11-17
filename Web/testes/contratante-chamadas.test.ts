import { beforeEach, describe, expect, it, vi } from "vitest";

import { action, loader } from "../app/rotas/contratante/chamadas";
import { argumentos, CASA, OUTRA_CASA, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const CHAMADA = "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d";
const VAGA = "2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e";
const CHAVE = "7b84c3e2-8e3b-4f9e-a0e2-1a2b3c4d5e6f";
const chamada = (extra: Record<string, unknown> = {}) => ({
  id: CHAMADA, vaga_id: VAGA, profissional_id: "p1", estabelecimento_id: CASA, estado: "aberta", recado: null, motivo_recusa: null,
  expira_em: "2026-12-12T15:00:00Z", respondida_em: null, criada_em: "2026-12-12T09:00:00Z",
  funcao: { id: "f1", nome: "Garçom", categoria: "Salão" }, inicio_em: "2026-12-12T21:00:00Z", fim_em: "2026-12-13T02:00:00Z", valor_centavos: 18000,
  outra_parte: { id: "p1", tipo: "profissional", nome: "Maria S.", reputacao: {} },
  ...extra,
});

function servidor(lista: unknown, post: unknown = ok({ id: CHAMADA })) {
  api.GET.mockImplementation(async (caminho: string) =>
    caminho === "/rpc/meus_estabelecimentos" ? ok([{ id: CASA, nome: "Bar Sintético", papel: "operador" }]) : caminho === "/rpc/minhas_chamadas" ? lista : recusa(500),
  );
  api.POST.mockResolvedValue(post);
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("chamadas da casa: loader", () => {
  it("mostra só as chamadas desta casa, com estado, prazo e os gestos possíveis", async () => {
    servidor(ok({ itens: [chamada(), chamada({ id: "c2", estabelecimento_id: OUTRA_CASA }), chamada({ id: "c3", estado: "recusada", motivo_recusa: "valor" }), chamada({ id: "c4", estado: "aceita" })], proximo_cursor: "k2" }));
    const dados = await loader(argumentos(`/casa/chamadas?casa=${CASA}`));
    expect(dados.itens.map((i) => i.id)).toEqual([CHAMADA, "c3", "c4"]);
    expect(dados.itens[0]).toMatchObject({ nome: "Maria S.", funcao: "Garçom", estado: "Aguardando resposta", podeCancelar: true, podePublicar: true });
    expect(dados.itens[0]?.respondaAte).toMatch(/^Resposta até /);
    expect(dados.itens[1]).toMatchObject({ estado: "Recusada", motivo: "Motivo: Valor", podeCancelar: false, podePublicar: true });
    expect(dados.itens[2]).toMatchObject({ estado: "Aceita", podeCancelar: false, podePublicar: false });
    expect(dados.proximoCursor).toBe("k2");
  });

  it("a página seguinte leva o cursor; servidor fora mostra o aviso", async () => {
    servidor(ok({ itens: [], proximo_cursor: null }));
    await loader(argumentos(`/casa/chamadas?casa=${CASA}&cursor=k2`));
    expect(api.GET.mock.calls.find(([c]) => c === "/rpc/minhas_chamadas")?.[1].params.query).toEqual({ cursor: "k2" });
    servidor(recusa(500));
    expect((await loader(argumentos("/casa/chamadas"))).estado).toBe("indisponivel");
  });

  it("sem casa volta ao painel", async () => {
    api.GET.mockResolvedValue(ok([]));
    expect(await redirecionamento(loader(argumentos("/casa/chamadas")))).toBe("/painel");
  });
});

describe("chamadas da casa: action", () => {
  it("cancelar e publicar para todos chamam a operação certa e voltam com o aviso", async () => {
    servidor(ok({ itens: [], proximo_cursor: null }));
    expect(await redirecionamento(action(argumentos("/casa/chamadas", { intencao: "cancelar", casa: CASA, chamada_id: CHAMADA })))).toBe(`/casa/chamadas?casa=${CASA}&cancelada=1`);
    expect(api.POST).toHaveBeenLastCalledWith("/rpc/cancelar_chamada", expect.objectContaining({ body: { chamada_id: CHAMADA } }));
    expect(await redirecionamento(action(argumentos("/casa/chamadas", { intencao: "publicar", casa: CASA, vaga_id: VAGA, chave: CHAVE })))).toBe(`/casa/chamadas?casa=${CASA}&publicada=1`);
    expect(api.POST).toHaveBeenLastCalledWith("/rpc/publicar_a_partir_da_chamada", expect.objectContaining({ body: { vaga_id: VAGA, chave: CHAVE } }));
  });

  it("traduz as recusas; id ruim não chega ao servidor", async () => {
    const com = async (resposta: unknown, dados: Record<string, string> = { intencao: "cancelar", casa: CASA, chamada_id: CHAMADA }) => {
      servidor(ok({ itens: [] }), resposta);
      return action(argumentos("/casa/chamadas", dados));
    };
    expect(await com(recusa(409, "chamada_indisponivel", "aceita"))).toEqual({ falha: "indisponivel_agora" });
    expect(await com(recusa(409, "vaga_encerrada"), { intencao: "publicar", casa: CASA, vaga_id: VAGA, chave: CHAVE })).toEqual({ falha: "vaga_encerrada" });
    expect(await com(recusa(403, "sem_permissao", "recurso_desligado"))).toEqual({ falha: "recurso_desligado" });
    expect(await com(recusa(403, "sem_permissao", "conta_suspensa"))).toEqual({ falha: "conta_suspensa" });
    expect(await com(recusa(404, "nao_encontrado"))).toEqual({ falha: "nao_encontrada" });
    api.POST.mockReset();
    expect(await action(argumentos("/casa/chamadas", { intencao: "cancelar", casa: CASA, chamada_id: "x" }))).toEqual({ falha: "nao_encontrada" });
    expect(api.POST).not.toHaveBeenCalled();
    servidor(ok({ itens: [] }), recusa(401));
    expect(await redirecionamento(action(argumentos("/casa/chamadas", { intencao: "cancelar", casa: CASA, chamada_id: CHAMADA })))).toBe("/entrar");
  });
});
