/**
 * Chamada direta a partir da busca (3.8, `chamar_profissional`, 0.2.55 a 0.2.95). Uma chamada por vez: o trabalho
 * (função da busca, horário, valor total, inclusos, quem recebe) no endereço da casa, e o servidor cria a vaga direta.
 * Para chamar mais alguém para o mesmo trabalho, o servidor responde `409 trabalho_ja_aberto` com o `vaga_id`: a tela
 * mostra os termos dessa vaga e só repete pelo `vaga_id` com a confirmação da casa (o contrato proíbe repetir sozinho).
 * Cada profissional da lista tem a sua `chave`: reenviar (rede que caiu, aviso de recorrência) não cria outra chamada.
 */
import type { Api } from "../api";
import type { CadastroDaCasa } from "./casa";
import { ehUuid, horarioEmUtc, valorEmCentavos } from "./publicar-vaga";

type Inclusos = { inclui_refeicao: boolean; inclui_transporte: boolean; exige_material_proprio: boolean };
export type TermosDigitados = { dia: string; inicio: string; fim: string; valor: string; responsavel_local: string; recado: string; total: boolean } & Inclusos;
export type CampoDosTermos = "dia" | "valor" | "responsavel_local" | "recado" | "total";
export type TermosLidos = { inicio_em: string; fim_em: string; valor_centavos: number; responsavel_local: string; recado?: string } & Inclusos;

export const RECADO_MAXIMO = 300;
const prazo = () => AbortSignal.timeout(8000);

export function termosDoFormulario(formulario: FormData): TermosDigitados {
  const texto = (campo: string) => String(formulario.get(campo) ?? "").trim();
  const marcado = (campo: string) => formulario.get(campo) === "sim";
  return {
    dia: texto("dia"), inicio: texto("inicio"), fim: texto("fim"), valor: texto("valor"), responsavel_local: texto("responsavel_local"),
    recado: texto("recado"), total: marcado("total"),
    inclui_refeicao: marcado("inclui_refeicao"), inclui_transporte: marcado("inclui_transporte"), exige_material_proprio: marcado("exige_material_proprio"),
  };
}

/** Só confere se dá para montar o pedido; prazo (2 h ou a antecedência do profissional) e duração são do servidor. */
export function lerTermos(termos: TermosDigitados): { ok: true; termos: TermosLidos } | { ok: false; erros: Partial<Record<CampoDosTermos, true>> } {
  const erros: Partial<Record<CampoDosTermos, true>> = {};
  const horario = horarioEmUtc(termos.dia, termos.inicio, termos.fim);
  if (!horario) erros.dia = true;
  const centavos = valorEmCentavos(termos.valor);
  if (centavos === null) erros.valor = true;
  if (!termos.responsavel_local) erros.responsavel_local = true;
  if (termos.recado.length > RECADO_MAXIMO) erros.recado = true;
  // O valor é o total fechado do trabalho, que o profissional recebe (RN01, RN29): a casa confirma que leu.
  if (!termos.total) erros.total = true;
  if (!horario || centavos === null || Object.keys(erros).length > 0) return { ok: false, erros };
  const { inclui_refeicao, inclui_transporte, exige_material_proprio } = termos;
  return {
    ok: true,
    termos: { ...horario, valor_centavos: centavos, responsavel_local: termos.responsavel_local, inclui_refeicao, inclui_transporte, exige_material_proprio, ...(termos.recado ? { recado: termos.recado } : {}) },
  };
}

/** O trabalho completo, no endereço e no ponto do cadastro da casa (como o app). A região é a da casa. */
export function pedidoDoTrabalho(casa: CadastroDaCasa, profissionalId: string, funcaoId: string, termos: TermosLidos, chave: string, confirmo: boolean) {
  return {
    chave, profissional_id: profissionalId, estabelecimento_id: casa.id, funcao_id: funcaoId,
    local: casa.endereco, regiao_administrativa: casa.regiao_administrativa, ponto: casa.ponto,
    ...termos,
    ...(confirmo ? { confirmo_recorrencia: true } : {}),
  };
}

/** Mais alguém para um trabalho já aberto: só o `vaga_id` (os termos são os da vaga). */
export function pedidoPelaVaga(casaId: string, profissionalId: string, vagaId: string, chave: string, recado: string, confirmo: boolean) {
  return {
    chave, profissional_id: profissionalId, estabelecimento_id: casaId, vaga_id: vagaId,
    ...(recado ? { recado } : {}),
    ...(confirmo ? { confirmo_recorrencia: true } : {}),
  };
}

