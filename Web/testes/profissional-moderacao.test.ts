import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as desbloquear, loader as carregarBloqueados } from "../app/rotas/profissional/bloqueados";
import { action as enviarDenuncia, loader as carregarDenuncia } from "../app/rotas/profissional/denunciar";
import { criarApi } from "../app/servidor/api";
import { bloquearCasa, denunciarCasa, protocoloCurto } from "../app/servidor/profissional/moderacao";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const CASA = "0b8a7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d";
const TURNO = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";
const CHAVE = "11111111-2222-4333-8444-555555555555";
const protocolo = { ocorrencia_id: "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88", tipo: "denuncia", criada_em: "x", prazo_resposta_ate: "y" };

function apiQueResponde(resposta: () => Response | Promise<Response>) {
  const pedidos: Request[] = [];
  const api = criarApi(ambiente, {
    token: "t",
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { api, pedidos };
}

describe("moderação (servidor)", () => {
  it("protocolo curto: 8 hexadecimais, sem hífen, em maiúsculas", () => {
    expect(protocoloCurto(protocolo.ocorrencia_id)).toBe("6F1C2A4E");
  });

  it("denuncia a casa com motivo, relato e a chave do formulário", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(protocolo));
    expect(await denunciarCasa(api, { alvoId: CASA, turnoId: TURNO, motivo: "assedio", relato: "  algo grave aconteceu  ", chave: CHAVE })).toEqual({
      ok: true,
      protocolo: "6F1C2A4E",
    });
    expect(await pedidos[0]?.json()).toEqual({ alvo_tipo: "estabelecimento", alvo_id: CASA, turno_id: TURNO, motivo: "assedio", relato: "algo grave aconteceu", chave: CHAVE });
  });

  it("relato curto e alvo torto nem saem", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(protocolo));
    expect(await denunciarCasa(api, { alvoId: CASA, turnoId: null, motivo: "outro", relato: "curto", chave: CHAVE })).toEqual({ ok: false, motivo: "relato_curto" });
    expect(await denunciarCasa(api, { alvoId: "x", turnoId: null, motivo: "outro", relato: "relato longo o bastante", chave: CHAVE })).toEqual({ ok: false, motivo: "nao_encontrado" });
    expect(pedidos).toHaveLength(0);
  });

  it("bloquear e desbloquear mandam o par da casa", async () => {
    const bloqueio = apiQueResponde(() => Response.json({ alvo_tipo: "estabelecimento", alvo_id: CASA, criado_em: "x" }));
    expect(await bloquearCasa(bloqueio.api, CASA)).toEqual({ ok: true });
    expect(new URL(bloqueio.pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/bloquear");
    expect(await bloquearCasa(bloqueio.api, CASA, true)).toEqual({ ok: true });
    expect(new URL(bloqueio.pedidos[1]?.url ?? "").pathname).toBe("/rest/v1/rpc/desbloquear");
    expect(await bloqueio.pedidos[1]?.json()).toEqual({ alvo_tipo: "estabelecimento", alvo_id: CASA });
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (url: string, dados: Record<string, string> | null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com", visitante: null } : null);
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: {}, url: new URL(url), matches: [] } as never;
};
const ok = (corpo: unknown) => ({ data: corpo, response: new Response() });

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("telas de denúncia e bloqueio", () => {
  it("sem sessão, manda entrar", async () => {
    expect(() => carregarDenuncia(argumentos(`https://frilabr.com/app/denunciar?alvo=${CASA}`, null, false))).toThrow();
    await expect(enviarDenuncia(argumentos("https://frilabr.com/app/denunciar", { alvo: CASA }, false))).rejects.toHaveProperty("status", 302);
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("o formulário leva o alvo do endereço (só uuid) e uma chave nova", () => {
    const dados = carregarDenuncia(argumentos(`https://frilabr.com/app/denunciar?alvo=${CASA}&turno=lixo`, null));
    expect(dados.alvo).toBe(CASA);
    expect(dados.turno).toBeNull();
    expect(dados.chave).toMatch(/^[0-9a-f-]{36}$/);
    expect(carregarDenuncia(argumentos("https://frilabr.com/app/denunciar?alvo=lixo", null)).alvo).toBeNull();
  });

  it("denunciar e bloquear juntos: denúncia primeiro, depois o bloqueio", async () => {
    api.POST.mockResolvedValueOnce(ok(protocolo)).mockResolvedValueOnce(ok({ alvo_tipo: "estabelecimento", alvo_id: CASA, criado_em: "x" }));
    const resultado = await enviarDenuncia(
      argumentos("https://frilabr.com/app/denunciar", { alvo: CASA, turno: "", chave: CHAVE, motivo: "discriminacao", relato: "relato com detalhes", bloquear: "sim" }),
    );
    expect(resultado).toEqual({ protocolo: "6F1C2A4E", bloqueada: true, erro: null, chave: CHAVE, bloqueioPendente: false });
    expect(api.POST.mock.calls.map((c) => c[0])).toEqual(["/rpc/denunciar", "/rpc/bloquear"]);
  });

  it("denúncia salva e bloqueio falhou: volta o protocolo, a MESMA chave e só o bloqueio pendente", async () => {
    api.POST.mockResolvedValueOnce(ok(protocolo)).mockResolvedValueOnce({ error: { code: "x" }, response: new Response(null, { status: 503 }) });
    const resultado = await enviarDenuncia(
      argumentos("https://frilabr.com/app/denunciar", { alvo: CASA, chave: CHAVE, motivo: "assedio", relato: "relato com detalhes", bloquear: "sim" }),
    );
    expect(resultado).toEqual({ protocolo: "6F1C2A4E", bloqueada: false, erro: "indisponivel", chave: CHAVE, bloqueioPendente: true });
  });

  it("só bloquear não denuncia", async () => {
    api.POST.mockResolvedValueOnce(ok({ alvo_tipo: "estabelecimento", alvo_id: CASA, criado_em: "x" }));
    expect(await enviarDenuncia(argumentos("https://frilabr.com/app/denunciar", { alvo: CASA, intencao: "bloquear" }))).toMatchObject({ protocolo: null, bloqueada: true, erro: null });
    expect(api.POST.mock.calls.map((c) => c[0])).toEqual(["/rpc/bloquear"]);
  });

  it("bloqueados: lista só casas e desbloqueia pelo par", async () => {
    api.GET.mockResolvedValue(ok([{ alvo_tipo: "estabelecimento", alvo_id: CASA, nome: "Casa", criado_em: "x" }, { alvo_tipo: "profissional", alvo_id: TURNO, nome: "P", criado_em: "x" }]));
    expect((await carregarBloqueados(argumentos("https://frilabr.com/app/bloqueados", null))).bloqueios).toEqual([{ alvoId: CASA, nome: "Casa" }]);
    api.POST.mockResolvedValueOnce(ok({ alvo_tipo: "estabelecimento", alvo_id: CASA, criado_em: "x" }));
    expect(await desbloquear(argumentos("https://frilabr.com/app/bloqueados", { alvo: CASA }))).toEqual({ erro: null });
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/desbloquear");
  });
});
