/**
 * Fluxo OAuth PKCE de "Continuar com a Apple" no servidor (Worker), sem SDK no navegador.
 * Integrado à Edge Function `POST /functions/v1/autenticar-social` (contrato 0.2.117).
 *
 * Segurança:
 * - PKCE S256 com verifier CSPRNG de 32 bytes (43 chars base64url) + `transacao_id` server-side
 *   guardados em cookie HttpOnly/SameSite=Lax/10 min (`__Host-frila-apple`).
 * - Correlação contra callback forjado (P2): callbacks `?error=...` ou sem `code` que não
 *   comprovam correspondência de `tx === transacaoId` NÃO apagam o cookie da transação ativa.
 * - Nenhum token, código OAuth ou verifier é registrado em log.
 */

const NOME_COOKIE_APPLE = "frila-apple";
const VIDA_COOKIE_APPLE_S = 60 * 10;
const REGEX_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REGEX_VERIFIER_PKCE = /^[A-Za-z0-9_-]{43,128}$/;
const REGEX_CODIGO_OAUTH = /^[\x21-\x7e]{4,512}$/;

export type TransacaoAppleCookie = {
  transacaoId: string;
  verifier: string;
};

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

export function cookieTransacaoApple(transacao: TransacaoAppleCookie | null, seguro: boolean): string {
  const nome = nomeCookieApple(seguro);
  const valor = transacao ? `${transacao.transacaoId}.${transacao.verifier}` : "";
  const maxAge = transacao ? VIDA_COOKIE_APPLE_S : 0;
  const partes = [`${nome}=${valor}`, "Path=/", `Max-Age=${maxAge}`, "HttpOnly", "SameSite=Lax"];
  if (seguro) partes.push("Secure");
  return partes.join("; ");
}

export function lerCookieTransacaoApple(request: Request, seguro: boolean): {
  presente: boolean;
  transacao: TransacaoAppleCookie | null;
} {
  const nome = nomeCookieApple(seguro);
  let bruto: string | null = null;
  for (const par of (request.headers.get("Cookie") ?? "").split(";")) {
    const corte = par.indexOf("=");
    if (corte > 0 && par.slice(0, corte).trim() === nome) {
      bruto = par.slice(corte + 1).trim();
      break;
    }
  }
  if (!bruto) return { presente: false, transacao: null };
  const sep = bruto.indexOf(".");
  if (sep <= 0) return { presente: true, transacao: null };
  const transacaoId = bruto.slice(0, sep);
  const verifier = bruto.slice(sep + 1);
  if (!REGEX_UUID.test(transacaoId) || !ehVerifierPkceValido(verifier)) {
    return { presente: true, transacao: null };
  }
  return { presente: true, transacao: { transacaoId, verifier } };
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
