import { lerConfiguracaoDesteAmbiente, lerLinkDaAppStore } from "../../servidor/abertura";
import { condicoesPublicas } from "../../servidor/publico";

/** Loader comum das páginas públicas: só as condições de exibição, nada da sessão. */
export async function carregarCondicoes() {
  const [web, linkDaAppStore] = await Promise.all([lerConfiguracaoDesteAmbiente(), lerLinkDaAppStore()]);
  return condicoesPublicas(web, linkDaAppStore);
}
