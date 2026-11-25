/**
 * B-116: o Worker assina o IP do visitante nas chamadas ao /rest/v1 com o token da pessoa (app/servidor/saida-rest.ts).
 * Sem rede: o `fetch` é de mentira e o `cloudflare:workers` é simulado. Dados sintéticos (chave, token e IPs de documentação).
 *
 * O oráculo é independente do código: os hex fixos abaixo foram calculados com `openssl` (a Forja usa o mesmo vetor no pgTAP)
 * e, de reserva, `node:crypto` calcula de novo.
 */
import { createHmac } from "node:crypto";

import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createStaticHandler, createStaticRouter, RouterContextProvider, StaticRouterProvider } from "react-router";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import Inicio, { loader as loaderDoInicio } from "../app/rotas/inicio";
import { criarApi } from "../app/servidor/api";
import { apiDoUsuario, fotoDoProfissional } from "../app/servidor/deste-ambiente";
import { registrarEvento } from "../app/servidor/eventos";
import {
  CABECALHO_ASSINATURA,
  CABECALHO_CARIMBO,
  CABECALHO_IP,
  cabecalhosDoIp,
  hmacDoIp,
} from "../app/servidor/saida-rest";
import { resolverSessao, sessaoAtualDe, type AuthDaSessao } from "../app/servidor/sessao";

const worker = vi.hoisted(() => ({ env: {} as Record<string, string>, esperas: [] as Promise<unknown>[] }));
vi.mock("cloudflare:workers", () => ({ env: worker.env, waitUntil: (espera: Promise<unknown>) => worker.esperas.push(espera) }));
vi.mock("../app/servidor/abertura", () => ({
  lerConfiguracaoDesteAmbiente: async () => ({ estado: "indisponivel" }),
  lerLinkDaAppStore: async () => null,
}));

const CHAVE = "chave-sintetica-de-teste";
const UID = "00000000-0000-4000-8000-000000000001";
const CARIMBO = 1764000000;
const IPV4 = "203.0.113.7";
const IPV6 = "2001:db8::1";
const IPV6_LONGO = "2001:0db8:0000:0000:0000:0000:0000:0001";
const VETOR = {
  [IPV4]: "92f88c71111a679549dbc95ed494f70cd334afba29f4a3671afbf2f05450f8cf",
  [IPV6]: "2b867312419c3f6da5ca307ef1309b9e5afc82aeba681ab20bc44a070057ac25",
  [IPV6_LONGO]: "bc9810ddf2fc4b945a3337c88cfedf0ef02121217b511107a390b243124be90b",
} as const;
const PRO = "5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c8d";
const URL_DO_SUPABASE = "https://exemplo.supabase.co";
const AMBIENTE = { url: URL_DO_SUPABASE, chavePublicavel: "sb_publishable_sintetica" };
const TRES = [CABECALHO_IP, CABECALHO_CARIMBO, CABECALHO_ASSINATURA];

const jwt = (campos: Record<string, unknown>) =>
  `cabecalho.${btoa(JSON.stringify(campos)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")}.assinatura`;
const acessoDe = (sub: string | null = UID) => jwt({ exp: 2_000_000_000, ...(sub === null ? {} : { sub }), email: "p@example.com" });
const sessaoDe = (visitante: string | null, acesso = acessoDe()) => sessaoAtualDe(acesso, visitante);
const assinatura = (hex: string, id = "a1") => `v1;k=${id};${hex}`;

/** Um pedido que saiu do Worker rumo ao Supabase. */
let saidas: Request[] = [];

function configurar(extra: Record<string, string> = {}) {
  for (const chave of Object.keys(worker.env)) Reflect.deleteProperty(worker.env, chave);
  Object.assign(worker.env, {
    SUPABASE_URL: URL_DO_SUPABASE,
    SUPABASE_CHAVE_PUBLICAVEL: AMBIENTE.chavePublicavel,
    IP_VISITANTE_HMAC: CHAVE,
    IP_VISITANTE_HMAC_ID: "a1",
    WEB_LIGADA: "1",
    ...extra,
  });
}

