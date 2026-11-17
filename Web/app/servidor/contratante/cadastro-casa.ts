/**
 * Cadastro da casa na web (2.9, `cadastrar_estabelecimento`). O endereço é digitado; o ponto vem SÓ do toque em
 * "Estou no endereço agora" (localização do navegador, uma leitura). Sem serviço de mapas nem de endereço (decisão
 * do O2): o ponto vai uma vez, no envio, e não fica guardado em lugar nenhum da web. Sem ponto, não há cadastro.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";

export type NovaCasa = components["schemas"]["NovoEstabelecimento"];
export type TipoDeCasa = components["schemas"]["TipoEstabelecimento"];
export const TIPOS: readonly TipoDeCasa[] = ["food_service", "evento", "varejo", "logistica", "servico_domestico", "outro"];

export type Ponto = { latitude: number; longitude: number };

/** Leitura de mais de 1 km de imprecisão é a do provedor de internet, e não a do endereço: não serve de ponto. */
export const PRECISAO_MAXIMA_M = 1000;

/** Retângulo folgado que envolve o Brasil. Fora dele, a leitura está errada (VPN, localização de outro lugar). */
export function dentroDoBrasil({ latitude, longitude }: Ponto): boolean {
  return latitude >= -33.8 && latitude <= 5.3 && longitude >= -74.0 && longitude <= -34.7;
}

/** O mesmo retângulo do app (com folga, pega um pedaço do Entorno). Fora dele, só um aviso: não impede o cadastro. */
export function dentroDoDF({ latitude, longitude }: Ponto): boolean {
  return latitude >= -16.06 && latitude <= -15.49 && longitude >= -48.3 && longitude <= -47.29;
}

export type CampoDaCasa = "nome" | "documento" | "tipo" | "endereco" | "regiao_administrativa" | "ponto";
export type ValoresDaCasa = Record<"nome" | "documento" | "tipo" | "endereco" | "regiao_administrativa" | "latitude" | "longitude", string>;
export type ProblemaDoPonto = "sem_ponto" | "fora_do_brasil";

export function valoresDoFormulario(formulario: FormData): ValoresDaCasa {
  const texto = (campo: string) => String(formulario.get(campo) ?? "").trim();
  return {
    nome: texto("nome"),
    // Só os dígitos: aceita "12.345.678/0001-90" ou "123.456.789-01".
    documento: texto("documento").replace(/\D/g, ""),
    tipo: texto("tipo"),
    endereco: texto("endereco"),
    regiao_administrativa: texto("regiao_administrativa"),
    latitude: texto("latitude"),
    longitude: texto("longitude"),
  };
}

/** Lê o ponto dos campos escondidos: dois números, dentro do Brasil. */
export function lerPonto(valores: Pick<ValoresDaCasa, "latitude" | "longitude">): { ok: true; ponto: Ponto } | { ok: false; problema: ProblemaDoPonto } {
  if (!valores.latitude || !valores.longitude) return { ok: false, problema: "sem_ponto" };
  const latitude = Number(valores.latitude);
  const longitude = Number(valores.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return { ok: false, problema: "sem_ponto" };
  const ponto = { latitude, longitude };
  return dentroDoBrasil(ponto) ? { ok: true, ponto } : { ok: false, problema: "fora_do_brasil" };
}

export type LeituraDaCasa = { ok: true; casa: NovaCasa } | { ok: false; erros: Partial<Record<CampoDaCasa, "obrigatorio" | "invalido" | ProblemaDoPonto>> };

/** Só confere se dá para montar o pedido; a região tem de ser uma do catálogo (a tela mostra só essas). */
export function lerFormularioDaCasa(valores: ValoresDaCasa, regioes: readonly string[]): LeituraDaCasa {
  const erros: Partial<Record<CampoDaCasa, "obrigatorio" | "invalido" | ProblemaDoPonto>> = {};
  if (!valores.nome) erros.nome = "obrigatorio";
  if (!valores.documento) erros.documento = "obrigatorio";
  else if (valores.documento.length !== 11 && valores.documento.length !== 14) erros.documento = "invalido";
  if (!TIPOS.includes(valores.tipo as TipoDeCasa)) erros.tipo = valores.tipo ? "invalido" : "obrigatorio";
  if (!valores.endereco) erros.endereco = "obrigatorio";
  if (!valores.regiao_administrativa) erros.regiao_administrativa = "obrigatorio";
  else if (!regioes.includes(valores.regiao_administrativa)) erros.regiao_administrativa = "invalido";
  const ponto = lerPonto(valores);
  if (!ponto.ok) erros.ponto = ponto.problema;
  if (!ponto.ok || Object.keys(erros).length > 0) return { ok: false, erros };
  return {
    ok: true,
    casa: {
      nome: valores.nome,
      documento: valores.documento,
      tipo: valores.tipo as TipoDeCasa,
      endereco: valores.endereco,
      regiao_administrativa: valores.regiao_administrativa,
      ponto: ponto.ponto,
    },
  };
}

export type ResultadoDoCadastro =
  | { ok: true; casaId: string }
  | { ok: false; motivo: "campo"; campo: CampoDaCasa; tipo: "obrigatorio" | "invalido" }
  | { ok: false; motivo: "documento_ja_cadastrado" | "perfil_incompativel" | "conta_suspensa" | "sem_sessao" | "indisponivel" };

const CAMPO_DO_SERVIDOR: Record<string, CampoDaCasa> = {
  nome: "nome", documento: "documento", tipo: "tipo", endereco: "endereco", regiao_administrativa: "regiao_administrativa",
  ponto: "ponto", latitude: "ponto", longitude: "ponto",
};

export async function cadastrarCasa(api: Api | null, casa: NovaCasa): Promise<ResultadoDoCadastro> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/cadastrar_estabelecimento", { body: casa, signal: AbortSignal.timeout(8000) });
    if (data) return { ok: true, casaId: data.id };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "conta_suspensa" };
    if (response.status === 409) return { ok: false, motivo: error?.code === "documento_ja_cadastrado" ? "documento_ja_cadastrado" : "indisponivel" };
    if (response.status === 422 && error) {
      if (error.code === "perfil_incompativel") return { ok: false, motivo: "perfil_incompativel" };
      const campo = CAMPO_DO_SERVIDOR[error.details ?? ""];
      if (campo && (error.code === "campo_obrigatorio" || error.code === "campo_invalido")) {
        return { ok: false, motivo: "campo", campo, tipo: error.code === "campo_obrigatorio" ? "obrigatorio" : "invalido" };
      }
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
