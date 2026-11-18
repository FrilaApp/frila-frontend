/**
 * A lista de e-mails de demonstração é segredo OPCIONAL do Worker: o repositório é público, então ela não pode ficar no
 * wrangler.jsonc, e o Prod não a tem (sem ela a lista é vazia). Estes testes garantem as duas coisas.
 */
import { describe, expect, it } from "vitest";

import { listaDeEmailsDeDemonstracao } from "~/servidor/ambiente";
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

type Bloco = { vars?: Record<string, unknown>; secrets?: { required?: string[] } };
const config = JSON.parse(semComentarios(textoDoWrangler)) as Bloco & { env?: Record<string, Bloco> };
const ambientes: Array<[string, Bloco]> = [["dev", config], ...Object.entries(config.env ?? {})];

describe("e-mails de demonstração", () => {
  it("sem o segredo, a lista é vazia", () => {
    expect(listaDeEmailsDeDemonstracao(undefined).size).toBe(0);
    expect(listaDeEmailsDeDemonstracao("").size).toBe(0);
    expect(listaDeEmailsDeDemonstracao(" , ,").size).toBe(0);
  });

  it("lê a lista separada por vírgula, sem espaço nem maiúscula", () => {
    expect([...listaDeEmailsDeDemonstracao(" A@exemplo.com ,b@Exemplo.com,")]).toEqual(["a@exemplo.com", "b@exemplo.com"]);
  });

  it.each(ambientes)("o wrangler.jsonc (%s) não tem a lista nos vars nem a exige como segredo", (_nome, bloco) => {
    expect(Object.keys(bloco.vars ?? {})).not.toContain("EMAILS_DE_DEMONSTRACAO");
    expect(bloco.secrets?.required ?? []).not.toContain("EMAILS_DE_DEMONSTRACAO");
  });

  it("nenhum e-mail fica escrito no wrangler.jsonc", () => {
    expect(semComentarios(textoDoWrangler)).not.toMatch(/@/);
  });
});
