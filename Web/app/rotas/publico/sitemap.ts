import { BASE } from "../../servidor/porteiro";
import type { Route } from "./+types/sitemap";

/**
 * Mapa do site para buscadores (5.4): só as páginas públicas, no endereço de quem pediu. As vagas públicas ficam fora
 * (noindex até o portão da Política; a lista pública é o 5.3). O robots.txt da raiz é do site frilabr.com, não da web.
 */
export const PAGINAS_DO_MAPA = ["/", "/como-funciona/casa", "/como-funciona/profissional", "/perguntas"] as const;

export function loader({ request }: Route.LoaderArgs) {
  const origem = new URL(request.url).origin;
  const urls = PAGINAS_DO_MAPA.map((caminho) => `  <url><loc>${origem}${BASE}${caminho}</loc></url>`).join("\n");
  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`;
  return new Response(xml, {
    headers: { "Content-Type": "application/xml; charset=utf-8", "Cache-Control": "public, max-age=3600" },
  });
}
