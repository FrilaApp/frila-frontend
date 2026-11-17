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

  it("encerrada (200, com o aviso): preenchida ou sem lugar, ainda por vir; a já começada é 410 (abaixo)", async () => {
    for (const extra of [{ estado: "preenchida" }, { posicoes_abertas: 0 }]) {
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

type Meta = Array<Record<string, unknown>>;
const ldJson = (dados: unknown) => (meta({ loaderData: dados } as never) as Meta).find((m) => "script:ld+json" in m)?.["script:ld+json"] as
  | Record<string, unknown>
  | undefined;
const status = (dados: unknown) => (dados as { init?: ResponseInit | null }).init?.status ?? 200;

describe("dados estruturados e vaga removida (5.2)", () => {
  it("404 x 410 x 200: inexistente, vencida ou cancelada, aberta", async () => {
    resposta = () => Response.json({ code: "nao_encontrado", message: "x" }, { status: 404 });
    expect(status(await loader(argumentos()))).toBe(404);
    for (const extra of [{ estado: "cancelada" }, { estado: "encerrada" }, { inicio_em: daqui(-1) }]) {
      resposta = () => Response.json(vaga(extra));
      const dados = await loader(argumentos());
      expect(status(dados), JSON.stringify(extra)).toBe(410);
      expect((dados as { data: { estado: string } }).data.estado).toBe("removida");
      expect(robots((dados as { data: unknown }).data)).toBe("noindex");
    }
    resposta = () => Response.json(vaga());
    expect(status(await loader(argumentos()))).toBe(200);
    // Preenchida, mas ainda por vir: o link continua, dizendo que não está mais aberta (200, sem JSON-LD).
    resposta = () => Response.json(vaga({ estado: "preenchida", posicoes_abertas: 0 }));
    const preenchida = await loader(argumentos());
    expect(status(preenchida)).toBe(200);
    ambiente.env.VAGA_PUBLICA_NO_INDICE = "1";
    expect(ldJson(await loader(argumentos()))).toBeUndefined();
  });

  it("PORTÃO fechado: nada de JSON-LD, e o noindex continua", async () => {
    resposta = () => Response.json(vaga());
    const dados = await loader(argumentos());
    expect(ldJson(dados)).toBeUndefined();
    expect(robots(dados)).toBe("noindex");
  });

  it("PORTÃO aberto: JobPosting só com o que a página mostra", async () => {
    ambiente.env.VAGA_PUBLICA_NO_INDICE = "1";
    resposta = () => Response.json(vaga({ local: "Rua X 123", ponto: { latitude: 1, longitude: 2 }, documento: "12345678000199", telefone: "+5561" }));
    const json = ldJson(await loader(argumentos()));
    expect(json).toMatchObject({
      "@context": "https://schema.org",
      "@type": "JobPosting",
      title: "Garçom",
      hiringOrganization: { "@type": "Organization", name: "Casa Sintética" },
      jobLocation: { "@type": "Place", address: { "@type": "PostalAddress", addressLocality: "Plano Piloto", addressRegion: "DF", addressCountry: "BR" } },
      baseSalary: { "@type": "MonetaryAmount", currency: "BRL", value: { "@type": "QuantitativeValue", value: 150, unitText: "DAY" } },
    });
    const texto = JSON.stringify(json);
    for (const proibido of ["Rua X 123", "latitude", "12345678000199", "+5561", "streetAddress", "telephone", "email", "identifier"]) {
      expect(texto, proibido).not.toContain(proibido);
    }
  });

  it("sem o nome da casa (CPF), quem anuncia é o Frila; sem região, só o DF", async () => {
    ambiente.env.VAGA_PUBLICA_NO_INDICE = "1";
    resposta = () => Response.json(vaga({ estabelecimento_nome: null, regiao_administrativa: null }));
    const json = ldJson(await loader(argumentos())) as { hiringOrganization: { name: string }; jobLocation: { address: Record<string, string> } };
    expect(json.hiringOrganization.name).toBe("Frila");
    expect(json.jobLocation.address.addressLocality).toBeUndefined();
    expect(json.jobLocation.address.addressRegion).toBe("DF");
  });

  it("cartão de compartilhamento com a função e o valor", async () => {
    resposta = () => Response.json(vaga());
    const metas = meta({ loaderData: await loader(argumentos()) } as never) as Meta;
    const titulo = metas.find((m) => m.property === "og:title")?.content as string;
    expect(titulo.replace(/\s/g, " ")).toBe("Garçom · R$ 150,00 · Frila");
    expect(metas.some((m) => m.property === "og:description")).toBe(true);
  });
});
