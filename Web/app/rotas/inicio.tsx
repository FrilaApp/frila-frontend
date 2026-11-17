import { env } from "cloudflare:workers";

import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/inicio";

export function loader() {
  const webLigada = env.WEB_LIGADA === "1";
  return { webLigada, ambiente: webLigada ? env.AMBIENTE : null };
}

export function meta({ loaderData }: Route.MetaArgs) {
  if (!loaderData?.webLigada) {
    return [{ title: textos.emBreve.tituloDaAba }, { name: "description", content: textos.emBreve.descricao }];
  }
  return [{ title: textos.inicio.tituloDaAba }, { name: "robots", content: "noindex" }];
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Inicio({ loaderData }: Route.ComponentProps) {
  const bloco = loaderData.webLigada ? textos.inicio : textos.emBreve;

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-center gap-4 p-6">
      <p className="font-titulo text-xl font-bold text-acao">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{bloco.titulo}</h1>
      <p className="text-texto-secundario">{bloco.corpo}</p>
      {loaderData.ambiente ? (
        <p className="text-sm text-texto-secundario">
          {textos.inicio.ambiente}: {loaderData.ambiente}
        </p>
      ) : null}
    </main>
  );
}
