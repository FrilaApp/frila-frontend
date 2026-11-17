import { lerConfiguracaoDesteAmbiente } from "../../servidor/abertura";
import { condicoesPublicas } from "../../servidor/publico";

/** Loader comum das páginas públicas: só as condições de exibição, nada da sessão. */
export async function carregarCondicoes() {
  return condicoesPublicas(await lerConfiguracaoDesteAmbiente());
}
