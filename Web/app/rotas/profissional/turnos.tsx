import { Link } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { listarMeusTurnos } from "../../servidor/profissional/turnos";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/turnos";

const t = textos.profissional.turnos;
const tv = textos.profissional.vagas;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await listarMeusTurnos(apiDoUsuario(sessao.acesso));
  if (leitura.estado !== "ok") return { estado: leitura.estado, turnos: [] };
  return {
    estado: "ok" as const,
    turnos: leitura.turnos.map((turno) => ({
      id: turno.id,
      funcao: turno.vaga.funcao,
      casa: turno.contraparte.nome,
      periodo: formatarPeriodo(turno.vaga.inicio_em, turno.vaga.fim_em),
      valor: formatarValor(turno.valor_acordado_centavos),
      estado: turno.estado ?? null,
      aCaminho: turno.a_caminho_em !== null,
      presenca: turno.checkin_em !== null,
    })),
  };
}

const AVISO_DO_ESTADO = {
  perfil_incompativel: tv.perfilIncompativel,
  conta_suspensa: tv.contaSuspensa,
  indisponivel: tv.indisponivel,
} as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Turnos({ loaderData }: Route.ComponentProps) {
  const { estado, turnos } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {estado !== "ok" ? <p role="alert">{AVISO_DO_ESTADO[estado]}</p> : null}
      {estado === "ok" && turnos.length === 0 ? <p role="status">{t.vazia}</p> : null}
      <ul className="flex flex-col gap-3">
        {turnos.map((turno) => (
          <li key={turno.id}>
            <Link to={`/turnos/${turno.id}`} className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4">
              <span className="text-lg font-bold">
                {turno.funcao} · {turno.valor}
              </span>
              <span>{turno.periodo}</span>
              <span className="text-tinta-suave">{turno.casa}</span>
              {turno.estado ? <span className="font-semibold">{t.estado[turno.estado]}</span> : null}
              {turno.presenca ? <span>{t.presencaRegistrada}</span> : turno.aCaminho ? <span>{t.aCaminhoDesde}</span> : null}
            </Link>
          </li>
        ))}
      </ul>
      <Link to="/vagas" className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">
        {t.verVagas}
      </Link>
    </main>
  );
}
