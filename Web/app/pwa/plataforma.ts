/**
 * Onde a web está aberta, para a tela de instalar e o aviso do navegador embutido. Só lê o navegador:
 * nada disto vai ao servidor.
 */
export type Plataforma = "instalada" | "embutido" | "iphone" | "outro";

/** Navegadores de dentro de redes sociais: não instalam, não recebem push e podem perder o cookie da sessão. */
const NAVEGADOR_EMBUTIDO = /Instagram|FBAN|FBAV|FB_IAB|FBIOS|TikTok|musical_ly|BytedanceWebview|Snapchat|LinkedInApp|Line\//i;

export function lerPlataforma(agente: string, opcoes: { instalada: boolean; toque: boolean }): Plataforma {
  if (opcoes.instalada) return "instalada";
  if (NAVEGADOR_EMBUTIDO.test(agente)) return "embutido";
  // O iPad em modo computador se anuncia como Mac: o toque denuncia.
  if (/iPhone|iPad|iPod/.test(agente) || (/Macintosh/.test(agente) && opcoes.toque)) return "iphone";
  return "outro";
}

export function ehAndroid(agente: string): boolean {
  return /Android/i.test(agente);
}

/** No Android, este link abre a mesma página no navegador padrão, fora do app da rede social. */
export function linkParaONavegador(endereco: string): string {
  const url = new URL(endereco);
  return `intent://${url.host}${url.pathname}${url.search}#Intent;scheme=https;end`;
}
