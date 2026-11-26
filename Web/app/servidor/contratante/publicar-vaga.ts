import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import type { CadastroDaCasa } from "./casa";
import { prazo } from "./casa";

export type NovaVaga = components["schemas"]["NovaVaga"];
type Modo = NovaVaga["modo"];

/** Os campos que a pessoa preenche. Local, região e ponto vêm do cadastro da casa, no servidor. */
export const CAMPOS_DA_VAGA = ["funcao_id", "dia", "inicio", "fim", "valor", "posicoes", "modo", "responsavel_local", "traje", "observacoes"] as const;
export type CampoDaVaga = (typeof CAMPOS_DA_VAGA)[number];
export type ProblemaDoCampo = "obrigatorio" | "invalido";

export type ValoresDaVaga = Record<CampoDaVaga, string> & {
  inclui_refeicao: boolean;
  inclui_transporte: boolean;
  exige_material_proprio: boolean;
};

export type VagaLida = Omit<NovaVaga, "estabelecimento_id" | "local" | "regiao_administrativa" | "ponto" | "chave">;

/** O padrão do contrato para a janela crítica (3 horas). Ajustar por vaga fica para depois. */
export const ALERTA_PADRAO_MIN = 180;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const ehUuid = (valor: string) => UUID.test(valor);

const texto = (formulario: FormData, campo: string) => String(formulario.get(campo) ?? "").trim();

export function valoresDoFormulario(formulario: FormData): ValoresDaVaga {
  const valores = Object.fromEntries(CAMPOS_DA_VAGA.map((campo) => [campo, texto(formulario, campo)])) as Record<CampoDaVaga, string>;
  return {
    ...valores,
    inclui_refeicao: formulario.get("inclui_refeicao") === "sim",
    inclui_transporte: formulario.get("inclui_transporte") === "sim",
    exige_material_proprio: formulario.get("exige_material_proprio") === "sim",
  };
}

/** "150", "150,50", "1.200,00" ou "R$ 150" viram centavos inteiros (RN18). Qualquer outra coisa é `null`. */
export function valorEmCentavos(bruto: string): number | null {
  const limpo = bruto.replace(/^R\$\s*/i, "").replace(/\s/g, "");
  if (!/^\d{1,3}(\.\d{3})*(,\d{1,2})?$|^\d+(,\d{1,2})?$/.test(limpo)) return null;
  const [reais = "0", centavos = ""] = limpo.replace(/\./g, "").split(",");
  const total = Number(reais) * 100 + Number(centavos.padEnd(2, "0"));
  return total >= 1 ? total : null;
}

/** Faixa de referência do B-124: só avisa na tela, nunca trava nem impede publicar. */
export const VALOR_REFERENCIA_MINIMO_CENTAVOS = 5000;
export const VALOR_REFERENCIA_MAXIMO_CENTAVOS = 200000;
export type AvisoDeFaixaDoValor = "baixo" | "alto" | null;

/** Classifica um valor em centavos fora da faixa de referência (B-124). */
export function faixaDeAvisoDoValor(centavos: number | null): AvisoDeFaixaDoValor {
  if (centavos === null || !Number.isFinite(centavos) || centavos <= 0) return null;
  if (centavos < VALOR_REFERENCIA_MINIMO_CENTAVOS) return "baixo";
  if (centavos > VALOR_REFERENCIA_MAXIMO_CENTAVOS) return "alto";
  return null;
}

/** O DF fica em UTC−3 o ano todo (sem horário de verão desde 2019). */
const FUSO_DO_DF = "-03:00";

/**
 * Dia e horas do DF em instantes UTC. Fim igual ou antes do início é o turno que vira a noite: termina no dia
 * seguinte. Se a regra recusar (turno no passado, longo demais), quem diz é o servidor.
 */
export function horarioEmUtc(dia: string, inicio: string, fim: string): { inicio_em: string; fim_em: string } | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dia) || !/^\d{2}:\d{2}$/.test(inicio) || !/^\d{2}:\d{2}$/.test(fim)) return null;
  const comeco = new Date(`${dia}T${inicio}:00${FUSO_DO_DF}`);
  const termino = new Date(`${dia}T${fim}:00${FUSO_DO_DF}`);
  if (Number.isNaN(comeco.getTime()) || Number.isNaN(termino.getTime())) return null;
  if (termino <= comeco) termino.setUTCDate(termino.getUTCDate() + 1);
  return { inicio_em: comeco.toISOString(), fim_em: termino.toISOString() };
}

export type LeituraDoFormulario =
  | { ok: true; vaga: VagaLida }
  | { ok: false; erros: Partial<Record<CampoDaVaga, ProblemaDoCampo>> };

