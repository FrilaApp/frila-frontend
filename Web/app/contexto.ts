import { createContext } from "react-router";

import type { SessaoAtual } from "./servidor/sessao";

/** Sessão do pedido, decidida uma vez pelo middleware da raiz. `null` = ninguém entrou. */
export const contextoDaSessao = createContext<SessaoAtual | null>(null);
