import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as agirNoTurno, loader as carregarTurno } from "../app/rotas/contratante/turno/detalhe";
import { loader as carregarLista } from "../app/rotas/contratante/turno/lista";

const CASA_A = "1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f";
const CASA_B = "2c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f";
const TURNO_ID = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";
const POSICAO_ID = "0b8a7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d";
const minutosAtras = (m: number) => new Date(Date.now() - m * 60_000).toISOString();

const turno = (mudancas: Record<string, unknown> = {}) => ({
  id: TURNO_ID,
  posicao_id: POSICAO_ID,
  vaga: { id: "v1", funcao: "Garçom", local: "Asa Norte", regiao_administrativa: "Plano Piloto", inicio_em: minutosAtras(20), fim_em: minutosAtras(-60), valor_centavos: 15000 },
  contraparte: { id: "p1", tipo: "profissional", nome: "Pessoa Sintética", reputacao: {} },
  a_caminho_em: null,
  checkin_em: null,
  checkin_tipo: null,
  checkin_distancia_m: null,
  checkin_confirmado_em: null,
  checkout_em: null,
  checkout_distancia_m: null,
  verificacao: "pendente",
  valor_acordado_centavos: 15000,
  pode_avaliar: false,
  estado: "confirmada",
  ...mudancas,
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const resposta = (status: number, corpo: unknown) =>
  status < 300 ? { data: corpo, response: new Response(null, { status }) } : { error: corpo, response: new Response(null, { status }) };
const casas = [
  { id: CASA_A, nome: "Bar Sintético", papel: "operador" },
  { id: CASA_B, nome: "Buffet Sintético", papel: "administrador" },
];
/** O servidor de mentira: as casas e os turnos de cada uma. */
function servidor(turnosPorCasa: Record<string, unknown[]>) {
  api.GET.mockImplementation(async (caminho: string, opcoes?: { params?: { query?: { estabelecimento_id?: string } } }) =>
    caminho === "/rpc/meus_estabelecimentos" ? resposta(200, casas) : resposta(200, turnosPorCasa[opcoes?.params?.query?.estabelecimento_id ?? ""] ?? []),
  );
}
const argumentos = (endereco: string, dados: Record<string, string> | null = null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "c@example.com" } : null);
  const url = `https://frilabr.com/app${endereco}`;
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: { turnoId: TURNO_ID }, url: new URL(url), matches: [] } as never;
};

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("turnos da casa (lista)", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    await expect(carregarLista(argumentos("/casa/turnos", null, false))).rejects.toHaveProperty("status", 302);
    await expect(carregarTurno(argumentos(`/casa/turnos/${TURNO_ID}`, null, false))).rejects.toHaveProperty("status", 302);
    await expect(agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "codigo", turno_id: TURNO_ID }, false))).rejects.toHaveProperty("status", 302);
    expect(api.GET).not.toHaveBeenCalled();
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("conta de profissional recebe o aviso, sem pedir turnos", async () => {
    api.GET.mockResolvedValue(resposta(422, { code: "perfil_incompativel" }));
    expect(await carregarLista(argumentos("/casa/turnos"))).toMatchObject({ estado: "perfil_incompativel", turnos: [] });
    expect(api.GET).toHaveBeenCalledTimes(1);
  });

  it("mostra a casa do endereço e oferece as outras; não devolve token", async () => {
    servidor({ [CASA_B]: [turno()] });
    const dados = (await carregarLista(argumentos(`/casa/turnos?casa=${CASA_B}`))) as {
      casa: { nome: string };
      outrasCasas: Array<{ id: string }>;
      turnos: Array<{ profissional: string; chegada: string }>;
    };
    expect(dados.casa.nome).toBe("Buffet Sintético");
    expect(dados.outrasCasas.map((casa) => casa.id)).toEqual([CASA_A]);
    expect(dados.turnos).toEqual([expect.objectContaining({ profissional: "Pessoa Sintética", chegada: "aguardando" })]);
    expect(JSON.stringify(dados)).not.toContain("token-sintetico");
  });
});