function semChave(...nomes: string[]) {
  for (const nome of nomes) Reflect.deleteProperty(worker.env, nome);
}

beforeEach(() => {
  saidas = [];
  worker.esperas.length = 0;
  configurar();
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(CARIMBO * 1000);
  vi.stubGlobal("fetch", async (entrada: RequestInfo | URL, inicio?: RequestInit) => {
    const pedido = new Request(entrada, inicio);
    saidas.push(pedido);
    const caminho = new URL(pedido.url).pathname;
    if (caminho === "/rest/v1/rpc/perfil_publico") {
      return Response.json({ id: PRO, tipo: "profissional", nome: "P", reputacao: {}, foto_url: `${URL_DO_SUPABASE}/functions/v1/ler-midia?midia_id=m1&token=${"a".repeat(64)}` });
    }
    if (caminho === "/functions/v1/ler-midia") return new Response(new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]), { headers: { "Content-Type": "image/jpeg" } });
    return Response.json({ nome: "Pessoa Sintética", perfil: "contratante", termos_versao: "2026-11-01" });
  });
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

function saida(indice: number): Request {
  const pedido = saidas[indice];
  if (!pedido) throw new Error(`a saída ${indice} não existe`);
  return pedido;
}
const cabecalhosDe = (pedido: Request) => Object.fromEntries(TRES.map((nome) => [nome, pedido.headers.get(nome)]));
const nenhum = (pedido: Request) => TRES.forEach((nome) => expect(pedido.headers.get(nome), nome).toBeNull());
const esperarEventos = () => Promise.all(worker.esperas);

describe("o vetor de teste da Forja (openssl): o HMAC é da mensagem v1|ip cru|carimbo|uid, com a chave em UTF-8", () => {
  it.each(Object.entries(VETOR))("ip %s", async (ip, esperado) => {
    expect(await hmacDoIp(CHAVE, ip, CARIMBO, UID)).toBe(esperado);
    expect(createHmac("sha256", CHAVE).update(`v1|${ip}|${CARIMBO}|${UID}`).digest("hex")).toBe(esperado);
  });

  it("o IPv6 longo e o curto são o mesmo endereço e assinam diferente: o que vale é o texto cru", async () => {
    expect(VETOR[IPV6_LONGO]).not.toBe(VETOR[IPV6]);
    expect(await hmacDoIp(CHAVE, IPV6_LONGO, CARIMBO, UID)).not.toBe(await hmacDoIp(CHAVE, IPV6, CARIMBO, UID));
  });

  it("os 3 cabeçalhos: IP cru, carimbo inteiro e `v1;k=<id>;<hex>`", async () => {
    expect(await cabecalhosDoIp({ segredo: CHAVE, id: "a1" }, IPV6_LONGO, acessoDe(), CARIMBO)).toEqual({
      [CABECALHO_IP]: IPV6_LONGO,
      [CABECALHO_CARIMBO]: "1764000000",
      [CABECALHO_ASSINATURA]: assinatura(VETOR[IPV6_LONGO]),
    });
  });

  it("o secret com quebra de linha no fim (secret put) assina igual", async () => {
    const cabecalhos = await cabecalhosDoIp({ segredo: `${CHAVE}\n`, id: "a1" }, IPV4, acessoDe(), CARIMBO);
    expect(cabecalhos?.[CABECALHO_ASSINATURA]).toBe(assinatura(VETOR[IPV4]));
  });
});

