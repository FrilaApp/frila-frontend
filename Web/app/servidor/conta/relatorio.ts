/**
 * Relatório dos turnos para baixar (3.17, Edge Function `exportar-turnos`): CSV ou PDF de um período de até 30 dias,
 * com data, função, horários, valor acordado e a outra parte. Com `estabelecimento_id`, os turnos da casa; sem ele,
 * os do profissional. O arquivo passa direto do servidor ao navegador (sem ficar guardado).
 */
import type { FuncoesDoUsuario } from "./dados";

export type Formato = "csv" | "pdf";
const DIA = /^\d{4}-\d{2}-\d{2}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PedidoDoRelatorio = { de: string; ate: string; formato: Formato; estabelecimento_id?: string };

/** Dias do DF (UTC−3) em instantes: do começo do primeiro ao fim do último. O limite de 30 dias é do servidor. */
export function lerPedido(campos: { de: string; ate: string; formato: string; casa: string }): PedidoDoRelatorio | null {
  if (!DIA.test(campos.de) || !DIA.test(campos.ate)) return null;
  if (campos.formato !== "csv" && campos.formato !== "pdf") return null;
  if (campos.casa && !UUID.test(campos.casa)) return null;
  const de = new Date(`${campos.de}T00:00:00-03:00`);
  const ate = new Date(`${campos.ate}T23:59:59-03:00`);
  if (Number.isNaN(de.getTime()) || Number.isNaN(ate.getTime())) return null;
  return { de: de.toISOString(), ate: ate.toISOString(), formato: campos.formato, ...(campos.casa ? { estabelecimento_id: campos.casa } : {}) };
}

export type Relatorio =
  | { ok: true; corpo: ReadableStream<Uint8Array>; tipo: string }
  | { ok: false; motivo: "vazio" | "intervalo" | "datas" | "sem_permissao" | "sem_sessao" | "indisponivel" };

export async function exportarTurnos(funcoes: FuncoesDoUsuario | null, pedido: PedidoDoRelatorio): Promise<Relatorio> {
  if (!funcoes) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await funcoes.POST("/exportar-turnos", { body: pedido, parseAs: "stream", signal: AbortSignal.timeout(20000) });
    // 204: o período não tem turnos, e nenhum arquivo vazio é gerado.
    if (response.status === 204) return { ok: false, motivo: "vazio" };
    if (response.ok && data) return { ok: true, corpo: data, tipo: response.headers.get("Content-Type") ?? (pedido.formato === "pdf" ? "application/pdf" : "text/csv") };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "sem_permissao" };
    const codigo = (error as { code?: string } | undefined)?.code;
    if (response.status === 422) return { ok: false, motivo: codigo === "intervalo_maximo_excedido" ? "intervalo" : "datas" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
