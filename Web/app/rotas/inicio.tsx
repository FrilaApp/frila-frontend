import { env } from "cloudflare:workers";

import { lerConfiguracaoDesteAmbiente } from "../servidor/abertura";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/inicio";

export async function loader() {
  if (env.WEB_LIGADA !== "1") {
    return { webLigada: false as const };
  }
  const leitura = await lerConfiguracaoDesteAmbiente();
  return {
    webLigada: true as const,
    ambiente: env.AMBIENTE,
    configuracao: leitura.estado,
    versaoMinima: leitura.estado === "ok" ? leitura.configuracao.versao_minima : null,
  };
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
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{bloco.titulo}</h1>
      <p className="text-tinta-suave">{bloco.corpo}</p>
      {loaderData.webLigada ? (
        <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm text-tinta-suave">
          <dt>{textos.inicio.ambiente}</dt>
          <dd>{loaderData.ambiente}</dd>
          <dt>{textos.inicio.configuracao}</dt>
          <dd>{textos.inicio.estadoDaConfiguracao[loaderData.configuracao]}</dd>
          {loaderData.versaoMinima ? (
            <>
              <dt>{textos.inicio.versaoMinima}</dt>
              <dd>{loaderData.versaoMinima}</dd>
            </>
          ) : null}
        </dl>
      ) : null}
    </main>
  );
}
