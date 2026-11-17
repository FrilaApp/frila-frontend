/**
 * O que o Worker responde antes de entregar o pedido ao React Router.
 *
 * - A web mora em /app. Pedido fora de /app vai para /app/.
 * - Com a chave desligada, só existem a página inicial (ela mostra "em breve") e a
 *   rota de saúde: qualquer outro caminho volta para o início, e nenhum loader das outras rotas roda.
 */
export const BASE = "/app";
const SEMPRE_ABERTOS = new Set([BASE, `${BASE}/`, `${BASE}/saude`]);

export function respostaAntesDoApp(request: Request, opcoes: { webLigada: boolean }): Response | null {
  const url = new URL(request.url);
  const caminho = url.pathname;
  const dentroDaBase = caminho === BASE || caminho.startsWith(`${BASE}/`);

  if (!dentroDaBase) {
    return redirecionar(url, `${BASE}/`);
  }
  if (opcoes.webLigada) {
    return null;
  }

  return SEMPRE_ABERTOS.has(caminho) ? null : redirecionar(url, `${BASE}/`);
}

function redirecionar(url: URL, caminho: string): Response {
  return new Response(null, {
    status: 302,
    headers: { Location: new URL(caminho, url.origin).toString(), "Cache-Control": "no-store" },
  });
}