/** Só confere se dá para montar o pedido. A regra (antecedência, termo bloqueado, limites) é do servidor. */
export function lerFormularioDaVaga(valores: ValoresDaVaga): LeituraDoFormulario {
  const erros: Partial<Record<CampoDaVaga, ProblemaDoCampo>> = {};
  const obrigatorio = (campo: CampoDaVaga) => {
    if (!valores[campo]) erros[campo] = "obrigatorio";
    return Boolean(valores[campo]);
  };

  if (obrigatorio("funcao_id") && !ehUuid(valores.funcao_id)) erros.funcao_id = "invalido";
  const horarioCompleto = [obrigatorio("dia"), obrigatorio("inicio"), obrigatorio("fim")].every(Boolean);
  const horario = horarioCompleto ? horarioEmUtc(valores.dia, valores.inicio, valores.fim) : null;
  if (horarioCompleto && !horario) erros.dia = "invalido";
  const centavos = obrigatorio("valor") ? valorEmCentavos(valores.valor) : null;
  if (valores.valor && centavos === null) erros.valor = "invalido";
  const posicoes = obrigatorio("posicoes") ? Number(valores.posicoes) : NaN;
  if (valores.posicoes && !(Number.isInteger(posicoes) && posicoes >= 1 && posicoes <= 200)) erros.posicoes = "invalido";
  const modo = valores.modo === "urgencia" || valores.modo === "selecao" ? (valores.modo as Modo) : null;
  if (obrigatorio("modo") && !modo) erros.modo = "invalido";
  obrigatorio("responsavel_local");

  if (!horario || centavos === null || !modo || Object.keys(erros).length > 0) return { ok: false, erros };
  return {
    ok: true,
    vaga: {
      funcao_id: valores.funcao_id,
      ...horario,
      valor_centavos: centavos,
      posicoes,
      modo,
      responsavel_local: valores.responsavel_local,
      inclui_refeicao: valores.inclui_refeicao,
      inclui_transporte: valores.inclui_transporte,
      exige_material_proprio: valores.exige_material_proprio,
      traje: valores.traje || null,
      observacoes: valores.observacoes || null,
      alerta_antecedencia_min: ALERTA_PADRAO_MIN,
    },
  };
}

/** O pedido inteiro: o que a pessoa preencheu + o endereço e o ponto do cadastro da casa + a chave da tela. */
export function montarNovaVaga(vaga: VagaLida, casa: CadastroDaCasa, chave: string): NovaVaga {
  return {
    ...vaga,
    estabelecimento_id: casa.id,
    local: casa.endereco,
    regiao_administrativa: casa.regiao_administrativa,
    ponto: casa.ponto,
    chave,
  };
}

/** Campo que o servidor recusou → campo da tela. `local`, `regiao_administrativa` e `ponto` são do cadastro da casa. */
const CAMPO_DA_TELA: Partial<Record<string, CampoDaVaga | "casa">> = {
  funcao_id: "funcao_id",
  inicio_em: "dia",
  fim_em: "dia",
  valor_centavos: "valor",
  posicoes: "posicoes",
  modo: "modo",
  responsavel_local: "responsavel_local",
  traje: "traje",
  observacoes: "observacoes",
  local: "casa",
  regiao_administrativa: "casa",
  ponto: "casa",
};

export type ResultadoDaPublicacao =
  | { ok: true; vagaId: string }
  | { ok: false; motivo: "campo"; campo: CampoDaVaga; tipo: ProblemaDoCampo }
  | {
      ok: false;
      motivo:
        | "cadastro_da_casa"
        | "horario_invalido"
        | "selecao_sem_antecedencia"
        | "perfil_incompativel"
        | "sem_permissao"
        | "conta_suspensa"
        | "sem_sessao"
        | "indisponivel";
    };

/** Publica. A mesma `chave` devolve a mesma vaga: reenviar o formulário não cria outra. */
export async function publicarVaga(api: Api | null, vaga: NovaVaga): Promise<ResultadoDaPublicacao> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/publicar_vaga", { body: vaga, signal: prazo() });
    if (data) return { ok: true, vagaId: data.vaga_id };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: error?.details === "conta_suspensa" ? "conta_suspensa" : "sem_permissao" };
    if (response.status === 422 && error) {
      if (error.code === "horario_invalido" || error.code === "selecao_sem_antecedencia" || error.code === "perfil_incompativel") {
        return { ok: false, motivo: error.code };
      }
      if (error.code === "campo_obrigatorio" || error.code === "campo_invalido") {
        const campo = CAMPO_DA_TELA[error.details ?? ""];
        if (campo === "casa") return { ok: false, motivo: "cadastro_da_casa" };
        if (campo) return { ok: false, motivo: "campo", campo, tipo: error.code === "campo_obrigatorio" ? "obrigatorio" : "invalido" };
      }
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
