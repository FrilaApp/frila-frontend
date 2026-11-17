import { describe, expect, it } from "vitest";

import codigoDoServiceWorker from "../public/app/sw.js?raw";
import { lerPlataforma, linkParaONavegador } from "~/pwa/plataforma";
import { respostaAntesDoApp } from "~/servidor/porteiro";
import { paginaSemConexao } from "~/servidor/sem-conexao";
import { textos } from "~/textos/pt-BR";

const IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1";
const IPAD_COMO_MAC = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15";
const ANDROID = "Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36";
const INSTAGRAM_ANDROID = `${ANDROID} Instagram 400.0.0.0.0 Android`;
const FACEBOOK_IPHONE = `${IPHONE} [FBAN/FBIOS;FBAV/500.0.0]`;

describe("onde a web está aberta", () => {
  const nada = { instalada: false, toque: false };

  it("reconhece o navegador de dentro de rede social, no iPhone e no Android", () => {
    expect(lerPlataforma(INSTAGRAM_ANDROID, nada)).toBe("embutido");
    expect(lerPlataforma(FACEBOOK_IPHONE, { instalada: false, toque: true })).toBe("embutido");
  });

  it("separa o iPhone (guia do Compartilhar), inclusive o iPad que se anuncia como Mac", () => {
    expect(lerPlataforma(IPHONE, { instalada: false, toque: true })).toBe("iphone");
    expect(lerPlataforma(IPAD_COMO_MAC, { instalada: false, toque: true })).toBe("iphone");
    expect(lerPlataforma(IPAD_COMO_MAC, nada)).toBe("outro");
    expect(lerPlataforma(ANDROID, nada)).toBe("outro");
  });

  it("já instalada vale mais que o resto", () => {
    expect(lerPlataforma(IPHONE, { instalada: true, toque: true })).toBe("instalada");
  });

  it("no Android, o link abre a mesma página no navegador padrão", () => {
    expect(linkParaONavegador("https://frilabr.com/app/v/abc?x=1")).toBe("intent://frilabr.com/app/v/abc?x=1#Intent;scheme=https;end");
  });
});

describe("página sem conexão", () => {
  it("se basta: texto do catálogo, sem script, e o estilo embutido liberado pelo hash da CSP", async () => {
    const resposta = await paginaSemConexao();
    const html = await resposta.text();
    expect(resposta.status).toBe(200);
    expect(html).toContain(textos.pwa.semConexao.corpo);
    expect(html).toContain('<a href="/app/">');
    expect(html).not.toMatch(/<script|<link|\ssrc=/);
    const estilo = /<style>([^<]*)<\/style>/.exec(html)?.[1] ?? "";
    const hash = btoa(String.fromCharCode(...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(estilo)))));
    const csp = resposta.headers.get("Content-Security-Policy") ?? "";
    expect(csp).toContain(`style-src 'sha256-${hash}'`);
    expect(csp).toContain("default-src 'none'");
    expect(csp).not.toContain("unsafe-inline");
  });

  it("fica aberta com a chave desligada (o service worker a guarda); a tela de instalar, não", () => {
    expect(respostaAntesDoApp(new Request("https://frilabr.com/app/sem-conexao"), { webLigada: false })).toBeNull();
    expect(respostaAntesDoApp(new Request("https://frilabr.com/app/instalar"), { webLigada: false })?.status).toBe(302);
  });
});

/** Roda o `public/app/sw.js` num contexto falso, com caches e rede de mentira. */
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

const navegar = (caminho: string) => ({ url: `https://frilabr.com${caminho}`, mode: "navigate", method: "GET" });

describe("service worker", () => {
  const paginaDaRede = async () => new Response("página com sessão");

  it("ao instalar, guarda só a página sem conexão e o texto neutro do push", async () => {
    const sw = serviceWorker({ rede: async () => new Response("sem conexão") });
    await sw.disparar("install");
    expect([...sw.guardados.keys()]).toEqual(["frila-casca-v2"]);
    expect([...(sw.guardados.get("frila-casca-v2")?.keys() ?? [])]).toEqual(["/app/sem-conexao", "/app/avisos/texto-neutro"]);
  });

  it("com rede, a navegação vem da rede e nada se guarda", async () => {
    const sw = serviceWorker({ rede: paginaDaRede });
    await sw.disparar("install");
    const resposta = await sw.disparar("fetch", { request: navegar("/app/turnos"), preloadResponse: Promise.resolve(undefined) });
    expect(await resposta?.text()).toBe("página com sessão");
    expect([...(sw.guardados.get("frila-casca-v2")?.keys() ?? [])]).toEqual(["/app/sem-conexao", "/app/avisos/texto-neutro"]);
  });

  it("sem rede, a navegação mostra a página guardada", async () => {
    let online = true;
    const sw = serviceWorker({ rede: async () => (online ? new Response("sem conexão") : Promise.reject(new TypeError("offline"))) });
    await sw.disparar("install");
    online = false;
    const resposta = await sw.disparar("fetch", { request: navegar("/app/turnos"), preloadResponse: Promise.resolve(undefined) });
    expect(await resposta?.text()).toBe("sem conexão");
  });

  it("não se mete em pedido que não é navegação (dados, envio, arquivos)", async () => {
    const sw = serviceWorker({ rede: paginaDaRede });
    expect(await sw.disparar("fetch", { request: { url: "https://frilabr.com/app/turnos.data", mode: "cors", method: "GET" } })).toBeUndefined();
    expect(await sw.disparar("fetch", { request: { url: "https://frilabr.com/app/entrar", mode: "navigate", method: "POST" } })).toBeUndefined();
  });

  it("ao ativar, apaga só os caches antigos do Frila, nunca os do site", async () => {
    const sw = serviceWorker({ rede: paginaDaRede, caches: ["frila-casca-v1", "cache-do-site", "frila-aviso-v1", "frila-casca-v2"] });
    await sw.disparar("activate");
    expect([...sw.guardados.keys()].sort()).toEqual(["cache-do-site", "frila-casca-v2"]);
  });
});

