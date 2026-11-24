/**
 * PONTO ÚNICO de saída do Worker para o `/rest/v1` do Supabase com o token de quem entrou (B-116, ADR-002).
 *
 * O Supabase só enxerga o Worker; sem ajuda, o registro de acesso (LGPD) gravaria o IP do Worker. Então cada chamada com
 * token leva 3 cabeçalhos juntos, que o banco confere antes de confiar neles:
 *   x-frila-ip-visitante   o texto CRU do `CF-Connecting-IP` que o Worker recebeu (sem normalizar);
 *   x-frila-ip-carimbo     segundos Unix UTC, calculado na hora de assinar (na saída da chamada);
 *   x-frila-ip-assinatura  `v1;k=<id>;<hex>`, HMAC-SHA256 (hex minúsculo) de `v1|<ip cru>|<carimbo>|<uid>`.
 * `<uid>` é o `sub` do token que vai NAQUELA chamada. A chave do HMAC são os bytes UTF-8 do texto do secret
 * `IP_VISITANTE_HMAC` (o banco usa `extensions.hmac(msg, texto, 'sha256')`), e o id da chave vem de `IP_VISITANTE_HMAC_ID`.
 *
 * Nenhum dos 3 cabeçalhos sai (nem parcial) se faltar secret, id válido, IP ou `sub` UUID, ou se a assinatura falhar:
 * a chamada sai normal e o banco usa o IP que ele mesmo vê (erro seguro). Os cabeçalhos só existem na chamada ao
 * Supabase: nada aqui chega ao navegador. Quem fala com o `/rest/v1` com token passa por este módulo (testes/ip-visitante.test.ts).
 */
import type { AmbienteDoSupabase } from "./ambiente";
import { criarApi } from "./api";
import { lerToken, type SessaoAtual } from "./sessao";

export const CABECALHO_IP = "x-frila-ip-visitante";
export const CABECALHO_CARIMBO = "x-frila-ip-carimbo";
export const CABECALHO_ASSINATURA = "x-frila-ip-assinatura";

const ID_DA_CHAVE = /^[a-z0-9]{1,16}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** Secret e id da chave, como o Worker os recebe. Ausentes (local, testes): a assinatura simplesmente não acontece. */
export type ChavesDoIp = { segredo?: string | undefined; id?: string | undefined };

/** O que a saída precisa da sessão: o token e o IP que o pedido trouxe (valores, lidos na hora de montar). */
export type OrigemDaSaida = Pick<SessaoAtual, "acesso" | "visitante">;

/** Lê as chaves das variáveis do Worker (`IP_VISITANTE_HMAC` é secret opcional; `IP_VISITANTE_HMAC_ID` é var). */
export function chavesDoIp(variaveis: { IP_VISITANTE_HMAC?: string; IP_VISITANTE_HMAC_ID?: string }): ChavesDoIp {
  return { segredo: variaveis.IP_VISITANTE_HMAC, id: variaveis.IP_VISITANTE_HMAC_ID };
}

function emHex(bytes: ArrayBuffer): string {
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** HMAC-SHA256 em hex minúsculo da mensagem `v1|<ip>|<carimbo>|<uid>`; a chave é o texto do secret em UTF-8. */
export async function hmacDoIp(segredo: string, ip: string, carimbo: number, uid: string): Promise<string> {
  const codificar = new TextEncoder();
  const chave = await crypto.subtle.importKey("raw", codificar.encode(segredo), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return emHex(await crypto.subtle.sign("HMAC", chave, codificar.encode(`v1|${ip}|${carimbo}|${uid}`)));
}

/**
 * Os 3 cabeçalhos para esta chamada, ou `null` se qualquer requisito faltar (ou a assinatura falhar). `carimbo` só existe
 * para o teste fixar a hora; em produção é o relógio no instante de assinar.
 */
export async function cabecalhosDoIp(
  chaves: ChavesDoIp,
  visitante: string | null,
  acesso: string,
  carimbo: number = Math.floor(Date.now() / 1000),
): Promise<Record<string, string> | null> {
  const segredo = chaves.segredo?.trim();
  const id = chaves.id;
  if (!segredo || !id || !ID_DA_CHAVE.test(id) || !visitante) return null;
  const uid = lerToken(acesso).usuarioId;
  if (!uid || !UUID.test(uid)) return null;
  try {
    const hex = await hmacDoIp(segredo, visitante, carimbo, uid);
    return {
      [CABECALHO_IP]: visitante,
      [CABECALHO_CARIMBO]: String(carimbo),
      [CABECALHO_ASSINATURA]: `v1;k=${id};${hex}`,
    };
  } catch {
    return null;
  }
}

/** O token que o Authorization da chamada leva, ou `null` (sem `Bearer`). */
function tokenDaChamada(autorizacao: string | null): string | null {
  const achado = /^Bearer (.+)$/.exec(autorizacao ?? "");
  return achado?.[1] ?? null;
}

/** Assina a chamada que está saindo: põe os 3 cabeçalhos juntos ou nenhum. Nunca lança. */
async function assinar(request: Request, chaves: ChavesDoIp, visitante: string | null): Promise<void> {
  const token = tokenDaChamada(request.headers.get("Authorization"));
  if (!token) return;
  const cabecalhos = await cabecalhosDoIp(chaves, visitante, token);
  if (!cabecalhos) return;
  try {
    for (const [nome, valor] of Object.entries(cabecalhos)) request.headers.set(nome, valor);
  } catch {
    for (const nome of Object.keys(cabecalhos)) request.headers.delete(nome);
  }
}

export type OpcoesDaSaida = { chaves: ChavesDoIp; fetch?: typeof fetch };

/**
 * Cliente da API com o token da sessão e a assinatura do IP. O IP e o token são capturados AQUI (por valor): quem chama
 * `registrarEvento` depois da resposta (`waitUntil`) não depende de nada que mude depois. A assinatura sai no `onRequest`.
 */
export function criarApiDoUsuario(ambiente: AmbienteDoSupabase, sessao: OrigemDaSaida, opcoes: OpcoesDaSaida) {
  const { acesso, visitante } = sessao;
  const api = criarApi(ambiente, { token: acesso, fetch: opcoes.fetch });
  api.use({
    onRequest: async ({ request }) => {
      await assinar(request, opcoes.chaves, visitante);
    },
  });
  return api;
}

/**
 * `fetch` do `/rest/v1` com o token da sessão e a assinatura do IP, para o que não passa pelo `openapi-fetch` (a RPC
 * `perfil_publico` por POST). O caminho é relativo ao `/rest/v1` (ex.: `/rpc/perfil_publico`).
 */
export function restDoUsuario(ambiente: AmbienteDoSupabase, sessao: OrigemDaSaida, opcoes: OpcoesDaSaida) {
  const { acesso, visitante } = sessao;
  const base = opcoes.fetch ?? ((pedido: Request) => fetch(pedido));
  return async (caminho: string, inicio: RequestInit = {}): Promise<Response> => {
    const cabecalhos = new Headers(inicio.headers);
    cabecalhos.set("apikey", ambiente.chavePublicavel);
    cabecalhos.set("Authorization", `Bearer ${acesso}`);
    const request = new Request(`${ambiente.url}/rest/v1${caminho}`, { ...inicio, headers: cabecalhos });
    await assinar(request, opcoes.chaves, visitante);
    return base(request);
  };
}
