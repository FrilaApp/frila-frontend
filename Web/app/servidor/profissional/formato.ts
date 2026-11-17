/**
 * Valor, data e distância como a tela mostra, no fuso de Brasília. Roda no loader (servidor), então o HTML e a
 * página no navegador mostram o mesmo texto.
 */
import { textos } from "../../textos/pt-BR";

const FUSO = "America/Sao_Paulo";

const reais = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const dia = new Intl.DateTimeFormat("pt-BR", { timeZone: FUSO, weekday: "short", day: "2-digit", month: "2-digit" });
const hora = new Intl.DateTimeFormat("pt-BR", { timeZone: FUSO, hour: "2-digit", minute: "2-digit" });
const km = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 1 });

export function formatarValor(centavos: number): string {
  return reais.format(centavos / 100);
}

/** "sex., 21/11 · 19:00 às 02:00" */
export function formatarPeriodo(inicioEm: string, fimEm: string): string {
  const inicio = new Date(inicioEm);
  const fim = new Date(fimEm);
  const horario = textos.profissional.periodo.replace("{inicio}", hora.format(inicio)).replace("{fim}", hora.format(fim));
  return `${dia.format(inicio)} · ${horario}`;
}

export function formatarDistancia(distanciaKm: number): string {
  return textos.profissional.vagas.distanciaEmKm.replace("{km}", km.format(distanciaKm));
}
