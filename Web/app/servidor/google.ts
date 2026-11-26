/**
 * Entrar com Google pelo fluxo OAuth do Supabase com PKCE, todo no servidor (sem SDK). O Worker gera o verifier,
 * guarda num cookie HttpOnly de vida curta e manda a pessoa ao Google pelo Supabase; na volta, troca o `code` com o
 * verifier. Nada aqui é logado: nem verifier, nem challenge, nem code.
 */
import { BASE } from "./porteiro";

/** Vida do cookie do verifier: o tempo de a pessoa escolher a conta no Google. */
export const VIDA_DO_VERIFIER_S = 600;

/** O botão e as duas rotas só existem quando a variável do Worker `GOOGLE_ENTRAR` vale `ligado` (só no ambiente de dev). */
export function googleLigado(valor: string | undefined): boolean {
  return valor === "ligado";
}

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** `code_verifier` do PKCE (RFC 7636): 32 bytes aleatórios em base64url, 43 caracteres. */
export function novoVerifier(): string {
  return base64url(crypto.getRandomValues(new Uint8Array(32)));
}

/** Formato do verifier que o Worker aceita ler do cookie (43 a 128 caracteres do alfabeto da RFC 7636). */
export function verifierValido(valor: string | null): valor is string {
  return valor !== null && /^[A-Za-z0-9\-._~]{43,128}$/.test(valor);
}

/** `code_challenge` método S256: base64url do SHA-256 do verifier. */
export async function desafioS256(verifier: string): Promise<string> {
  const resumo = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier));
  return base64url(new Uint8Array(resumo));
}

/** Endereço de retorno desta web (precisa estar na lista de redirect do Supabase do ambiente). */
export function enderecoDeRetorno(request: Request): string {
  return new URL(`${BASE}/entrar/google/retorno`, request.url).toString();
}
