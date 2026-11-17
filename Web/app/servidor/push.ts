/**
 * Push no navegador (fase 4, item 6.1): o aparelho web registra o token do FCM com `plataforma: web`.
 *
 * O token fica num cookie `HttpOnly` deste navegador, só para o sair chamar `remover_dispositivo` (o contrato pede no
 * logout: sem isso o aparelho seguiria recebendo aviso da conta anterior, RN15). A sessão continua nos cookies dela.
 */
import type { Api } from "./api";
import { VERSAO_DA_WEB } from "../versao";

/**
 * Config pública do app web do Firebase (vai para o navegador, que tira o token). Fora do repositório: variáveis do Worker.
 * Sem `vapidKey`, o SDK usa a chave padrão do FCM (vale no dev); a chave própria entra antes do Prod.
 */
export type ConfigDoPush = { apiKey: string; projectId: string; messagingSenderId: string; appId: string; vapidKey?: string };

const NOMES = {
  apiKey: "FIREBASE_WEB_API_KEY",
  projectId: "FIREBASE_PROJECT_ID",
  messagingSenderId: "FIREBASE_MESSAGING_SENDER_ID",
  appId: "FIREBASE_WEB_APP_ID",
} as const;
const NOME_DA_VAPID = "FIREBASE_VAPID_CHAVE_PUBLICA";

/** Sem qualquer uma das quatro variáveis, o push fica desligado neste ambiente (a tela diz isso). A VAPID é opcional. */
export function lerConfigDoPush(variaveis: object): ConfigDoPush | null {
  const lidas = variaveis as Record<string, unknown>;
  const config: Partial<ConfigDoPush> = {};
  for (const [campo, nome] of Object.entries(NOMES) as Array<[keyof ConfigDoPush, string]>) {
    const valor = lidas[nome];
    if (typeof valor !== "string" || valor.trim() === "") return null;
    config[campo] = valor.trim();
  }
  const vapid = lidas[NOME_DA_VAPID];
  if (typeof vapid === "string" && vapid.trim() !== "") config.vapidKey = vapid.trim();
  return config as ConfigDoPush;
}

export const COOKIE_DO_APARELHO = "frila_aparelho";
const VIDA_DO_COOKIE_S = 400 * 24 * 60 * 60;

/** O token do FCM tem letras, números e `-_:`; qualquer outra coisa é recusada antes de ir ao servidor ou ao cookie. */
export function tokenValido(token: unknown): token is string {
  return typeof token === "string" && token.length >= 20 && token.length <= 4096 && /^[A-Za-z0-9_:-]+$/.test(token);
}

export function cookieDoAparelho(token: string | null, seguro: boolean): string {
  const partes = [`${COOKIE_DO_APARELHO}=${token ?? ""}`, "Path=/app", `Max-Age=${token ? VIDA_DO_COOKIE_S : 0}`, "HttpOnly", "SameSite=Lax"];
  if (seguro) partes.push("Secure");
  return partes.join("; ");
}

export function lerTokenDoAparelho(request: Request): string | null {
  for (const par of (request.headers.get("Cookie") ?? "").split(";")) {
    const corte = par.indexOf("=");
    if (corte > 0 && par.slice(0, corte).trim() === COOKIE_DO_APARELHO) {
      const valor = par.slice(corte + 1).trim();
      return tokenValido(valor) ? valor : null;
    }
  }
  return null;
}

export type ResultadoDoRegistro = { ok: true; vinculoId: string | null } | { ok: false; motivo: "sem_sessao" | "indisponivel" };

export async function registrarAparelho(api: Api | null, token: string): Promise<ResultadoDoRegistro> {
  if (!api) return { ok: false, motivo: "indisponivel" };
  try {
    const { data, response } = await api.POST("/rpc/registrar_dispositivo", {
      body: { token_fcm: token, plataforma: "web", versao_app: VERSAO_DA_WEB },
      signal: AbortSignal.timeout(8000),
    });
    if (data) return { ok: true, vinculoId: data.vinculo_id ?? null };
    return { ok: false, motivo: response.status === 401 ? "sem_sessao" : "indisponivel" };
  } catch {
    return { ok: false, motivo: "indisponivel" };
  }
}

export async function removerAparelho(api: Api | null, token: string): Promise<boolean> {
  if (!api) return false;
  try {
    const { data } = await api.POST("/rpc/remover_dispositivo", { body: { token_fcm: token }, signal: AbortSignal.timeout(5000) });
    return Boolean(data);
  } catch {
    return false;
  }
}

/**
 * O aviso que chegou é da sessão viva deste navegador? Quem decide é o servidor do Frila, na hora do push: o registro
 * do token pela sessão atual devolve o vínculo dela, e o aviso só mostra o conteúdo com esse mesmo vínculo (RN15).
 * Sem sessão, sem token, com falha ou com vínculo diferente: não.
 */
export async function avisoEhDestaSessao(api: Api | null, token: string | null, vinculoDoAviso: unknown): Promise<boolean> {
  if (!api || !token) return false;
  const registro = await registrarAparelho(api, token);
  if (!registro.ok) return false;
  // Servidor sem vínculo na resposta: o contrato diz "sem conferência por vínculo" (aqui, com sessão viva e aparelho dela).
  if (registro.vinculoId === null) return true;
  return typeof vinculoDoAviso === "string" && vinculoDoAviso === registro.vinculoId;
}
