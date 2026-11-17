import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao, contextoDoAuth } from "../app/contexto";
import { estadoDosAvisos } from "../app/pwa/avisos";
import { action as avisos } from "../app/rotas/avisos";
import { action as sair } from "../app/rotas/sair";
import { criarApi } from "../app/servidor/api";
import { cookieDoAparelho, lerConfigDoPush, lerTokenDoAparelho, registrarAparelho, tokenValido } from "../app/servidor/push";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const TOKEN = "fcm-token_de:teste-com-mais-de-vinte";

/** API e Auth simulados: guardam os pedidos e respondem o que o teste mandar. */
const simulado = vi.hoisted(() => ({
  pedidos: [] as Request[],
  responder: (() => Response.json({})) as (pedido: Request) => Response,
  encerrar: async () => ({ ok: true }),
}));
vi.mock("cloudflare:workers", () => ({ env: {} }));
vi.mock("../app/servidor/deste-ambiente", () => ({
  apiDoUsuario: () =>
    criarApi(ambiente, {
      token: "t",
      fetch: async (entrada, inicio) => {
        const pedido: Request = new Request(entrada, inicio);
        simulado.pedidos.push(pedido.clone() as Request);
        return simulado.responder(pedido);
      },
    }),
  authDesteAmbiente: () => ({ encerrar: simulado.encerrar }),
}));

beforeEach(() => {
  simulado.pedidos.length = 0;
  simulado.responder = () => Response.json({});
  simulado.encerrar = async () => ({ ok: true });
});

function contexto() {
  const ctx = new RouterContextProvider();
  ctx.set(contextoDaSessao, { acesso: "acesso", usuarioId: "u-1", email: "pessoa@exemplo.com" } as never);
  ctx.set(contextoDoAuth, "ok" as never);
  return ctx;
}

const envio = (caminho: string, corpo: Record<string, string>, cookie = "") =>
  new Request(`https://frilabr.com/app/${caminho}`, {
    method: "POST",
    headers: { Origin: "https://frilabr.com", ...(cookie ? { Cookie: cookie } : {}) },
    body: new URLSearchParams(corpo),
  });

async function resultado(promessa: Promise<unknown>): Promise<{ dados: unknown; cabecalhos: Headers }> {
  try {
    const valor = (await promessa) as { data?: unknown; init?: { headers?: HeadersInit } } | Response;
    if (valor instanceof Response) return { dados: null, cabecalhos: valor.headers };
    // `data()` do React Router guarda o corpo e o init.
    if (valor && typeof valor === "object" && "init" in valor) return { dados: valor.data, cabecalhos: new Headers(valor.init?.headers) };
    return { dados: valor, cabecalhos: new Headers() };
  } catch (erro) {
    if (erro instanceof Response) return { dados: null, cabecalhos: erro.headers };
    throw erro;
  }
}

describe("config do push", () => {
  const completa = {
    FIREBASE_WEB_API_KEY: "a",
    FIREBASE_PROJECT_ID: "b",
    FIREBASE_MESSAGING_SENDER_ID: "c",
    FIREBASE_WEB_APP_ID: "d",
    FIREBASE_VAPID_CHAVE_PUBLICA: "e",
  };

  it("só existe com as cinco variáveis; faltando uma, o push fica desligado neste ambiente", () => {
    expect(lerConfigDoPush(completa)).toEqual({ apiKey: "a", projectId: "b", messagingSenderId: "c", appId: "d", vapidKey: "e" });
    expect(lerConfigDoPush({ ...completa, FIREBASE_VAPID_CHAVE_PUBLICA: "" })).toBeNull();
    expect(lerConfigDoPush({})).toBeNull();
  });
});

describe("token e cookie do aparelho", () => {
  it("só aceita token com cara de token do FCM", () => {
    expect(tokenValido(TOKEN)).toBe(true);
    expect(tokenValido("curto")).toBe(false);
    expect(tokenValido(`${TOKEN}; Path=/`)).toBe(false);
    expect(tokenValido(null)).toBe(false);
  });

  it("o cookie é HttpOnly, só de /app, e some ao desligar", () => {
    const gravado = cookieDoAparelho(TOKEN, true);
    expect(gravado).toContain("HttpOnly");
    expect(gravado).toContain("Path=/app");
    expect(gravado).toContain("Secure");
    expect(cookieDoAparelho(null, true)).toContain("Max-Age=0");
    const pedido = new Request("https://frilabr.com/app/sair", { headers: { Cookie: `x=1; ${gravado.split(";")[0]}` } });
    expect(lerTokenDoAparelho(pedido)).toBe(TOKEN);
  });
});

