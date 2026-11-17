import { paginaSemConexao } from "../servidor/sem-conexao";

/** Item 1.10: a página que o service worker guarda e mostra sem rede. Igual para todo mundo, sem dado pessoal. */
export async function loader() {
  return paginaSemConexao();
}
