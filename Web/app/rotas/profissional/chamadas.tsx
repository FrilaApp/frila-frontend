import { Link } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { listarChamadas } from "../../servidor/profissional/chamadas";
import { formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/chamadas";

const t = textos.profissional.chamadas;
const tv = textos.profissional.vagas;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context, request }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const cursor = new URL(request.url).searchParams.get("cursor");
  const leitura = await listarChamadas(apiDoUsuario(sessao.acesso), cursor && cursor.length <= 512 ? cursor : null);
  if (leitura.estado !== "ok") return { estado: leitura.estado, chamadas: [], proximoCursor: null };
  return {
    estado: "ok" as const,
    proximoCursor: leitura.proximoCursor,
    chamadas: leitura.itens.map((c) => ({
      id: c.id,
      funcao: c.funcao.nome,
      casa: c.outra_parte.nome,
      periodo: formatarPeriodo(c.inicio_em, c.fim_em),
      valor: formatarValor(c.valor_centavos),
      estado: c.estado,
    })),
  };
}

const AVISO_DO_ESTADO = {
  recurso_desligado: t.desligado,
  perfil_incompativel: tv.perfilIncompativel,
  conta_suspensa: tv.contaSuspensa,
  indisponivel: tv.indisponivel,
} as const;
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Chamadas({ loaderData }: Route.ComponentProps) {
  const { estado, chamadas, proximoCursor } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {estado !== "ok" ? <p role="status">{AVISO_DO_ESTADO[estado]}</p> : <p className="text-tinta-suave">{t.corpo}</p>}
      {estado === "ok" && chamadas.length === 0 ? <p role="status">{t.vazia}</p> : null}
      <ul className="flex flex-col gap-3">
        {chamadas.map((c) => (
          <li key={c.id}>
            <Link to={`/chamadas/${c.id}`} className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4">
              <span className="text-lg font-bold">
                {c.funcao} · {c.valor}
              </span>
              <span>{c.periodo}</span>
              <span className="text-tinta-suave">{c.casa}</span>
              <span className="font-semibold">{t.estado[c.estado]}</span>
            </Link>
          </li>
        ))}
      </ul>
      {proximoCursor ? (
        <Link to={`/chamadas?cursor=${encodeURIComponent(proximoCursor)}`} className={classeDoLink}>
          {t.mais}
        </Link>
      ) : null}
      <Link to="/" className={classeDoLink}>
        {tv.voltarAoInicio}
      </Link>
    </main>
  );
}
