import { Link } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { listarMinhasCandidaturas } from "../../servidor/profissional/candidaturas";
import { formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/candidaturas";

const t = textos.profissional.candidaturas;
const tv = textos.profissional.vagas;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await listarMinhasCandidaturas(apiDoUsuario(sessao.acesso));
  if (leitura.estado !== "ok") return { estado: leitura.estado, candidaturas: [] };
  return {
    estado: "ok" as const,
    candidaturas: leitura.candidaturas.map((c) => ({
      id: c.id,
      vagaId: c.vaga.id,
      funcao: c.vaga.funcao,
      regiao: c.vaga.regiao_administrativa,
      periodo: formatarPeriodo(c.vaga.inicio_em, c.vaga.fim_em),
      valor: formatarValor(c.vaga.valor_centavos),
      estado: c.estado,
    })),
  };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const AVISO_DO_ESTADO = {
  perfil_incompativel: tv.perfilIncompativel,
  conta_suspensa: tv.contaSuspensa,
  indisponivel: tv.indisponivel,
} as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Candidaturas({ loaderData }: Route.ComponentProps) {
  const { estado, candidaturas } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {estado !== "ok" ? <p role="alert">{AVISO_DO_ESTADO[estado]}</p> : null}
      {estado === "ok" && candidaturas.length === 0 ? <p role="status">{t.vazia}</p> : null}
      <ul className="flex flex-col gap-3">
        {candidaturas.map((c) => (
          <li key={c.id}>
            <Link to={`/vagas/${c.vagaId}`} className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4">
              <span className="text-lg font-bold">
                {c.funcao} · {c.valor}
              </span>
              <span>{c.periodo}</span>
              <span className="text-tinta-suave">{c.regiao}</span>
              <span className="font-semibold">{t.estado[c.estado]}</span>
            </Link>
          </li>
        ))}
      </ul>
      <Link to="/vagas" className={classeDoLink}>
        {t.verVagas}
      </Link>
    </main>
  );
}
