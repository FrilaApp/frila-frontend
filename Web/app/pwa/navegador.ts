/**
 * O lado do navegador da instalação (só roda no navegador, a partir da raiz):
 * registra o service worker e guarda o pedido de instalação do Chrome para o botão da tela /instalar.
 */
import { useSyncExternalStore } from "react";

import { lerPlataforma, type Plataforma } from "./plataforma";

/** O evento `beforeinstallprompt` (Chrome e afins; não existe no iPhone). */
type PedidoDeInstalacao = Event & { prompt: () => Promise<void>; userChoice: Promise<{ outcome: "accepted" | "dismissed" }> };

let pedidoGuardado: PedidoDeInstalacao | null = null;
let instalouAgora = false;
let comecou = false;
const ouvintes = new Set<() => void>();
const avisar = () => ouvintes.forEach((ouvinte) => ouvinte());
const assinar = (ouvinte: () => void) => {
  ouvintes.add(ouvinte);
  return () => ouvintes.delete(ouvinte);
};

export function comecarNoNavegador(): void {
  if (comecou) return;
  comecou = true;
  window.addEventListener("beforeinstallprompt", (evento) => {
    // O Frila oferece a instalação pelo próprio botão, na tela /instalar.
    evento.preventDefault();
    pedidoGuardado = evento as PedidoDeInstalacao;
    avisar();
  });
  window.addEventListener("appinstalled", () => {
    pedidoGuardado = null;
    instalouAgora = true;
    avisar();
  });
  // No servidor de desenvolvimento o service worker fica de fora (o Vite serve outro código).
  if (import.meta.env.PROD && "serviceWorker" in navigator) {
    navigator.serviceWorker.register("/app/sw.js", { scope: "/app/" }).catch(() => {
      // Sem service worker a web funciona igual: só não abre a página "sem conexão" nem instala no Chrome.
    });
  }
}

/** Mostra o pedido de instalação do navegador. Devolve se a pessoa aceitou. */
export async function pedirInstalacao(): Promise<boolean> {
  const pedido = pedidoGuardado;
  if (!pedido) return false;
  pedidoGuardado = null;
  avisar();
  await pedido.prompt();
  return (await pedido.userChoice).outcome === "accepted";
}

export function usePodeInstalar(): boolean {
  return useSyncExternalStore(assinar, () => pedidoGuardado !== null, () => false);
}

export function useInstalouAgora(): boolean {
  return useSyncExternalStore(assinar, () => instalouAgora, () => false);
}

function plataformaDesteNavegador(): Plataforma {
  const instalada =
    window.matchMedia("(display-mode: standalone)").matches || (navigator as Navigator & { standalone?: boolean }).standalone === true;
  return lerPlataforma(navigator.userAgent, { instalada, toque: navigator.maxTouchPoints > 1 });
}

const nada = () => () => undefined;

/** A plataforma só existe no navegador: no servidor (e na hidratação) é `null`. */
export function usePlataforma(): Plataforma | null {
  return useSyncExternalStore(nada, plataformaDesteNavegador, () => null);
}

export function useAgente(): string | null {
  return useSyncExternalStore(nada, () => navigator.userAgent, () => null);
}

export function useOrigem(): string | null {
  return useSyncExternalStore(nada, () => window.location.origin, () => null);
}
