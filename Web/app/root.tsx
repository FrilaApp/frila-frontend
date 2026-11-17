import { isRouteErrorResponse, Links, Meta, Outlet, Scripts, ScrollRestoration, useHref } from "react-router";

import type { Route } from "./+types/root";
import "./app.css";
import { textos } from "./textos/pt-BR";

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="theme-color" content="#F46700" />
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
  return <Outlet />;
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
      <p className="text-texto-secundario">{corpo}</p>
      <p>
        <a href={inicio} className="font-semibold text-acao underline underline-offset-4">
          {textos.erro.voltarAoInicio}
        </a>
      </p>
    </main>
  );
}
