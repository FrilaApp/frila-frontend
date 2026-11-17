import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as contestar, loader as carregarSituacao } from "../app/rotas/conta/suspensa";
import { criarApi } from "../app/servidor/api";
import { contestarSuspensao, lerSituacaoDaConta } from "../app/servidor/conta/suspensao";
import { dataCivil, protocoloCurto } from "../app/servidor/protocolo";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const PROTOCOLO = { ocorrencia_id: "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88", tipo: "contestacao", criada_em: "2026-11-16T14:00:00Z", prazo_resposta_ate: "2026-11-23" };
const RELATO = "Relato sintético da contestação, com mais de dez letras.";

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

describe("protocolo", () => {
  it("o curto são os 8 primeiros hexadecimais, em maiúsculas (como o app)", () => {
    expect(protocoloCurto(PROTOCOLO.ocorrencia_id)).toBe("6F1C2A4E");
    expect(dataCivil("2026-11-23")).toBe("23/11/2026");
  });
});

describe("situação da conta e contestação (servidor)", () => {
  it("lê a situação; falha vira indisponível", async () => {
    const situacao = { estado: "suspensa", suspensao: { motivo: "Motivo sintético", desde: "2026-11-15T12:00:00Z", contestacao: null } };
    expect(await lerSituacaoDaConta(apiQueResponde(() => Response.json(situacao)).api)).toEqual({ estado: "ok", situacao });
    expect((await lerSituacaoDaConta(apiQueResponde(recusa(500, "x")).api)).estado).toBe("indisponivel");
  });

  it("contesta só com o relato no corpo; relato curto nem sai", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(PROTOCOLO));
    expect(await contestarSuspensao(api, `  ${RELATO} `)).toEqual({ ok: true, protocolo: PROTOCOLO });
    expect(await pedidos[0]?.json()).toEqual({ relato: RELATO });
    expect(new URL(pedidos[0]?.url ?? "").search).toBe("");
    const curto = apiQueResponde(() => Response.json(PROTOCOLO));
    expect(await contestarSuspensao(curto.api, "curto")).toEqual({ ok: false, motivo: "relato_curto" });
    expect(curto.pedidos).toHaveLength(0);
  });

  it("cada recusa do contrato tem o seu aviso; a segunda contestação é 'já contestada'", async () => {
    const casos: Array<[() => Response, string]> = [
      [recusa(409, "contestacao_ja_aberta"), "ja_contestada"],
      [recusa(422, "sem_suspensao_ativa"), "sem_suspensao"],
      [recusa(422, "campo_invalido", "relato"), "relato_curto"],
      [recusa(401, "nao_autenticado"), "sem_sessao"],
      [recusa(503, "x"), "indisponivel"],
    ];
    for (const [resposta, motivo] of casos) {
      expect(await contestarSuspensao(apiQueResponde(resposta).api, RELATO), motivo).toEqual({ ok: false, motivo });
    }
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string> | null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com" } : null);
  const url = "https://frilabr.com/app/conta/suspensa";
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: {}, url: new URL(url), matches: [] } as never;
};
const ok = (corpo: unknown) => ({ data: corpo, response: new Response(null, { status: 200 }) });
const erro = (status: number, code: string) => ({ error: { code }, response: new Response(null, { status }) });

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("tela da conta suspensa", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    await expect(carregarSituacao(argumentos(null, false))).rejects.toHaveProperty("status", 302);
    await expect(contestar(argumentos({ relato: RELATO }, false))).rejects.toHaveProperty("status", 302);
    expect(api.GET).not.toHaveBeenCalled();
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("suspensa sem contestação: motivo, data e o formulário", async () => {
    api.GET.mockResolvedValue(ok({ estado: "suspensa", suspensao: { motivo: "Motivo sintético", desde: "2026-11-15T12:00:00Z", contestacao: null } }));
    expect(await carregarSituacao(argumentos(null))).toMatchObject({
      estado: "suspensa",
      motivo: "Motivo sintético",
      desde: "15/11/2026",
      contestacao: null,
    });
  });

  it("já contestada: o protocolo curto e o prazo, sem formulário", async () => {
    api.GET.mockResolvedValue(ok({ estado: "suspensa", suspensao: { motivo: "M", desde: "2026-11-15T12:00:00Z", contestacao: PROTOCOLO } }));
    expect(await carregarSituacao(argumentos(null))).toMatchObject({ contestacao: { numero: "6F1C2A4E", enviadaEm: "16/11/2026", prazo: "23/11/2026" } });
  });

  it("conta ativa diz que está ativa", async () => {
    api.GET.mockResolvedValue(ok({ estado: "ativa", suspensao: null }));
    expect(await carregarSituacao(argumentos(null))).toMatchObject({ estado: "ativa" });
  });

  it("a action não devolve o relato; o reenvio depois de registrada vira 'já contestada'", async () => {
    api.POST.mockResolvedValueOnce(ok(PROTOCOLO));
    const enviada = await contestar(argumentos({ relato: RELATO }));
    expect(enviada).toEqual({ resultado: "enviada" });
    expect(api.POST.mock.calls[0]?.[1]).toMatchObject({ body: { relato: RELATO } });
    api.POST.mockResolvedValueOnce(erro(409, "contestacao_ja_aberta"));
    const reenvio = await contestar(argumentos({ relato: RELATO }));
    expect(reenvio).toEqual({ resultado: "ja_contestada" });
    expect(JSON.stringify([enviada, reenvio])).not.toContain("sintético");
  });
});
