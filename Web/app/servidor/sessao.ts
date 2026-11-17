/**
 * Sessão da web: dois cookies `HttpOnly` gravados pelo Worker. O token nunca chega ao JavaScript da página
 * (RNF07 do contrato). Este arquivo só monta, lê e avalia os cookies; quem fala com o Supabase é `auth.ts`.
 */
import type { components } from "../contrato/tipos.gerado";

export type Sessao = components["schemas"]["Sessao"];

/** O que loaders e actions enxergam da sessão. O token de renovação nunca sai deste módulo. */
export type SessaoAtual = { acesso: string; usuarioId: string | null; email: string | null };

const NOME_ACESSO = "frila-acesso";
const NOME_RENOVACAO = "frila-renovacao";
/** Sem uso por 30 dias, a pessoa entra de novo. */
const VIDA_DA_RENOVACAO_S = 60 * 60 * 24 * 30;
/** Renova um pouco antes de vencer, para o token não morrer no meio de um pedido. */
export const FOLGA_DA_RENOVACAO_S = 60;

/**
 * Em HTTPS os cookies levam `Secure` e o prefixo `__Host-`: o navegador só aceita esse nome vindo do próprio host,
 * com `Path=/` e sem `Domain`, então um subdomínio não planta sessão. `Path=/` também cobre `/app.data`, que um
 * `Path=/app` não cobre. Só o servidor local roda em HTTP (sem prefixo).
 */
function nomes(seguro: boolean) {
  const prefixo = seguro ? "__Host-" : "";
  return { acesso: `${prefixo}${NOME_ACESSO}`, renovacao: `${prefixo}${NOME_RENOVACAO}` };
}

function cookie(nome: string, valor: string, vidaEmSegundos: number, seguro: boolean): string {
  const partes = [`${nome}=${valor}`, "Path=/", `Max-Age=${vidaEmSegundos}`, "HttpOnly", "SameSite=Lax"];
  if (seguro) partes.push("Secure");
  return partes.join("; ");
}

export function ehPedidoSeguro(request: Request): boolean {
  return new URL(request.url).protocol === "https:";
}

export function cookiesDaSessao(sessao: Sessao, seguro: boolean): string[] {
  const nome = nomes(seguro);
  return [
    cookie(nome.acesso, sessao.access_token, Math.max(0, sessao.expires_in), seguro),
    cookie(nome.renovacao, sessao.refresh_token, VIDA_DA_RENOVACAO_S, seguro),
  ];
}

export function cookiesDeSaida(seguro: boolean): string[] {
  const nome = nomes(seguro);
  return [cookie(nome.acesso, "", 0, seguro), cookie(nome.renovacao, "", 0, seguro)];
}

function cookiesDoPedido(request: Request): Map<string, string> {
  const cookies = new Map<string, string>();
  for (const par of (request.headers.get("Cookie") ?? "").split(";")) {
    const corte = par.indexOf("=");
    if (corte > 0) cookies.set(par.slice(0, corte).trim(), par.slice(corte + 1).trim());
  }
  return cookies;
}

export function lerCookiesDaSessao(request: Request): { acesso: string | null; renovacao: string | null } {
  const nome = nomes(ehPedidoSeguro(request));
  const cookies = cookiesDoPedido(request);
  return { acesso: cookies.get(nome.acesso) || null, renovacao: cookies.get(nome.renovacao) || null };
}

/** A resposta já mexe nos cookies da sessão? (entrar e sair gravam os seus; a renovação não pode passar por cima.) */
export function respostaJaGravaSessao(resposta: Response): boolean {
  return resposta.headers.getSetCookie().some((linha) => /^(__Host-)?frila-(acesso|renovacao)=/.test(linha));
}

/**
 * Lê o corpo do token de acesso SEM conferir a assinatura: serve só para saber quando renovar e o que mostrar.
 * Quem confere o token é o Supabase, em cada pedido. Nada aqui decide permissão.
 */
