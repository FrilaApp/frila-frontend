/**
 * Revisões do Lince (Codex) no #886 (orquestracao/retornos/WEB-V1-revisao-886.md e WEB-V1-revisao-886-delta.md) e a
 * decisão do O2 de 17/11 (opção A): na web v1, todo push mostra só o texto neutro, e o conteúdo aparece ao abrir o Frila
 * com a sessão. Os cenários dele viram o comportamento esperado: sem conferência no servidor, sem registro implícito,
 * sem pedido em voo que valha depois do Sair.
 */
import { RouterContextProvider } from "react-router";
import { beforeEach, expect, it, vi } from "vitest";
import codigoDoServiceWorker from "../public/app/sw.js?raw";
import { contextoDaSessao, contextoDoAuth } from "../app/contexto";
import { action as sair } from "../app/rotas/sair";
import { criarApi } from "../app/servidor/api";
const TOKEN = "fcm-token_sintetico-com-mais-de-vinte";
/** Servidor do Frila simulado: o remover cai (503, como na reprodução dele); qualquer pedido fica anotado. */
const mock = vi.hoisted(() => ({ encerrar: vi.fn(async () => ({ ok: true })), pedidos: [] as Request[] }));
vi.mock("../app/servidor/deste-ambiente", () => ({
  authDesteAmbiente: () => ({ encerrar: mock.encerrar }),
  apiDoUsuario: (acesso: string) =>
    criarApi({ url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_sintetica" }, {
      token: acesso,
      fetch: async (entrada, inicio) => {
        mock.pedidos.push(new Request(entrada, inicio));
        return Response.json({ erro: "indisponivel" }, { status: 503 });
      },
    }),
}));
beforeEach(() => {
  mock.pedidos.length = 0;
  mock.encerrar.mockClear();
});

function serviceWorker(opcoes: {
  rede: (pedido: Request) => Promise<Response>;
  caches?: string[];
  janelas?: Array<{ url: string; focus: () => Promise<void> }>;
}) {
  const ouvintes = new Map<string, (evento: unknown) => void>();
  const guardados = new Map<string, Map<string, Response>>((opcoes.caches ?? []).map((nome) => [nome, new Map()]));
  const pedidosDaRede: string[] = [];
  const notificacoes: Array<{ titulo: string; corpo: string }> = [];
  const abertas: string[] = [];
  const caches = {
    open: async (nome: string) => {
      const cache = guardados.get(nome) ?? new Map<string, Response>();
      guardados.set(nome, cache);
      return {
        add: async (pedido: Request) => {
          pedidosDaRede.push(pedido.url);
          cache.set(new URL(pedido.url).pathname, await opcoes.rede(pedido));
        },
        addAll: async (pedidos: Request[]) => {
          for (const pedido of pedidos) {
            pedidosDaRede.push(pedido.url);
            cache.set(new URL(pedido.url).pathname, await opcoes.rede(pedido));
          }
        },
        put: async (caminho: string, resposta: Response) => void cache.set(caminho, resposta),
        match: async (caminho: string) => cache.get(caminho)?.clone(),
      };
    },
    keys: async () => [...guardados.keys()],
    delete: async (nome: string) => guardados.delete(nome),
    match: async (caminho: string) => [...guardados.values()].find((cache) => cache.has(caminho))?.get(caminho)?.clone(),
  };
  const self = {
    addEventListener: (tipo: string, ouvinte: (evento: unknown) => void) => ouvintes.set(tipo, ouvinte),
    skipWaiting: async () => undefined,
    clients: {
      claim: async () => undefined,
      matchAll: async () => opcoes.janelas ?? [],
      openWindow: async (endereco: string) => void abertas.push(endereco),
    },
    registration: {
      navigationPreload: { enable: async () => undefined },
      showNotification: async (titulo: string, detalhe: { body: string }) => void notificacoes.push({ titulo, corpo: detalhe.body }),
    },
  };
  const BaseRequest = Request;
  // No service worker, caminho relativo resolve pelo endereço do próprio arquivo.
  const RequestDoSw = class extends BaseRequest {
    constructor(entrada: string, init?: RequestInit) {
      super(new URL(entrada, "https://frilabr.com/app/sw.js"), init);
    }
  };
  const rede = async (pedido: Request) => {
    pedidosDaRede.push(pedido.url);
    return opcoes.rede(pedido);
  };
  // O código roda com estes nomes no lugar dos globais do service worker.
  new Function("self", "caches", "fetch", "Request", "Response", codigoDoServiceWorker)(self, caches, rede, RequestDoSw, Response);

  async function disparar(tipo: string, extra: Record<string, unknown> = {}) {
    const esperas: Promise<unknown>[] = [];
    let resposta: Promise<Response> | undefined;
    ouvintes.get(tipo)?.({ ...extra, waitUntil: (p: Promise<unknown>) => esperas.push(p), respondWith: (p: Promise<Response>) => (resposta = p) });
    await Promise.all(esperas);
    return resposta ? await resposta : undefined;
  }
  return { disparar, guardados, pedidosDaRede, notificacoes, abertas };
}


