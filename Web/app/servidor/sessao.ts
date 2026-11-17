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
/** Sessões do Auth que esta pessoa encerrou neste navegador (as últimas). Barra resposta atrasada que regrave a sessão. */
const NOME_ENCERRADAS = "frila-encerradas";
const MAXIMO_DE_ENCERRADAS = 5;
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
  return {
    acesso: `${prefixo}${NOME_ACESSO}`,
    renovacao: `${prefixo}${NOME_RENOVACAO}`,
    encerradas: `${prefixo}${NOME_ENCERRADAS}`,
  };
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

function sessoesEncerradas(request: Request): string[] {
  const valor = cookiesDoPedido(request).get(nomes(ehPedidoSeguro(request)).encerradas) ?? "";
  return valor.split(".").filter((chave) => /^[\w-]{1,64}$/.test(chave));
}

/**
 * A sessão do Auth a que o token pertence (`session_id`): a renovação troca o token e mantém a sessão.
 * Sem `session_id`, usa o fim da assinatura do próprio token.
 */
function chaveDaSessao(acesso: string): string | null {
  const { sessaoId } = lerToken(acesso);
  if (sessaoId && /^[\w-]{1,64}$/.test(sessaoId)) return sessaoId;
  const assinatura = (acesso.split(".")[2] ?? "").replace(/[^\w-]/g, "").slice(-43);
  return assinatura.length > 0 ? assinatura : null;
}

function foiEncerrada(acesso: string, encerradas: string[]): boolean {
  const chave = chaveDaSessao(acesso);
  return chave !== null && encerradas.includes(chave);
}

/**
 * Ao sair: guarda a sessão encerrada num cookie próprio, que nenhuma outra resposta regrava. Assim uma renovação que
 * ficou retida e responde depois do sair não reativa a sessão: o próximo pedido vê que ela foi encerrada e sai.
 */
export function cookieDeSessaoEncerrada(request: Request, acesso: string): string | null {
  const chave = chaveDaSessao(acesso);
  if (!chave) return null;
  const encerradas = [...sessoesEncerradas(request).filter((c) => c !== chave), chave].slice(-MAXIMO_DE_ENCERRADAS);
  const seguro = ehPedidoSeguro(request);
  return cookie(nomes(seguro).encerradas, encerradas.join("."), VIDA_DA_RENOVACAO_S, seguro);
}

/** A resposta já mexe nos cookies da sessão? (entrar e sair gravam os seus; a renovação não pode passar por cima.) */
export function respostaJaGravaSessao(resposta: Response): boolean {
  return resposta.headers.getSetCookie().some((linha) => /^(__Host-)?frila-(acesso|renovacao)=/.test(linha));
}

/**
 * Lê o corpo do token de acesso SEM conferir a assinatura: serve só para saber quando renovar e o que mostrar.
 * Quem confere o token é o Supabase, em cada pedido. Nada aqui decide permissão.
 */
export function lerToken(acesso: string): {
  venceEm: number | null;
  usuarioId: string | null;
  email: string | null;
  sessaoId: string | null;
} {
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
      sessaoId: typeof campos.session_id === "string" ? campos.session_id : null,
    };
  } catch {
    return { venceEm: null, usuarioId: null, email: null, sessaoId: null };
  }
}

export function sessaoAtualDe(acesso: string): SessaoAtual {
  const { usuarioId, email } = lerToken(acesso);
  return { acesso, usuarioId, email };
}

export type Renovacao = { ok: true; sessao: Sessao } | { ok: false; motivo: "recusada" | "indisponivel" };

/**
 * Decide a sessão de um pedido, uma vez só (no middleware da raiz):
 * - token de acesso ainda bom: usa;
 * - vencido ou perto de vencer, com token de renovação: renova e manda regravar os cookies;
 * - renovação recusada: sai (apaga os cookies);
 * - Supabase fora do ar: segue com o token atual enquanto ele valer, sem apagar nada;
 * - token de uma sessão que a pessoa encerrou neste navegador (antes ou depois de renovar): sai.
 */
export async function resolverSessao(
  request: Request,
  renovar: (tokenDeRenovacao: string) => Promise<Renovacao>,
  agoraEmSegundos: number = Math.floor(Date.now() / 1000),
): Promise<{ sessao: SessaoAtual | null; cookies: string[] }> {
  const seguro = ehPedidoSeguro(request);
  const { acesso, renovacao } = lerCookiesDaSessao(request);
  if (!acesso && !renovacao) {
    return { sessao: null, cookies: [] };
  }

  const encerradas = sessoesEncerradas(request);
  if (acesso && foiEncerrada(acesso, encerradas)) {
    return { sessao: null, cookies: cookiesDeSaida(seguro) };
  }

  const venceEm = acesso ? lerToken(acesso).venceEm : null;
  const acessoVale = acesso !== null && venceEm !== null && venceEm > agoraEmSegundos;
  const acessoFolgado = acessoVale && venceEm - agoraEmSegundos > FOLGA_DA_RENOVACAO_S;
  if (acesso && acessoFolgado) {
    return { sessao: sessaoAtualDe(acesso), cookies: [] };
  }
  if (!renovacao) {
    return acesso && acessoVale
      ? { sessao: sessaoAtualDe(acesso), cookies: [] }
      : { sessao: null, cookies: cookiesDeSaida(seguro) };
  }

  const resultado = await renovar(renovacao);
  if (resultado.ok) {
    if (foiEncerrada(resultado.sessao.access_token, encerradas)) {
      return { sessao: null, cookies: cookiesDeSaida(seguro) };
    }
    return { sessao: sessaoAtualDe(resultado.sessao.access_token), cookies: cookiesDaSessao(resultado.sessao, seguro) };
  }
  if (resultado.motivo === "recusada") {
    return { sessao: null, cookies: cookiesDeSaida(seguro) };
  }
  return { sessao: acesso && acessoVale ? sessaoAtualDe(acesso) : null, cookies: [] };
}
