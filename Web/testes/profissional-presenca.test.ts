import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { distanciaEmMetros } from "../app/rotas/profissional/localizacao";
import { action as agirNoTurno } from "../app/rotas/profissional/turno";
import { criarApi } from "../app/servidor/api";
import { distanciaDoFormulario, marcarChegada, marcarSaida, validarCodigo } from "../app/servidor/profissional/presenca";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const TURNO_ID = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";
const registro = (verificacao: string) => ({ turno_id: TURNO_ID, tipo: "manual", verificacao, registrado_em: "x", distancia_m: 30 });

function apiQueResponde(resposta: () => Response | Promise<Response>) {
  const pedidos: Request[] = [];
  const api = criarApi(ambiente, {
    token: "token-do-usuario",
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { api, pedidos };
}
const recusa = (status: number, code: string, details: string | null = null) => () =>
  Response.json({ code, message: code, details, hint: null }, { status });

describe("presença (servidor)", () => {
  it("chegada: manda só turno, distância e a hora do servidor; nada de sinais nem coordenada", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json({ ...registro("pendente"), codigo_exigido: true }));
    const antes = Date.now();
    expect(await marcarChegada(api, TURNO_ID, 30)).toEqual({ ok: true, verificado: false });
    const corpo = (await pedidos[0]?.json()) as Record<string, unknown>;
    expect(Object.keys(corpo).sort()).toEqual(["distancia_m", "registrado_em", "turno_id"]);
    expect(corpo.distancia_m).toBe(30);
    expect(Date.parse(String(corpo.registrado_em))).toBeGreaterThanOrEqual(antes - 1000);
    expect(new URL(pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/fazer_checkin");
  });

  it("sem posição, a distância vai nula (o servidor decide)", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(registro("pendente")));
    await marcarChegada(api, TURNO_ID, null);
    expect(((await pedidos[0]?.json()) as { distancia_m: unknown }).distancia_m).toBeNull();
  });

  it("código: valida com a distância; presença verificada", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(registro("verificado")));
    expect(await validarCodigo(api, TURNO_ID, "482913", 20)).toEqual({ ok: true, verificado: true });
    expect(await pedidos[0]?.json()).toEqual({ turno_id: TURNO_ID, codigo: "482913", distancia_m: 20 });
  });

  it("código torto nem sai", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json({}));
    expect(await validarCodigo(api, TURNO_ID, "12ab", 20)).toEqual({ ok: false, motivo: "codigo_invalido" });
    expect(pedidos).toHaveLength(0);
  });

  it("traduz cada recusa do contrato", async () => {
    const casos: Array<[() => Response, string]> = [
      [recusa(422, "sem_localizacao"), "sem_localizacao"],
      [recusa(422, "fora_do_raio"), "fora_do_raio"],
      [recusa(422, "codigo_invalido"), "codigo_invalido"],
      [recusa(409, "codigo_bloqueado"), "codigo_bloqueado"],
      [recusa(422, "fora_da_janela"), "fora_da_janela"],
      [recusa(422, "registro_no_futuro"), "fora_da_janela"],
      [recusa(409, "vaga_encerrada", "posicao_cancelada"), "turno_cancelado"],
      [recusa(409, "checkin_pendente"), "checkin_pendente"],
      [recusa(404, "nao_encontrado"), "nao_encontrado"],
      [recusa(503, "x"), "indisponivel"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await validarCodigo(apiQueResponde(resposta).api, TURNO_ID, "482913", 20), motivo).toEqual({ ok: false, motivo });
    }
    expect(await marcarSaida(apiQueResponde(recusa(409, "checkin_pendente")).api, TURNO_ID, null)).toEqual({
      ok: false,
      motivo: "checkin_pendente",
    });
  });

  it("distância do formulário: só metros inteiros; o resto vira nulo", () => {
    expect(distanciaDoFormulario("42")).toBe(42);
    for (const torto of ["", "-3", "1.5", "abc", null]) expect(distanciaDoFormulario(torto), String(torto)).toBeNull();
  });

  it("distância entre dois pontos, em metros", () => {
    const casa = { latitude: -15.7942, longitude: -47.8822 };
    expect(distanciaEmMetros(casa, casa)).toBe(0);
    // 0,00045° de latitude ≈ 50 m
    expect(distanciaEmMetros(casa, { latitude: -15.79465, longitude: -47.8822 })).toBe(50);
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string>, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com", visitante: null } : null);
  const url = `https://frilabr.com/app/turnos/${TURNO_ID}`;
  const request = new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) });
  return { request, context, params: { turnoId: TURNO_ID }, url: new URL(url), matches: [] } as never;
};
const ok = (corpo: unknown) => ({ data: corpo, response: new Response(null, { status: 200 }) });

beforeEach(() => api.POST.mockReset());

describe("tela do turno: presença", () => {
  it("sem sessão, nada sai", async () => {
    await expect(agirNoTurno(argumentos({ intencao: "chegar", turno_id: TURNO_ID }, false))).rejects.toHaveProperty("status", 302);
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("chegar → código → encerrar", async () => {
    api.POST.mockResolvedValueOnce(ok(registro("pendente")));
    expect(await agirNoTurno(argumentos({ intencao: "chegar", turno_id: TURNO_ID, distancia_m: "30" }))).toEqual({ presenca: "chegada" });
    expect(api.POST.mock.calls[0]?.[1].body).toMatchObject({ turno_id: TURNO_ID, distancia_m: 30 });
    api.POST.mockResolvedValueOnce(ok(registro("verificado")));
    expect(await agirNoTurno(argumentos({ intencao: "validar", turno_id: TURNO_ID, codigo: " 482913 ", distancia_m: "" }))).toEqual({
      presenca: "verificada",
    });
    expect(api.POST.mock.calls[1]?.[1].body).toEqual({ turno_id: TURNO_ID, codigo: "482913", distancia_m: null });
    api.POST.mockResolvedValueOnce(ok(registro("verificado")));
    expect(await agirNoTurno(argumentos({ intencao: "encerrar", turno_id: TURNO_ID }))).toEqual({ presenca: "saida" });
    expect(api.POST.mock.calls[2]?.[0]).toBe("/rpc/fazer_checkout");
  });

  it("recusa do servidor vira o aviso da presença", async () => {
    api.POST.mockResolvedValueOnce({ error: { code: "fora_do_raio" }, response: new Response(null, { status: 422 }) });
    expect(await agirNoTurno(argumentos({ intencao: "validar", turno_id: TURNO_ID, codigo: "482913", distancia_m: "80" }))).toEqual({
      presenca: "fora_do_raio",
    });
  });
});
