/**
 * Revisão do Lince (Codex) no #886, os 2 bloqueantes de RN15 (orquestracao/retornos/WEB-V1-revisao-886.md). As
 * reproduções dele viraram o comportamento esperado: o conteúdo de um push só aparece quando o Worker, com a sessão viva
 * deste navegador, confirma que o aviso é dela. Nada depende do JavaScript da página nem de mensagem guardada no SW.
 */
import { RouterContextProvider } from "react-router";
import { beforeEach, expect, it, vi } from "vitest";
import codigoDoServiceWorker from "../public/app/sw.js?raw";
import { contextoDaSessao, contextoDoAuth } from "../app/contexto";
import { action as conferirAviso } from "../app/rotas/avisos-vinculo";
import { action as sair } from "../app/rotas/sair";
import { criarApi } from "../app/servidor/api";
const TOKEN = "fcm-token_sintetico-com-mais-de-vinte";
/** Servidor do Frila simulado: o remover cai (503, como na reprodução) e o registro devolve o vínculo da conta que chama. */
const mock = vi.hoisted(() => ({ encerrar: vi.fn(async () => ({ ok: true })), pedidos: [] as Request[], vinculoDe: {} as Record<string, string> }));
vi.mock("../app/servidor/deste-ambiente", () => ({
  authDesteAmbiente: () => ({ encerrar: mock.encerrar }),
  apiDoUsuario: (acesso: string) =>
    criarApi({ url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_sintetica" }, {
      token: acesso,
      fetch: async (entrada, inicio) => {
        const r: Request = new Request(entrada, inicio);
        mock.pedidos.push(r);
        if (new URL(r.url).pathname.endsWith("/registrar_dispositivo")) {
          return Response.json({ plataforma: "web", atualizado_em: "2026-11-17T09:00:00Z", vinculo_id: mock.vinculoDe[acesso] });
        }
        return Response.json({ erro: "indisponivel" }, { status: 503 });
      },
    }),
}));
beforeEach(() => {
  mock.pedidos.length = 0;
  mock.encerrar.mockClear();
  mock.vinculoDe = { "ACESSO-A": "v-A", "ACESSO-B": "v-B" };
});

/** O navegador: a sessão viva (ou nenhuma) e os cookies. O SW fala com o Worker de verdade (a action real). */
function navegador(estado: { acesso: string | null; cookie: string }) {
  const contexto = () => {
    const ctx = new RouterContextProvider();
    ctx.set(contextoDaSessao, (estado.acesso ? { acesso: estado.acesso, usuarioId: "u", email: null } : null) as never);
    ctx.set(contextoDoAuth, (estado.acesso ? "ok" : "sem_cookie") as never);
    return ctx;
  };
  const rede = async (pedido: Request) => {
    if (new URL(pedido.url).pathname !== "/app/avisos/vinculo") return new Response("");
    const request = new Request(pedido.url, { method: pedido.method, headers: { Origin: "https://frilabr.com", Cookie: estado.cookie, "Content-Type": "application/json" }, body: await pedido.text() });
    return (await conferirAviso({ request, context: contexto() } as never)) as Response;
  };
  return { contexto, rede };
}

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


const neutro = { titulo: "Frila", corpo: "Aviso neutro" };
const push = { data: { json: () => ({ notification: { title: "PRIVADO-CONTA-A", body: "DADO-SINTETICO-A" }, data: { vinculo_id: "v-A" } }) } };

it("saída nativa com remover 503: o Sair conclui, o cookie do aparelho some e o push de A aparece neutro", async () => {
  const estado = { acesso: "ACESSO-A" as string | null, cookie: `frila_aparelho=${TOKEN}` };
  const nav = navegador(estado);
  const sw = serviceWorker({ rede: nav.rede });
  // O que a página mandava antes (não vale mais nada para o SW).
  await sw.disparar("message", { data: { tipo: "vinculo", vinculo_id: "v-A", neutro } });
  const request = new Request("https://frilabr.com/app/sair", { method: "POST", headers: { Origin: "https://frilabr.com", Cookie: estado.cookie } });
  expect(await sw.disparar("fetch", { request })).toBeUndefined();
  let resposta: Response | undefined;
  try {
    await sair({ request, context: nav.contexto() } as never);
  } catch (e) {
    if (e instanceof Response) resposta = e;
    else throw e;
  }
  expect(resposta?.headers.get("Location")).toBe("/entrar");
  expect(resposta?.headers.getSetCookie()).toHaveLength(3);
  expect(new URL(mock.pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/remover_dispositivo");
  // O navegador aplica a resposta: sem sessão e sem o cookie do aparelho.
  estado.acesso = null;
  estado.cookie = "";
  await sw.disparar("push", push);
  expect(sw.notificacoes).toHaveLength(1);
  expect(JSON.stringify(sw.notificacoes)).not.toMatch(/PRIVADO|SINTETICO/);
});

it("o cookie do aparelho restaurado por uma resposta tardia, sem sessão viva: push de A segue neutro", async () => {
  const estado = { acesso: null as string | null, cookie: `frila_aparelho=${TOKEN}` };
  const sw = serviceWorker({ rede: navegador(estado).rede });
  await sw.disparar("message", { data: { tipo: "vinculo", vinculo_id: "v-A", neutro } });
  await sw.disparar("message", { data: { tipo: "esquecer" } });
  await sw.disparar("message", { data: { tipo: "vinculo", vinculo_id: "v-A", neutro } });
  await sw.disparar("push", push);
  expect(JSON.stringify(sw.notificacoes)).not.toMatch(/PRIVADO|SINTETICO/);
});

it("outra conta entrou no mesmo navegador: o push de A aparece neutro", async () => {
  const sw = serviceWorker({ rede: navegador({ acesso: "ACESSO-B", cookie: `frila_aparelho=${TOKEN}` }).rede });
  await sw.disparar("push", push);
  expect(JSON.stringify(sw.notificacoes)).not.toMatch(/PRIVADO|SINTETICO/);
});

it("a própria conta, com sessão viva e o aparelho registrado: o push aparece com o conteúdo", async () => {
  const sw = serviceWorker({ rede: navegador({ acesso: "ACESSO-A", cookie: `frila_aparelho=${TOKEN}` }).rede });
  await sw.disparar("push", push);
  expect(sw.notificacoes).toEqual([{ titulo: "PRIVADO-CONTA-A", corpo: "DADO-SINTETICO-A" }]);
});

it("Worker fora do ar na hora do push: neutro", async () => {
  const sw = serviceWorker({ rede: async () => Promise.reject(new TypeError("offline")) });
  await sw.disparar("push", push);
  expect(sw.notificacoes).toHaveLength(1);
  expect(JSON.stringify(sw.notificacoes)).not.toMatch(/PRIVADO|SINTETICO/);
});
