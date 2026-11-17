import type { components } from "../contrato/tipos.gerado";
import type { Api } from "./api";

export type Usuario = components["schemas"]["Usuario"];

export type LeituraDaConta =
  | { estado: "ok"; nome: string; perfil: Usuario["perfil"] }
  /** Há sessão, mas a pessoa ainda não criou a conta no produto (o 404 do contrato). */
  | { estado: "sem_conta" }
  | { estado: "indisponivel" };

const PRAZO_MS = 5000;

export async function lerMinhaConta(api: Api | null): Promise<LeituraDaConta> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/minha_conta", { signal: AbortSignal.timeout(PRAZO_MS) });
    if (data) return { estado: "ok", nome: data.nome, perfil: data.perfil };
    return { estado: response.status === 404 ? "sem_conta" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}
