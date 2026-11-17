import { describe, expect, it } from "vitest";

import { telefoneParaE164 } from "~/servidor/telefone";

describe("telefone para o formato do contrato", () => {
  it("aceita celular e fixo do Brasil, com qualquer pontuação", () => {
    expect(telefoneParaE164("(61) 99999-0000")).toBe("+5561999990000");
    expect(telefoneParaE164("61 3333 4444")).toBe("+556133334444");
    expect(telefoneParaE164("+55 61 99999-0000")).toBe("+5561999990000");
    expect(telefoneParaE164("5561999990000")).toBe("+5561999990000");
    expect(telefoneParaE164("061 99999-0000")).toBe("+5561999990000");
    expect(telefoneParaE164("061 3333-4444")).toBe("+556133334444");
  });

  it("não confunde o DDD 55 com o código do país", () => {
    expect(telefoneParaE164("(55) 99999-0000")).toBe("+5555999990000");
    expect(telefoneParaE164("55 3333-4444")).toBe("+555533334444");
    expect(telefoneParaE164("+55 55 99999-0000")).toBe("+5555999990000");
  });

  it("recusa o que não tem DDD ou não tem o tamanho de um número do Brasil", () => {
    for (const ruim of ["", "99999-0000", "123", "0000000000", "+1 415 555 0100 99", "abc"]) {
      expect(telefoneParaE164(ruim), ruim).toBeNull();
    }
  });

  it("o resultado cabe no formato E.164 do contrato", () => {
    expect(telefoneParaE164("(11) 98888-7777")).toMatch(/^\+[1-9][0-9]{7,14}$/);
  });
});
