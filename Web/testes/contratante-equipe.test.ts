import { beforeEach, describe, expect, it, vi } from "vitest";

import { action, loader } from "../app/rotas/contratante/equipe";
import { loader as carregarTurno } from "../app/rotas/contratante/turno/detalhe";
import { argumentos, CASA, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const MARIA = "5d1c2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d";
const perfil = { id: MARIA, tipo: "profissional", nome: "Maria Sintética", funcoes: ["garçom"], reputacao: { recomendacoes: 3, avaliacoes: 3 } };
const casas = (papel = "administrador") => ok([{ id: CASA, nome: "Bar Sintético", papel }]);

function servidor(get: Record<string, unknown>, post: unknown = ok({ estabelecimento_id: CASA, profissional_id: MARIA })) {
  api.GET.mockImplementation(async (caminho: string) => get[caminho] ?? recusa(500));
  api.POST.mockResolvedValue(post);
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("equipe de confiança: loader", () => {
  it("lista a equipe da casa pelo contrato, só com nome e funções", async () => {
    servidor({ "/rpc/meus_estabelecimentos": casas(), "/rpc/equipe_de_confianca": ok([perfil]) });
    const dados = await loader(argumentos(`/casa/equipe?casa=${CASA}&incluido=1`));
    expect(dados.casa).toEqual({ id: CASA, nome: "Bar Sintético", administrador: true });
    expect(dados.membros).toEqual([{ id: MARIA, nome: "Maria Sintética", funcoes: ["garçom"] }]);
    expect(dados.aviso).toBe("Incluído na equipe de confiança.");
    const consulta = api.GET.mock.calls.find(([caminho]) => caminho === "/rpc/equipe_de_confianca")?.[1];
    expect(consulta.params.query).toEqual({ estabelecimento_id: CASA });
  });

  it("operador vê a equipe sem poder mudar; servidor fora mostra o aviso, sem lista", async () => {
    servidor({ "/rpc/meus_estabelecimentos": casas("operador"), "/rpc/equipe_de_confianca": ok([]) });
    expect((await loader(argumentos("/casa/equipe"))).casa.administrador).toBe(false);
    servidor({ "/rpc/meus_estabelecimentos": casas(), "/rpc/equipe_de_confianca": recusa(500) });
    const fora = await loader(argumentos("/casa/equipe"));
    expect(fora.estado).toBe("indisponivel");
    expect(fora.membros).toEqual([]);
  });

  it("sem casa volta ao painel; 401 manda entrar", async () => {
    servidor({ "/rpc/meus_estabelecimentos": ok([]) });
    expect(await redirecionamento(loader(argumentos("/casa/equipe")))).toBe("/painel");
    servidor({ "/rpc/meus_estabelecimentos": casas(), "/rpc/equipe_de_confianca": recusa(401) });
    expect(await redirecionamento(loader(argumentos("/casa/equipe")))).toBe("/entrar");
  });
});

describe("equipe de confiança: action", () => {
  const pedido = (intencao: string, extra: Record<string, string> = {}) =>
    argumentos("/casa/equipe", { intencao, casa: CASA, profissional_id: MARIA, ...extra });

  it("incluir e remover chamam a operação certa e voltam à equipe com o aviso", async () => {
    servidor({});
    expect(await redirecionamento(action(pedido("incluir")))).toBe(`/casa/equipe?casa=${CASA}&incluido=1`);
    expect(api.POST).toHaveBeenLastCalledWith("/rpc/incluir_na_equipe", expect.objectContaining({ body: { estabelecimento_id: CASA, profissional_id: MARIA } }));
    expect(await redirecionamento(action(pedido("remover")))).toBe(`/casa/equipe?casa=${CASA}&removido=1`);
    expect(api.POST).toHaveBeenLastCalledWith("/rpc/remover_da_equipe", expect.objectContaining({ body: { estabelecimento_id: CASA, profissional_id: MARIA } }));
  });

  it("traduz cada recusa do servidor", async () => {
    const com = async (resposta: unknown) => {
      servidor({}, resposta);
      return action(pedido("incluir"));
    };
    expect(await com(recusa(403, "sem_permissao", "sem_turno_cumprido"))).toEqual({ falha: "sem_turno_cumprido" });
    expect(await com(recusa(403, "sem_permissao", "conta_suspensa"))).toEqual({ falha: "conta_suspensa" });
    expect(await com(recusa(403, "sem_permissao"))).toEqual({ falha: "so_administrador" });
    expect(await com(recusa(404, "nao_encontrado"))).toEqual({ falha: "nao_encontrado" });
    expect(await com(recusa(500, "XX000"))).toEqual({ falha: "indisponivel" });
    servidor({}, recusa(401));
    expect(await redirecionamento(action(pedido("incluir")))).toBe("/entrar");
  });

  it("intenção estranha ou id que não é uuid não chegam ao servidor", async () => {
    servidor({});
    expect(await action(pedido("apagar"))).toEqual({ falha: "indisponivel" });
    expect(await action(pedido("remover", { profissional_id: "x" }))).toEqual({ falha: "nao_encontrado" });
    expect(api.POST).not.toHaveBeenCalled();
  });
});

describe("equipe de confiança: o turno da casa oferece incluir", () => {
  const TURNO = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";
  const turno = (verificacao: string) => ({
    id: TURNO, posicao_id: "p1", estado: "confirmada", verificacao, pode_avaliar: false, valor_acordado_centavos: 15000,
    vaga: { id: "v1", funcao: "Garçom", local: "Rua", regiao_administrativa: "Plano Piloto", inicio_em: "2026-11-10T21:00:00Z", fim_em: "2026-11-11T02:00:00Z", valor_centavos: 15000 },
    contraparte: perfil, a_caminho_em: null, checkin_em: "2026-11-10T20:55:00Z", checkin_tipo: "codigo", checkin_distancia_m: null,
    checkin_confirmado_em: null, checkout_em: null, checkout_distancia_m: null,
  });
  const abrir = async (verificacao: string) => {
    servidor({ "/rpc/meus_estabelecimentos": casas(), "/rpc/meus_turnos": ok([turno(verificacao)]) });
    const pedido = argumentos(`/casa/turnos/${TURNO}?casa=${CASA}`) as { params: Record<string, string> };
    pedido.params = { turnoId: TURNO };
    return (await carregarTurno(pedido as never)) as { turno: { profissionalId: string; podeIncluirNaEquipe: boolean } };
  };

  it("só com a presença verificada, e leva o id do profissional", async () => {
    const verificado = await abrir("verificado");
    expect(verificado.turno).toMatchObject({ profissionalId: MARIA, podeIncluirNaEquipe: true });
    expect((await abrir("pendente")).turno.podeIncluirNaEquipe).toBe(false);
    expect((await abrir("nao_verificado")).turno.podeIncluirNaEquipe).toBe(false);
  });
});
