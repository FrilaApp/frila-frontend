/**
 * O que a tela /avisos mostra, decidido pelo navegador, e a conversa com o service worker sobre de quem é o aparelho.
 */
import type { Plataforma } from "./plataforma";
import { textos } from "../textos/pt-BR";

export type EstadoDosAvisos = "sem_config" | "sem_suporte" | "embutido" | "iphone_sem_instalar" | "negado" | "desligado" | "ligado";

export function estadoDosAvisos(entrada: {
  temConfig: boolean;
  suporta: boolean;
  plataforma: Plataforma;
  permissao: NotificationPermission;
  registrado: boolean;
}): EstadoDosAvisos {
  if (!entrada.temConfig) return "sem_config";
  if (entrada.plataforma === "embutido") return "embutido";
  // No iPhone, o navegador só ganha push depois de instalado: fora disso, a API nem existe.
  if (entrada.plataforma === "iphone") return "iphone_sem_instalar";
  if (!entrada.suporta) return "sem_suporte";
  if (entrada.permissao === "denied") return "negado";
  return entrada.permissao === "granted" && entrada.registrado ? "ligado" : "desligado";
}

export function navegadorSuportaPush(): boolean {
  return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
}

/** Mensagens para o `public/app/sw.js` (o mesmo formato que ele lê). */
type MensagemAoServiceWorker =
  | { tipo: "vinculo"; vinculo_id: string | null; neutro: { titulo: string; corpo: string } }
  | { tipo: "esquecer" };

async function avisarServiceWorker(mensagem: MensagemAoServiceWorker): Promise<void> {
  if (!("serviceWorker" in navigator)) return;
  const registro = await navigator.serviceWorker.getRegistration("/app/");
  registro?.active?.postMessage(mensagem);
}

/** Depois de registrar: o aviso só mostra o conteúdo quando vier com este vínculo (RN15). */
export function guardarVinculo(vinculoId: string | null): Promise<void> {
  return avisarServiceWorker({
    tipo: "vinculo",
    vinculo_id: vinculoId,
    neutro: { titulo: textos.pwa.avisos.neutroTitulo, corpo: textos.pwa.avisos.neutroCorpo },
  });
}

/** Ao sair ou desligar: daqui em diante, aviso que chegar aparece sem conteúdo. */
export function esquecerVinculo(): Promise<void> {
  return avisarServiceWorker({ tipo: "esquecer" });
}
