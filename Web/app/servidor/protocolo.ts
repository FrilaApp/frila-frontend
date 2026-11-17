/** O protocolo como o app mostra (contrato 0.2.40): o curto e as datas, no fuso de Brasília. */
const dia = new Intl.DateTimeFormat("pt-BR", { timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit", year: "numeric" });

/** Os 8 primeiros caracteres hexadecimais da ocorrência, sem hífens, em maiúsculas. */
export function protocoloCurto(ocorrenciaId: string): string {
  return ocorrenciaId.replaceAll("-", "").slice(0, 8).toUpperCase();
}

/** Instante → "15/11/2026", no fuso de Brasília. */
export function dataDoInstante(instante: string): string {
  return dia.format(new Date(instante));
}

/** Data civil "2026-11-23" → "23/11/2026", sem passar por fuso (é uma data, não um instante). */
export function dataCivil(aaaaMmDd: string): string {
  const [ano, mes, diaDoMes] = aaaaMmDd.split("-");
  return `${diaDoMes}/${mes}/${ano}`;
}
