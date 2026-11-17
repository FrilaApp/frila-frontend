/**
 * O que as páginas públicas podem mostrar, pelas condições de exibição do marketing
 * (orquestracao/retornos/WEB-textos-publicos.md): texto de recurso só aparece com o recurso ligado na web.
 */
import type { LeituraDaConfiguracao } from "./configuracao";

export type CondicoesPublicas = {
  /** chamada_direta e busca_profissionais ligados para a plataforma web. */
  chamadaDireta: boolean;
  /** Equipe de confiança (paridade 3.9): ainda não existe na web. */
  equipe: false;
  /** Exclusão de conta pela web (paridade 2.11): ainda não existe. */
  exclusaoNaWeb: false;
  /** O link da App Store vem da configuração; sem ele, o botão não aparece (nada de link inventado). */
  linkDaAppStore: string | null;
};

export function condicoesPublicas(leitura: LeituraDaConfiguracao, linkDaAppStore: string | null = null): CondicoesPublicas {
  const recursos = leitura.estado === "ok" ? leitura.configuracao.recursos : undefined;
  return {
    chamadaDireta: recursos?.chamada_direta === true && recursos.busca_profissionais === true,
    equipe: false,
    exclusaoNaWeb: false,
    linkDaAppStore: linkDaAppStore && /^https:\/\/apps\.apple\.com\//.test(linkDaAppStore) ? linkDaAppStore : null,
  };
}
