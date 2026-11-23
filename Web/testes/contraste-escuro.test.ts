/// <reference types="node" />
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

// O Vitest entrega CSS vazio com ?raw; por isso a leitura direta do arquivo.
const css = readFileSync(new URL("../app/app.css", import.meta.url), "utf8");
// WCAG 1.4.11: a borda de campos e cartões precisa de 3:1 contra o fundo e a superfície do tema Escuro.
const blocoEscuro = css.match(/html\[data-aparencia="escuro"\]\s*\{([^}]*)\}/)?.[1] ?? "";

function token(nome: string): string {
  const valor = blocoEscuro.match(new RegExp(`${nome}:\\s*(#[0-9a-fA-F]{6})`))?.[1];
  if (!valor) throw new Error(`token ${nome} não encontrado no bloco Escuro`);
  return valor;
}

function canal(hex: string, inicio: number): number {
  const c = parseInt(hex.slice(inicio, inicio + 2), 16) / 255;
  return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

function luminancia(hex: string): number {
  return 0.2126 * canal(hex, 1) + 0.7152 * canal(hex, 3) + 0.0722 * canal(hex, 5);
}

function razao(a: string, b: string): number {
  const la = luminancia(a);
  const lb = luminancia(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

describe("contraste da borda no tema Escuro", () => {
  it.each(["--cor-fundo", "--cor-superficie"])("a borda tem pelo menos 3:1 contra %s", (fundo) => {
    expect(razao(token("--cor-borda"), token(fundo))).toBeGreaterThanOrEqual(3);
  });
});
