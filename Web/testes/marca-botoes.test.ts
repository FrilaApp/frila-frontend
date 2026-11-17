import { describe, expect, it } from "vitest";

/** Regra da marca (app/marca/LEIAME.md): sobre o laranja, só texto grande, em branco e negrito (≥ 19 px: text-xl). */
const telas = import.meta.glob<string>("../app/**/*.tsx", { query: "?raw", import: "default", eager: true });

describe("botão laranja segue a marca", () => {
  it("toda classe com bg-acao leva text-sobre-acao, text-xl e font-bold", () => {
    const linhas = Object.entries(telas).flatMap(([arquivo, fonte]) =>
      fonte
        .split("\n")
        .map((linha, i) => ({ onde: `${arquivo}:${i + 1}`, linha }))
        .filter(({ linha }) => linha.includes("bg-acao")),
    );
    expect(linhas.length).toBeGreaterThan(0);
    for (const { onde, linha } of linhas) {
      expect(linha, onde).toContain("text-sobre-acao");
      expect(linha, onde).toContain("text-xl");
      expect(linha, onde).toContain("font-bold");
      expect(linha, onde).not.toMatch(/\btext-tinta\b/);
    }
  });
});