describe("registrar o aparelho web", () => {
  it("manda plataforma web e a versão da web, e devolve o vínculo", async () => {
    const api = criarApi(ambiente, {
      token: "t",
      fetch: async (entrada, inicio) => {
        simulado.pedidos.push(new Request(entrada, inicio));
        return Response.json({ plataforma: "web", atualizado_em: "2026-11-17T08:00:00Z", vinculo_id: "v-1" });
      },
    });
    expect(await registrarAparelho(api, TOKEN)).toEqual({ ok: true, vinculoId: "v-1" });
    expect(new URL(simulado.pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/registrar_dispositivo");
    expect(await simulado.pedidos[0]?.json()).toEqual({ token_fcm: TOKEN, plataforma: "web", versao_app: "1.0.0" });
  });

  it("a tela grava o token no cookie HttpOnly e devolve só o vínculo", async () => {
    simulado.responder = () => Response.json({ plataforma: "web", atualizado_em: "2026-11-17T08:00:00Z", vinculo_id: "v-1" });
    const { dados, cabecalhos } = await resultado(avisos({ request: envio("avisos", { intencao: "ligar", token_fcm: TOKEN }), context: contexto() } as never));
    expect(dados).toEqual({ ok: true, vinculoId: "v-1" });
    expect(cabecalhos.get("Set-Cookie")).toContain(`frila_aparelho=${TOKEN}`);
  });

  it("token estranho não chega ao servidor", async () => {
    const { dados } = await resultado(avisos({ request: envio("avisos", { intencao: "ligar", token_fcm: "x" }), context: contexto() } as never));
    expect(dados).toEqual({ ok: false, vinculoId: null });
    expect(simulado.pedidos).toHaveLength(0);
  });

  it("desligar tira o token do servidor e apaga o cookie", async () => {
    const cookie = cookieDoAparelho(TOKEN, true).split(";")[0] ?? "";
    const { cabecalhos } = await resultado(avisos({ request: envio("avisos", { intencao: "desligar" }, cookie), context: contexto() } as never));
    expect(new URL(simulado.pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/remover_dispositivo");
    expect(await simulado.pedidos[0]?.json()).toEqual({ token_fcm: TOKEN });
    expect(cabecalhos.get("Set-Cookie")).toContain("Max-Age=0");
  });
});

describe("sair tira o aparelho web da conta (RN15)", () => {
  it("com avisos ligados: remover_dispositivo antes de encerrar, e o cookie do aparelho some", async () => {
    const cookie = cookieDoAparelho(TOKEN, true).split(";")[0] ?? "";
    const { cabecalhos } = await resultado(sair({ request: envio("sair", {}, cookie), context: contexto() } as never));
    expect(new URL(simulado.pedidos[0]?.url ?? "").pathname).toBe("/rest/v1/rpc/remover_dispositivo");
    expect(cabecalhos.get("Location")).toBe("/entrar");
    expect(cabecalhos.getSetCookie().some((linha) => linha.startsWith("frila_aparelho=;") && linha.includes("Max-Age=0"))).toBe(true);
  });

  it("sem avisos ligados: nada muda no sair", async () => {
    const { cabecalhos } = await resultado(sair({ request: envio("sair", {}), context: contexto() } as never));
    expect(simulado.pedidos).toHaveLength(0);
    expect(cabecalhos.getSetCookie()).toHaveLength(2);
  });
});

describe("o que a tela de avisos mostra", () => {
  const base = { temConfig: true, suporta: true, plataforma: "outro" as const, permissao: "default" as NotificationPermission, registrado: false };

  it("cada caso no seu estado", () => {
    expect(estadoDosAvisos({ ...base, temConfig: false })).toBe("sem_config");
    expect(estadoDosAvisos({ ...base, plataforma: "embutido" })).toBe("embutido");
    expect(estadoDosAvisos({ ...base, plataforma: "iphone", suporta: false })).toBe("iphone_sem_instalar");
    expect(estadoDosAvisos({ ...base, plataforma: "instalada" })).toBe("desligado");
    expect(estadoDosAvisos({ ...base, suporta: false })).toBe("sem_suporte");
    expect(estadoDosAvisos({ ...base, permissao: "denied" })).toBe("negado");
    expect(estadoDosAvisos({ ...base, permissao: "granted" })).toBe("desligado");
    expect(estadoDosAvisos({ ...base, permissao: "granted", registrado: true })).toBe("ligado");
  });
});
