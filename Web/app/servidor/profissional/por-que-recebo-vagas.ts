/**
 * "Por que recebo vagas" (RF27): os critérios que decidem a notificação de uma vaga (criterios_de_notificacao) e o
 * pedido de revisão do despacho (pedir_revisao_despacho). O texto é da web; a função só devolve os dados.
 * O relato é texto livre (dado pessoal): vai só no corpo do POST, nunca em URL, cookie ou log, e não volta na tela.
 * Uma contestação por despacho: a segunda é 409, que a tela lê como "já aberta" (sem duplicar no reenvio).
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import type { RecusaDoProfissional } from "./vagas";

export type CriteriosDeNotificacao = components["schemas"]["CriteriosDeNotificacao"];
export type JanelaDeDisponibilidade = components["schemas"]["JanelaDeDisponibilidade"];
export type Protocolo = components["schemas"]["Protocolo"];

export const RELATO_MINIMO = 10;

export type LeituraDosCriterios =
  | { estado: "ok"; criterios: CriteriosDeNotificacao }
  | { estado: "sem_perfil" }
  | { estado: "sem_sessao" }
  | { estado: RecusaDoProfissional };

export async function lerCriteriosDeNotificacao(api: Api | null): Promise<LeituraDosCriterios> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, error, response } = await api.GET("/rpc/criterios_de_notificacao", { signal: AbortSignal.timeout(5000) });
    if (data) return { estado: "ok", criterios: data };
    if (response.status === 401) return { estado: "sem_sessao" };
    if (response.status === 403) return { estado: "conta_suspensa" };
    if (response.status === 404) return { estado: "sem_perfil" };
    if (response.status === 422 && error?.code === "perfil_incompativel") return { estado: "perfil_incompativel" };
    return { estado: "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type ResultadoDoPedidoDeRevisao =
  | { ok: true; protocolo: Protocolo }
  | { ok: false; motivo: "relato_curto" | "ja_aberta" | "conta_suspensa" | "limite" | "sem_sessao" | "indisponivel" };

export async function pedirRevisaoDoDespacho(api: Api | null, relato: string): Promise<ResultadoDoPedidoDeRevisao> {
  const texto = relato.trim();
  if (texto.length < RELATO_MINIMO) return { ok: false, motivo: "relato_curto" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, response } = await api.POST("/rpc/pedir_revisao_despacho", { body: { relato: texto }, signal: AbortSignal.timeout(8000) });
    if (data) return { ok: true, protocolo: data };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "conta_suspensa" };
    if (response.status === 409) return { ok: false, motivo: "ja_aberta" };
    if (response.status === 422) return { ok: false, motivo: "relato_curto" };
    if (response.status === 429) return { ok: false, motivo: "limite" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

/** "Sexta-feira: 18:00 às 02:00 (dia seguinte)": `hora_fim` menor que `hora_inicio` atravessa a meia-noite. */
export function descreverJanela(
  janela: JanelaDeDisponibilidade,
  nomesDosDias: readonly string[],
  modelo: { deAte: string; diaSeguinte: string },
): string {
  const horas = modelo.deAte.replace("{inicio}", janela.hora_inicio).replace("{fim}", janela.hora_fim);
  const sufixo = janela.hora_fim < janela.hora_inicio ? ` ${modelo.diaSeguinte}` : "";
  return `${nomesDosDias[janela.dia_semana] ?? ""}: ${horas}${sufixo}`;
}

const numero = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 1 });

/** O parâmetro vem do servidor como número: 15 sai "15", e uma fração sai com vírgula ("7,5"). */
export function formatarKm(km: number): string {
  return numero.format(km);
}
