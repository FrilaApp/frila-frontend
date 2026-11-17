/**
 * "Tem sessão" é decidido pelo Auth, no servidor, em todo pedido que usa a sessão (revisão do #835, 2ª rodada).
 * Nada guardado no navegador serve de revogação: o Auth simulado abaixo encerra a sessão no sair, como o do
 * Supabase (provado no dev: depois do logout, GET /auth/v1/user responde 403 session_not_found).
 * Regra de custo: no máximo 1 chamada ao Auth por pedido (renovar OU conferir, nunca as duas).
 */
import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as sair } from "../app/rotas/sair";
import { middlewareDeSessao } from "../app/servidor/middleware-de-sessao";
import { cookiesDaSessao, type Sessao, type SessaoAtual } from "../app/servidor/sessao";

const agora = Math.floor(Date.now() / 1000);
const token = (sessaoId: string, exp: number) =>
  `cabecalho.${btoa(JSON.stringify({ sub: `u-${sessaoId}`, session_id: sessaoId, exp }))}.assinatura-${sessaoId}-${exp}`;
const sessaoDe = (id: string, vida = 3600): Sessao => ({
  access_token: token(id, agora + vida),
  refresh_token: `r-${id}-${vida}`,
  expires_in: vida,
  token_type: "bearer",
});
const sessaoIdDe = (acesso: string) => (JSON.parse(atob(acesso.split(".")[1] ?? "")) as { session_id: string }).session_id;

/** Auth simulado: sabe quais sessões foram encerradas e conta as chamadas. */
const auth = vi.hoisted(() => ({
  encerradas: new Set<string>(),
  fora: false,
  chamadas: 0,
  renovar: vi.fn(),
  conferir: vi.fn(),
  encerrar: vi.fn(),
}));
vi.mock("../app/servidor/deste-ambiente", () => ({ authDesteAmbiente: () => auth }));

beforeEach(() => {
  auth.encerradas.clear();
  auth.fora = false;
  auth.chamadas = 0;
  auth.renovar.mockReset().mockImplementation(async (renovacao: string) => {
    auth.chamadas++;
    if (auth.fora) return { ok: false, motivo: "indisponivel" };
    const id = renovacao.split("-")[1] ?? "";
    return auth.encerradas.has(id) ? { ok: false, motivo: "recusada" } : { ok: true, sessao: sessaoDe(id) };
  });
  auth.conferir.mockReset().mockImplementation(async (acesso: string) => {
    auth.chamadas++;
    if (auth.fora) return { ok: false, motivo: "indisponivel" };
    return auth.encerradas.has(sessaoIdDe(acesso)) ? { ok: false, motivo: "recusada" } : { ok: true };
  });
  auth.encerrar.mockReset().mockImplementation(async (acesso: string) => {
    auth.chamadas++;
    if (auth.fora) return { ok: false };
    auth.encerradas.add(sessaoIdDe(acesso));
    return { ok: true };
  });
});

function pote() {
  const guardados = new Map<string, string>();
  return {
    aplicar(linhas: string[]) {
      for (const linha of linhas) {
        const par = linha.split(";")[0] ?? "";
        const nome = par.slice(0, par.indexOf("="));
        if (/;\s*Max-Age=0(;|$)/.test(linha)) guardados.delete(nome);
        else guardados.set(nome, par.slice(par.indexOf("=") + 1));
      }
    },
    remover(trecho: string) {
      for (const nome of [...guardados.keys()]) if (nome.includes(trecho)) guardados.delete(nome);
    },
    cabecalho: () => [...guardados].map(([nome, valor]) => `${nome}=${valor}`).join("; "),
  };
}

/** Um pedido passando pelo middleware real. Devolve a sessão que as rotas veriam e a resposta. */
async function pedir(cookie: string, metodo = "GET") {
  const request = new Request("https://frilabr.com/app/", {
    method: metodo,
    headers: { Origin: "https://frilabr.com", Cookie: cookie },
  });
  const context = new RouterContextProvider();
  let vista: SessaoAtual | null = null;
  const resposta = (await middlewareDeSessao({ request, context, params: {}, url: new URL(request.url), matches: [] } as never, async () => {
    vista = context.get(contextoDaSessao);
    return new Response("ok");
  })) as Response;
  return { sessao: vista as SessaoAtual | null, resposta };
}

async function sairCom(cookie: string): Promise<Response> {
  const request = new Request("https://frilabr.com/app/sair", {
    method: "POST",
    headers: { Origin: "https://frilabr.com", Cookie: cookie },
  });
  const args = { request, context: new RouterContextProvider(), params: {}, url: new URL(request.url), matches: [] };
  return (await middlewareDeSessao(args as never, async () => {
    try {
      await sair(args as never);
    } catch (resposta) {
      if (resposta instanceof Response) return resposta;
      throw resposta;
    }
    throw new Error("esperava o redirect");
  })) as Response;
}

