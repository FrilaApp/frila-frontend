import { describe, expect, it } from "vitest";

import { turnoDaVaga } from "../scripts/turno-da-vaga.mjs";

// Incidente de 17/11, 04h31: a prova pegava o primeiro turno confirmado da lista e agiu num turno de outra vaga.
const VAGA = "9c6259b0-431f-4fc3-9fa3-9d47dbcbdb7a";
const OUTRA = "1111aaaa-431f-4fc3-9fa3-9d47dbcbdb7a";
const turno = (id: string, vagaId: string, estado = "confirmada") => ({ id, estado, vaga: { id: vagaId } });

describe("a prova do turno escolhe o turno pela vaga dada", () => {
  it("acha o turno da vaga, mesmo com outro confirmado antes na lista", () => {
    const turnos = [turno("f14eb6f5-0000-4000-8000-000000000000", OUTRA), turno("001b6684-0000-4000-8000-000000000000", VAGA, "cumprida")];
    expect(turnoDaVaga(turnos, VAGA)).toEqual({ turnoId: "001b6684-0000-4000-8000-000000000000" });
  });

  it("recusa (nunca cai no primeiro da lista) quando a vaga não tem turno da pessoa", () => {
    expect(turnoDaVaga([turno("f14eb6f5-0000-4000-8000-000000000000", OUTRA)], VAGA)).toEqual({ recusa: "sem_turno_da_vaga" });
    expect(turnoDaVaga([], VAGA)).toEqual({ recusa: "sem_turno_da_vaga" });
  });

  it("ignora o turno cancelado da vaga; dois de pé na mesma vaga é ambíguo e recusa", () => {
    const cancelado = turno("aaaa0000-0000-4000-8000-000000000000", VAGA, "cancelada");
    const dePe = turno("bbbb0000-0000-4000-8000-000000000000", VAGA);
    expect(turnoDaVaga([cancelado, dePe], VAGA)).toEqual({ turnoId: "bbbb0000-0000-4000-8000-000000000000" });
    expect(turnoDaVaga([cancelado], VAGA)).toEqual({ recusa: "sem_turno_da_vaga" });
    expect(turnoDaVaga([dePe, turno("cccc0000-0000-4000-8000-000000000000", VAGA)], VAGA)).toEqual({ recusa: "mais_de_um_turno_da_vaga" });
  });

  it("vaga ausente ou torta recusa antes de olhar a lista; resposta que não é lista também", () => {
    expect(turnoDaVaga([turno("x", VAGA)], undefined)).toEqual({ recusa: "vaga_invalida" });
    expect(turnoDaVaga([turno("x", VAGA)], "lixo")).toEqual({ recusa: "vaga_invalida" });
    expect(turnoDaVaga({ code: "nao_autenticado" }, VAGA)).toEqual({ recusa: "sem_lista" });
  });
});