export type FalhaDaChamada =
  | "ja_aberta"
  | "recorrencia"
  | "indisponivel_para_chamada"
  | "antecedencia"
  | "limite"
  | "recurso_desligado"
  | "termos_pendentes"
  | "conta_suspensa"
  | "sem_permissao"
  | "nao_encontrado"
  | "vaga_encerrada"
  | "recado"
  | "horario"
  | "valor"
  | "sem_sessao"
  /** Rede, prazo ou 5xx: a chamada pode ter sido criada. Só a mesma chave descobre (reenvio idempotente). */
  | "incerto";

export type ResultadoDaChamada = { ok: true } | { ok: false; motivo: "trabalho_ja_aberto"; vagaId: string } | { ok: false; motivo: FalhaDaChamada };

type Corpo = ReturnType<typeof pedidoDoTrabalho> | ReturnType<typeof pedidoPelaVaga>;

export async function chamarProfissional(api: Api | null, corpo: Corpo): Promise<ResultadoDaChamada> {
  if (!api) return { ok: false, motivo: "incerto" };
  try {
    const { data, error, response } = await api.POST("/rpc/chamar_profissional", { body: corpo as never, signal: prazo() });
    if (data) return { ok: true };
    const codigo = error?.code;
    const detalhe = error?.details ?? "";
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 404) return { ok: false, motivo: "nao_encontrado" };
    if (response.status === 403) {
      if (detalhe === "recurso_desligado" || detalhe === "termos_pendentes" || detalhe === "conta_suspensa") return { ok: false, motivo: detalhe };
      return { ok: false, motivo: "sem_permissao" };
    }
    if (response.status === 409) {
      if (codigo === "trabalho_ja_aberto" && ehUuid(detalhe)) return { ok: false, motivo: "trabalho_ja_aberto", vagaId: detalhe };
      if (codigo === "chamada_ja_aberta") return { ok: false, motivo: "ja_aberta" };
      if (codigo === "recorrencia_nao_confirmada") return { ok: false, motivo: "recorrencia" };
      if (codigo === "vaga_encerrada") return { ok: false, motivo: "vaga_encerrada" };
    }
    if (response.status === 422) {
      if (codigo === "profissional_indisponivel") return { ok: false, motivo: detalhe === "antecedencia_insuficiente" ? "antecedencia" : "indisponivel_para_chamada" };
      if (codigo === "limite_de_chamadas") return { ok: false, motivo: "limite" };
      if (codigo === "campo_invalido" || codigo === "campo_obrigatorio") {
        if (detalhe === "recado") return { ok: false, motivo: "recado" };
        if (detalhe === "inicio_em" || detalhe === "fim_em") return { ok: false, motivo: "horario" };
        if (detalhe === "valor_centavos") return { ok: false, motivo: "valor" };
      }
      if (codigo === "horario_invalido") return { ok: false, motivo: "horario" };
    }
    return { ok: false, motivo: response.status >= 500 ? "incerto" : "indisponivel_para_chamada" };
  } catch {
    return { ok: false, motivo: "incerto" };
  }
}

export type TermosDaVagaAberta = { funcao: string; inicioEm: string; fimEm: string; valorCentavos: number } & Inclusos;

/**
 * Os termos da vaga que o `409 trabalho_ja_aberto` apontou, pelas chamadas da própria casa (o contrato manda ler
 * `minhas_chamadas` com `estado=aberta` e `detalhe_chamada`, e não `detalhe_vaga`). Sem achar: `null`, e nada se repete.
 */
export async function lerTermosDaVagaAberta(api: Api | null, vagaId: string): Promise<TermosDaVagaAberta | null> {
  if (!api) return null;
  try {
    let cursor: string | undefined;
    for (let pagina = 0; pagina < 3; pagina++) {
      const { data } = await api.GET("/rpc/minhas_chamadas", { params: { query: { estado: "aberta", ...(cursor ? { cursor } : {}) } }, signal: prazo() });
      if (!data) return null;
      const item = data.itens.find((chamada) => chamada.vaga_id === vagaId);
      if (item) {
        const { data: detalhe } = await api.GET("/rpc/detalhe_chamada", { params: { query: { chamada_id: item.id } }, signal: prazo() });
        if (!detalhe) return null;
        return {
          funcao: item.funcao.nome, inicioEm: item.inicio_em, fimEm: item.fim_em, valorCentavos: item.valor_centavos,
          inclui_refeicao: detalhe.inclui_refeicao, inclui_transporte: detalhe.inclui_transporte, exige_material_proprio: detalhe.exige_material_proprio,
        };
      }
      if (!data.proximo_cursor) return null;
      cursor = data.proximo_cursor;
    }
    return null;
  } catch {
    return null;
  }
}
