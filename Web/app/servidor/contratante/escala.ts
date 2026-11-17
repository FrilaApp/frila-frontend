/**
 * Escala em lote (3.3, `publicar_escala`, contrato 0.2.96): um evento e de 1 a 10 vagas de uma vez, tudo ou nada.
 * Cada item é lido com as mesmas conversões de `publicar_vaga` (valor, horário em UTC); o endereço e o ponto do
 * evento são os do cadastro da casa, como na vaga avulsa. Limites e regras (soma de posições, antecedência, termos)
 * são do servidor: a web só confere se dá para montar o pedido e traduz a recusa para o campo certo.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import type { CadastroDaCasa } from "./casa";
import { CAMPOS_DA_VAGA, type CampoDaVaga, lerFormularioDaVaga, type ProblemaDoCampo, type ValoresDaVaga, type VagaLida } from "./publicar-vaga";

export type NovaEscala = components["schemas"]["NovaEscala"];

export const MAXIMO_DE_VAGAS = 10;
export const MAXIMO_DE_POSICOES_POR_VAGA = 100;
/** Uma transação com até 10 vagas: um pouco mais de prazo que a vaga avulsa. */
const PRAZO_DA_ESCALA_MS = 8000;

export type CampoDoEvento = "nome" | "data";
export type ValoresDaEscala = { nome: string; data: string; itens: ValoresDaVaga[] };
export type ErrosDaEscala = {
  evento: Partial<Record<CampoDoEvento, ProblemaDoCampo>>;
  itens: Array<Partial<Record<CampoDaVaga, ProblemaDoCampo>>>;
};

export const ITEM_VAZIO: ValoresDaVaga = {
  funcao_id: "", dia: "", inicio: "", fim: "", valor: "", posicoes: "1", modo: "urgencia", responsavel_local: "",
  traje: "", observacoes: "", inclui_refeicao: false, inclui_transporte: false, exige_material_proprio: false,
};

/** O nome do campo do item `i` no formulário. */
export const nomeDoCampo = (i: number, campo: string) => `vagas.${i}.${campo}`;

const texto = (formulario: FormData, campo: string) => String(formulario.get(campo) ?? "").trim();

/** Lê o evento e os itens. Quantos itens a tela mostra vem do campo `itens` (de 1 a 10). */
export function valoresDaEscala(formulario: FormData): ValoresDaEscala {
  const quantos = Math.min(MAXIMO_DE_VAGAS, Math.max(1, Number.parseInt(texto(formulario, "itens"), 10) || 1));
  const itens = Array.from({ length: quantos }, (_, i): ValoresDaVaga => {
    const valores = Object.fromEntries(CAMPOS_DA_VAGA.map((campo) => [campo, texto(formulario, nomeDoCampo(i, campo))])) as Record<CampoDaVaga, string>;
    const marcado = (campo: string) => formulario.get(nomeDoCampo(i, campo)) === "sim";
    return {
      ...valores,
      inclui_refeicao: marcado("inclui_refeicao"),
      inclui_transporte: marcado("inclui_transporte"),
      exige_material_proprio: marcado("exige_material_proprio"),
    };
  });
  return { nome: texto(formulario, "nome"), data: texto(formulario, "data"), itens };
}

export type LeituraDaEscala = { ok: true; evento: { nome: string; data: string }; itens: VagaLida[] } | { ok: false; erros: ErrosDaEscala };

/** Só confere se dá para montar o pedido; o resto (nome curto demais, soma de posições, antecedência) é do servidor. */
export function lerFormularioDaEscala(valores: ValoresDaEscala): LeituraDaEscala {
  const erros: ErrosDaEscala = { evento: {}, itens: valores.itens.map(() => ({})) };
  if (!valores.nome) erros.evento.nome = "obrigatorio";
  if (!valores.data) erros.evento.data = "obrigatorio";
  else if (!/^\d{4}-\d{2}-\d{2}$/.test(valores.data)) erros.evento.data = "invalido";

  const itens: VagaLida[] = [];
  valores.itens.forEach((item, i) => {
    const lido = lerFormularioDaVaga(item);
    if (lido.ok) itens.push(lido.vaga);
    else erros.itens[i] = lido.erros;
    // Na escala, cada vaga vai até 100 pessoas (na vaga avulsa, até 200).
    const posicoes = Number(item.posicoes);
    if (item.posicoes && !erros.itens[i]?.posicoes && posicoes > MAXIMO_DE_POSICOES_POR_VAGA) erros.itens[i] = { ...erros.itens[i], posicoes: "invalido" };
  });

  const temErro = Object.keys(erros.evento).length > 0 || erros.itens.some((item) => Object.keys(item).length > 0);
  if (temErro) return { ok: false, erros };
  return { ok: true, evento: { nome: valores.nome, data: valores.data }, itens };
}

