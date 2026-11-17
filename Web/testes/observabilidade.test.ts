/**
 * Achado de segurança (Bússola, 17/11): os logs de invocação dos Workers guardam os cabeçalhos do pedido, e o Cookie
 * carrega a sessão. Estes testes garantem que eles ficam desligados nos 2 ambientes e que nenhum log do código leva
 * cabeçalho, cookie, authorization ou token.
 */
import { describe, expect, it } from "vitest";

import textoDoWrangler from "../wrangler.jsonc?raw";

const fontes = import.meta.glob<string>(["../app/**/*.{ts,tsx}", "../workers/**/*.ts", "../public/**/*.js"], { query: "?raw", import: "default", eager: true });

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

type Observabilidade = { enabled?: boolean; logs?: { invocation_logs?: boolean } };
const config = JSON.parse(semComentarios(textoDoWrangler)) as { observability?: Observabilidade; env?: Record<string, { observability?: Observabilidade }> };

describe("logs do Worker sem cabeçalho do pedido", () => {
  it("os logs de invocação ficam desligados no dev e em produção", () => {
    expect(config.observability?.logs?.invocation_logs).toBe(false);
    expect(Object.keys(config.env ?? {})).toContain("producao");
    for (const [nome, ambiente] of Object.entries(config.env ?? {})) {
      expect(ambiente.observability?.logs?.invocation_logs, nome).toBe(false);
    }
  });

  it("nenhum console.* do código recebe cabeçalho, pedido, cookie, authorization ou token", () => {
    const suspeitos = Object.entries(fontes).flatMap(([arquivo, fonte]) =>
      [...fonte.matchAll(/console\.(log|info|warn|error|debug|trace)\(([^)]*)\)/g)]
        .filter((achado) => /header|cabe[cç]alho|cookie|authorization|request|pedido|token|acesso|sessao|sessão/i.test(achado[2] ?? ""))
        .map((achado) => `${arquivo}: ${achado[0]}`),
    );
    expect(suspeitos).toEqual([]);
  });
});
