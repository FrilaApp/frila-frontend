/**
 * Achados do Juiz (revisão da Política, 17/11) no código da web:
 * A1 — em produção, http://frilabr.com/app respondia 200 e os cookies saíam sem Secure: agora vai para https (301).
 * A4 — o Sair ignorava a falha do remover_dispositivo: agora falha como na falha do Auth, sem dizer que saiu.
 * A7 — excluir a conta não apagava o cookie do aparelho (frila_aparelho): agora apaga.
 */
import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import codigoDoWorker from "../workers/app.ts?raw";
import { contextoDaSessao, contextoDoAuth } from "../app/contexto";
import { action as excluir } from "../app/rotas/conta/dados";
import { action as sair } from "../app/rotas/sair";
import { criarApi } from "../app/servidor/api";
import { respostaAntesDoApp } from "../app/servidor/porteiro";
import { argumentos } from "./contratante-apoio";

const simulado = vi.hoisted(() => ({
  removerResponde: 200,
  encerrar: vi.fn(async () => ({ ok: true })),
  funcoes: { POST: vi.fn() },
}));
vi.mock("../app/servidor/deste-ambiente", () => ({
  authDesteAmbiente: () => ({ encerrar: simulado.encerrar }),
  funcoesDoUsuario: () => simulado.funcoes,
  apiDoUsuario: (acesso: string) =>
    criarApi({ url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_sintetica" }, {
      token: acesso,
      fetch: async () =>
        simulado.removerResponde === 200 ? Response.json({ removido: true }) : Response.json({ erro: "indisponivel" }, { status: simulado.removerResponde }),
    }),
}));
beforeEach(() => {
  simulado.removerResponde = 200;
  simulado.encerrar.mockClear();
  simulado.funcoes.POST.mockReset();
});

async function resposta(promessa: Promise<unknown>): Promise<Response> {
  try {
    await promessa;
  } catch (erro) {
    if (erro instanceof Response) return erro;
    throw erro;
  }
  throw new Error("esperava um redirect");
}

describe("A1: em produção, http vai para https", () => {
  it("o porteiro manda http para https (301), com o mesmo caminho e a mesma busca", () => {
    const r = respostaAntesDoApp(new Request("http://frilabr.com/app/vagas?x=1"), { webLigada: true, exigirHttps: true });
    expect(r?.status).toBe(301);
    expect(r?.headers.get("Location")).toBe("https://frilabr.com/app/vagas?x=1");
    // Antes de qualquer outra regra: nem um envio por http chega ao app.
    const envio = new Request("http://frilabr.com/app/sair", { method: "POST", headers: { Origin: "http://frilabr.com" } });
    expect(respostaAntesDoApp(envio, { webLigada: true, exigirHttps: true })?.status).toBe(301);
    expect(respostaAntesDoApp(new Request("https://frilabr.com/app/"), { webLigada: true, exigirHttps: true })).toBeNull();
  });

  it("fora de produção (servidor local em http), nada muda", () => {
    expect(respostaAntesDoApp(new Request("http://localhost:5173/app/"), { webLigada: true, exigirHttps: false })).toBeNull();
  });

  it("o Worker liga a regra só em produção", () => {
    expect(codigoDoWorker).toContain('exigirHttps: env.AMBIENTE === "producao"');
  });
});

function contextoComSessao() {
  const ctx = new RouterContextProvider();
  ctx.set(contextoDaSessao, { acesso: "ACESSO-SINTETICO", usuarioId: "u1", email: null } as never);
  ctx.set(contextoDoAuth, "ok" as never);
  return ctx;
}
const pedidoDeSair = () =>
  new Request("https://frilabr.com/app/sair", { method: "POST", headers: { Origin: "https://frilabr.com", Cookie: "frila_aparelho=fcm-token_sintetico-com-mais-de-vinte" } });

describe("A4: o Sair não diz que saiu com o aparelho ainda registrado", () => {
  it("remover_dispositivo falhou: o Sair falha (sessão e cookies ficam) e a pessoa tenta de novo", async () => {
    simulado.removerResponde = 503;
    const r = await resposta(sair({ request: pedidoDeSair(), context: contextoComSessao() } as never));
    expect(r.headers.get("Location")).toBe("/?sair=falhou");
    expect(r.headers.getSetCookie()).toEqual([]);
    expect(simulado.encerrar).not.toHaveBeenCalled();
  });

  it("remover_dispositivo deu certo: encerra a sessão e apaga os 3 cookies", async () => {
    const r = await resposta(sair({ request: pedidoDeSair(), context: contextoComSessao() } as never));
    expect(r.headers.get("Location")).toBe("/entrar");
    expect(r.headers.getSetCookie()).toHaveLength(3);
    expect(simulado.encerrar).toHaveBeenCalledOnce();
  });
});

describe("A7: excluir a conta apaga também o cookie do aparelho", () => {
  it("excluída: os cookies da sessão e o frila_aparelho saem", async () => {
    simulado.funcoes.POST.mockResolvedValue({ data: { perfil_removido_em: "x", dados_apagados_ate: "2026-12-02", turnos_cancelados: 0 }, response: new Response(null, { status: 202 }) });
    const r = await resposta(excluir(argumentos("/conta", { ciente: "sim" })));
    expect(r.headers.get("Location")).toBe("/entrar");
    const cookies = r.headers.getSetCookie();
    expect(cookies.some((linha) => linha.startsWith("frila_aparelho=;") && linha.includes("Max-Age=0"))).toBe(true);
    for (const linha of cookies) expect(linha).toMatch(/Max-Age=0/);
  });
});
