import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";

export type CasaDaConta = components["schemas"]["EstabelecimentoDaConta"];
export type CadastroDaCasa = components["schemas"]["MeuEstabelecimento"];

export const PRAZO_MS = 5000;
export const prazo = () => AbortSignal.timeout(PRAZO_MS);

export type LeituraDasCasas =
  | { estado: "ok"; casas: CasaDaConta[] }
  /** Conta de profissional: o contrato responde 422 perfil_incompativel, e não lista vazia. */
  | { estado: "perfil_profissional" }
  | { estado: "conta_suspensa" }
  | { estado: "sem_sessao" }
  | { estado: "indisponivel" };

/** As casas de que a conta é membro, na ordem do servidor (por nome). Lista vazia é resposta legítima. */
export async function lerMinhasCasas(api: Api | null): Promise<LeituraDasCasas> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, error, response } = await api.GET("/rpc/meus_estabelecimentos", { signal: prazo() });
    if (data) return { estado: "ok", casas: data };
    if (response.status === 401) return { estado: "sem_sessao" };
    if (response.status === 403) return { estado: "conta_suspensa" };
    if (response.status === 422 && error?.code === "perfil_incompativel") return { estado: "perfil_profissional" };
    return { estado: "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

/** A casa pedida no endereço, se a conta é membro dela; senão, a primeira da lista. */
export function escolherCasa(casas: CasaDaConta[], pedida: string | null): CasaDaConta | null {
  return casas.find((casa) => casa.id === pedida) ?? casas[0] ?? null;
}

export type LeituraDoCadastro =
  | { estado: "ok"; casa: CadastroDaCasa }
  /** Não é membro, ou a casa não existe: o contrato responde 403 nos dois casos. */
  | { estado: "sem_permissao" }
  | { estado: "sem_sessao" }
  | { estado: "indisponivel" };

/** Endereço, região e ponto da casa, que a publicação usa. Sem o documento (RN15). */
export async function lerCadastroDaCasa(api: Api | null, casaId: string): Promise<LeituraDoCadastro> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/meu_estabelecimento", {
      params: { query: { estabelecimento_id: casaId } },
      signal: prazo(),
    });
    if (data) return { estado: "ok", casa: data };
    if (response.status === 401) return { estado: "sem_sessao" };
    if (response.status === 403) return { estado: "sem_permissao" };
    return { estado: "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}