describe("a) os 3 cabeçalhos saem na chamada com o token, com o IP que o pedido trouxe", () => {
  it("apiDoUsuario(...).GET e .POST", async () => {
    const api = apiDoUsuario(sessaoDe(IPV4));
    await api?.GET("/rpc/minha_conta");
    await api?.POST("/rpc/registrar_evento", { body: { evento: "cadastro_concluido" } });
    expect(saidas).toHaveLength(2);
    for (const pedido of saidas) {
      expect(pedido.headers.get("Authorization")).toBe(`Bearer ${acessoDe()}`);
      expect(cabecalhosDe(pedido)).toEqual({
        [CABECALHO_IP]: IPV4,
        [CABECALHO_CARIMBO]: "1764000000",
        [CABECALHO_ASSINATURA]: assinatura(VETOR[IPV4]),
      });
    }
  });

  it("IPv6 curto e longo saem como chegaram (texto cru, sem normalizar)", async () => {
    for (const ip of [IPV6, IPV6_LONGO]) {
      saidas = [];
      await apiDoUsuario(sessaoDe(ip))?.GET("/rpc/minha_conta");
      expect(cabecalhosDe(saida(0))).toEqual({
        [CABECALHO_IP]: ip,
        [CABECALHO_CARIMBO]: "1764000000",
        [CABECALHO_ASSINATURA]: assinatura(VETOR[ip as keyof typeof VETOR]),
      });
    }
  });

  it("o carimbo é da hora de assinar (na saída), não da hora em que o cliente foi criado", async () => {
    const api = apiDoUsuario(sessaoDe(IPV4));
    vi.setSystemTime((CARIMBO + 30) * 1000 + 999);
    await api?.GET("/rpc/minha_conta");
    expect(saidas[0]?.headers.get(CABECALHO_CARIMBO)).toBe(String(CARIMBO + 30));
    expect(saidas[0]?.headers.get(CABECALHO_ASSINATURA)).toBe(assinatura(await hmacDoIp(CHAVE, IPV4, CARIMBO + 30, UID)));
  });

  it("o uid assinado é o sub do token que vai NAQUELA chamada (outro token, outro uid)", async () => {
    const outro = "00000000-0000-4000-8000-0000000000aa";
    await apiDoUsuario(sessaoDe(IPV4, acessoDe(outro)))?.GET("/rpc/minha_conta");
    expect(saidas[0]?.headers.get(CABECALHO_ASSINATURA)).toBe(assinatura(await hmacDoIp(CHAVE, IPV4, CARIMBO, outro)));
    expect(saidas[0]?.headers.get(CABECALHO_ASSINATURA)).not.toBe(assinatura(VETOR[IPV4]));
  });

  it("registrarEvento (depois da resposta, pelo waitUntil)", async () => {
    registrarEvento(sessaoDe(IPV4), "cadastro_concluido");
    await new Promise((r) => setTimeout(r, 0));
    await esperarEventos();
    expect(saidas).toHaveLength(1);
    expect(new URL(saida(0).url).pathname).toBe("/rest/v1/rpc/registrar_evento");
    expect(cabecalhosDe(saida(0))).toEqual({
      [CABECALHO_IP]: IPV4,
      [CABECALHO_CARIMBO]: "1764000000",
      [CABECALHO_ASSINATURA]: assinatura(VETOR[IPV4]),
    });
  });

  it("registrarEvento captura o IP e o token NA CHAMADA: dois pedidos em sequência, cada evento com o IP do seu pedido", async () => {
    const outro = "00000000-0000-4000-8000-0000000000bb";
    const primeira = sessaoDe(IPV4);
    const segunda = sessaoDe(IPV6, acessoDe(outro));
    registrarEvento(primeira, "cadastro_concluido");
    registrarEvento(segunda, "cadastro_concluido");
    // Depois da chamada, a sessão (mutável) muda: o que já saiu da rota não pode acompanhar.
    primeira.visitante = "198.51.100.99";
    segunda.visitante = null;
    await new Promise((r) => setTimeout(r, 0));
    await esperarEventos();
    expect(saidas).toHaveLength(2);
    const porIp = new Map(saidas.map((pedido) => [pedido.headers.get(CABECALHO_IP), pedido]));
    expect([...porIp.keys()].sort()).toEqual([IPV6, IPV4].sort());
    expect(porIp.get(IPV4)?.headers.get(CABECALHO_ASSINATURA)).toBe(assinatura(VETOR[IPV4]));
    expect(porIp.get(IPV6)?.headers.get(CABECALHO_ASSINATURA)).toBe(assinatura(await hmacDoIp(CHAVE, IPV6, CARIMBO, outro)));
    expect(porIp.get(IPV6)?.headers.get("Authorization")).toBe(`Bearer ${acessoDe(outro)}`);
  });

  it("fotoDoProfissional: o perfil_publico sai assinado; a miniatura (ler-midia) sai sem token e sem cabeçalho", async () => {
    const foto = await fotoDoProfissional(sessaoDe(IPV4), PRO);
    expect(foto).toMatch(/^data:image\/jpeg;base64,/);
    expect(saidas).toHaveLength(2);
    expect(new URL(saida(0).url).pathname).toBe("/rest/v1/rpc/perfil_publico");
    expect(saidas[0]?.headers.get("Authorization")).toBe(`Bearer ${acessoDe()}`);
    expect(saidas[0]?.headers.get("apikey")).toBe(AMBIENTE.chavePublicavel);
    expect(await saidas[0]?.json()).toEqual({ id: PRO });
    expect(cabecalhosDe(saida(0))).toEqual({
      [CABECALHO_IP]: IPV4,
      [CABECALHO_CARIMBO]: "1764000000",
      [CABECALHO_ASSINATURA]: assinatura(VETOR[IPV4]),
    });
    expect(new URL(saida(1).url).pathname).toBe("/functions/v1/ler-midia");
    expect(saidas[1]?.headers.get("Authorization")).toBeNull();
    nenhum(saida(1));
  });
});

