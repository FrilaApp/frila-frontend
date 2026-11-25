/**
 * Fluxo OAuth PKCE de "Continuar com a Apple" no servidor (Worker), sem SDK no navegador.
 *
 * Segurança:
 * - PKCE S256 com verifier CSPRNG de 32 bytes (43 chars base64url) guardado em cookie HttpOnly/SameSite=Lax/10 min.
 * - O cookie é apagado em TODOS os desfechos do retorno (sucesso, cancelamento, erro ou conflito).
 * - Nenhum token, código OAuth ou verifier é registrado em log.
 * - Identidade existente é preservada: conflitos de identidade são recusados explicitamente sem auto-vínculo por e-mail.
 */

const NOME_COOKIE_APPLE = "frila-apple";
const VIDA_COOKIE_APPLE_S = 60 * 10;
const REGEX_VERIFIER_PKCE = /^[A-Za-z0-9_-]{43,128}$/;
const REGEX_CODIGO_OAUTH = /^[\x21-\x7e]{4,512}$/;

function bytesParaBase64Url(bytes: Uint8Array): string {
  let binario = "";
  for (const b of bytes) binario += String.fromCharCode(b);
  return btoa(binario).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function gerarVerifierPkce(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return bytesParaBase64Url(bytes);
}

export async function desafioPkceS256(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return bytesParaBase64Url(new Uint8Array(digest));
}

export function ehVerifierPkceValido(valor: string | null | undefined): valor is string {
  return typeof valor === "string" && REGEX_VERIFIER_PKCE.test(valor);
}

export function ehCodigoOauthValido(valor: string | null | undefined): valor is string {
  return typeof valor === "string" && REGEX_CODIGO_OAUTH.test(valor);
}

function nomeCookieApple(seguro: boolean): string {
  return `${seguro ? "__Host-" : ""}${NOME_COOKIE_APPLE}`;
}

export function cookieVerifierApple(verifier: string | null, seguro: boolean): string {
  const nome = nomeCookieApple(seguro);
  const maxAge = verifier ? VIDA_COOKIE_APPLE_S : 0;
  const partes = [`${nome}=${verifier ?? ""}`, "Path=/", `Max-Age=${maxAge}`, "HttpOnly", "SameSite=Lax"];
  if (seguro) partes.push("Secure");
  return partes.join("; ");
}

export function lerCookieVerifierApple(request: Request, seguro: boolean): string | null {
  const nome = nomeCookieApple(seguro);
  for (const par of (request.headers.get("Cookie") ?? "").split(";")) {
    const corte = par.indexOf("=");
    if (corte > 0 && par.slice(0, corte).trim() === nome) {
      return par.slice(corte + 1).trim() || null;
    }
  }
  return null;
}

export function montarUrlAutorizacaoApple(params: {
  supabaseUrl: string;
  urlRetorno: string;
  codeChallenge: string;
}): string {
  const base = params.supabaseUrl.replace(/\/$/, "");
  const url = new URL(`${base}/auth/v1/authorize`);
  url.searchParams.set("provider", "apple");
  url.searchParams.set("redirect_to", params.urlRetorno);
  url.searchParams.set("code_challenge", params.codeChallenge);
  url.searchParams.set("code_challenge_method", "s256");
  return url.toString();
}

export function classificarErroCallbackApple(
  error: string | null,
  errorCode: string | null,
  errorDescription: string | null,
): "apple_cancelado" | "conflito_identidade" | "apple_recusado" {
  const combinado = `${error ?? ""} ${errorCode ?? ""} ${errorDescription ?? ""}`.toLowerCase();
  if (combinado.includes("access_denied") || combinado.includes("user_cancelled") || combinado.includes("canceled")) {
    return "apple_cancelado";
  }
  if (
    combinado.includes("identity_already_exists") ||
    combinado.includes("manual_linking") ||
    combinado.includes("email_conflict") ||
    combinado.includes("already_registered") ||
    combinado.includes("account_exists")
  ) {
    return "conflito_identidade";
  }
  return "apple_recusado";
}
