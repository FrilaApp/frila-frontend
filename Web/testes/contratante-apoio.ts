/** Apoio dos testes do contratante: sessão sintética, pedido com Origin e captura de redirect. Dados sintéticos. */
import { RouterContextProvider } from "react-router";

import { contextoDaSessao } from "../app/contexto";

export const CASA = "b027f000-0000-4000-8000-0000000000c1";
export const OUTRA_CASA = "b027f000-0000-4000-8000-0000000000c2";
export const GARCOM = "365ace5a-c202-4969-ad70-7f3f4dfa57a3";
export const CHAVE = "7b84c3e2-8e3b-4f9e-a0e2-1a2b3c4d5e6f";

export const ok = (data: unknown) => ({ data, response: new Response(null, { status: 200 }) });
export const recusa = (status: number, code = "x", details: string | null = null) => ({
  error: { code, message: code, details, hint: null },
  response: new Response(null, { status }),
});

export function argumentos(caminho: string, dados?: Record<string, string>, comSessao = true) {
  const context = new RouterContextProvider();
  if (comSessao) context.set(contextoDaSessao, { acesso: "sintetico", usuarioId: "u1", email: "casa@example.com", visitante: null });
  const request = new Request(`https://frilabr.com/app${caminho}`, {
    method: dados ? "POST" : "GET",
    headers: { Origin: "https://frilabr.com" },
    body: dados ? new URLSearchParams(dados) : undefined,
  });
  return { request, context, params: {}, url: new URL(request.url), matches: [] } as never;
}

export async function redirecionamento(promessa: Promise<unknown>): Promise<string> {
  try {
    await promessa;
  } catch (resposta) {
    if (resposta instanceof Response) return resposta.headers.get("Location") ?? "";
    throw resposta;
  }
  throw new Error("esperava um redirect");
}
