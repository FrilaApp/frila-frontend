/**
 * Equipe de confiança da casa (3.9): ver (equipe_de_confianca), incluir (incluir_na_equipe) e remover
 * (remover_da_equipe). Quem está na equipe recebe as vagas da casa mesmo além de 15 km. Só o administrador muda a
 * equipe, e só entra quem já cumpriu um turno com presença verificada na casa: quem decide é o servidor (403 com o
 * motivo em `details`); a tela só traduz.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import { ehUuid } from "./publicar-vaga";

export type MembroDaEquipe = components["schemas"]["PerfilPublico"];

const prazo = () => AbortSignal.timeout(5000);

export type LeituraDaEquipe = { estado: "ok"; membros: MembroDaEquipe[] } | { estado: "sem_permissao" | "sem_sessao" | "indisponivel" };

export async function lerEquipe(api: Api | null, casaId: string): Promise<LeituraDaEquipe> {
  if (!ehUuid(casaId)) return { estado: "sem_permissao" };
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/equipe_de_confianca", { params: { query: { estabelecimento_id: casaId } }, signal: prazo() });
    if (data) return { estado: "ok", membros: data };
    if (response.status === 401) return { estado: "sem_sessao" };
    return { estado: response.status === 403 ? "sem_permissao" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type FalhaNaEquipe = "sem_turno_cumprido" | "so_administrador" | "conta_suspensa" | "nao_encontrado" | "sem_sessao" | "indisponivel";
export type MudancaNaEquipe = { ok: true } | { ok: false; motivo: FalhaNaEquipe };

/** Incluir e remover são idempotentes: repetir o mesmo pedido devolve o mesmo resultado. */
export async function mudarEquipe(api: Api | null, gesto: "incluir" | "remover", casaId: string, profissionalId: string): Promise<MudancaNaEquipe> {
  if (!ehUuid(casaId) || !ehUuid(profissionalId)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  const caminho = gesto === "incluir" ? "/rpc/incluir_na_equipe" : "/rpc/remover_da_equipe";
  try {
    const { data, error, response } = await api.POST(caminho, { body: { estabelecimento_id: casaId, profissional_id: profissionalId }, signal: prazo() });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) {
      if (error?.details === "sem_turno_cumprido") return { ok: false, motivo: "sem_turno_cumprido" };
      if (error?.details === "conta_suspensa") return { ok: false, motivo: "conta_suspensa" };
      return { ok: false, motivo: "so_administrador" };
    }
    if (response.status === 404) return { ok: false, motivo: "nao_encontrado" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
