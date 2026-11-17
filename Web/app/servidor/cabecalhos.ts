/**
 * Cabeçalhos de segurança da web.
 *
 * - `cabecalhosFixos`: vão em TODA resposta do Worker (página, dados, redirecionamento).
 * - `politicaDeConteudo`: a CSP das páginas. Script só do próprio endereço e com o nonce da resposta;
 *   nada de script ou estilo embutido sem nonce, nada de moldura em outro site.
 */
export const cabecalhosFixos: Readonly<Record<string, string>> = {
  // Sem includeSubDomains nem preload: a web divide o domínio com o site e não decide por ele.
  "Strict-Transport-Security": "max-age=31536000",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "Cross-Origin-Opener-Policy": "same-origin",
  "Permissions-Policy": "geolocation=(self), camera=(), microphone=(), payment=(), usb=()",
};

export function gerarNonce(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return btoa(String.fromCharCode(...bytes));
}

export function politicaDeConteudo(nonce: string): string {
  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}'`,
    "style-src 'self'",
    "img-src 'self' data:",
    "font-src 'self'",
    // Push (fase 4): o token do aparelho sai do navegador direto para o Firebase. Só estes dois endereços.
    "connect-src 'self' https://firebaseinstallations.googleapis.com https://fcmregistrations.googleapis.com",
    "manifest-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join("; ");
}

/** Devolve a mesma resposta com os cabeçalhos fixos. O que a rota já definiu não é trocado. */
export function comCabecalhosDeSeguranca(resposta: Response): Response {
  const nova = new Response(resposta.body, resposta);
  for (const [nome, valor] of Object.entries(cabecalhosFixos)) {
    nova.headers.set(nome, valor);
  }
  if (!nova.headers.has("Cache-Control")) {
    nova.headers.set("Cache-Control", "private, no-store");
  }
  return nova;
}
