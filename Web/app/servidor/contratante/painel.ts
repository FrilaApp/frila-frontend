import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import { prazo } from "./casa";

export type Painel = components["schemas"]["Painel"];
export type VagaNoPainel = components["schemas"]["VagaNoPainel"];

/** "Hoje e em breve": o turno que começou há pouco ainda aparece, e as próximas duas semanas. */
export const HORAS_ANTES = 12;
export const DIAS_DEPOIS = 14;

export function janelaDoPainel(agora: Date): { de: string; ate: string } {
  const de = new Date(agora.getTime() - HORAS_ANTES * 3_600_000);
  const ate = new Date(agora.getTime() + DIAS_DEPOIS * 86_400_000);
  return { de: de.toISOString(), ate: ate.toISOString() };
}

export type LeituraDoPainel =
  | { estado: "ok"; painel: Painel }
  | { estado: "sem_permissao" }
  | { estado: "sem_sessao" }
  | { estado: "indisponivel" };

export async function lerPainel(api: Api | null, casaId: string, agora: Date): Promise<LeituraDoPainel> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/painel_estabelecimento", {
      params: { query: { estabelecimento_id: casaId, ...janelaDoPainel(agora) } },
      signal: prazo(),
    });
    if (data) return { estado: "ok", painel: data };
    if (response.status === 401) return { estado: "sem_sessao" };
    if (response.status === 403) return { estado: "sem_permissao" };
    return { estado: "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

const FUSO = "America/Sao_Paulo";
const dia = new Intl.DateTimeFormat("pt-BR", { timeZone: FUSO, weekday: "short", day: "2-digit", month: "2-digit" });
const hora = new Intl.DateTimeFormat("pt-BR", { timeZone: FUSO, hour: "2-digit", minute: "2-digit" });
const real = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });

/** Data e hora no fuso do DF, formatadas no servidor (a página não depende do relógio do navegador). */
export function quandoDaVaga(inicio: string, fim: string): { dia: string; horario: string } {
  return { dia: dia.format(new Date(inicio)), horario: `${hora.format(new Date(inicio))}–${hora.format(new Date(fim))}` };
}

export const valorEmReais = (centavos: number) => real.format(centavos / 100);

export type VagaNaTela = {
  id: string;
  funcao: string;
  dia: string;
  horario: string;
  valor: string;
  estado: VagaNoPainel["estado"];
  oculta: boolean;
  alertaVagaVazia: boolean;
  candidatosPendentes: number;
  posicoes: number;
  ocupadas: number;
};

/** O que a tela do painel mostra de cada vaga, na ordem do início. */
export function vagasParaATela(painel: Painel): VagaNaTela[] {
  return [...painel.vagas]
    .sort((a, b) => a.vaga.inicio_em.localeCompare(b.vaga.inicio_em))
    .map((item) => ({
      id: item.vaga.id,
      funcao: item.vaga.funcao,
      ...quandoDaVaga(item.vaga.inicio_em, item.vaga.fim_em),
      valor: valorEmReais(item.vaga.valor_centavos),
      estado: item.estado,
      oculta: item.oculta,
      alertaVagaVazia: item.alerta_vaga_vazia,
      candidatosPendentes: item.candidatos_pendentes,
      posicoes: item.posicoes.filter((posicao) => posicao.estado !== "cancelada").length,
      ocupadas: item.posicoes.filter((posicao) => posicao.estado === "confirmada" || posicao.estado === "cumprida").length,
    }));
}
