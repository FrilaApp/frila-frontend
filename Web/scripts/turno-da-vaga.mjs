// Qual turno a prova do turno pode tocar: só o da vaga dada, e só se houver exatamente um de pé.
// Nunca o primeiro da lista (incidente de 17/11, 04h31: a prova agiu num turno de outra vaga).
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** @param {unknown} turnos a resposta de meus_turnos @param {string | undefined} vagaId */
export function turnoDaVaga(turnos, vagaId) {
  if (!vagaId || !UUID.test(vagaId)) return { recusa: "vaga_invalida" };
  if (!Array.isArray(turnos)) return { recusa: "sem_lista" };
  const daVaga = turnos.filter((t) => t?.vaga?.id === vagaId && t?.estado !== "cancelada");
  if (daVaga.length === 0) return { recusa: "sem_turno_da_vaga" };
  if (daVaga.length > 1) return { recusa: "mais_de_um_turno_da_vaga" };
  return { turnoId: daVaga[0].id };
}
