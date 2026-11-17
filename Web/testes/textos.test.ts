import { describe, expect, it } from "vitest";

import { textos } from "~/textos/pt-BR";

function folhas(no: unknown, caminho: string[] = []): Array<[string, unknown]> {
  if (typeof no === "object" && no !== null) {
    return Object.entries(no).flatMap(([chave, valor]) => folhas(valor, [...caminho, chave]));
  }
  return [[caminho.join("."), no]];
}

describe("catálogo de textos", () => {
  it("só tem textos preenchidos", () => {
    for (const [chave, valor] of folhas(textos)) {
      expect(typeof valor, chave).toBe("string");
      expect((valor as string).trim().length, chave).toBeGreaterThan(0);
    }
  });
});
