/**
 * Cadastro do profissional na web, em passos (2.8): funções, ponto base, horários, regiões atendidas e serviços
 * com preço. O perfil nasce com `criar_perfil_profissional` (funções, ponto base e a grade de horários), as regiões
 * vão em `definir_regioes_atendidas` e os serviços em `definir_servicos`. O ponto base é o centro da Região
 * Administrativa que a pessoa escolhe: a web não lê a posição do aparelho em passo nenhum. Regra é do servidor;
 * aqui só se confere se dá para montar o pedido e se traduz a resposta.
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";
import { centroDaRegiao, type Coordenada } from "./cadastro-centros";

export const PASSOS = ["funcoes", "ponto", "horarios", "regioes", "servicos"] as const;
export type Passo = (typeof PASSOS)[number];

export const UNIDADES = ["hora", "diaria", "evento", "pacote", "por_pessoa", "a_combinar"] as const;
export type Unidade = (typeof UNIDADES)[number];
/** Um serviço como veio do formulário: a unidade e os campos dela, em texto. */
export type ServicoMarcado = { unidade: Unidade; valor: string; horas: string; pessoas: string; pacote: string };

/** O que a pessoa marcou até aqui, como veio do formulário (os passos já feitos viajam em campos escondidos). */
export type Valores = {
  funcoes: string[];
  ponto_regiao: string;
  /** Horários já adicionados, um por texto: "dia-início-fim" (ex.: "5-18:00-02:00"; 0 = domingo). */
  janelas: string[];
  /** O horário que está no formulário e ainda não foi adicionado. */
  novo_horario: { dias: string[]; inicio: string; fim: string };
  atende_todo_df: boolean;
  regioes: string[];
  /** Só os serviços oferecidos, pelo id da função. */
  servicos: Record<string, ServicoMarcado>;
};
export const VAZIO: Valores = { funcoes: [], ponto_regiao: "", janelas: [], novo_horario: { dias: [], inicio: "", fim: "" }, atende_todo_df: false, regioes: [], servicos: {} };

const textosDe = (formulario: FormData, campo: string) => [...new Set(formulario.getAll(campo).map((valor) => String(valor).trim()).filter(Boolean))];

