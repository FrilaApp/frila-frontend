/**
 * Fluxo OAuth PKCE de "Continuar com a Apple" e "Entrar com o Google" no servidor (Worker), sem SDK no navegador.
 * Integrado à Edge Function `POST /functions/v1/autenticar-social` (contrato 0.2.117 + B-116).
 *
 * Segurança:
 * - PKCE S256 com verifier CSPRNG de 32 bytes (43 chars base64url) + `transacao_id` server-side
 *   + `correlacao` CSPRNG de 16 bytes guardados em cookie HttpOnly/SameSite=Lax/10 min por provedor
 *   (`__Host-frila-apple` ou `__Host-frila-google`), impedindo cruzamento entre Apple e Google.
 * - Correlação obrigatória em callbacks de `error` e de `code`: callbacks sem `tx` correspondente
 *   NÃO consomem nem apagam o cookie de uma transação legítima em andamento.
 * - Nenhum token, código OAuth, verifier ou correlação é registrado em log.
 */

import { redirect } from "react-router";

import { contextoDaSessao } from "../contexto";
import type { RouterContextProvider } from "react-router";
import { authDesteAmbiente, socialEntrarLigado } from "./deste-ambiente";
import { BASE } from "./porteiro";
import { cookiesDaSessao, ehPedidoSeguro, lerClaimsDoToken, visitanteDoPedido } from "./sessao";

export type ProvedorSocial = "apple" | "google";

const VIDA_COOKIE_SOCIAL_S = 60 * 10;
const REGEX_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REGEX_VERIFIER_PKCE = /^[A-Za-z0-9_-]{43,128}$/;
const REGEX_CORRELACAO = /^[A-Za-z0-9_-]{16,128}$/;
const REGEX_CODIGO_OAUTH = /^[\x21-\x7e]{4,512}$/;

const NOME_COOKIE_POR_PROVEDOR: Record<ProvedorSocial, string> = {
  apple: "frila-apple",
  google: "frila-google",
};

