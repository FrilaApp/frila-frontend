import { Link } from "react-router";

import { textos } from "../../textos/pt-BR";

const r = textos.publico.rodape;
const classeDoLink = "inline-flex min-h-11 items-center underline underline-offset-4";

/** Rodapé das páginas públicas. "Regras da Comunidade" fica fora até a página existir em frilabr.com. */
export function RodapePublico({ linkDaAppStore }: { linkDaAppStore: string | null }) {
  return (
    <footer className="mt-8 flex flex-col gap-3 border-t border-borda pt-6 text-sm">
      <nav className="flex flex-wrap gap-x-5">
        <Link to="/como-funciona/casa" className={classeDoLink}>
          {r.comoFuncionaCasa}
        </Link>
        <Link to="/como-funciona/profissional" className={classeDoLink}>
          {r.comoFuncionaProfissional}
        </Link>
        <Link to="/perguntas" className={classeDoLink}>
          {r.perguntas}
        </Link>
        <a href="https://frilabr.com/suporte" className={classeDoLink}>
          {r.suporte}
        </a>
        <a href="https://frilabr.com/termos" className={classeDoLink}>
          {r.termos}
        </a>
        <a href="https://frilabr.com/privacidade" className={classeDoLink}>
          {r.privacidade}
        </a>
        {linkDaAppStore ? (
          <a href={linkDaAppStore} className={classeDoLink}>
            {r.appStore}
          </a>
        ) : null}
        <Link to="/entrar" className={classeDoLink}>
          {r.entrar}
        </Link>
      </nav>
      <p className="text-tinta-suave">{r.local}</p>
    </footer>
  );
}

export function Passo({ titulo, corpo, aviso }: { titulo: string; corpo: string; aviso?: string }) {
  return (
    <li className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4">
      <h2 className="text-lg font-bold">{titulo}</h2>
      <p>{corpo}</p>
      {aviso ? <p className="text-sm text-tinta-suave">{aviso}</p> : null}
    </li>
  );
}
