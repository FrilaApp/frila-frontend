/**
 * Rotas do Worker em produção (web ligada em 17/11/2026). Garantem que /app, /app/* e /app.data vão ao Worker sem
 * pegar outra página do site (/apps, /app-store) e que a web fica ligada em produção. Limite conhecido: a Cloudflare
 * não aceita parâmetro no padrão da rota, e /app?utm_source=... não chega ao Worker (cai no site): o conserto é no site.
 */
import { describe, expect, it } from "vitest";

import textoDoWrangler from "../wrangler.jsonc?raw";

/** Tira os comentários do JSONC sem mexer no que está dentro de aspas. */
function semComentarios(texto: string): string {
  let saida = "";
  for (let i = 0, emTexto = false; i < texto.length; i++) {
    const c = texto[i] ?? "";
    if (emTexto) {
      saida += c;
      if (c === "\\") saida += texto[++i] ?? "";
      else if (c === '"') emTexto = false;
    } else if (c === '"') {
      emTexto = true;
      saida += c;
    } else if (c === "/" && texto[i + 1] === "/") {
      while (i < texto.length && texto[i] !== "\n") i++;
      saida += "\n";
    } else if (c === "/" && texto[i + 1] === "*") {
      i = texto.indexOf("*/", i + 2) + 1;
    } else saida += c;
  }
  return saida.replace(/,(\s*[}\]])/g, "$1");
}

type Producao = { routes?: { pattern: string; zone_name?: string }[]; vars?: Record<string, string> };
const config = JSON.parse(semComentarios(textoDoWrangler)) as { env?: { producao?: Producao } };
const producao = config.env?.producao ?? {};
const padroes = (producao.routes ?? []).map((r) => r.pattern);

/**
 * Como a Cloudflare casa uma rota com o pedido (host + caminho + parâmetros): `*` no fim casa qualquer resto; sem `*`,
 * só o endereço exato. É assim que o `/app?x` ficava de fora da rota `frilabr.com/app`.
 */
function casa(padrao: string, endereco: string): boolean {
  return padrao.endsWith("*") ? endereco.startsWith(padrao.slice(0, -1)) : endereco === padrao;
}
const vaiAoWorker = (endereco: string) => padroes.some((p) => casa(p, endereco));

describe("rotas do Worker em produção", () => {
  it("a web fica ligada em produção (o próximo deploy da main não a desliga)", () => {
    expect(producao.vars?.WEB_LIGADA).toBe("1");
  });

  it("todas as rotas são do frilabr.com e nenhuma é o padrão largo frilabr.com/app*", () => {
    expect(padroes.length).toBeGreaterThan(0);
    for (const r of producao.routes ?? []) expect(r.zone_name).toBe("frilabr.com");
    expect(padroes).not.toContain("frilabr.com/app*");
  });

  it.each([
    "frilabr.com/app",
    "frilabr.com/app/",
    "frilabr.com/app/?x",
    "frilabr.com/app/entrar",
    "frilabr.com/app/x",
    "frilabr.com/app.data",
  ])("%s vai ao Worker", (endereco) => {
    expect(vaiAoWorker(endereco)).toBe(true);
  });

  it.each([
    "frilabr.com/",
    "frilabr.com/apps",
    "frilabr.com/app-store",
    "frilabr.com/appx",
    "frilabr.com/app.dataextra",
    "frilabr.com/privacidade",
    "frilabr.com/termos",
    "frilabr.com/suporte",
  ])("%s fica com o site", (endereco) => {
    expect(vaiAoWorker(endereco)).toBe(false);
  });
});