export function passoDoFormulario(formulario: FormData): Passo {
  return PASSOS.find((passo) => passo === formulario.get("passo")) ?? "funcoes";
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function valoresDoFormulario(formulario: FormData): Valores {
  const texto = (campo: string) => String(formulario.get(campo) ?? "").trim();
  const servicos: Valores["servicos"] = {};
  for (const campo of new Set(formulario.keys())) {
    const funcaoId = campo.startsWith("unidade:") ? campo.slice("unidade:".length) : "";
    const unidade = UNIDADES.find((nome) => nome === texto(campo));
    if (unidade && UUID.test(funcaoId)) {
      servicos[funcaoId] = { unidade, valor: texto(`valor:${funcaoId}`), horas: texto(`horas:${funcaoId}`), pessoas: texto(`pessoas:${funcaoId}`), pacote: texto(`pacote:${funcaoId}`) };
    }
  }
  return {
    funcoes: textosDe(formulario, "funcoes"),
    ponto_regiao: texto("ponto_regiao"),
    janelas: lerJanelas(textosDe(formulario, "janelas")).map(textoDaJanela),
    novo_horario: { dias: textosDe(formulario, "dias"), inicio: texto("inicio"), fim: texto("fim") },
    atende_todo_df: formulario.get("atende_todo_df") === "sim",
    regioes: textosDe(formulario, "regioes"),
    servicos,
  };
}

export type Janela = components["schemas"]["JanelaDeDisponibilidade"];
const HORA = /^([01]\d|2[0-3]):[0-5]\d$/;

export const textoDaJanela = (janela: Janela) => `${janela.dia_semana}-${janela.hora_inicio}-${janela.hora_fim}`;

/** As janelas válidas (dia de 0 a 6, horas HH:MM, início diferente do fim), sem repetir, por dia e por início. */
export function lerJanelas(textos: readonly string[]): Janela[] {
  const janelas = new Map<string, Janela>();
  for (const texto of textos) {
    const [dia = "", inicio = "", fim = "", ...resto] = texto.split("-");
    if (resto.length > 0 || !/^[0-6]$/.test(dia) || !HORA.test(inicio) || !HORA.test(fim) || inicio === fim) continue;
    janelas.set(texto, { dia_semana: Number(dia), hora_inicio: inicio, hora_fim: fim });
  }
  return [...janelas.values()].sort((a, b) => a.dia_semana - b.dia_semana || a.hora_inicio.localeCompare(b.hora_inicio) || a.hora_fim.localeCompare(b.hora_fim));
}

export type ProblemaDoHorario = "sem_dia" | "invalido" | "igual";

/** Junta à grade o horário do formulário: um para cada dia marcado. A janela pode atravessar a meia-noite. */
export function adicionarHorario(valores: Valores): { ok: true; janelas: string[] } | { ok: false; problema: ProblemaDoHorario } {
  const { dias, inicio, fim } = valores.novo_horario;
  const validos = dias.filter((dia) => /^[0-6]$/.test(dia));
  if (validos.length === 0) return { ok: false, problema: "sem_dia" };
  if (!HORA.test(inicio) || !HORA.test(fim)) return { ok: false, problema: "invalido" };
  if (inicio === fim) return { ok: false, problema: "igual" };
  return { ok: true, janelas: lerJanelas([...valores.janelas, ...validos.map((dia) => `${dia}-${inicio}-${fim}`)]).map(textoDaJanela) };
}

/** Só as funções do catálogo ativo, como o app faz. Nenhuma: nulo. */
export function lerFuncoesMarcadas(valores: Valores, catalogo: readonly string[]): string[] | null {
  const funcoes = valores.funcoes.filter((id) => catalogo.includes(id));
  return funcoes.length > 0 ? funcoes : null;
}

const idDeRegiao = (texto: string, catalogo: readonly number[]): number | null => {
  const id = /^\d+$/.test(texto) ? Number(texto) : 0;
  return catalogo.includes(id) ? id : null;
};

/** O ponto base é o centro da região escolhida: ela tem de estar no catálogo e ter centro na tabela. */
export function lerPontoBase(valores: Valores, catalogo: readonly number[]): Coordenada | null {
  const id = idDeRegiao(valores.ponto_regiao, catalogo);
  return id === null ? null : centroDaRegiao(id);
}

export type RegioesAtendidas = { regioes: number[]; atende_todo_df: boolean };

/** Com "todo o DF", a lista vai vazia (o servidor a ignora). Região fora do catálogo: nulo. */
export function lerRegioesAtendidas(valores: Valores, catalogo: readonly number[]): RegioesAtendidas | null {
  if (valores.atende_todo_df) return { regioes: [], atende_todo_df: true };
  const regioes = valores.regioes.map((texto) => idDeRegiao(texto, catalogo));
  return regioes.includes(null) ? null : { regioes: regioes as number[], atende_todo_df: false };
}

export type Servico = components["schemas"]["ServicoOferecido"];
export type CampoDoServico = "valor" | "horas" | "pessoas" | "pacote";
export const LIMITE_DE_SERVICOS = 10;

/** "25" ou "25,50" em centavos, dentro da faixa do contrato (R$ 10 a R$ 10.000). Fora disso, nulo. */
function centavos(texto: string): number | null {
  const partes = /^(\d{1,5})(?:,(\d{1,2}))?$/.exec(texto);
  if (!partes) return null;
  const valor = Number(partes[1]) * 100 + Number((partes[2] ?? "").padEnd(2, "0"));
  return valor >= 1000 && valor <= 1000000 ? valor : null;
}

const inteiro = (texto: string, minimo: number, maximo: number): number | null => {
  const numero = /^\d{1,4}$/.test(texto) ? Number(texto) : Number.NaN;
  return numero >= minimo && numero <= maximo ? numero : null;
};

export type LeituraDosServicos = { ok: true; servicos: Servico[] } | { ok: false; problema: "muitos" } | { ok: false; problema: CampoDoServico; funcaoId: string };

/**
 * Monta os serviços das funções marcadas, na ordem delas, só com os campos que a unidade pede (os obrigatórios do
 * contrato: o resto fica para a edição do perfil). Serviço de função não marcada é ignorado.
 */
export function lerServicos(marcados: Valores["servicos"], funcoes: readonly string[]): LeituraDosServicos {
  const servicos: Servico[] = [];
  for (const funcaoId of funcoes) {
    const marcado = marcados[funcaoId];
    if (!marcado) continue;
    const servico: Servico = { funcao_id: funcaoId, unidade: marcado.unidade };
    if (marcado.unidade !== "a_combinar") {
      const valor = centavos(marcado.valor);
      if (valor === null) return { ok: false, problema: "valor", funcaoId };
      servico.valor_centavos = valor;
    }
    if (marcado.unidade === "diaria") {
      const horas = inteiro(marcado.horas, 4, 12);
      if (horas === null) return { ok: false, problema: "horas", funcaoId };
      servico.horas_incluidas = horas;
    }
    if (marcado.unidade === "por_pessoa") {
      const pessoas = inteiro(marcado.pessoas, 1, 2000);
      if (pessoas === null) return { ok: false, problema: "pessoas", funcaoId };
      servico.minimo_pessoas = pessoas;
    }
    if (marcado.unidade === "pacote") {
      const pacote = marcado.pacote.trim();
      if (!pacote || pacote.length > 120) return { ok: false, problema: "pacote", funcaoId };
      servico.descricao_pacote = pacote;
    }
    servicos.push(servico);
  }
  return servicos.length > LIMITE_DE_SERVICOS ? { ok: false, problema: "muitos" } : { ok: true, servicos };
}

export type LeituraDoPerfilCriado = "tem" | "nao_tem" | "sem_sessao" | "indisponivel";

/** Diz só se o perfil existe (`meu_perfil_profissional` não depende da chave do perfil rico). */
export async function lerSeTemPerfil(api: Api | null): Promise<LeituraDoPerfilCriado> {
  if (!api) return "indisponivel";
  try {
    const { data, response } = await api.GET("/rpc/meu_perfil_profissional", { signal: AbortSignal.timeout(5000) });
    if (data) return "tem";
    if (response.status === 404) return "nao_tem";
    return response.status === 401 ? "sem_sessao" : "indisponivel";
  } catch {
    return "indisponivel";
  }
}

export type ResultadoDaCriacao =
  | { ok: true }
  | { ok: false; motivo: "funcoes" | "ponto_base" | "perfil_incompativel" | "conta_suspensa" | "sem_sessao" | "indisponivel" };

/**
 * Cria o perfil. Grade vazia é aceita pelo contrato (a tela avisa que, sem horário, o aviso de vaga não chega).
 * `409 perfil_ja_existe` conta como criado (o envio anterior gravou e só a resposta se perdeu): o contrato não
 * sobrescreve, e vale o que está gravado.
 */
export async function criarPerfil(api: Api | null, funcoes: string[], pontoBase: Coordenada, disponibilidades: Janela[]): Promise<ResultadoDaCriacao> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/criar_perfil_profissional", {
      body: { funcoes, ponto_base: pontoBase, disponibilidades },
      signal: AbortSignal.timeout(8000),
    });
    if (data) return { ok: true };
    if (response.status === 409 && error?.code === "perfil_ja_existe") return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403) return { ok: false, motivo: "conta_suspensa" };
    if (response.status === 422 && error) {
      if (error.code === "perfil_incompativel") return { ok: false, motivo: "perfil_incompativel" };
      if (error.details === "funcoes" || error.details === "ponto_base") return { ok: false, motivo: error.details };
    }
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type ResultadoDasRegioes = { ok: true } | { ok: false; motivo: "recurso_desligado" | "sem_sessao" | "indisponivel" };

