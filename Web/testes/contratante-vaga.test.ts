import { beforeEach, describe, expect, it, vi } from "vitest";

import { action, loader } from "../app/rotas/contratante/vaga";
import { textos } from "../app/textos/pt-BR";
import { argumentos, CASA, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const t = textos.contratante.vaga;
const VAGA = "1665487f-92ca-4bd6-b0cb-d7f9f0ca9f6e";
const CANDIDATURA = "c0000000-0000-4000-8000-000000000001";
const reputacao = (positivas: number, total: number, taxa: number | null, considerados: number, realizados: number) => ({
  positivas, total, taxa_comparecimento: taxa, turnos_considerados: considerados, turnos_realizados: realizados,
});
const perfil = (nome: string) => ({ id: crypto.randomUUID(), tipo: "profissional", nome, reputacao: reputacao(0, 0, null, 0, 0) });
const posicao = (estado: string, extra = {}) => ({ id: crypto.randomUUID(), estado, profissional: null, turno_id: null, verificacao: null, em_atraso: false, a_caminho_em: null, ...extra });

function painelCom(modo: string, estado = "publicada") {
  return {
    estabelecimento_id: CASA,
    checkins_pendentes: [],
    vagas: [{
      vaga: { id: VAGA, funcao: "garçom", local: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto", inicio_em: "2026-11-26T22:00:00Z", fim_em: "2026-11-27T02:30:00Z", valor_centavos: 13000 },
      modo, estado, oculta: false, alerta_vaga_vazia: false, candidatos_pendentes: 2,
      posicoes: [posicao("confirmada", { profissional: perfil("Ana Sintética"), verificacao: "pendente", a_caminho_em: "2026-11-26T21:30:00Z" }), posicao("aberta")],
    }],
  };
}
const candidatos = [
  { candidatura_id: CANDIDATURA, profissional: { ...perfil("Bruno Sintético"), reputacao: reputacao(7, 7, 0.9, 10, 9) }, criada_em: "2026-11-20T12:00:00Z", da_equipe: true },
  { candidatura_id: "c0000000-0000-4000-8000-000000000002", profissional: perfil("Clara Sintética"), criada_em: "2026-11-20T13:00:00Z" },
];

function servidor(respostas: Record<string, unknown>) {
  api.GET.mockImplementation(async (caminho: string) => respostas[caminho] ?? recusa(500));
}
const casas = ok([{ id: CASA, nome: "Bar Sintético", papel: "administrador" }]);
const comVaga = (args: ReturnType<typeof argumentos>) => ({ ...(args as object), params: { vagaId: VAGA } }) as never;

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("vaga da casa: loader", () => {
  it("no modo seleção traz os lugares e os candidatos em ordem de chegada, com o denominador", async () => {
    servidor({ "/rpc/meus_estabelecimentos": casas, "/rpc/painel_estabelecimento": ok(painelCom("selecao")), "/rpc/candidatos_da_vaga": ok(candidatos) });
    const dados = await loader(comVaga(argumentos(`/painel/vagas/${VAGA}?casa=${CASA}`)));
    expect(dados.estado).toBe("ok");
    if (dados.estado !== "ok") return;
    expect(dados.vaga.lista.map((p) => [p.estado, p.profissional, p.aCaminho, p.verificacao])).toEqual([
      ["confirmada", "Ana Sintética", true, "pendente"],
      ["aberta", null, false, null],
    ]);
    expect(dados.candidatos?.map((c) => c.nome)).toEqual(["Bruno Sintético", "Clara Sintética"]);
    expect(dados.candidatos?.[0]).toMatchObject({ daEquipe: true, chamariamDeNovo: { positivas: 7, total: 7 }, turnosRealizados: 9, comparecimento: { porcento: 90, considerados: 10 } });
    expect(dados.candidatos?.[1]).toMatchObject({ daEquipe: false, chamariamDeNovo: null, comparecimento: null });
    const consulta = api.GET.mock.calls.find(([caminho]) => caminho === "/rpc/candidatos_da_vaga")?.[1];
    expect(consulta.params.query).toEqual({ vaga_id: VAGA });
  });

  it("no modo urgência, ou com a vaga fechada, não pede candidatos", async () => {
    servidor({ "/rpc/meus_estabelecimentos": casas, "/rpc/painel_estabelecimento": ok(painelCom("urgencia")) });
    const urgencia = await loader(comVaga(argumentos(`/painel/vagas/${VAGA}`)));
    expect(urgencia.estado === "ok" && urgencia.candidatos).toBeNull();
    servidor({ "/rpc/meus_estabelecimentos": casas, "/rpc/painel_estabelecimento": ok(painelCom("selecao", "preenchida")) });
    await loader(comVaga(argumentos(`/painel/vagas/${VAGA}`)));
    expect(api.GET.mock.calls.some(([caminho]) => caminho === "/rpc/candidatos_da_vaga")).toBe(false);
  });

  it("vaga fora do painel não abre; candidatos fora do ar não derrubam a tela", async () => {
    servidor({ "/rpc/meus_estabelecimentos": casas, "/rpc/painel_estabelecimento": ok({ ...painelCom("selecao"), vagas: [] }) });
    expect(await loader(comVaga(argumentos(`/painel/vagas/${VAGA}`)))).toEqual({ estado: "nao_encontrada", casaId: CASA });
    servidor({ "/rpc/meus_estabelecimentos": casas, "/rpc/painel_estabelecimento": ok(painelCom("selecao")), "/rpc/candidatos_da_vaga": recusa(500) });
    const dados = await loader(comVaga(argumentos(`/painel/vagas/${VAGA}`)));
    expect(dados.estado === "ok" && dados.candidatosIndisponiveis).toBe(true);
    servidor({ "/rpc/meus_estabelecimentos": recusa(401, "PGRST301") });
    expect(await redirecionamento(loader(comVaga(argumentos(`/painel/vagas/${VAGA}`))))).toBe("/entrar");
  });
});

describe("vaga da casa: escolher (action)", () => {
  const escolher = (dados: Record<string, string> = { casa: CASA, candidatura_id: CANDIDATURA }) =>
    action(comVaga(argumentos(`/painel/vagas/${VAGA}`, dados)));

  it("escolhe pela candidatura e volta à vaga com o aviso", async () => {
    api.POST.mockResolvedValue(ok({ estado: "confirmada", posicao_id: "p1", turno_id: "t1" }));
    expect(await redirecionamento(escolher())).toBe(`/painel/vagas/${VAGA}?casa=${CASA}&escolhido=1`);
    expect(api.POST).toHaveBeenCalledWith("/rpc/escolher_candidato", expect.objectContaining({ body: { candidatura_id: CANDIDATURA } }));
  });

  it("traduz cada recusa do servidor", async () => {
    const com = async (resposta: unknown) => {
      api.POST.mockResolvedValue(resposta);
      return escolher();
    };
    expect(await com(recusa(409, "posicao_ja_preenchida"))).toEqual({ erro: t.erros.posicao_ja_preenchida });
    expect(await com(recusa(409, "candidatura_indisponivel"))).toEqual({ erro: t.erros.candidatura_indisponivel });
    expect(await com(recusa(409, "vaga_encerrada"))).toEqual({ erro: t.erros.vaga_encerrada });
    expect(await com(recusa(422, "inelegivel", "turno_sobreposto"))).toEqual({ erro: t.erros.turno_sobreposto });
    expect(await com(recusa(422, "vaga_oculta"))).toEqual({ erro: t.erros.vaga_oculta });
    expect(await com(recusa(403, "sem_permissao"))).toEqual({ erro: t.erros.sem_permissao });
    expect(await com(recusa(500, "XX000"))).toEqual({ erro: t.erros.indisponivel });
    api.POST.mockResolvedValue(recusa(401, "PGRST301"));
    expect(await redirecionamento(escolher())).toBe("/entrar");
  });

  it("formulário sem candidatura válida não chega ao servidor", async () => {
    expect(await escolher({ casa: CASA, candidatura_id: "x" })).toEqual({ erro: t.erros.formularioVelho });
    expect(api.POST).not.toHaveBeenCalled();
  });
});
