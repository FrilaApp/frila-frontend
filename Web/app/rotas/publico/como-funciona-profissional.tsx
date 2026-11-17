import { Link } from "react-router";

import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/como-funciona-profissional";
import { carregarCondicoes } from "./carregar";
import { Passo, RodapePublico } from "./componentes";

const t = textos.publico.comoFuncionaProfissional;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "description", content: t.descricao }];
}

export const loader = carregarCondicoes;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function ComoFuncionaProfissional({ loaderData }: Route.ComponentProps) {
  const c = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-2xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p className="text-lg text-tinta-suave">{t.subtitulo}</p>
      <ol className="flex flex-col gap-3">
        <Passo titulo={t.passo1Titulo} corpo={t.passo1Corpo} />
        <Passo titulo={t.passo2Titulo} corpo={t.passo2Corpo} />
        <Passo titulo={t.passo3Titulo} corpo={t.passo3Corpo} />
        <Passo titulo={t.passo4Titulo} corpo={t.passo4Corpo} />
        <Passo titulo={t.passo5Titulo} corpo={t.passo5Corpo} />
        {c.chamadaDireta ? <Passo titulo={t.passo6Titulo} corpo={t.passo6Corpo} /> : null}
      </ol>
      {[
        [t.reputacaoTitulo, t.reputacaoCorpo],
        [t.imprevistoTitulo, t.imprevistoCorpo],
        [t.segurancaTitulo, t.segurancaCorpo],
      ].map(([titulo, corpo]) => (
        <section key={titulo} className="flex flex-col gap-2">
          <h2 className="text-xl font-bold">{titulo}</h2>
          <p>{corpo}</p>
        </section>
      ))}
      <p>
        <Link to="/vagas" className="inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao">
          {t.acao}
        </Link>
      </p>
      <RodapePublico linkDaAppStore={c.linkDaAppStore} />
    </main>
  );
}