export type TransacaoSocialCookie = {
  transacaoId: string;
  verifier: string;
  correlacao: string;
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

export function gerarCorrelacaoSocial(): string {
  const bytes = new Uint8Array(16);
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

export function ehCorrelacaoValida(valor: string | null | undefined): valor is string {
  return typeof valor === "string" && REGEX_CORRELACAO.test(valor);
}

export function ehCodigoOauthValido(valor: string | null | undefined): valor is string {
  return typeof valor === "string" && REGEX_CODIGO_OAUTH.test(valor);
}

function nomeCookieSocial(provedor: ProvedorSocial, seguro: boolean): string {
  return `${seguro ? "__Host-" : ""}${NOME_COOKIE_POR_PROVEDOR[provedor]}`;
}

export function cookieTransacaoSocial(
  provedor: ProvedorSocial,
  transacao: TransacaoSocialCookie | null,
  seguro: boolean,
): string {
  const nome = nomeCookieSocial(provedor, seguro);
  const valor = transacao ? `${transacao.transacaoId}.${transacao.verifier}.${transacao.correlacao}` : "";
  const maxAge = transacao ? VIDA_COOKIE_SOCIAL_S : 0;
  const partes = [`${nome}=${valor}`, "Path=/", `Max-Age=${maxAge}`, "HttpOnly", "SameSite=Lax"];
  if (seguro) partes.push("Secure");
  return partes.join("; ");
}

export function lerCookieTransacaoSocial(
  provedor: ProvedorSocial,
  request: Request,
  seguro: boolean,
): {
  presente: boolean;
  transacao: TransacaoSocialCookie | null;
} {
  const nome = nomeCookieSocial(provedor, seguro);
  let bruto: string | null = null;
  for (const par of (request.headers.get("Cookie") ?? "").split(";")) {
    const corte = par.indexOf("=");
    if (corte > 0 && par.slice(0, corte).trim() === nome) {
      bruto = par.slice(corte + 1).trim();
      break;
    }
  }
  if (!bruto) return { presente: false, transacao: null };
  const partes = bruto.split(".");
  if (partes.length !== 3) return { presente: true, transacao: null };
  const [transacaoId, verifier, correlacao] = partes;
  if (!transacaoId || !REGEX_UUID.test(transacaoId) || !ehVerifierPkceValido(verifier) || !ehCorrelacaoValida(correlacao)) {
    return { presente: true, transacao: null };
  }
  return { presente: true, transacao: { transacaoId, verifier, correlacao } };
}

export function classificarErroCallbackSocial(
  provedor: ProvedorSocial,
  error: string | null,
  errorCode: string | null,
  errorDescription: string | null,
): "apple_cancelado" | "google_cancelado" | "conflito_identidade" | "apple_recusado" | "google_recusado" {
  const combinado = `${error ?? ""} ${errorCode ?? ""} ${errorDescription ?? ""}`.toLowerCase();
  if (combinado.includes("access_denied") || combinado.includes("user_cancelled") || combinado.includes("canceled")) {
    return `${provedor}_cancelado`;
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
  return `${provedor}_recusado`;
}

function redirecionarSocial(
  provedor: ProvedorSocial,
  destino: string,
  opcoes: { limparCookie: boolean; seguro: boolean; cookiesExtras?: string[] },
): Response {
  const cabecalhos = new Headers({
    Location: destino,
    "Cache-Control": "no-store",
  });
  if (opcoes.limparCookie) {
    cabecalhos.append("Set-Cookie", cookieTransacaoSocial(provedor, null, opcoes.seguro));
  }
  for (const linha of opcoes.cookiesExtras ?? []) cabecalhos.append("Set-Cookie", linha);
  return new Response(null, { status: 302, headers: cabecalhos });
}

export async function iniciarEntradaSocial(
  provedor: ProvedorSocial,
  request: Request,
  context: Readonly<RouterContextProvider>,
): Promise<Response> {
  if (!socialEntrarLigado(provedor)) {
    return new Response(null, { status: 404, headers: { "Cache-Control": "no-store" } });
  }
  if (context.get(contextoDaSessao)) {
    throw redirect("/");
  }

  const auth = authDesteAmbiente();
  if (!auth) {
    throw redirect("/entrar?erro=indisponivel");
  }

  const seguro = ehPedidoSeguro(request);
  const visitante = visitanteDoPedido(request);
  const verifier = gerarVerifierPkce();
  const correlacao = gerarCorrelacaoSocial();
  const codeChallenge = await desafioPkceS256(verifier);
  const urlRetorno = new URL(`${BASE}/entrar/${provedor}/retorno`, new URL(request.url).origin);
  urlRetorno.searchParams.set("tx", correlacao);

  const inicio = await auth.iniciarLoginSocialPkce({
    provedor,
    codeChallenge,
    redirectTo: urlRetorno.toString(),
    visitante,
  });
  if (!inicio.ok) {
    throw redirect(`/entrar?erro=${inicio.motivo}`);
  }

  return new Response(null, {
    status: 302,
    headers: {
      Location: inicio.urlAutorizacao,
      "Cache-Control": "no-store",
      "Set-Cookie": cookieTransacaoSocial(
        provedor,
        { transacaoId: inicio.transacaoId, verifier, correlacao },
        seguro,
      ),
    },
  });
}

export async function concluirEntradaSocial(
  provedor: ProvedorSocial,
  request: Request,
  context?: Readonly<RouterContextProvider>,
): Promise<Response> {
  const seguro = ehPedidoSeguro(request);

  if (!socialEntrarLigado(provedor)) {
    return new Response(null, {
      status: 404,
      headers: { "Cache-Control": "no-store" },
    });
  }
  if (context?.get(contextoDaSessao)) {
    return redirecionarSocial(provedor, `${BASE}/`, { limparCookie: true, seguro });
  }

  const url = new URL(request.url);
  const { presente, transacao } = lerCookieTransacaoSocial(provedor, request, seguro);
  const txCallback = url.searchParams.get("tx") ?? url.searchParams.get("state");
  const txCorresponde =
    transacao !== null &&
    txCallback !== null &&
    (txCallback === transacao.correlacao || txCallback === transacao.transacaoId);

  const erroCallback = url.searchParams.get("error");
  const erroCodigo = url.searchParams.get("error_code");
  const erroDescricao = url.searchParams.get("error_description");
  if (erroCallback || erroCodigo) {
    const motivo = classificarErroCallbackSocial(provedor, erroCallback, erroCodigo, erroDescricao);
    // Callback com erro sem correspondência de `tx` (ex.: link forjado) NÃO apaga transação ativa.
    const limparCookie = (presente && transacao === null) || txCorresponde;
    return redirecionarSocial(provedor, `${BASE}/entrar?erro=${motivo}`, { limparCookie, seguro });
  }

  const codigo = url.searchParams.get("code");
  if (!ehCodigoOauthValido(codigo)) {
    return redirecionarSocial(provedor, `${BASE}/entrar?erro=${provedor}_recusado`, {
      limparCookie: presente && transacao === null,
      seguro,
    });
  }

  if (!transacao) {
    return redirecionarSocial(provedor, `${BASE}/entrar?erro=${provedor}_recusado`, {
      limparCookie: presente,
      seguro,
    });
  }

  // Correlação obrigatória no retorno com `code`: rejeita tx ausente ou divergente sem apagar cookie legítimo.
  if (!txCorresponde) {
    return redirecionarSocial(provedor, `${BASE}/entrar?erro=${provedor}_recusado`, {
      limparCookie: false,
      seguro,
    });
  }

  const auth = authDesteAmbiente();
  if (!auth) {
    return redirecionarSocial(provedor, `${BASE}/entrar?erro=indisponivel`, { limparCookie: false, seguro });
  }

  const troca = await auth.concluirLoginSocialPkce({
    provedor,
    transacaoId: transacao.transacaoId,
    codigo,
    codeVerifier: transacao.verifier,
    visitante: visitanteDoPedido(request),
  });
  if (!troca.ok) {
    // Em indisponibilidade transitória mantém cookie; em recusa definitiva consome/limpa.
    const limparCookie = troca.motivo !== "indisponivel";
    return redirecionarSocial(provedor, `${BASE}/entrar?erro=${troca.motivo}`, { limparCookie, seguro });
  }

  const precisaDefinirSenha =
    troca.precisaDefinirSenha || lerClaimsDoToken(troca.sessao.access_token).precisaDefinirSenha;
  const destino = precisaDefinirSenha ? `${BASE}/definir-senha?origem=pendente` : `${BASE}/`;
  return redirecionarSocial(provedor, destino, {
    limparCookie: true,
    seguro,
    cookiesExtras: cookiesDaSessao(troca.sessao, seguro),
  });
}
