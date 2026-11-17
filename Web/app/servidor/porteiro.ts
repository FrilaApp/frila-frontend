/**
 * O que o Worker responde antes de entregar o pedido ao React Router.
 *
 * - Pedido que muda dado (POST e afins) só passa se veio de uma página do próprio endereço (cabeçalho `Origin`).
 *   Com o cookie `SameSite=Lax`, é a defesa contra pedido forjado por outro site (CSRF).
 * - Em produção, pedido por http vai para https (301), antes de tudo: sem isso a página e os cookies sairiam sem
 *   criptografia (achado A1 do Juiz).
 * - A web mora em /app. Pedido fora de /app vai para /app/.
 * - Com a chave desligada, só existem a página inicial (ela mostra "em breve"), a
 *   rota de saúde, a página "sem conexão" e o texto neutro do push: qualquer outro caminho volta para o início, e nenhum loader das outras rotas roda.
 */
export const BASE = "/app";
/** Pedidos de dados da página inicial (o React Router v8 pede `/app.data` ou `/app/_.data` ao navegar sem recarregar). */
const DADOS_DO_INICIO = new Set([`${BASE}.data`, `${BASE}/_.data`]);
// A página "sem conexão" e o texto neutro do push ficam abertos: o service worker os guarda ao instalar, com a chave
// ligada ou desligada. Nenhum dos dois tem dado de ninguém.
const SEMPRE_ABERTOS = new Set([BASE, `${BASE}/`, `${BASE}/saude`, `${BASE}/sem-conexao`, `${BASE}/avisos/texto-neutro`, ...DADOS_DO_INICIO]);
const METODOS_QUE_SO_LEEM = new Set(["GET", "HEAD", "OPTIONS"]);

export function respostaAntesDoApp(request: Request, opcoes: { webLigada: boolean; exigirHttps?: boolean }): Response | null {
  const url = new URL(request.url);
  if (opcoes.exigirHttps && url.protocol === "http:") {
    url.protocol = "https:";
    return new Response(null, { status: 301, headers: { Location: url.toString(), "Cache-Control": "no-store" } });
  }
  const caminho = url.pathname;
  const dentroDaBase = caminho === BASE || caminho.startsWith(`${BASE}/`) || DADOS_DO_INICIO.has(caminho);

  if (!METODOS_QUE_SO_LEEM.has(request.method.toUpperCase()) && request.headers.get("Origin") !== url.origin) {
    return new Response(null, { status: 403, headers: { "Cache-Control": "no-store" } });
  }

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
