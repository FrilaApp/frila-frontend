/**
 * O perfil do profissional, visto pela casa (perfil_publico). A reputação vem sempre com denominador; sem histórico,
 * "Sem histórico", nunca nota zero (RN08). Entre partes bloqueadas o servidor responde 404, igual a um id que não
 * existe: a tela diz "perfil indisponível" e não revela o bloqueio. Nenhum contato sai por aqui (RN10).
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";

export type PerfilDoProfissional = components["schemas"]["PerfilPublico"];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type LeituraDoPerfil = { estado: "ok"; perfil: PerfilDoProfissional } | { estado: "nao_encontrado" | "indisponivel" };

export async function lerPerfilDoProfissional(api: Api | null, profissionalId: string): Promise<LeituraDoPerfil> {
  if (!UUID.test(profissionalId)) return { estado: "nao_encontrado" };
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/perfil_publico", { params: { query: { id: profissionalId } }, signal: AbortSignal.timeout(5000) });
    if (data) return data.tipo === "profissional" ? { estado: "ok", perfil: data } : { estado: "nao_encontrado" };
    return { estado: response.status === 404 ? "nao_encontrado" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

/** O "voltar" só aceita caminho dentro da área da casa (nada de outro site nem de //). */
export function caminhoDeVolta(pedido: string | null): string {
  return pedido && /^\/(painel|casa)(\/[\w\-/]*)?(\?[\w\-=&%]*)?$/.test(pedido) ? pedido : "/painel";
}
