/**
 * B-116, ponto único: esquecer um caminho seria silencioso (sem assinatura, o banco grava o IP do Worker). Então só o
 * módulo `app/servidor/saida-rest.ts` pode falar com o `/rest/v1` com o token da pessoa e só ele escreve os cabeçalhos
 * `x-frila-ip-*`. Estilo do observabilidade.test.ts: lê as fontes de app/ e workers/ pelo `import.meta.glob`.
 */
import { describe, expect, it } from "vitest";

const fontes = import.meta.glob<string>(["../app/**/*.{ts,tsx}", "../workers/**/*.ts"], { query: "?raw", import: "default", eager: true });

const PONTO_UNICO = "../app/servidor/saida-rest.ts";
/** Arquivo gerado a partir do contrato (só tipos): fica de fora da busca. */
const gerado = (arquivo: string) => arquivo.includes("tipos.gerado");
const candidatos = Object.entries(fontes).filter(([arquivo]) => arquivo !== PONTO_UNICO && !gerado(arquivo));

/** Do `(` que abre até o `)` que FECHA (pula texto entre aspas e crase). Devolve os argumentos. */
function argumentosAte(fonte: string, abre: number): string {
  let nivel = 0;
  for (let i = abre; i < fonte.length; i++) {
    const c = fonte[i];
    if (c === "(") nivel++;
    else if (c === ")") {
      if (--nivel === 0) return fonte.slice(abre + 1, i);
    } else if (c === '"' || c === "'" || c === "`") {
      for (i++; i < fonte.length && fonte[i] !== c; i++) if (fonte[i] === "\\") i++;
    }
  }
  return fonte.slice(abre + 1);
}

/** Cada CHAMADA de `criarApi(` (a declaração `function criarApi(` não conta), com os argumentos inteiros. */
function chamadasDeCriarApi(fonte: string): string[] {
  return [...fonte.matchAll(/(?<!function\s)\bcriarApi\s*\(/g)].map((achado) => argumentosAte(fonte, (achado.index ?? 0) + achado[0].length - 1));
}

describe("ponto único de saída para o /rest/v1 com token", () => {
  it("o módulo existe e as fontes foram lidas (o teste não passa por estar vazio)", () => {
    expect(Object.keys(fontes)).toContain(PONTO_UNICO);
    expect(candidatos.length).toBeGreaterThan(50);
  });

  it("fora dele, nenhum arquivo chama criarApi( passando token", () => {
    const infratores = candidatos.filter(([, fonte]) => chamadasDeCriarApi(fonte).some((argumentos) => /\btoken\b/.test(argumentos))).map(([arquivo]) => arquivo);
    expect(infratores).toEqual([]);
  });

  it("fora de api.ts e do ponto único, nenhum arquivo tem o texto rest/v1 (pega até createClient avulso com baseUrl)", () => {
    const infratores = candidatos.filter(([arquivo, fonte]) => arquivo !== "../app/servidor/api.ts" && /rest\/v1/.test(fonte)).map(([arquivo]) => arquivo);
    expect(infratores).toEqual([]);
  });

  it("nenhum arquivo além dele escreve x-frila-ip", () => {
    const infratores = candidatos.filter(([, fonte]) => /x-frila-ip/i.test(fonte)).map(([arquivo]) => arquivo);
    expect(infratores).toEqual([]);
  });

  it("o próprio módulo é quem tem os 3 cabeçalhos e o /rest/v1 (a prova de que as buscas acima olham o lugar certo)", () => {
    const fonte = fontes[PONTO_UNICO] ?? "";
    expect(fonte).toMatch(/x-frila-ip-visitante/);
    expect(fonte).toMatch(/x-frila-ip-carimbo/);
    expect(fonte).toMatch(/x-frila-ip-assinatura/);
    expect(fonte).toMatch(/\/rest\/v1/);
    expect(chamadasDeCriarApi(fonte).some((argumentos) => /\btoken\b/.test(argumentos))).toBe(true);
  });
});
