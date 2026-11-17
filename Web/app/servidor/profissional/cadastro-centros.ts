/**
 * Centro de cada Região Administrativa do DF, pelo id do catálogo (`GET /regiao_administrativa`: RA I = 1).
 * É o ponto base de quem se cadastra pela web: a pessoa escolhe a região e o servidor da web põe o centro dela.
 * A tabela é a mesma do app Android (`GeocodificadorDfOffline.REGIOES_ADMINISTRATIVAS`), para os dois darem o
 * mesmo ponto. Região que ainda não está aqui não aparece na escolha do ponto base. Fica só no servidor.
 */
import type { components } from "../../contrato/tipos.gerado";

export type Coordenada = components["schemas"]["Coordenada"];

export const CENTRO_DA_REGIAO: Readonly<Record<number, Coordenada>> = {
  1: { latitude: -15.793889, longitude: -47.882778 }, // Plano Piloto
  2: { latitude: -16.016667, longitude: -48.066667 }, // Gama
  3: { latitude: -15.833333, longitude: -48.056944 }, // Taguatinga
  4: { latitude: -15.666667, longitude: -48.2 }, // Brazlândia
  5: { latitude: -15.65, longitude: -47.783333 }, // Sobradinho
  6: { latitude: -15.616667, longitude: -47.65 }, // Planaltina
  7: { latitude: -15.766667, longitude: -47.783333 }, // Paranoá
  8: { latitude: -15.866667, longitude: -47.966667 }, // Núcleo Bandeirante
  9: { latitude: -15.816667, longitude: -48.116667 }, // Ceilândia
  10: { latitude: -15.816667, longitude: -47.983333 }, // Guará
  11: { latitude: -15.791667, longitude: -47.936111 }, // Cruzeiro
  12: { latitude: -15.875, longitude: -48.086111 }, // Samambaia
  13: { latitude: -16.016667, longitude: -47.983333 }, // Santa Maria
  14: { latitude: -15.9, longitude: -47.766667 }, // São Sebastião
  15: { latitude: -15.908333, longitude: -48.066667 }, // Recanto das Emas
  16: { latitude: -15.84, longitude: -47.87 }, // Lago Sul
  17: { latitude: -15.883333, longitude: -48.016667 }, // Riacho Fundo
  18: { latitude: -15.733333, longitude: -47.85 }, // Lago Norte
  19: { latitude: -15.85, longitude: -47.95 }, // Candangolândia
  20: { latitude: -15.839722, longitude: -48.026389 }, // Águas Claras
  21: { latitude: -15.9, longitude: -48.033333 }, // Riacho Fundo II
  22: { latitude: -15.796944, longitude: -47.925 }, // Sudoeste/Octogonal
  23: { latitude: -15.716667, longitude: -47.883333 }, // Varjão
  24: { latitude: -15.89, longitude: -47.95 }, // Park Way
  25: { latitude: -15.783333, longitude: -47.983333 }, // SCIA/Estrutural
  26: { latitude: -15.633333, longitude: -47.8 }, // Sobradinho II
  27: { latitude: -15.883333, longitude: -47.816667 }, // Jardim Botânico
  28: { latitude: -15.75, longitude: -47.766667 }, // Itapoã
  29: { latitude: -15.816667, longitude: -47.95 }, // SIA
  30: { latitude: -15.808333, longitude: -48.033333 }, // Vicente Pires
  31: { latitude: -15.583333, longitude: -47.883333 }, // Fercal
  32: { latitude: -15.825, longitude: -48.14 }, // Sol Nascente/Pôr do Sol
  33: { latitude: -15.866667, longitude: -48.016667 }, // Arniqueira
  34: { latitude: -15.63, longitude: -47.69 }, // Arapoanga
  35: { latitude: -16.0, longitude: -48.166667 }, // Água Quente
};

export function centroDaRegiao(id: number): Coordenada | null {
  return CENTRO_DA_REGIAO[id] ?? null;
}
