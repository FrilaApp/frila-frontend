/**
 * Vários membros na mesma casa (3.16) e o link de convite (5.7): o administrador convida por e-mail e papel
 * (`convidar_membro`, token de uso único, 7 dias) e quem recebeu o link aceita (`aceitar_convite_membro`). O token é
 * um segredo de portador: vai no fragmento do link (`#…`, que o navegador não manda ao servidor) e no corpo do POST,
 * nunca em URL de pedido, cookie ou log. Remover e transferir a administração pedem a lista dos membros, que o
 * contrato ainda não tem.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import { ehUuid } from "./publicar-vaga";

export type Papel = components["schemas"]["PapelMembro"];
export const PAPEIS: readonly Papel[] = ["operador", "administrador"];
const TOKEN = /^[0-9a-f]{64}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const prazo = () => AbortSignal.timeout(8000);

export type Convite = { ok: true; token: string; expiraEm: string } | { ok: false; motivo: "email" | "papel" | "so_administrador" | "nao_encontrado" | "sem_sessao" | "indisponivel" };

export async function convidarMembro(api: Api | null, casaId: string, email: string, papel: string): Promise<Convite> {
  if (!EMAIL.test(email)) return { ok: false, motivo: "email" };
  if (!PAPEIS.includes(papel as Papel)) return { ok: false, motivo: "papel" };
  if (!ehUuid(casaId)) return { ok: false, motivo: "nao_encontrado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/convidar_membro", { body: { estabelecimento_id: casaId, email, papel: papel as Papel }, signal: prazo() });
    if (data && TOKEN.test(data.token)) return { ok: true, token: data.token, expiraEm: data.expira_em };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "so_administrador" };
    if (response.status === 404) return { ok: false, motivo: "nao_encontrado" };
    if (response.status === 422 && error?.details === "email") return { ok: false, motivo: "email" };
    if (response.status === 422 && error?.details === "papel") return { ok: false, motivo: "papel" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type Aceite = { ok: true; casaId: string | null } | { ok: false; motivo: "convite_invalido" | "perfil_incompativel" | "sem_sessao" | "indisponivel" };

export async function aceitarConvite(api: Api | null, token: string): Promise<Aceite> {
  if (!TOKEN.test(token)) return { ok: false, motivo: "convite_invalido" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/aceitar_convite_membro", { body: { token }, signal: prazo() });
    if (data) return { ok: true, casaId: data.estabelecimento_id && ehUuid(data.estabelecimento_id) ? data.estabelecimento_id : null };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 422 && error?.code === "perfil_incompativel") return { ok: false, motivo: "perfil_incompativel" };
    if (response.status === 422) return { ok: false, motivo: "convite_invalido" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