describe("tela do turno da casa", () => {
  const carregar = async () =>
    (await carregarTurno(argumentos(`/casa/turnos/${TURNO_ID}?casa=${CASA_A}`))) as {
      turno: { podeVerCodigo: boolean; podeConfirmar: boolean; podeReabrir: boolean } | null;
      init?: ResponseInit | null;
    };

  it("turno de outra casa responde 404", async () => {
    servidor({ [CASA_B]: [turno()] });
    expect((await carregar()).init?.status).toBe(404);
  });

  it("chegada registrada com a presença em aberto: código e confirmação manual", async () => {
    servidor({ [CASA_A]: [turno({ checkin_em: minutosAtras(2), checkin_tipo: "manual" })] });
    expect((await carregar()).turno).toMatchObject({ podeVerCodigo: true, podeConfirmar: true, podeReabrir: false });
  });

  it("reabrir só aparece depois de 15 minutos do início sem check-in", async () => {
    servidor({ [CASA_A]: [turno()] });
    expect((await carregar()).turno).toMatchObject({ podeVerCodigo: false, podeConfirmar: false, podeReabrir: true });
    servidor({ [CASA_A]: [turno({ vaga: { ...turno().vaga, inicio_em: minutosAtras(5) } })] });
    expect((await carregar()).turno?.podeReabrir).toBe(false);
  });

  it("o código vem só no corpo da resposta, com a validade do servidor em minutos", async () => {
    api.POST.mockResolvedValueOnce(resposta(200, { turno_id: TURNO_ID, codigo: "482913", expira_em: "x", segundos_restantes: 241 }));
    expect(await agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "codigo", turno_id: TURNO_ID }))).toEqual({ codigo: "482913", minutos: 5 });
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/gerar_codigo_checkin");
    api.POST.mockResolvedValueOnce(resposta(409, { code: "codigo_bloqueado", details: "encerrado" }));
    expect(await agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "codigo", turno_id: TURNO_ID }))).toEqual({ resultado: "codigo_encerrado" });
  });

  it("confirmar a presença e reabrir por atraso pela action", async () => {
    api.POST.mockResolvedValueOnce(resposta(200, { turno_id: TURNO_ID }));
    expect(await agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "confirmar", turno_id: TURNO_ID }))).toEqual({ resultado: "confirmada" });
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/confirmar_checkin_manual");
    api.POST.mockResolvedValueOnce(resposta(200, { posicao_id: POSICAO_ID, falta: true, reaberta: true, nova_posicao_id: null }));
    expect(await agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "reabrir", posicao_id: POSICAO_ID }))).toEqual({ resultado: "reaberta" });
    expect(api.POST.mock.calls[1]?.[1]).toMatchObject({ body: { posicao_id: POSICAO_ID } });
    api.POST.mockResolvedValueOnce(resposta(422, { code: "reabertura_antes_da_tolerancia" }));
    expect(await agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "reabrir", posicao_id: POSICAO_ID }))).toEqual({ resultado: "antes_da_tolerancia" });
  });

  it("sessão vencida no servidor manda entrar de novo", async () => {
    api.POST.mockResolvedValueOnce(resposta(401, { code: "nao_autenticado" }));
    await expect(agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "confirmar", turno_id: TURNO_ID }))).rejects.toHaveProperty("status", 302);
  });
});

describe("avaliar o profissional (C5)", () => {
  const carregar = async () =>
    (await carregarTurno(argumentos(`/casa/turnos/${TURNO_ID}?casa=${CASA_A}`))) as {
      turno: { podeAvaliar: boolean; respostaDada: boolean | null } | null;
    };
  const cumprido = { estado: "cumprida", checkin_em: minutosAtras(90), checkout_em: minutosAtras(5), verificacao: "verificado" };

  it("depois do turno com presença verificada, a pergunta abre; a resposta dada aparece no lugar", async () => {
    servidor({ [CASA_A]: [turno({ ...cumprido, pode_avaliar: true, avaliacao: null })] });
    expect((await carregar()).turno).toMatchObject({ podeAvaliar: true, respostaDada: null });
    servidor({ [CASA_A]: [turno({ ...cumprido, pode_avaliar: false, avaliacao: { turno_id: TURNO_ID, resposta: false, criada_em: "x" } })] });
    expect((await carregar()).turno).toMatchObject({ podeAvaliar: false, respostaDada: false });
  });

  it("servidor anterior sem o campo avaliacao: não afirma que a casa ainda não avaliou", async () => {
    servidor({ [CASA_A]: [turno({ ...cumprido, pode_avaliar: false })] });
    expect((await carregar()).turno).toMatchObject({ podeAvaliar: false, respostaDada: null });
  });

  it("a action manda o turno e a resposta; resposta fora de sim ou não nem sai", async () => {
    api.POST.mockResolvedValueOnce(resposta(200, { turno_id: TURNO_ID, resposta: true, criada_em: "x" }));
    expect(await agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "avaliar", turno_id: TURNO_ID, resposta: "sim" }))).toEqual({ avaliacao: "registrada" });
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/avaliar");
    expect(api.POST.mock.calls[0]?.[1]).toMatchObject({ body: { turno_id: TURNO_ID, resposta: true } });
    api.POST.mockResolvedValueOnce(resposta(409, { code: "avaliacao_ja_registrada" }));
    expect(await agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "avaliar", turno_id: TURNO_ID, resposta: "nao" }))).toEqual({ avaliacao: "ja_registrada" });
    expect(await agirNoTurno(argumentos(`/casa/turnos/${TURNO_ID}`, { intencao: "avaliar", turno_id: TURNO_ID, resposta: "talvez" }))).toEqual({ avaliacao: "indisponivel" });
    expect(api.POST).toHaveBeenCalledTimes(2);
  });
});
