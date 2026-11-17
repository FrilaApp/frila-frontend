import type { components } from "../contrato/tipos.gerado";
import type { Api } from "./api";

export type Usuario = components["schemas"]["Usuario"];
export type Perfil = Usuario["perfil"];

export type LeituraDaConta =
  | { estado: "ok"; nome: string; perfil: Perfil; termosVersao: string | null }
  /** Há sessão, mas a pessoa ainda não criou a conta no produto (o 404 do contrato). */
  | { estado: "sem_conta" }
  | { estado: "indisponivel" };

const PRAZO_MS = 5000;
const prazo = () => AbortSignal.timeout(PRAZO_MS);

export async function lerMinhaConta(api: Api | null): Promise<LeituraDaConta> {
  if (!api) return { estado: "indisponivel" };
  try {
    const { data, response } = await api.GET("/rpc/minha_conta", { signal: prazo() });
    if (data) return { estado: "ok", nome: data.nome, perfil: data.perfil, termosVersao: data.termos_versao ?? null };
    return { estado: response.status === 404 ? "sem_conta" : "indisponivel" };
  } catch {
    return { estado: "indisponivel" };
  }
}

export const CAMPOS_DO_CADASTRO = ["perfil", "nome", "telefone", "nascimento", "termos_versao"] as const;
export type CampoDoCadastro = (typeof CAMPOS_DO_CADASTRO)[number];

export type DadosDoCadastro = { perfil: Perfil; nome: string; telefone: string; nascimento: string; termos_versao: string };

export type ResultadoDoCadastro =
  | { ok: true }
  /** O servidor recusou um campo: faltou (`obrigatorio`) ou não serve (`invalido`). */
  | { ok: false; motivo: "campo"; campo: CampoDoCadastro; tipo: "obrigatorio" | "invalido" }
  | { ok: false; motivo: "menor_de_idade" | "ja_existe" | "sem_sessao" | "indisponivel" };

/** Cria a conta. Toda regra (maioridade, nome, telefone, versão dos termos) é do servidor: aqui só se traduz a recusa. */
export async function criarConta(api: Api | null, dados: DadosDoCadastro): Promise<ResultadoDoCadastro> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/criar_conta", { body: dados, signal: prazo() });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 409) return { ok: false, motivo: "ja_existe" };
    if (response.status === 422 && error) {
      if (error.code === "menor_de_idade") return { ok: false, motivo: "menor_de_idade" };
      const campo = CAMPOS_DO_CADASTRO.find((nome) => nome === error.details);
      if (campo && (error.code === "campo_obrigatorio" || error.code === "campo_invalido")) {
        return { ok: false, motivo: "campo", campo, tipo: error.code === "campo_obrigatorio" ? "obrigatorio" : "invalido" };
      }
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

/** Registra o aceite da versão dos Termos que a tela mostrou. O instante é do servidor. */
export async function aceitarTermos(api: Api | null, versao: string): Promise<{ ok: boolean }> {
  if (!api) return { ok: false };
  try {
    const { data } = await api.POST("/rpc/aceitar_termos", { body: { termos_versao: versao }, signal: prazo() });
    return { ok: Boolean(data) };
  } catch {
    return { ok: false };
  }
}
