import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
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
