import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as abrirChamado, loader as carregarSuporte } from "../app/rotas/suporte";
import { criarApi } from "../app/servidor/api";
import { abrirSuporte, emailDoSuporte } from "../app/servidor/suporte";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const TURNO_ID = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";
const CASA_ID = "1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f";
const CHAVE = "3f2e1d0c-9b8a-4765-8432-10fedcba9876";
const PROTOCOLO = { ocorrencia_id: "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88", tipo: "suporte" as const, criada_em: "2026-11-17T06:00:00Z", prazo_resposta_ate: "2026-11-24" };

function apiQueResponde(resposta: () => Response) {
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
const recusa = (status: number, code: string, details: string | null = null) => () =>
  Response.json({ code, message: code, details, hint: null }, { status });

describe("abrir suporte (servidor)", () => {
  it("manda só turno, categoria e chave", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(PROTOCOLO));
    expect(await abrirSuporte(api, TURNO_ID, "atraso", CHAVE)).toEqual({ ok: true, protocolo: PROTOCOLO });
    expect(await pedidos[0]?.json()).toEqual({ turno_id: TURNO_ID, categoria: "atraso", chave: CHAVE });
  });

  it("categoria fora da lista nem sai; recusas do contrato viram aviso", async () => {
    const fora = apiQueResponde(() => Response.json(PROTOCOLO));
    expect(await abrirSuporte(fora.api, TURNO_ID, "qualquer", CHAVE)).toEqual({ ok: false, motivo: "categoria" });
    expect(fora.pedidos).toHaveLength(0);
    const casos: Array<[() => Response, string]> = [
      [recusa(403, "sem_permissao", "conta_suspensa"), "conta_suspensa"],
      [recusa(429, "limite_excedido"), "limite"],
      [recusa(404, "nao_encontrado"), "nao_encontrado"],
      [recusa(401, "nao_autenticado"), "sem_sessao"],
      [recusa(503, "x"), "indisponivel"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await abrirSuporte(apiQueResponde(resposta).api, TURNO_ID, "outro", CHAVE), motivo).toEqual({ ok: false, motivo });
    }
  });

  it("o e-mail leva o protocolo curto no assunto e os dados do turno, sem relato", () => {
    const email = emailDoSuporte(PROTOCOLO, { turnoId: TURNO_ID, funcao: "Garçom", outraParte: "Casa Sintética", lado: "profissional", horario: "seg., 17/11 · 03:30 às 04:30", local: "Asa Norte", motivo: "Atraso ou imprevisto no comparecimento" });
    expect(email.assunto).toBe("[Frila Suporte #6F1C2A4E] Garçom");
    expect(email.corpo).toContain(`- ID: ${TURNO_ID}`);
    expect(email.corpo).toContain("- Contratante: Casa Sintética");
    expect(email.corpo).toContain("- Prazo de resposta: até 24/11/2026");
    expect(email.corpo).toContain("Motivo do Chamado:\nAtraso ou imprevisto no comparecimento");
    expect(email.link.startsWith("mailto:suporte@frilabr.com?subject=%5BFrila%20Suporte%20%236F1C2A4E%5D")).toBe(true);
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (endereco: string, dados: Record<string, string> | null = null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com" } : null);
  const url = `https://frilabr.com/app${endereco}`;
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: { turnoId: TURNO_ID }, url: new URL(url), matches: [] } as never;
};
const ok = (corpo: unknown) => ({ data: corpo, response: new Response(null, { status: 200 }) });
const erro = (status: number, code: string) => ({ error: { code }, response: new Response(null, { status }) });
const turno = {
  id: TURNO_ID,
  posicao_id: "0b8a7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d",
  vaga: { id: "v1", funcao: "Garçom", local: "Asa Norte", regiao_administrativa: "Plano Piloto", inicio_em: "2026-11-17T06:30:00Z", fim_em: "2026-11-17T07:30:00Z", valor_centavos: 15000 },
  contraparte: { id: "e1", tipo: "estabelecimento", nome: "Casa Sintética", reputacao: {} },
};

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("tela do suporte", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    await expect(carregarSuporte(argumentos(`/suporte/${TURNO_ID}`, null, false))).rejects.toHaveProperty("status", 302);
    await expect(abrirChamado(argumentos(`/suporte/${TURNO_ID}`, { categoria: "outro", chave: CHAVE }, false))).rejects.toHaveProperty("status", 302);
    expect(api.GET).not.toHaveBeenCalled();
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("o turno vem da lista de quem chama; do lado da casa, pela casa", async () => {
    api.GET.mockResolvedValue(ok([turno]));
    const dados = (await carregarSuporte(argumentos(`/suporte/${TURNO_ID}`))) as { turno: { funcao: string }; chave: string };
    expect(dados.turno.funcao).toBe("Garçom");
    expect(dados.chave).toMatch(/^[0-9a-f-]{36}$/);
    expect(api.GET.mock.calls[0]?.[1]?.params).toBeUndefined();
    await carregarSuporte(argumentos(`/suporte/${TURNO_ID}?casa=${CASA_ID}`));
    expect(api.GET.mock.calls[1]?.[1]?.params).toEqual({ query: { estabelecimento_id: CASA_ID } });
  });

  it("turno que não é de quem chama responde 404", async () => {
    api.GET.mockResolvedValue(ok([]));
    expect(((await carregarSuporte(argumentos(`/suporte/${TURNO_ID}`))) as { init: ResponseInit | null }).init?.status).toBe(404);
  });

  it("registrado: devolve o protocolo e o e-mail; a chave do reenvio é a mesma", async () => {
    api.GET.mockResolvedValue(ok([turno]));
    api.POST.mockResolvedValueOnce(ok(PROTOCOLO));
    const feito = (await abrirChamado(argumentos(`/suporte/${TURNO_ID}`, { categoria: "atraso", chave: CHAVE }))) as { numero: string; email: { assunto: string } };
    expect(feito).toMatchObject({ numero: "6F1C2A4E", prazo: "24/11/2026", email: { assunto: "[Frila Suporte #6F1C2A4E] Garçom" } });
    expect(api.POST.mock.calls[0]?.[1]).toMatchObject({ body: { turno_id: TURNO_ID, categoria: "atraso", chave: CHAVE } });
    api.POST.mockResolvedValueOnce(erro(503, "x"));
    expect(await abrirChamado(argumentos(`/suporte/${TURNO_ID}`, { categoria: "atraso", chave: CHAVE }))).toEqual({ resultado: "indisponivel", chave: CHAVE });
  });
});
