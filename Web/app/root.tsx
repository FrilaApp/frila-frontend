import { useEffect } from "react";
import { isRouteErrorResponse, Links, Meta, Outlet, Scripts, ScrollRestoration, useHref, useNavigation } from "react-router";

import type { Route } from "./+types/root";
import "./app.css";
import fonteDoTitulo from "./marca/fontes/ProdigySans-Bold.woff2?url";
import { AvisoDoNavegadorEmbutido } from "./pwa/aviso-do-navegador-embutido";
import { esquecerVinculo } from "./pwa/avisos";
import { comecarNoNavegador } from "./pwa/navegador";
import { middlewareDeSessao } from "./servidor/middleware-de-sessao";
import { textos } from "./textos/pt-BR";

// Ativos de marca (app/marca/LEIAME.md). Os arquivos ficam em public/app e são servidos em /app.
const IMAGEM_DE_COMPARTILHAMENTO = "https://frilabr.com/app/og-1200x630.png";

// A sessão é decidida aqui, uma vez por pedido, para todas as rotas.
export const middleware: Route.MiddlewareFunction[] = [middlewareDeSessao];

export const links: Route.LinksFunction = () => [
  { rel: "icon", href: "/app/favicon.svg", type: "image/svg+xml" },
  { rel: "icon", href: "/app/favicon-32.png", sizes: "32x32", type: "image/png" },
  { rel: "apple-touch-icon", href: "/app/apple-touch-icon-180.png" },
  { rel: "manifest", href: "/app/site.webmanifest" },
  { rel: "preload", href: fonteDoTitulo, as: "font", type: "font/woff2", crossOrigin: "anonymous" },
];

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="theme-color" content="#F46700" />
        <meta property="og:site_name" content={textos.marca} />
        <meta property="og:image" content={IMAGEM_DE_COMPARTILHAMENTO} />
        <meta property="og:image:width" content="1200" />
        <meta property="og:image:height" content="630" />
        <meta property="og:image:alt" content={textos.imagemDeCompartilhamento} />
        <meta name="twitter:card" content="summary_large_image" />
        <Meta />
        <Links />
      </head>
      <body>
        {children}
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function App() {
  // Service worker e pedido de instalação (fase 4): só no navegador, uma vez.
  useEffect(() => comecarNoNavegador(), []);
  // Ao sair, o aviso que chegar neste aparelho passa a aparecer sem conteúdo (RN15).
  const enviando = useNavigation().formAction;
  useEffect(() => {
    if (enviando?.endsWith("/sair")) void esquecerVinculo();
  }, [enviando]);
  return (
    <>
      <AvisoDoNavegadorEmbutido />
      <Outlet />
    </>
  );
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
  const naoEncontrado = isRouteErrorResponse(error) && error.status === 404;
  const titulo = naoEncontrado ? textos.erro.naoEncontradoTitulo : textos.erro.inesperadoTitulo;
  const corpo = naoEncontrado ? textos.erro.naoEncontradoCorpo : textos.erro.inesperadoCorpo;
  // Link comum (recarrega a página): funciona mesmo com a chave desligada, quando só o início existe.
  const inicio = useHref("/");

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-center gap-4 p-6">
      <title>{titulo}</title>
      <h1 className="font-titulo text-3xl font-bold">{titulo}</h1>
      <p className="text-tinta-suave">{corpo}</p>
      <p>
        <a href={inicio} className="font-semibold underline underline-offset-4">
          {textos.erro.voltarAoInicio}
        </a>
      </p>
    </main>
  );
}
