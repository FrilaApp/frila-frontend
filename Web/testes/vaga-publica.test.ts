import { RouterContextProvider } from "react-router";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";

const ambiente = vi.hoisted(() => ({
  env: { SUPABASE_URL: "https://sintetico.supabase.co", SUPABASE_CHAVE_PUBLICAVEL: "sb_publishable_sintetica", VAGA_PUBLICA_NO_INDICE: "0" },
}));
vi.mock("cloudflare:workers", () => ambiente);

const { loader, meta } = await import("../app/rotas/publico/vaga");

const VAGA = "7b84c3e2-8e3b-4f9e-a0e2-1a2b3c4d5e6f";
const daqui = (horas: number) => new Date(Date.now() + horas * 3600_000).toISOString();
const vaga = (extra: Record<string, unknown> = {}) => ({
  id: VAGA,
  funcao: { id: "f1", nome: "Garçom", categoria: "Salão" },
  estabelecimento_nome: "Casa Sintética",
  regiao_administrativa: "Plano Piloto",
  inicio_em: daqui(30),
  fim_em: daqui(36),
  valor_centavos: 15000,
  publicado_em: daqui(-1),
  inclusos: { inclui_refeicao: true, inclui_transporte: false, exige_material_proprio: false },
  modo: "urgencia",
  posicoes_abertas: 1,
  estado: "publicada",
  ...extra,
});

let pedidos: Request[] = [];
let resposta: () => Response = () => Response.json(vaga());
beforeEach(() => {
  pedidos = [];
  ambiente.env.VAGA_PUBLICA_NO_INDICE = "0";
  vi.stubGlobal("fetch", async (entrada: RequestInfo, inicio?: RequestInit) => {
    pedidos.push(new Request(entrada, inicio));
    return resposta();
  });
});
afterEach(() => vi.unstubAllGlobals());

const argumentos = (vagaId = VAGA, logado = false) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-do-usuario", usuarioId: "u1", email: "p@example.com" } : null);
  return { request: new Request(`https://frilabr.com/app/v/${vagaId}`), context, params: { vagaId }, url: new URL(`https://frilabr.com/app/v/${vagaId}`), matches: [] } as never;
};
type Dados = { estado: string; vaga: { casa: string | null; regiao: string | null; encerrada: boolean; indexar: boolean; funcao: string } | null };
const robots = (dados: unknown) => (meta({ loaderData: dados } as never) as Array<{ name?: string; content?: string }>).find((m) => m.name === "robots")?.content;

describe("vaga pelo link, sem login", () => {
  it("lê vaga_publica SEM o token de quem entrou, só com a chave publicável", async () => {
    resposta = () => Response.json(vaga());
    const dados = (await loader(argumentos(VAGA, true))) as Dados;
    expect(dados.vaga).toMatchObject({ funcao: "Garçom", casa: "Casa Sintética", regiao: "Plano Piloto", encerrada: false });
    const url = new URL(pedidos[0]?.url ?? "");
    expect(url.pathname).toBe("/rest/v1/rpc/vaga_publica");
    expect(url.searchParams.get("vaga_id")).toBe(VAGA);
    expect(pedidos[0]?.headers.get("Authorization")).toBe("Bearer sb_publishable_sintetica");
    expect(JSON.stringify(dados)).not.toContain("token-do-usuario");
  });

  it("sem nome da casa (null no contrato) e sem região, a tela não inventa", async () => {
    resposta = () => Response.json(vaga({ estabelecimento_nome: null, regiao_administrativa: null }));
    const dados = (await loader(argumentos())) as Dados;
    expect(dados.vaga).toMatchObject({ casa: null, regiao: null });
  });

  it("nada de endereço, ponto, contato ou quem recebe sai para a tela, mesmo se o servidor mandasse", async () => {
    resposta = () => Response.json(vaga({ local: "Rua X 123", ponto: { latitude: 1, longitude: 2 }, responsavel_local: "Fulano", telefone: "+5561" }));
    const texto = JSON.stringify(await loader(argumentos()));
    for (const proibido of ["Rua X 123", "latitude", "Fulano", "+5561"]) expect(texto, proibido).not.toContain(proibido);
  });

  it("encerrada: não publicada, sem lugar ou já começada", async () => {
    for (const extra of [{ estado: "preenchida" }, { posicoes_abertas: 0 }, { inicio_em: daqui(-1) }]) {
      resposta = () => Response.json(vaga(extra));
      expect(((await loader(argumentos())) as Dados).vaga?.encerrada, JSON.stringify(extra)).toBe(true);
    }
  });

  it("PORTÃO: noindex com a chave em 0; index só com a chave em 1 E a vaga aberta", async () => {
    resposta = () => Response.json(vaga());
    expect(robots(await loader(argumentos()))).toBe("noindex");
    ambiente.env.VAGA_PUBLICA_NO_INDICE = "1";
    expect(robots(await loader(argumentos()))).toBe("index, follow");
    resposta = () => Response.json(vaga({ estado: "encerrada" }));
    expect(robots(await loader(argumentos()))).toBe("noindex");
  });

  it("inexistente ou id torto: 404 (o torto nem sai)", async () => {
    resposta = () => Response.json({ code: "nao_encontrado", message: "x" }, { status: 404 });
    const respostaDoLoader = (await loader(argumentos())) as { init: ResponseInit | null };
    expect(respostaDoLoader.init?.status).toBe(404);
    pedidos = [];
    const torto = (await loader(argumentos("nao-e-uuid"))) as { init: ResponseInit | null };
    expect(torto.init?.status).toBe(404);
    expect(pedidos).toHaveLength(0);
  });
});
