import { createContext } from "react-router";

import type { RespostaDoAuth, SessaoAtual } from "./servidor/sessao";

/** Sessão do pedido, decidida uma vez pelo middleware da raiz. `null` = ninguém entrou. */
export const contextoDaSessao = createContext<SessaoAtual | null>(null);

/** O que o Auth disse da sessão neste pedido. O sair usa para saber se a sessão já não existe ou se o Auth falhou. */
export const contextoDoAuth = createContext<RespostaDoAuth>("sem_cookie");