export async function definirRegioes(api: Api | null, regioes: RegioesAtendidas): Promise<ResultadoDasRegioes> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/definir_regioes_atendidas", { body: regioes, signal: AbortSignal.timeout(8000) });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403 && error?.details === "recurso_desligado") return { ok: false, motivo: "recurso_desligado" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export type ResultadoDosServicos =
  | { ok: true }
  /** O servidor recusou um campo (faixa de valor, filtro de contato no texto do pacote...). */
  | { ok: false; motivo: "campo"; campo: CampoDoServico | "outro" }
  | { ok: false; motivo: "recurso_desligado" | "sem_sessao" | "indisponivel" };

const CAMPO_DO_SERVIDOR: Record<string, CampoDoServico> = { valor_centavos: "valor", horas_incluidas: "horas", minimo_pessoas: "pessoas", descricao_pacote: "pacote" };

export async function definirServicos(api: Api | null, servicos: Servico[]): Promise<ResultadoDosServicos> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/definir_servicos", { body: { servicos }, signal: AbortSignal.timeout(8000) });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403 && error?.details === "recurso_desligado") return { ok: false, motivo: "recurso_desligado" };
    if (response.status === 422) return { ok: false, motivo: "campo", campo: CAMPO_DO_SERVIDOR[error?.details ?? ""] ?? "outro" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
