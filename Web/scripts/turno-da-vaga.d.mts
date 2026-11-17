export function turnoDaVaga(
  turnos: unknown,
  vagaId: string | undefined,
): { turnoId: string } | { recusa: "vaga_invalida" | "dado_fixo_de_demonstracao" | "sem_lista" | "sem_turno_da_vaga" | "mais_de_um_turno_da_vaga" };
