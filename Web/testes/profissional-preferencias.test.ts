import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as salvar, loader as carregar } from "../app/rotas/profissional/preferencias";
import { criarApi } from "../app/servidor/api";
import { salvarPreferencias, VERSAO_DO_TEXTO_DA_BUSCA } from "../app/servidor/profissional/preferencias";
import { textos } from "../app/textos/pt-BR";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };

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
const em = { aceita_de_quem_ja_trabalhou: true, antecedencia_minima_h: 6, aceita_de: "todos" };

describe("texto 'busca-1' (decisão da Bússola): as 2 frases exatas do iOS e a versão", () => {
  it("título, explicação e versão", () => {
    expect(textos.profissional.preferencias.aceitoChamadas).toBe("Aceito chamadas diretas");
    expect(textos.profissional.preferencias.aceitoChamadasExplicacao).toBe("Quem contrata pode te achar na busca e te chamar direto, sem publicar uma vaga.");
    expect(VERSAO_DO_TEXTO_DA_BUSCA).toBe("busca-1");
  });
});

describe("preferências (servidor)", () => {
  it("ligar manda aceita_chamadas com a versão do texto", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(em));
    expect(await salvarPreferencias(api, { aceitaDeQuemJaTrabalhou: true, antecedenciaMinimaH: 24, pausadoAte: null, aceitaChamadas: true })).toEqual({ ok: true });
    expect(await pedidos[0]?.json()).toEqual({ aceita_de_quem_ja_trabalhou: true, antecedencia_minima_h: 24, pausado_ate: null, aceita_chamadas: true, versao_texto_busca: "busca-1" });
  });

  it("desligar não manda versão; sem mexer na chave, nem a chave vai", async () => {
    const desligar = apiQueResponde(() => Response.json(em));
    await salvarPreferencias(desligar.api, { aceitaDeQuemJaTrabalhou: false, antecedenciaMinimaH: 6, pausadoAte: "2026-11-30", aceitaChamadas: false });
    expect(await desligar.pedidos[0]?.json()).toEqual({ aceita_de_quem_ja_trabalhou: false, antecedencia_minima_h: 6, pausado_ate: "2026-11-30", aceita_chamadas: false });
    const intacta = apiQueResponde(() => Response.json(em));
    await salvarPreferencias(intacta.api, { aceitaDeQuemJaTrabalhou: true, antecedenciaMinimaH: 6, pausadoAte: null, aceitaChamadas: null });
    expect(Object.keys((await intacta.pedidos[0]?.json()) as object).sort()).toEqual(["aceita_de_quem_ja_trabalhou", "antecedencia_minima_h", "pausado_ate"]);
  });

  it("pausa no passado e recurso desligado viram aviso", async () => {
    const passado = apiQueResponde(() => Response.json({ code: "campo_invalido", message: "x", details: "pausado_ate" }, { status: 422 }));
    expect(await salvarPreferencias(passado.api, { aceitaDeQuemJaTrabalhou: true, antecedenciaMinimaH: 6, pausadoAte: "2020-01-01", aceitaChamadas: null })).toEqual({ ok: false, motivo: "pausa_no_passado" });
    const desligado = apiQueResponde(() => Response.json({ code: "sem_permissao", message: "x", details: "recurso_desligado" }, { status: 403 }));
    expect(await salvarPreferencias(desligado.api, { aceitaDeQuemJaTrabalhou: true, antecedenciaMinimaH: 6, pausadoAte: null, aceitaChamadas: null })).toEqual({ ok: false, motivo: "recurso_desligado" });
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string> | null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com" } : null);
  const url = "https://frilabr.com/app/preferencias";
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: {}, url: new URL(url), matches: [] } as never;
};

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset().mockResolvedValue({ data: em, response: new Response() });
});

describe("tela de preferências", () => {
  it("sem sessão, manda entrar", async () => {
    await expect(carregar(argumentos(null, false))).rejects.toHaveProperty("status", 302);
    await expect(salvar(argumentos({ antecedencia: "6" }, false))).rejects.toHaveProperty("status", 302);
  });

  it("sem preferência gravada, valem os padrões do contrato", async () => {
    api.GET.mockResolvedValue({ data: { funcoes: [], reputacao: {}, regioes: [], atende_todo_df: true, cursos: [], idiomas: [], servicos: [] }, response: new Response() });
    expect((await carregar(argumentos(null))).preferencias).toEqual({ aceitaChamadas: false, deQuemJaTrabalhou: true, antecedencia: 6, pausadoAte: null });
  });

  it("só manda a chave quando ela mudou; ligar leva a versão", async () => {
    await salvar(argumentos({ aceita_chamadas_antes: "nao", aceita_chamadas: "sim", de_quem_ja_trabalhou: "sim", antecedencia: "48" }));
    expect(api.POST.mock.calls[0]?.[1].body).toMatchObject({ aceita_chamadas: true, versao_texto_busca: "busca-1", antecedencia_minima_h: 48 });
    await salvar(argumentos({ aceita_chamadas_antes: "sim", aceita_chamadas: "sim", antecedencia: "999" }));
    expect(api.POST.mock.calls[1]?.[1].body).toEqual({ aceita_de_quem_ja_trabalhou: false, antecedencia_minima_h: 6, pausado_ate: null });
  });
});
