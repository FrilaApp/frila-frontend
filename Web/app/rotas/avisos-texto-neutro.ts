import { textos } from "../textos/pt-BR";

/**
 * O texto que todo push da web mostra (item 6.1, RN15). O service worker guarda esta resposta ao instalar: o conteúdo do
 * aviso nunca aparece na notificação, só ao abrir o Frila com a sessão. Igual para todo mundo, sem dado de ninguém.
 */
export function loader() {
  return Response.json(
    { titulo: textos.pwa.avisos.neutroTitulo, corpo: textos.pwa.avisos.neutroCorpo },
    { headers: { "Cache-Control": "no-cache" } },
  );
}
