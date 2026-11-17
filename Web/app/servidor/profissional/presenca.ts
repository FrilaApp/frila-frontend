/**
 * Presença do profissional: chegada (`fazer_checkin`), o código que a casa mostra (`validar_codigo_checkin`) e a saída
 * (`fazer_checkout`). A web manda só a distância até o local, medida no navegador no toque (nunca a coordenada), e
 * nenhum `sinais` (opcional no contrato). A hora que vale é a do servidor; quem decide janela, raio e bloqueio também.
 */
import type { Api } from "../api";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const prazo = () => AbortSignal.timeout(8000);

export type FalhaDaPresenca =
  | "fora_da_janela"
  | "turno_cancelado"
  | "sem_localizacao"
  | "fora_do_raio"
  | "codigo_invalido"
  | "codigo_bloqueado"
  | "checkin_pendente"
  | "nao_encontrado"
  | "sem_permissao"
  | "sem_sessao"
  | "indisponivel";

export type ResultadoDaPresenca =
  | { ok: true; verificado: boolean }
  | { ok: false; motivo: FalhaDaPresenca };

type Resposta = { data?: { verificacao: string }; error?: { code?: string; details?: string | null }; response: Response };

function traduzir({ data, error, response }: Resposta): ResultadoDaPresenca {
  if (data) return { ok: true, verificado: data.verificacao === "verificado" };
  const codigo = error?.code;
  if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
  if (response.status === 403) return { ok: false, motivo: "sem_permissao" };
  if (response.status === 404) return { ok: false, motivo: "nao_encontrado" };
  if (response.status === 409 && codigo === "vaga_encerrada") return { ok: false, motivo: "turno_cancelado" };
  if (response.status === 409 && codigo === "codigo_bloqueado") return { ok: false, motivo: "codigo_bloqueado" };
  if (response.status === 409 && codigo === "checkin_pendente") return { ok: false, motivo: "checkin_pendente" };
  if (response.status === 422) {
    if (codigo === "fora_da_janela" || codigo === "registro_no_futuro") return { ok: false, motivo: "fora_da_janela" };
    if (codigo === "sem_localizacao" || codigo === "fora_do_raio" || codigo === "codigo_invalido") return { ok: false, motivo: codigo };
  }
  return { ok: false, motivo: "indisponivel" };
}

/** Metros inteiros, ou nulo quando o navegador não deu a posição (campo vazio ou torto). */
export function distanciaDoFormulario(valor: FormDataEntryValue | null): number | null {
  const texto = typeof valor === "string" ? valor.trim() : "";
  if (!/^\d{1,7}$/.test(texto)) return null;
  return Number(texto);
}

async function enviar(chamada: () => Promise<Resposta>): Promise<ResultadoDaPresenca> {
  try {
    return traduzir(await chamada());
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

/** Cheguei. Com o check-in por código ligado, a presença fica pendente até o código da casa. */
export async function marcarChegada(api: Api | null, turnoId: string, distanciaM: number | null): Promise<ResultadoDaPresenca> {
  if (!UUID.test(turnoId)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  const registradoEm = new Date().toISOString();
  return enviar(() =>
    api.POST("/rpc/fazer_checkin", { body: { turno_id: turnoId, distancia_m: distanciaM, registrado_em: registradoEm }, signal: prazo() }),
  );
}

export async function validarCodigo(api: Api | null, turnoId: string, codigo: string, distanciaM: number | null): Promise<ResultadoDaPresenca> {
  if (!UUID.test(turnoId)) return { ok: false, motivo: "nao_encontrado" };
  if (!/^\d{6}$/.test(codigo)) return { ok: false, motivo: "codigo_invalido" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  return enviar(() =>
    api.POST("/rpc/validar_codigo_checkin", { body: { turno_id: turnoId, codigo, distancia_m: distanciaM }, signal: prazo() }),
  );
}

export async function marcarSaida(api: Api | null, turnoId: string, distanciaM: number | null): Promise<ResultadoDaPresenca> {
  if (!UUID.test(turnoId)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  const registradoEm = new Date().toISOString();
  return enviar(() =>
    api.POST("/rpc/fazer_checkout", { body: { turno_id: turnoId, distancia_m: distanciaM, registrado_em: registradoEm }, signal: prazo() }),
  );
}
