import { describe, expect, it, vi } from "vitest";

import { corpoDoEvento, registrarEvento } from "../app/servidor/eventos";

const VAGA = "9c6259b0-0000-4000-8000-000000000001";

describe("eventos de uso (registrar_evento)", () => {
  it("o corpo leva só o evento do dicionário e ids que são uuid, sem texto livre nem hora do Worker", () => {
    expect(corpoDoEvento("candidatura_enviada", { vaga_id: VAGA })).toEqual({ evento: "candidatura_enviada", vaga_id: VAGA });
    expect(corpoDoEvento("checkin_tentado", { turno_id: "nao-e-uuid" })).toEqual({ evento: "checkin_tentado" });
    expect(corpoDoEvento("cadastro_concluido")).toEqual({ evento: "cadastro_concluido" });
  });

  it("fora do Worker não sai nada e nunca lança: a resposta da tela não depende dele", async () => {
    const buscar = vi.spyOn(globalThis, "fetch");
    expect(() => registrarEvento({ acesso: "token-sintetico", usuarioId: null, email: null, visitante: null }, "vaga_detalhe_aberto", { vaga_id: VAGA })).not.toThrow();
    await new Promise((r) => setTimeout(r, 20));
    expect(buscar).not.toHaveBeenCalled();
    buscar.mockRestore();
  });
});