describe("sair só conclui com a sessão encerrada no Auth", () => {
  it("Auth de pé: sair encerra a sessão, apaga os cookies e vai para entrar", async () => {
    const saida = await sairCom(cookiesDaSessao(sessaoDe("A"), true).map((c) => c.split(";")[0]).join("; "));
    expect(saida.headers.get("Location")).toBe("/entrar");
    expect(saida.headers.getSetCookie().filter((c) => c.includes("Max-Age=0"))).toHaveLength(2);
    expect(auth.encerradas.has("A")).toBe(true);
  });

  it("Auth fora do ar: não diz que saiu, não apaga os cookies e volta com o aviso", async () => {
    auth.fora = true;
    const saida = await sairCom(cookiesDaSessao(sessaoDe("A"), true).map((c) => c.split(";")[0]).join("; "));
    expect(saida.headers.get("Location")).toBe("/?sair=falhou");
    expect(saida.headers.getSetCookie()).toEqual([]);
    expect(auth.encerradas.has("A")).toBe(false);
  });

  it("o logout falha com o Auth de pé na conferência: também não conclui", async () => {
    auth.encerrar.mockImplementationOnce(async () => ({ ok: false }));
    const saida = await sairCom(cookiesDaSessao(sessaoDe("A"), true).map((c) => c.split(";")[0]).join("; "));
    expect(saida.headers.get("Location")).toBe("/?sair=falhou");
    expect(saida.headers.getSetCookie()).toEqual([]);
  });

  it("sessão que o Auth já recusou: sair conclui (não há o que encerrar)", async () => {
    auth.encerradas.add("A");
    const saida = await sairCom(cookiesDaSessao(sessaoDe("A"), true).map((c) => c.split(";")[0]).join("; "));
    expect(saida.headers.get("Location")).toBe("/entrar");
    expect(saida.headers.getSetCookie().filter((c) => c.includes("Max-Age=0")).length).toBeGreaterThanOrEqual(2);
  });
});

describe("a sessão é decidida pelo Auth", () => {
  it("sessão encerrada no Auth não vale, mesmo com os cookies regravados por uma resposta atrasada", async () => {
    const navegador = pote();
    navegador.aplicar(cookiesDaSessao(sessaoDe("A"), true));
    const cookieA = navegador.cabecalho();
    // Duas saídas de A partem juntas; a segunda fica retida pela rede.
    navegador.aplicar((await sairCom(cookieA)).headers.getSetCookie());
    const saidaA2 = await sairCom(cookieA);
    // Entra em B; uma renovação de B fica retida; sai de B.
    navegador.aplicar(cookiesDaSessao(sessaoDe("B"), true));
    navegador.aplicar((await sairCom(navegador.cabecalho())).headers.getSetCookie());
    // Chegam por último: a 2ª saída de A e a renovação de B.
    navegador.aplicar(saidaA2.headers.getSetCookie());
    navegador.aplicar(cookiesDaSessao(sessaoDe("B"), true));

    const seguinte = await pedir(navegador.cabecalho());
    expect(seguinte.sessao).toBeNull();
    expect(seguinte.resposta.headers.getSetCookie().filter((c) => c.includes("Max-Age=0"))).toHaveLength(2);
  });

  it("apagar ou trocar qualquer outro cookie não reativa a sessão encerrada", async () => {
    const navegador = pote();
    navegador.aplicar(cookiesDaSessao(sessaoDe("A"), true));
    const cookieA = navegador.cabecalho();
    navegador.aplicar((await sairCom(cookieA)).headers.getSetCookie());
    // Os cookies de A voltam (resposta atrasada ou cópia) e qualquer marca do navegador some.
    navegador.aplicar(cookiesDaSessao(sessaoDe("A"), true));
    navegador.remover("encerradas");
    expect((await pedir(navegador.cabecalho())).sessao).toBeNull();
    expect((await pedir(`${navegador.cabecalho()}; __Host-frila-encerradas=outra`)).sessao).toBeNull();
  });

  it("sessão válida passa, com uma chamada só ao Auth (conferir), sem regravar cookie", async () => {
    const { sessao, resposta } = await pedir(cookiesDaSessao(sessaoDe("A"), true).map((c) => c.split(";")[0]).join("; "));
    expect(sessao?.usuarioId).toBe("u-A");
    expect(auth.conferir).toHaveBeenCalledOnce();
    expect(auth.renovar).not.toHaveBeenCalled();
    expect(auth.chamadas).toBe(1);
    expect(resposta.headers.getSetCookie()).toEqual([]);
  });

  it("token perto de vencer: a renovação é a única chamada ao Auth do pedido", async () => {
    const quaseVencendo = sessaoDe("A", 30);
    const { sessao } = await pedir(cookiesDaSessao(quaseVencendo, true).map((c) => c.split(";")[0]).join("; "));
    expect(sessao?.usuarioId).toBe("u-A");
    expect(auth.renovar).toHaveBeenCalledOnce();
    expect(auth.conferir).not.toHaveBeenCalled();
    expect(auth.chamadas).toBe(1);
  });

  it("sem cookie de sessão, o Auth nem é chamado", async () => {
    expect((await pedir("outro=1")).sessao).toBeNull();
    expect(auth.chamadas).toBe(0);
  });

  it("Auth fora do ar: sem sessão em leitura e em envio, e os cookies ficam (a pessoa segue logada quando ele voltar)", async () => {
    auth.fora = true;
    const cookie = cookiesDaSessao(sessaoDe("A"), true).map((c) => c.split(";")[0]).join("; ");
    for (const metodo of ["GET", "POST"]) {
      const { sessao, resposta } = await pedir(cookie, metodo);
      expect(sessao, metodo).toBeNull();
      expect(resposta.headers.getSetCookie(), metodo).toEqual([]);
    }
    // Perto de vencer e o Auth fora: também sem sessão, sem apagar nada.
    const { sessao } = await pedir(cookiesDaSessao(sessaoDe("A", 30), true).map((c) => c.split(";")[0]).join("; "));
    expect(sessao).toBeNull();
  });
});
