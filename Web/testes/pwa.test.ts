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

  it("ao instalar, guarda só a página sem conexão", async () => {
    const sw = serviceWorker({ rede: async () => new Response("sem conexão") });
    await sw.disparar("install");
    expect([...sw.guardados.keys()]).toEqual(["frila-casca-v1"]);
    expect([...(sw.guardados.get("frila-casca-v1")?.keys() ?? [])]).toEqual(["/app/sem-conexao"]);
  });

  it("com rede, a navegação vem da rede e nada se guarda", async () => {
    const sw = serviceWorker({ rede: paginaDaRede });
    await sw.disparar("install");
    const resposta = await sw.disparar("fetch", { request: navegar("/app/turnos"), preloadResponse: Promise.resolve(undefined) });
    expect(await resposta?.text()).toBe("página com sessão");
    expect([...(sw.guardados.get("frila-casca-v1")?.keys() ?? [])]).toEqual(["/app/sem-conexao"]);
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
    const sw = serviceWorker({ rede: paginaDaRede, caches: ["frila-casca-v0", "cache-do-site", "frila-casca-v1"] });
    await sw.disparar("activate");
    expect([...sw.guardados.keys()].sort()).toEqual(["cache-do-site", "frila-casca-v1"]);
  });
});

describe("service worker: push", () => {
  const neutro = { titulo: textos.pwa.avisos.neutroTitulo, corpo: textos.pwa.avisos.neutroCorpo };
  const aviso = (vinculo: string | null) => ({
    data: { json: () => ({ notification: { title: "Turno amanhã", body: "Bar do Zé, 19h" }, data: { tipo: "turno", vinculo_id: vinculo } }) },
  });
  const comVinculo = async (vinculo: string | null) => {
    const sw = serviceWorker({ rede: async () => new Response("") });
    await sw.disparar("message", { data: { tipo: "vinculo", vinculo_id: vinculo, neutro } });
    return sw;
  };

  it("aviso da conta que ligou os avisos aparece com o conteúdo", async () => {
    const sw = await comVinculo("v-1");
    await sw.disparar("push", aviso("v-1"));
    expect(sw.notificacoes).toEqual([{ titulo: "Turno amanhã", corpo: "Bar do Zé, 19h" }]);
  });

  it("aviso de outra conta aparece neutro (RN15)", async () => {
    const sw = await comVinculo("v-1");
    await sw.disparar("push", aviso("v-2"));
    await sw.disparar("push", aviso(null));
    expect(sw.notificacoes).toEqual([
      { titulo: neutro.titulo, corpo: neutro.corpo },
      { titulo: neutro.titulo, corpo: neutro.corpo },
    ]);
  });

  it("depois do sair, até o aviso do vínculo antigo aparece neutro", async () => {
    const sw = await comVinculo("v-1");
    await sw.disparar("message", { data: { tipo: "esquecer" } });
    await sw.disparar("push", aviso("v-1"));
    expect(sw.notificacoes).toEqual([{ titulo: neutro.titulo, corpo: neutro.corpo }]);
  });

  it("sem nada guardado (avisos nunca ligados aqui), não mostra conteúdo", async () => {
    const sw = serviceWorker({ rede: async () => new Response("") });
    await sw.disparar("push", aviso("v-1"));
    expect(sw.notificacoes[0]?.corpo).not.toContain("Bar do Zé");
  });

  it("servidor sem vínculo na resposta: sem conferência, como diz o contrato", async () => {
    const sw = await comVinculo(null);
    await sw.disparar("push", aviso(null));
    expect(sw.notificacoes).toEqual([{ titulo: "Turno amanhã", corpo: "Bar do Zé, 19h" }]);
  });

  it("tocar no aviso abre o Frila, ou volta para a janela já aberta", async () => {
    const fechar = { close: () => undefined };
    const sw = serviceWorker({ rede: async () => new Response("") });
    await sw.disparar("notificationclick", { notification: fechar });
    expect(sw.abertas).toEqual(["/app/"]);

    let focou = false;
    const comJanela = serviceWorker({ rede: async () => new Response(""), janelas: [{ url: "https://frilabr.com/app/turnos", focus: async () => void (focou = true) }] });
    await comJanela.disparar("notificationclick", { notification: fechar });
    expect(focou).toBe(true);
    expect(comJanela.abertas).toEqual([]);
  });
});
