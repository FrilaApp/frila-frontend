import { redirect, type RouterContextProvider } from "react-router";

import { contextoDaSessao } from "../contexto";
import type { SessaoAtual } from "./sessao";

/** Para rota que só existe para quem entrou: sem sessão, manda entrar. */
export function exigirSessao(context: Readonly<RouterContextProvider>): SessaoAtual {
  const sessao = context.get(contextoDaSessao);
  if (!sessao) {
    throw redirect("/entrar");
  }
  return sessao;
}
