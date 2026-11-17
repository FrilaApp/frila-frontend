import { Link } from "react-router";

import type { CondicoesPublicas } from "../../servidor/publico";
import { textos } from "../../textos/pt-BR";
import { RodapePublico } from "./componentes";

const t = textos.publico.inicio;
const classeDoBotao = "inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao";
const classeDoBotaoSecundario = "inline-flex min-h-12 items-center rounded-controle border border-borda bg-superficie px-6 text-lg font-bold";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

function Bloco({ titulo, itens, acao, para }: { titulo: string; itens: string[]; acao: string; para: string }) {
  return (
    <section className="flex flex-col gap-3 rounded-cartao border border-borda bg-superficie p-4">
      <h2 className="text-xl font-bold">{titulo}</h2>
      <ul className="flex list-disc flex-col gap-1 pl-5">
        {itens.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
      <Link to={para} className={classeDoLink}>
        {acao}
      </Link>
    </section>
  );
}

/** A página inicial de quem não entrou, com a web ligada. TELA PROVISÓRIA: substituir pelo high-fi do Fabrício. */
export function InicioPublico({ condicoes }: { condicoes: CondicoesPublicas }) {
  return (
    <main className="mx-auto flex min-h-dvh max-w-2xl flex-col gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p className="text-lg text-tinta-suave">{t.subtitulo}</p>
      <p className="flex flex-wrap gap-3">
        <Link to="/entrar" className={classeDoBotao}>
          {t.acaoCasa}
        </Link>
        <Link to="/vagas" className={classeDoBotaoSecundario}>
          {t.acaoProfissional}
        </Link>
        <Link to="/entrar" className={classeDoLink}>
          {t.acaoEntrar}
        </Link>
      </p>
      <Bloco titulo={t.casaTitulo} itens={[t.casaItem1, t.casaItem2, t.casaItem3]} acao={t.casaAcao} para="/como-funciona/casa" />
      <Bloco
        titulo={t.profissionalTitulo}
        itens={[t.profissionalItem1, t.profissionalItem2, t.profissionalItem3]}
        acao={t.profissionalAcao}
        para="/como-funciona/profissional"
      />
      {[
        [t.presencaTitulo, t.presencaCorpo],
        [t.avaliacaoTitulo, t.avaliacaoCorpo],
        [t.ondeTitulo, t.ondeCorpo],
        [t.iphoneTitulo, t.iphoneCorpo],
      ].map(([titulo, corpo]) => (
        <section key={titulo} className="flex flex-col gap-2">
          <h2 className="text-xl font-bold">{titulo}</h2>
          <p>{corpo}</p>
        </section>
      ))}
      {condicoes.linkDaAppStore ? (
        <a href={condicoes.linkDaAppStore} className={classeDoLink}>
          {t.iphoneAcao}
        </a>
      ) : null}
      <RodapePublico linkDaAppStore={condicoes.linkDaAppStore} />
    </main>
  );
}