export function lerToken(acesso: string): { venceEm: number | null; usuarioId: string | null; email: string | null } {
  try {
    const corpo = acesso.split(".")[1] ?? "";
    const bytes = Uint8Array.from(atob(corpo.replace(/-/g, "+").replace(/_/g, "/")), (letra) => letra.charCodeAt(0));
    const dados: unknown = JSON.parse(new TextDecoder().decode(bytes));
    if (typeof dados !== "object" || dados === null) throw new Error("token sem corpo");
    const campos = dados as Record<string, unknown>;
    return {
      venceEm: typeof campos.exp === "number" ? campos.exp : null,
      usuarioId: typeof campos.sub === "string" ? campos.sub : null,
      email: typeof campos.email === "string" ? campos.email : null,
    };
  } catch {
    return { venceEm: null, usuarioId: null, email: null };
  }
}

export function sessaoAtualDe(acesso: string): SessaoAtual {
  const { usuarioId, email } = lerToken(acesso);
  return { acesso, usuarioId, email };
}

export type Renovacao = { ok: true; sessao: Sessao } | { ok: false; motivo: "recusada" | "indisponivel" };
export type Conferencia = { ok: true } | { ok: false; motivo: "recusada" | "indisponivel" };

/** O que a sessão precisa do Auth. As duas chamadas nunca acontecem no mesmo pedido. */
export type AuthDaSessao = {
  renovar: (tokenDeRenovacao: string) => Promise<Renovacao>;
  conferir: (acesso: string) => Promise<Conferencia>;
};

/** `ok`: há sessão · `recusou`: a sessão não existe mais · `indisponivel`: o Auth falhou · `sem_cookie`: ninguém entrou. */
export type RespostaDoAuth = "ok" | "recusou" | "indisponivel" | "sem_cookie";

type Decisao = { sessao: SessaoAtual | null; cookies: string[]; auth: RespostaDoAuth };

/**
 * Decide a sessão de um pedido, uma vez só (no middleware da raiz). Quem diz se a sessão existe é o Auth, no
 * servidor, em todo pedido com cookie de sessão, com UMA chamada:
 * - token de acesso com folga: confere no Auth (`conferir`);
 * - vencido ou perto de vencer, com token de renovação: renova (a renovação já é a conferência) e regrava os cookies;
 * - Auth recusa (sessão encerrada, token ruim): sai e apaga os cookies;
 * - Auth fora do ar ou sem resposta no prazo: sem sessão neste pedido, leitura ou envio, sem apagar os cookies
 *   (quando o Auth voltar, a pessoa segue logada). Nada guardado no navegador decide sozinho que há sessão.
 */
export async function resolverSessao(
  request: Request,
  auth: AuthDaSessao | null,
  agoraEmSegundos: number = Math.floor(Date.now() / 1000),
): Promise<Decisao> {
  const seguro = ehPedidoSeguro(request);
  const { acesso, renovacao } = lerCookiesDaSessao(request);
  if (!acesso && !renovacao) {
    return { sessao: null, cookies: [], auth: "sem_cookie" };
  }
  if (!auth) {
    return { sessao: null, cookies: [], auth: "indisponivel" };
  }

  const venceEm = acesso ? lerToken(acesso).venceEm : null;
  const acessoVale = acesso !== null && venceEm !== null && venceEm > agoraEmSegundos;
  const acessoFolgado = acessoVale && venceEm - agoraEmSegundos > FOLGA_DA_RENOVACAO_S;

  if (acesso && (acessoFolgado || (acessoVale && !renovacao))) {
    const conferencia = await auth.conferir(acesso);
    if (conferencia.ok) return { sessao: sessaoAtualDe(acesso), cookies: [], auth: "ok" };
    return conferencia.motivo === "recusada"
      ? { sessao: null, cookies: cookiesDeSaida(seguro), auth: "recusou" }
      : { sessao: null, cookies: [], auth: "indisponivel" };
  }
  if (!renovacao) {
    // Token vencido (ou ilegível) e nada com que renovar: não há sessão a manter.
    return { sessao: null, cookies: cookiesDeSaida(seguro), auth: "recusou" };
  }

  const resultado = await auth.renovar(renovacao);
  if (resultado.ok) {
    return { sessao: sessaoAtualDe(resultado.sessao.access_token), cookies: cookiesDaSessao(resultado.sessao, seguro), auth: "ok" };
  }
  return resultado.motivo === "recusada"
    ? { sessao: null, cookies: cookiesDeSaida(seguro), auth: "recusou" }
    : { sessao: null, cookies: [], auth: "indisponivel" };
}
