export function turnoDaVaga(
  turnos: unknown,
  vagaId: string | undefined,
): { turnoId: string } | { recusa: "vaga_invalida" | "sem_lista" | "sem_turno_da_vaga" | "mais_de_um_turno_da_vaga" };