// Push (decisão do O2, 17/11): sempre o texto neutro; o conteúdo do aviso nunca aparece. Casos de conta e de sair estão
// em testes/revisao-lince-886.test.ts.
describe("service worker: push", () => {
  const ID = "0f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7e6f";
  const aviso = (dados: Record<string, string>) => ({
    data: { json: () => ({ notification: { title: "PRIVADO", body: "DADO-DO-AVISO" }, data: dados }) },
  });
  const instalado = async (abertas: Array<{ url: string; focus: () => Promise<void>; navigate?: (u: string) => Promise<void> }> = []) => {
    const sw = serviceWorker({ rede: async () => Response.json({ titulo: "Nova notificação do Frila", corpo: "Abra o aplicativo para conferir." }), janelas: abertas });
    await sw.disparar("install");
    sw.pedidosDaRede.length = 0;
    return sw;
  };

  it("o sw.js nunca lê o título nem o corpo do push", () => {
    expect(codigoDoServiceWorker).not.toMatch(/\.(title|body)\b/);
    expect(codigoDoServiceWorker).not.toMatch(/notification\s*\?\?|carga\.notification/);
  });

  it("todo push mostra o texto neutro guardado na instalação, sem ir à rede", async () => {
    const sw = await instalado();
    await sw.disparar("push", aviso({ tipo: "vaga", vaga_id: ID }));
    expect(sw.notificacoes).toEqual([{ titulo: "Nova notificação do Frila", corpo: "Abra o aplicativo para conferir." }]);
    expect(sw.pedidosDaRede).toEqual([]);
  });

  it("sem o texto guardado, só o nome do Frila", async () => {
    const sw = serviceWorker({ rede: async () => new Response("") });
    await sw.disparar("push", aviso({}));
    expect(sw.notificacoes).toEqual([{ titulo: "Frila", corpo: "" }]);
  });
});

describe("service worker: o toque no aviso", () => {
  const ID = "0f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7e6f";
  const tocar = async (dados: Record<string, string>) => {
    const abertas: string[] = [];
    const ouvintes = new Map<string, (evento: unknown) => void>();
    let mostrada: { data?: { destino?: string } } = {};
    const self = {
      addEventListener: (tipo: string, ouvinte: (evento: unknown) => void) => ouvintes.set(tipo, ouvinte),
      clients: { matchAll: async () => [], openWindow: async (u: string) => void abertas.push(u) },
      registration: { showNotification: async (_t: string, opcoes: { data?: { destino?: string } }) => void (mostrada = opcoes) },
    };
    const cachesFalsos = { match: async () => undefined, open: async () => ({}), keys: async () => [] };
    new Function("self", "caches", "fetch", "Request", "Response", codigoDoServiceWorker)(self, cachesFalsos, fetch, Request, Response);
    const esperas: Promise<unknown>[] = [];
    const evento = (extra: object) => ({ ...extra, waitUntil: (p: Promise<unknown>) => esperas.push(p) });
    ouvintes.get("push")?.(evento({ data: { json: () => ({ data: dados }) } }));
    await Promise.all(esperas.splice(0));
    ouvintes.get("notificationclick")?.(evento({ notification: { close: () => undefined, data: mostrada.data } }));
    await Promise.all(esperas);
    return abertas[0];
  };

  it("abre a página do aviso (que exige sessão), só com id no formato certo", async () => {
    expect(await tocar({ tipo: "chamada_direta", chamada_id: ID })).toBe(`/app/chamadas/${ID}`);
    expect(await tocar({ tipo: "vaga", vaga_id: ID })).toBe(`/app/vagas/${ID}`);
    expect(await tocar({ tipo: "lembrete_3h", turno_id: ID })).toBe(`/app/turnos/${ID}`);
    expect(await tocar({ tipo: "vaga", vaga_id: "../../sair" })).toBe("/app/");
    expect(await tocar({ tipo: "suspensao" })).toBe("/app/");
  });

  it("com o Frila já aberto, leva a janela até a página do aviso", async () => {
    let foi = "";
    let focou = false;
    const sw = serviceWorker({
      rede: async () => new Response(""),
      janelas: [{ url: "https://frilabr.com/app/turnos", focus: async () => void (focou = true), navigate: async (u: string) => void (foi = u) } as never],
    });
    await sw.disparar("notificationclick", { notification: { close: () => undefined, data: { destino: `/app/vagas/${ID}` } } });
    expect(focou).toBe(true);
    expect(foi).toBe(`/app/vagas/${ID}`);
    expect(sw.abertas).toEqual([]);
  });
});
