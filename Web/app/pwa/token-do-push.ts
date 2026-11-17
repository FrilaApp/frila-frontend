/**
 * Token do FCM no navegador. Este módulo é importado sob demanda só pela tela /avisos: o SDK do Firebase (só app e
 * messaging, sem Analytics) não entra em nenhuma outra tela. O token sai daqui para o Firebase (endereços liberados na
 * CSP) e para o Worker do Frila; nada vai para o armazenamento da página.
 */
import { getApps, initializeApp } from "@firebase/app";
import { deleteToken, getMessaging, getToken } from "@firebase/messaging";

import type { ConfigDoPush } from "../servidor/push";

const NOME_DO_APP = "frila-web";

function mensageria(config: ConfigDoPush) {
  const app =
    getApps().find((existente) => existente.name === NOME_DO_APP) ??
    initializeApp(
      { apiKey: config.apiKey, projectId: config.projectId, messagingSenderId: config.messagingSenderId, appId: config.appId },
      NOME_DO_APP,
    );
  return getMessaging(app);
}

/** Usa o service worker do Frila (/app/sw.js): o Firebase não registra outro. */
export async function tirarToken(config: ConfigDoPush): Promise<string> {
  const registro = await navigator.serviceWorker.ready;
  // Sem a chave própria, o SDK usa a padrão do FCM.
  return getToken(mensageria(config), { ...(config.vapidKey ? { vapidKey: config.vapidKey } : {}), serviceWorkerRegistration: registro });
}

export async function apagarToken(config: ConfigDoPush): Promise<void> {
  await deleteToken(mensageria(config));
}
