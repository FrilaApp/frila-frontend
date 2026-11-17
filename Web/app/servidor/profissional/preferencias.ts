/**
 * Preferências do profissional para receber chamadas (definir_preferencia_chamadas). A leitura vem do perfil
 * detalhado (`preferencia_chamadas`). Ligar "Aceito chamadas diretas" manda a versão do texto que a tela mostrou
 * ('busca-1', decisão da Bússola de 17/11/2026: o mesmo texto do iOS), porque o servidor guarda esse registro (LGPD).
 */
import type { components } from "../../contrato/tipos.gerado";
import type { Api } from "../api";

export type Preferencias = components["schemas"]["PreferenciaChamadas"];
export const VERSAO_DO_TEXTO_DA_BUSCA = "busca-1";
export const ANTECEDENCIAS = [2, 6, 24, 48] as const;
export type Antecedencia = (typeof ANTECEDENCIAS)[number];

export type Alteracao = {
  aceitaDeQuemJaTrabalhou: boolean;
  antecedenciaMinimaH: Antecedencia;
  pausadoAte: string | null;
  /** Só quando a pessoa mudou a chave nesta tela (cada vez que liga, o servidor registra). */
  aceitaChamadas: boolean | null;
};

export type ResultadoDasPreferencias =
  | { ok: true }
  | { ok: false; motivo: "pausa_no_passado" | "recurso_desligado" | "sem_sessao" | "indisponivel" };

export async function salvarPreferencias(api: Api | null, alteracao: Alteracao): Promise<ResultadoDasPreferencias> {
  if (alteracao.pausadoAte !== null && !/^\d{4}-\d{2}-\d{2}$/.test(alteracao.pausadoAte)) return { ok: false, motivo: "pausa_no_passado" };
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, error, response } = await api.POST("/rpc/definir_preferencia_chamadas", {
      body: {
        aceita_de_quem_ja_trabalhou: alteracao.aceitaDeQuemJaTrabalhou,
        antecedencia_minima_h: alteracao.antecedenciaMinimaH,
        pausado_ate: alteracao.pausadoAte,
        ...(alteracao.aceitaChamadas === null
          ? {}
          : alteracao.aceitaChamadas
            ? { aceita_chamadas: true, versao_texto_busca: VERSAO_DO_TEXTO_DA_BUSCA }
            : { aceita_chamadas: false }),
      },
      signal: AbortSignal.timeout(8000),
    });
    if (data) return { ok: true };
    if (response.status === 401) return { ok: false, motivo: "sem_sessao" };
    if (response.status === 403 && error?.details === "recurso_desligado") return { ok: false, motivo: "recurso_desligado" };
    if (response.status === 422 && error?.details === "pausado_ate") return { ok: false, motivo: "pausa_no_passado" };
    return { ok: false, motivo: "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}
