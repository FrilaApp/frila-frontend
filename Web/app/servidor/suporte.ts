/**
 * Suporte a partir de um turno (abrir_suporte). O Frila registra o chamado e devolve o protocolo, mas não envia
 * e-mail nem guarda o texto da pessoa (RN15): a tela abre o e-mail para suporte@frilabr.com com o protocolo curto no
 * assunto e os dados do turno no corpo, e a pessoa escreve o relato lá. Idempotente pela chave.
 */
import type { components } from "../contrato/tipos.gerado";
import type { Api } from "./api";
import { dataCivil, protocoloCurto } from "./protocolo";

type Protocolo = components["schemas"]["Protocolo"];
export type TurnoDoSuporte = components["schemas"]["Turno"];
export type CategoriaDoSuporte = components["schemas"]["CategoriaSuporte"];

export const EMAIL_DO_SUPORTE = "suporte@frilabr.com";
export const CATEGORIAS: readonly CategoriaDoSuporte[] = ["seguranca", "atraso", "endereco", "conduta", "outro"];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ehCategoria = (valor: string): valor is CategoriaDoSuporte => (CATEGORIAS as readonly string[]).includes(valor);

/** O turno sai da lista de quem chama: a do profissional, ou a da casa quando vem `casaId`. */
export async function lerTurnoDoSuporte(api: Api | null, turnoId: string, casaId: string | null): Promise<TurnoDoSuporte | "nao_encontrado" | "indisponivel"> {
  if (!api) return "indisponivel";
  if (casaId !== null && !UUID.test(casaId)) return "nao_encontrado";
  try {
    const opcoes = casaId ? { params: { query: { estabelecimento_id: casaId } } } : {};
    const { data, response } = await api.GET("/rpc/meus_turnos", { ...opcoes, signal: AbortSignal.timeout(5000) });
    if (!data) return response.status === 403 ? "nao_encontrado" : "indisponivel";
    return data.find((turno) => turno.id === turnoId) ?? "nao_encontrado";
  } catch {
    return "indisponivel";
  }
}

export type ResultadoDoSuporte =
  | { ok: true; protocolo: Protocolo }
  | { ok: false; motivo: "categoria" | "conta_suspensa" | "limite" | "nao_encontrado" | "sem_sessao" | "indisponivel" };

export async function abrirSuporte(api: Api | null, turnoId: string, categoria: string, chave: string): Promise<ResultadoDoSuporte> {
  if (!ehCategoria(categoria)) return { ok: false, motivo: "categoria" };
  if (!UUID.test(turnoId) || !UUID.test(chave)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, response } = await api.POST("/rpc/abrir_suporte", { body: { turno_id: turnoId, categoria, chave }, signal: AbortSignal.timeout(8000) });
    if (data) return { ok: true, protocolo: data };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "conta_suspensa" };
    if (response.status === 404) return { ok: false, motivo: "nao_encontrado" };
    if (response.status === 429) return { ok: false, motivo: "limite" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type DadosDoEmail = {
  turnoId: string;
  funcao: string;
  outraParte: string;
  lado: "profissional" | "casa";
  horario: string;
  local: string;
  motivo: string;
};

/** Assunto e corpo como o app monta (SuporteTurnoViewModel), sem o relato: a pessoa escreve no próprio e-mail. */
export function emailDoSuporte(protocolo: Protocolo, dados: DadosDoEmail) {
  const numero = protocoloCurto(protocolo.ocorrencia_id);
  const assunto = `[Frila Suporte #${numero}] ${dados.funcao}`;
  const corpo = [
    "Identificação do Turno:",
    `- ID: ${dados.turnoId}`,
    `- Função: ${dados.funcao}`,
    `- ${dados.lado === "profissional" ? "Contratante" : "Profissional"}: ${dados.outraParte}`,
    `- Horário: ${dados.horario}`,
    `- Local: ${dados.local}`,
    `- Protocolo: #${numero}`,
    `- Prazo de resposta: até ${dataCivil(protocolo.prazo_resposta_ate)}`,
    "",
    "Motivo do Chamado:",
    dados.motivo,
    "",
    "Relato:",
    "",
  ].join("\n");
  const link = `mailto:${EMAIL_DO_SUPORTE}?subject=${encodeURIComponent(assunto)}&body=${encodeURIComponent(corpo)}`;
  return { assunto, corpo, link };
}
