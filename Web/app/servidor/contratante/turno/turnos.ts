/**
 * O dia do turno, do lado da casa: as casas da conta (meus_estabelecimentos) e os turnos de uma casa
 * (meus_turnos?estabelecimento_id). Os gestos do dia (código, confirmação, atraso) ficam em `presenca.ts`.
 */
import type { components } from "../../../contrato/tipos.gerado";
import type { Api } from "../../api";

export type CasaDaConta = components["schemas"]["EstabelecimentoDaConta"];
export type TurnoDaCasa = components["schemas"]["Turno"];

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const prazo = (ms: number) => AbortSignal.timeout(ms);

export type LeituraDasCasas =
  | { estado: "ok"; casas: CasaDaConta[] }
  | { estado: "perfil_incompativel" | "conta_suspensa" | "indisponivel" };

/** Lista vazia é legítima (conta nova, antes do primeiro cadastro); conta de profissional recebe 422. */
export async function listarMinhasCasas(api: Api | null): Promise<LeituraDasCasas> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/meus_estabelecimentos", { signal: prazo(5000) });
    if (data) return { estado: "ok", casas: data };
    if (response.status === 422) return { estado: "perfil_incompativel" };
    return { estado: response.status === 403 ? "conta_suspensa" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

export type LeituraDosTurnosDaCasa = { estado: "ok"; turnos: TurnoDaCasa[] } | { estado: "sem_permissao" | "indisponivel" };

/** Hoje e os próximos primeiro (ordem do servidor). Quem não é membro da casa recebe 403. */
export async function listarTurnosDaCasa(api: Api | null, casaId: string): Promise<LeituraDosTurnosDaCasa> {
  if (!UUID.test(casaId)) return { estado: "sem_permissao" };
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/meus_turnos", {
      params: { query: { estabelecimento_id: casaId } },
      signal: prazo(5000),
    });
    if (data) return { estado: "ok", turnos: data };
    return { estado: response.status === 403 ? "sem_permissao" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

/** A casa da tela: a do endereço (?casa=), se for da conta; senão a primeira (a lista vem por nome). */
export function casaDaTela(casas: CasaDaConta[], pedida: string | null): CasaDaConta | null {
  return casas.find((casa) => casa.id === pedida) ?? casas[0] ?? null;
}

/** Em que pé está a chegada, pelo que o turno diz; quem decide a verificação é o servidor. */
export function chegadaDo(turno: TurnoDaCasa): "saiu" | "verificada" | "naoVerificada" | "pendente" | "aCaminho" | "aguardando" {
  if (turno.checkout_em) return "saiu";
  if (turno.verificacao === "verificado") return "verificada";
  if (turno.verificacao === "nao_verificado") return "naoVerificada";
  if (turno.checkin_em) return "pendente";
  return turno.a_caminho_em ? "aCaminho" : "aguardando";
}