describe("c) nenhum cabeçalho (nem um dos 3) quando falta um requisito, e a chamada sai normalmente", () => {
  const casos: Array<[string, () => void, string | null, string?]> = [
    ["sem secret", () => semChave("IP_VISITANTE_HMAC"), IPV4],
    ["secret vazio", () => configurar({ IP_VISITANTE_HMAC: "" }), IPV4],
    ["secret só com quebra de linha", () => configurar({ IP_VISITANTE_HMAC: "\n" }), IPV4],
    ["sem id", () => semChave("IP_VISITANTE_HMAC_ID"), IPV4],
    ["id vazio", () => configurar({ IP_VISITANTE_HMAC_ID: "" }), IPV4],
    ["id com maiúscula (A1)", () => configurar({ IP_VISITANTE_HMAC_ID: "A1" }), IPV4],
    ["id com hífen (a-1)", () => configurar({ IP_VISITANTE_HMAC_ID: "a-1" }), IPV4],
    ["id com 17 caracteres", () => configurar({ IP_VISITANTE_HMAC_ID: "a".repeat(17) }), IPV4],
    ["sem CF-Connecting-IP", () => undefined, null],
    ["CF-Connecting-IP vazio", () => undefined, ""],
    ["token sem sub", () => undefined, IPV4, acessoDe(null)],
    ["sub que não é UUID", () => undefined, IPV4, acessoDe("usuario-1")],
    ["token ilegível", () => undefined, IPV4, "lixo"],
  ];

  it.each(casos)("%s", async (_nome, preparar, visitante, acesso) => {
    preparar();
    const sessao = sessaoDe(visitante, acesso);
    await apiDoUsuario(sessao)?.GET("/rpc/minha_conta");
    registrarEvento(sessao, "cadastro_concluido");
    await new Promise((r) => setTimeout(r, 0));
    await esperarEventos();
    await fotoDoProfissional(sessao, PRO);
    // minha_conta + registrar_evento + perfil_publico + ler-midia: todas saíram.
    expect(saidas).toHaveLength(4);
    for (const pedido of saidas) nenhum(pedido);
    for (const pedido of saidas.slice(0, 3)) expect(pedido.headers.get("Authorization")).toBe(`Bearer ${sessao.acesso}`);
  });

  it("erro na assinatura (crypto) = sai sem cabeçalho e não derruba a chamada", async () => {
    const falha = vi.spyOn(crypto.subtle, "importKey").mockRejectedValue(new Error("sintético"));
    try {
      const { response } = (await apiDoUsuario(sessaoDe(IPV4))?.GET("/rpc/minha_conta")) ?? {};
      expect(response?.status).toBe(200);
      expect(saidas).toHaveLength(1);
      nenhum(saida(0));
    } finally {
      falha.mockRestore();
    }
  });
});