/** O pedido inteiro: o evento no endereço e no ponto do cadastro da casa, os itens e a chave da tela. */
export function montarNovaEscala(lido: Extract<LeituraDaEscala, { ok: true }>, casa: CadastroDaCasa, chave: string): NovaEscala {
  return {
    estabelecimento_id: casa.id,
    evento: { ...lido.evento, local: casa.endereco, regiao_administrativa: casa.regiao_administrativa, ponto: casa.ponto },
    vagas: lido.itens,
    chave,
  };
}

/** Campo do item que o servidor recusou → campo da tela. */
const CAMPO_DO_ITEM: Partial<Record<string, CampoDaVaga>> = {
  funcao_id: "funcao_id",
  inicio_em: "dia",
  fim_em: "dia",
  valor_centavos: "valor",
  posicoes: "posicoes",
  modo: "modo",
  responsavel_local: "responsavel_local",
  traje: "traje",
  observacoes: "observacoes",
};

export type MotivoGeral =
  | "quantidade"
  | "soma_de_posicoes"
  | "cadastro_da_casa"
  | "perfil_incompativel"
  | "sem_permissao"
  | "conta_suspensa"
  | "sem_sessao"
  | "indisponivel";

export type ResultadoDaEscala =
  | { ok: true; eventoId: string; vagas: number }
  | { ok: false; motivo: "evento"; campo: CampoDoEvento; tipo: ProblemaDoCampo }
  | { ok: false; motivo: "item"; indice: number; campo: CampoDaVaga; tipo: ProblemaDoCampo }
  | { ok: false; motivo: "horario_invalido" | "selecao_sem_antecedencia"; indice: number }
  | { ok: false; motivo: MotivoGeral };

/** `details` da recusa → onde está o erro: `evento.nome`, `vagas[2].valor_centavos`, `vagas[1]`, `vagas`, `posicoes`. */
function traduzir(code: string, details: string | null | undefined): ResultadoDaEscala {
  const caminho = details ?? "";
  const doItem = /^vagas\[(\d+)\](?:\.(\w+))?$/.exec(caminho);
  if (doItem) {
    const indice = Number(doItem[1]);
    if (code === "horario_invalido" || code === "selecao_sem_antecedencia") return { ok: false, motivo: code, indice };
    const campo = CAMPO_DO_ITEM[doItem[2] ?? ""];
    if (campo && (code === "campo_obrigatorio" || code === "campo_invalido")) {
      return { ok: false, motivo: "item", indice, campo, tipo: code === "campo_obrigatorio" ? "obrigatorio" : "invalido" };
    }
    return { ok: false, motivo: "indisponivel" };
  }
  if (code !== "campo_obrigatorio" && code !== "campo_invalido") return { ok: false, motivo: "indisponivel" };
  const tipo: ProblemaDoCampo = code === "campo_obrigatorio" ? "obrigatorio" : "invalido";
  if (caminho === "evento.nome" || caminho === "evento.data") return { ok: false, motivo: "evento", campo: caminho === "evento.nome" ? "nome" : "data", tipo };
  // Endereço, região e ponto vêm do cadastro da casa: a pessoa conserta lá, não nesta tela.
  if (caminho === "evento.local" || caminho === "evento.regiao_administrativa" || caminho === "evento.ponto") return { ok: false, motivo: "cadastro_da_casa" };
  if (caminho === "vagas") return { ok: false, motivo: "quantidade" };
  if (caminho === "posicoes") return { ok: false, motivo: "soma_de_posicoes" };
  return { ok: false, motivo: "indisponivel" };
}

/** Publica tudo ou nada. A mesma `chave` devolve a mesma escala: reenviar não cria outra nem avisa de novo. */
export async function publicarEscala(api: Api | null, escala: NovaEscala): Promise<ResultadoDaEscala> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/publicar_escala", { body: escala, signal: AbortSignal.timeout(PRAZO_DA_ESCALA_MS) });
    if (data) return { ok: true, eventoId: data.evento_id, vagas: data.vagas.length };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: error?.details === "conta_suspensa" ? "conta_suspensa" : "sem_permissao" };
    if (response.status === 422 && error) {
      if (error.code === "perfil_incompativel") return { ok: false, motivo: "perfil_incompativel" };
      return traduzir(error.code, error.details);
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
