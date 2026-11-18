/**
 * Mapa do site para buscadores (5.4): `/app/sitemap.xml` lista só as 4 páginas públicas. As vagas públicas ficam fora
 * (noindex até o portão da Política, e a lista pública é o 5.3). O robots.txt da raiz é do site frilabr.com, não da web.
 */
import { describe, expect, it, vi } from "vitest";

import textoDasRotas from "../app/routes.ts?raw";
import { meta as metaDaCasa } from "../app/rotas/publico/como-funciona-casa";
import { meta as metaDoProfissional } from "../app/rotas/publico/como-funciona-profissional";
import { meta as metaDasPerguntas } from "../app/rotas/publico/perguntas";
import { loader, PAGINAS_DO_MAPA } from "../app/rotas/publico/sitemap";

vi.mock("cloudflare:workers", () => ({ env: {} }));

const pedido = (origem: string) => ({ request: new Request(`${origem}/app/sitemap.xml`), context: {}, params: {} }) as never;

async function enderecos(origem: string) {
  const resposta = await loader(pedido(origem));
  const xml = await resposta.text();
  return { resposta, xml, locs: [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]) };
}

describe("mapa do site (5.4)", () => {
  it("responde XML do protocolo sitemaps.org, sem dado de ninguém e com cache público", async () => {
    const { resposta, xml } = await enderecos("https://frilabr.com");
    expect(resposta.status).toBe(200);
    expect(resposta.headers.get("Content-Type")).toBe("application/xml; charset=utf-8");
    expect(resposta.headers.get("Cache-Control")).toBe("public, max-age=3600");
    expect(xml.startsWith('<?xml version="1.0" encoding="UTF-8"?>')).toBe(true);
    expect(xml).toContain('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  });

  it("lista só as 4 páginas públicas, no endereço de quem pediu", async () => {
    expect((await enderecos("https://frilabr.com")).locs).toEqual([
      "https://frilabr.com/app/",
      "https://frilabr.com/app/como-funciona/casa",
      "https://frilabr.com/app/como-funciona/profissional",
      "https://frilabr.com/app/perguntas",
    ]);
    expect((await enderecos("https://frila-web-dev.frilabr.workers.dev")).locs[0]).toBe("https://frila-web-dev.frilabr.workers.dev/app/");
  });

  it("as vagas públicas e as telas de quem entrou ficam fora", async () => {
    const { xml } = await enderecos("https://frilabr.com");
    for (const fora of ["/app/v/", "/app/vagas", "/app/painel", "/app/entrar", "/app/casa", "/app/conta"]) {
      expect(xml).not.toContain(fora);
    }
  });

  it("cada página do mapa existe no routes.ts, e a rota do mapa também", () => {
    expect(textoDasRotas).toContain('route("sitemap.xml", "rotas/publico/sitemap.ts")');
    for (const caminho of PAGINAS_DO_MAPA.filter((c) => c !== "/")) {
      expect(textoDasRotas).toContain(`route("${caminho.slice(1)}", `);
    }
    expect(textoDasRotas).toContain('index("rotas/inicio.tsx")');
  });

  it("nenhuma página do mapa pede para não ser indexada", () => {
    for (const meta of [metaDaCasa, metaDoProfissional, metaDasPerguntas]) {
      expect(JSON.stringify(meta())).not.toContain("noindex");
    }
  });
});