describe("d) o criarApi sem token nunca manda os cabeçalhos", () => {
  it("chamada pública (chave publicável) sai limpa, mesmo com secret e IP no Worker", async () => {
    const api = criarApi(AMBIENTE);
    await api.GET("/rpc/minha_conta");
    expect(saidas).toHaveLength(1);
    expect(saidas[0]?.headers.get("Authorization")).toBe(`Bearer ${AMBIENTE.chavePublicavel}`);
    nenhum(saida(0));
  });
});

describe("a sessão leva o IP do pedido (CF-Connecting-IP), cru, para a saída assinar", () => {
  const auth: AuthDaSessao = {
    conferir: async () => ({ ok: true }),
    renovar: async () => ({ ok: true, sessao: { access_token: acessoDe(), refresh_token: "r2", token_type: "bearer", expires_in: 3600 } }),
  };
  const pedido = (cookies: string, ip?: string) =>
    new Request("https://frilabr.com/app/", { headers: { Cookie: cookies, ...(ip === undefined ? {} : { "CF-Connecting-IP": ip }) } });
  const agora = 1_800_000_000;
  const vivo = jwt({ exp: agora + 600, sub: UID });

  it("token em dia: o texto cru do cabeçalho, sem normalizar", async () => {
    for (const ip of [IPV4, IPV6, IPV6_LONGO]) {
      const { sessao } = await resolverSessao(pedido(`__Host-frila-acesso=${vivo}`, ip), auth, agora);
      expect(sessao?.visitante).toBe(ip);
    }
  });

  it("sem o cabeçalho, ou vazio: null", async () => {
    expect((await resolverSessao(pedido(`__Host-frila-acesso=${vivo}`), auth, agora)).sessao?.visitante).toBeNull();
    expect((await resolverSessao(pedido(`__Host-frila-acesso=${vivo}`, ""), auth, agora)).sessao?.visitante).toBeNull();
  });

  it("token renovado no pedido: o IP também vai", async () => {
    const { sessao } = await resolverSessao(pedido("__Host-frila-renovacao=r1", IPV4), auth, agora);
    expect(sessao?.visitante).toBe(IPV4);
  });
});

describe("e) NUNCA no navegador: nem os cabeçalhos nem o IP aparecem no que o loader devolve ou na resposta", () => {
  it("o loader do início (chama a API com o token) devolve só o que a tela mostra", async () => {
    const context = new RouterContextProvider();
    context.set(contextoDaSessao, sessaoDe(IPV4));
    const request = new Request("https://frilabr.com/app/", { headers: { "CF-Connecting-IP": IPV4 } });
    const dados = await loaderDoInicio({ request, context, params: {}, url: new URL(request.url), matches: [] } as never);
    // A API foi chamada com o IP assinado...
    expect(saidas.map((p) => p.headers.get(CABECALHO_IP))).toContain(IPV4);
    // ...e nada disso volta ao navegador.
    const texto = JSON.stringify(dados);
    for (const proibido of [IPV4, VETOR[IPV4], "x-frila-ip", "visitante", acessoDe()]) expect(texto, proibido).not.toContain(proibido);

    const handler = createStaticHandler([{ id: "inicio", path: "/", loader: () => dados, Component: () => createElement(Inicio, { loaderData: dados } as never) }]);
    const contexto = await handler.query(new Request("https://frilabr.com/"));
    if (contexto instanceof Response) throw contexto;
    const router = createStaticRouter(handler.dataRoutes, contexto);
    const pagina = renderToStaticMarkup(createElement(StaticRouterProvider, { router, context: contexto, hydrate: false }));
    for (const proibido of [IPV4, VETOR[IPV4], "x-frila-ip"]) expect(pagina, proibido).not.toContain(proibido);
    const cabecalhosDaResposta = [...Object.values(contexto.loaderHeaders ?? {}), ...Object.values(contexto.actionHeaders ?? {})].flatMap((h) => [...h.entries()]);
    expect(JSON.stringify(cabecalhosDaResposta).toLowerCase()).not.toContain("x-frila-ip");
    expect(JSON.stringify(cabecalhosDaResposta)).not.toContain(IPV4);
  });
});
