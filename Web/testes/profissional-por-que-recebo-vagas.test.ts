import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as enviar, loader as carregar } from "../app/rotas/profissional/por-que-recebo-vagas";
import { criarApi } from "../app/servidor/api";
import {
  descreverJanela,
  formatarKm,
  lerCriteriosDeNotificacao,
  pedirRevisaoDoDespacho,
} from "../app/servidor/profissional/por-que-recebo-vagas";
import { textos } from "../app/textos/pt-BR";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const criterios = {
  funcoes: [{ id: "f1", nome: "Garçom", categoria: "Salão" }],
  disponibilidades: [
    { dia_semana: 5, hora_inicio: "18:00", hora_fim: "02:00" },
    { dia_semana: 0, hora_inicio: "09:00", hora_fim: "17:00" },
  ],
  distancia_maxima_km: 15,
  equipes_de_confianca: [{ estabelecimento_id: "e1", nome: "Bar do Teste" }],
  notificacoes_no_maximo_a_cada_min: 30,
  contestacao: null,
};
const protocolo = { ocorrencia_id: "6f1c2a4e-0000-4000-8000-000000000000", tipo: "revisao_despacho", criada_em: "2026-11-23T15:00:00Z", prazo_resposta_ate: "2026-11-30" };

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
const recusa = (status: number, code: string, details: string | null = null) => () =>
  Response.json({ code, message: code, details, hint: null }, { status });

describe("critérios de notificação (servidor)", () => {
  it("200: devolve os critérios, lidos por GET autenticado", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(criterios));
    expect(await lerCriteriosDeNotificacao(api)).toEqual({ estado: "ok", criterios });
    expect(pedidos[0]?.method).toBe("GET");
    expect(pedidos[0]?.url).toContain("/rpc/criterios_de_notificacao");
    expect(pedidos[0]?.headers.get("authorization")).toBe("Bearer t");
  });

  it("401, 403, 404 e falha viram estados da tela", async () => {
    expect(await lerCriteriosDeNotificacao(apiQueResponde(recusa(401, "nao_autenticado")).api)).toEqual({ estado: "sem_sessao" });
    expect(await lerCriteriosDeNotificacao(apiQueResponde(recusa(403, "conta_suspensa")).api)).toEqual({ estado: "conta_suspensa" });
    expect(await lerCriteriosDeNotificacao(apiQueResponde(recusa(404, "nao_encontrado")).api)).toEqual({ estado: "sem_perfil" });
    expect(await lerCriteriosDeNotificacao(apiQueResponde(recusa(500, "erro")).api)).toEqual({ estado: "indisponivel" });
    expect(await lerCriteriosDeNotificacao(null)).toEqual({ estado: "indisponivel" });
  });
});

describe("pedido de revisão do despacho (servidor)", () => {
  it("200: manda o relato aparado no corpo e devolve o protocolo", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(protocolo));
    expect(await pedirRevisaoDoDespacho(api, "  Esperava a vaga do bar.  ")).toEqual({ ok: true, protocolo });
    expect(pedidos[0]?.url).toContain("/rpc/pedir_revisao_despacho");
    expect(await pedidos[0]?.json()).toEqual({ relato: "Esperava a vaga do bar." });
  });

  it("relato curto nem sai; o 422 do servidor também vira relato curto", async () => {
    const curto = apiQueResponde(() => Response.json(protocolo));
    expect(await pedirRevisaoDoDespacho(curto.api, "  curto ")).toEqual({ ok: false, motivo: "relato_curto" });
    expect(curto.pedidos).toHaveLength(0);
    const recusado = apiQueResponde(recusa(422, "campo_invalido", "relato"));
    expect(await pedirRevisaoDoDespacho(recusado.api, "relato com tamanho bom")).toEqual({ ok: false, motivo: "relato_curto" });
  });

  it("401, 403, 409, 429 e falha viram motivos", async () => {
    const relato = "relato com tamanho bom";
    expect(await pedirRevisaoDoDespacho(apiQueResponde(recusa(401, "nao_autenticado")).api, relato)).toEqual({ ok: false, motivo: "sem_sessao" });
    expect(await pedirRevisaoDoDespacho(apiQueResponde(recusa(403, "conta_suspensa")).api, relato)).toEqual({ ok: false, motivo: "conta_suspensa" });
    expect(await pedirRevisaoDoDespacho(apiQueResponde(recusa(409, "contestacao_ja_aberta")).api, relato)).toEqual({ ok: false, motivo: "ja_aberta" });
    expect(await pedirRevisaoDoDespacho(apiQueResponde(recusa(429, "limite")).api, relato)).toEqual({ ok: false, motivo: "limite" });
    expect(await pedirRevisaoDoDespacho(apiQueResponde(recusa(500, "erro")).api, relato)).toEqual({ ok: false, motivo: "indisponivel" });
    expect(await pedirRevisaoDoDespacho(null, relato)).toEqual({ ok: false, motivo: "indisponivel" });
  });
});

