import { describe, expect, it } from "vitest";

import { enviandoEste } from "../app/rotas/contratante/comum";

const formulario = (dados: Record<string, string>) => new URLSearchParams(dados) as unknown as FormData;
const enviando = (dados: Record<string, string>) => ({ formData: formulario(dados) });

describe("rótulo de envio por formulário", () => {
  it("só o formulário enviado mostra o texto de andamento", () => {
    const cancelando = enviando({ intencao: "cancelar" });
    expect(enviandoEste(cancelando, "cancelar")).toBe(true);
    expect(enviandoEste(cancelando, "repetir")).toBe(false);
    expect(enviandoEste(cancelando, "restantes")).toBe(false);
    expect(enviandoEste(cancelando, "escolher")).toBe(false);
  });

  it("entre os candidatos, só o botão do escolhido muda", () => {
    const escolhendo = enviando({ intencao: "escolher", candidatura_id: "a" });
    expect(enviandoEste(escolhendo, "escolher", "a")).toBe(true);
    expect(enviandoEste(escolhendo, "escolher", "b")).toBe(false);
  });

  it("parado, ou navegando sem formulário (carregando a página), nenhum botão muda", () => {
    expect(enviandoEste({ formData: undefined }, "cancelar")).toBe(false);
    expect(enviandoEste({}, "cancelar")).toBe(false);
  });
});
