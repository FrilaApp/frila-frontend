/** O que a tela /avisos mostra, decidido pelo navegador. Se um aviso mostra o conteúdo, quem decide é o servidor (sw.js). */
import type { Plataforma } from "./plataforma";

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