describe("textos dos critérios", () => {
  const dias = textos.profissionalCadastro.horarios.nomesDosDias;
  const modelo = textos.profissionalCadastro.horarios;

  it("janela que atravessa a meia-noite leva o dia seguinte; a normal não", () => {
    expect(descreverJanela({ dia_semana: 5, hora_inicio: "18:00", hora_fim: "02:00" }, dias, modelo)).toBe("Sexta-feira: 18:00 até 02:00 (dia seguinte)");
    expect(descreverJanela({ dia_semana: 0, hora_inicio: "09:00", hora_fim: "17:00" }, dias, modelo)).toBe("Domingo: 09:00 até 17:00");
  });

  it("distância inteira sem casas; fração com vírgula", () => {
    expect(formatarKm(15)).toBe("15");
    expect(formatarKm(7.5)).toBe("7,5");
  });
});

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (dados: Record<string, string> | null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "p@example.com" } : null);
  const url = "https://frilabr.com/app/por-que-recebo-vagas";
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: {}, url: new URL(url), matches: [] } as never;
};

beforeEach(() => {
  api.GET.mockReset().mockResolvedValue({ data: criterios, response: new Response() });
  api.POST.mockReset().mockResolvedValue({ data: protocolo, response: new Response() });
});

describe("rota por-que-recebo-vagas", () => {
  it("sem sessão, manda entrar (loader e action)", async () => {
    await expect(carregar(argumentos(null, false))).rejects.toHaveProperty("status", 302);
    await expect(enviar(argumentos({ relato: "relato com tamanho bom" }, false))).rejects.toHaveProperty("status", 302);
  });

  it("o loader entrega as frases dos critérios da conta, sem contestação", async () => {
    expect(await carregar(argumentos(null))).toEqual({
      estado: "ok",
      criterios: {
        funcoes: ["Garçom"],
        horarios: ["Sexta-feira: 18:00 até 02:00 (dia seguinte)", "Domingo: 09:00 até 17:00"],
        distancia: "Até 15 km do seu ponto base.",
        equipes: ["Bar do Teste"],
        frequencia: "No máximo uma notificação a cada 30 minutos.",
        contestacao: null,
      },
    });
  });

  it("com contestação em andamento, mostra o protocolo curto e as datas (e a tela não oferece novo envio)", async () => {
    api.GET.mockResolvedValue({ data: { ...criterios, contestacao: protocolo }, response: new Response() });
    const dados = await carregar(argumentos(null));
    expect(dados.criterios?.contestacao).toEqual({ numero: "6F1C2A4E", enviadoEm: "23/11/2026", prazo: "30/11/2026" });
  });

  it("401 na leitura manda entrar; 404, 403 e falha viram aviso", async () => {
    api.GET.mockResolvedValue({ response: new Response(null, { status: 401 }) });
    await expect(carregar(argumentos(null))).rejects.toHaveProperty("status", 302);
    api.GET.mockResolvedValue({ response: new Response(null, { status: 404 }) });
    expect(await carregar(argumentos(null))).toEqual({ estado: "sem_perfil", criterios: null });
    api.GET.mockResolvedValue({ response: new Response(null, { status: 403 }) });
    expect(await carregar(argumentos(null))).toEqual({ estado: "conta_suspensa", criterios: null });
    api.GET.mockResolvedValue({ response: new Response(null, { status: 500 }) });
    expect(await carregar(argumentos(null))).toEqual({ estado: "indisponivel", criterios: null });
  });

  it("relato curto não chega ao servidor", async () => {
    expect(await enviar(argumentos({ relato: "curto" }))).toEqual({ resultado: "relato_curto" });
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("relato bom: envia uma vez e devolve só o resultado (o relato não volta)", async () => {
    const resposta = await enviar(argumentos({ relato: "Esperava a vaga do bar na sexta." }));
    expect(resposta).toEqual({ resultado: "enviado" });
    expect(api.POST).toHaveBeenCalledTimes(1);
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/pedir_revisao_despacho");
    expect(api.POST.mock.calls[0]?.[1].body).toEqual({ relato: "Esperava a vaga do bar na sexta." });
  });

  it("reenvio (409) vira 'já aberta' e erro vira aviso", async () => {
    api.POST.mockResolvedValue({ error: { code: "contestacao_ja_aberta" }, response: new Response(null, { status: 409 }) });
    expect(await enviar(argumentos({ relato: "relato com tamanho bom" }))).toEqual({ resultado: "ja_aberta" });
    api.POST.mockResolvedValue({ response: new Response(null, { status: 500 }) });
    expect(await enviar(argumentos({ relato: "relato com tamanho bom" }))).toEqual({ resultado: "indisponivel" });
  });
});
