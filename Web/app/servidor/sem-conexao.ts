import { textos } from "../textos/pt-BR";

/**
 * A página "sem conexão" (item 1.10). O service worker (`public/app/sw.js`) guarda esta resposta ao instalar e a mostra
 * quando uma navegação em /app fica sem rede. Por isso ela se basta: sem script, sem arquivo de fora, sem dado de
 * ninguém. O único estilo é o embutido abaixo, liberado na CSP pelo hash (sem `unsafe-inline`).
 */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
const ESTILO =
  "body{margin:0;font-family:system-ui,-apple-system,sans-serif;line-height:1.5}" +
  "main{max-width:36rem;min-height:100dvh;margin:0 auto;padding:1.5rem;display:flex;flex-direction:column;justify-content:center;gap:1rem}" +
  "h1{margin:0;font-size:1.875rem}p{margin:0}a{display:inline-flex;min-height:3rem;align-items:center;font-weight:700}";

function escapar(texto: string): string {
  return texto.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

async function hashDoEstilo(): Promise<string> {
  const resumo = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(ESTILO));
  return btoa(String.fromCharCode(...new Uint8Array(resumo)));
}

export async function paginaSemConexao(): Promise<Response> {
  const t = textos.pwa.semConexao;
  const html =
    '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex">' +
    `<title>${escapar(t.tituloDaAba)}</title><style>${ESTILO}</style></head>` +
    `<body><main><p>${escapar(textos.marca)}</p><h1>${escapar(t.titulo)}</h1><p>${escapar(t.corpo)}</p>` +
    `<p><a href="/app/">${escapar(t.tentarDeNovo)}</a></p></main></body></html>`;
  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Content-Security-Policy": `default-src 'none'; style-src 'sha256-${await hashDoEstilo()}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
      "Cache-Control": "no-cache",
    },
  });
}