const NEUTRO = { titulo: "Nova notificação do Frila", corpo: "Abra o aplicativo para conferir." };
const pushDe = (conta: "A" | "B") => ({
  data: { json: () => ({ notification: { title: `PRIVADO-CONTA-${conta}`, body: `DADO-SINTETICO-${conta}` }, data: { tipo: "vaga", vinculo_id: `v-${conta}` } }) },
});
async function swInstalado() {
  const sw = serviceWorker({ rede: async (pedido) => (pedido.url.endsWith("/app/avisos/texto-neutro") ? Response.json(NEUTRO) : new Response("")) });
  await sw.disparar("install");
  sw.pedidosDaRede.length = 0;
  return sw;
}
function contexto(acesso: string | null) {
  const ctx = new RouterContextProvider();
  ctx.set(contextoDaSessao, (acesso ? { acesso, usuarioId: "u", email: null } : null) as never);
  ctx.set(contextoDoAuth, (acesso ? "ok" : "sem_cookie") as never);
  return ctx;
}

it("Sair nativo com remover 503: o Sair falha (achado A4 do Juiz), e o push de A segue neutro", async () => {
  const sw = await swInstalado();
  // Mensagens antigas da página não valem nada para o SW.
  await sw.disparar("message", { data: { tipo: "vinculo", vinculo_id: "v-A", neutro: { titulo: "x", corpo: "y" } } });
  const request = new Request("https://frilabr.com/app/sair", { method: "POST", headers: { Origin: "https://frilabr.com", Cookie: `frila_aparelho=${TOKEN}` } });
  expect(await sw.disparar("fetch", { request })).toBeUndefined();
  let resposta: Response | undefined;
  try {
    await sair({ request, context: contexto("ACESSO-A") } as never);
  } catch (e) {
    if (e instanceof Response) resposta = e;
    else throw e;
  }
  expect(resposta?.headers.get("Location")).toBe("/?sair=falhou");
  expect(resposta?.headers.getSetCookie()).toEqual([]);
  expect(mock.encerrar).not.toHaveBeenCalled();
  expect(new URL(mock.pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/remover_dispositivo");
  await sw.disparar("push", pushDe("A"));
  expect(sw.notificacoes).toEqual([NEUTRO]);
});

it("push para A com B logada no mesmo navegador: texto neutro, sem conteúdo, e o aparelho não muda de dono", async () => {
  const sw = await swInstalado();
  mock.pedidos.length = 0;
  await sw.disparar("push", pushDe("A"));
  await sw.disparar("push", pushDe("B"));
  expect(sw.notificacoes).toEqual([NEUTRO, NEUTRO]);
  expect(JSON.stringify(sw.notificacoes)).not.toMatch(/PRIVADO|SINTETICO/);
  // Nenhum registrar_dispositivo implícito: o push não fala com o servidor.
  expect(mock.pedidos).toHaveLength(0);
});

it("nenhum pedido em voo: o push não vai à rede, então nada atrasado vale depois do Sair", async () => {
  const sw = await swInstalado();
  await sw.disparar("push", pushDe("A"));
  expect(sw.pedidosDaRede).toEqual([]);
  expect(codigoDoServiceWorker).not.toContain("/app/avisos/vinculo");
});
