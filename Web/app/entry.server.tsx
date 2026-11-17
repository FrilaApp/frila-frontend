import { isbot } from "isbot";
import { renderToReadableStream } from "react-dom/server";
import type { EntryContext } from "react-router";
import { ServerRouter } from "react-router";

import { gerarNonce, politicaDeConteudo } from "./servidor/cabecalhos";

export const streamTimeout = 5_000;

export default async function handleRequest(
  request: Request,
  responseStatusCode: number,
  responseHeaders: Headers,
  routerContext: EntryContext,
) {
  // Um nonce novo por página: só os scripts que o servidor escreveu rodam.
  // No servidor de desenvolvimento a CSP fica de fora (o Vite injeta script e estilo próprios).
  const nonce = gerarNonce();
  if (import.meta.env.PROD) {
    responseHeaders.set("Content-Security-Policy", politicaDeConteudo(nonce));
  }
  responseHeaders.set("Content-Type", "text/html; charset=utf-8");

  // https://httpwg.org/specs/rfc9110.html#HEAD
  if (request.method.toUpperCase() === "HEAD") {
    return new Response(null, { status: responseStatusCode, headers: responseHeaders });
  }

  let shellRendered = false;
  const userAgent = request.headers.get("user-agent");

  const body = await renderToReadableStream(<ServerRouter context={routerContext} url={request.url} nonce={nonce} />, {
    nonce,
    signal: AbortSignal.timeout(streamTimeout + 1000),
    onError(error: unknown) {
      responseStatusCode = 500;
      // Erro durante o streaming, depois da casca: registra. O erro da casca rejeita e o React Router registra.
      if (shellRendered) {
        console.error(error);
      }
    },
  });
  shellRendered = true;

  // Robô de busca espera a página inteira.
  if (userAgent && isbot(userAgent)) {
    await body.allReady;
  }

  return new Response(body, { headers: responseHeaders, status: responseStatusCode });
}
