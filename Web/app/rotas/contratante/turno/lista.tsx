import { Link } from "react-router";

import { casaDaTela, chegadaDo, listarMinhasCasas, listarTurnosDaCasa } from "../../../servidor/contratante/turno/turnos";
import { apiDoUsuario } from "../../../servidor/deste-ambiente";
import { exigirSessao } from "../../../servidor/guarda";
import { formatarPeriodo } from "../../../servidor/profissional/formato";
import { textos } from "../../../textos/pt-BR";
import type { Route } from "./+types/lista";

const t = textos.contratanteTurno;

export function meta() {
  return [{ title: t.lista.tituloDaAba }, { name: "robots", content: "noindex" }];
}

type Casa = { id: string; nome: string };

/** A conta pode operar mais de uma casa: a tela mostra uma por vez (?casa=), e as outras viram links. */
export async function loader({ context, request }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const casas = await listarMinhasCasas(api);
  const vazio = { casa: null, outrasCasas: [] as Casa[], turnos: [] };
  if (casas.estado !== "ok") return { estado: casas.estado, ...vazio };
  const casa = casaDaTela(casas.casas, new URL(request.url).searchParams.get("casa"));
  if (!casa) return { estado: "sem_casa" as const, ...vazio };
  const outrasCasas = casas.casas.filter((outra) => outra.id !== casa.id).map(({ id, nome }) => ({ id, nome }));
  const leitura = await listarTurnosDaCasa(api, casa.id);
  if (leitura.estado !== "ok") return { estado: leitura.estado, ...vazio, casa: { id: casa.id, nome: casa.nome }, outrasCasas };
  return {
    estado: "ok" as const,
    casa: { id: casa.id, nome: casa.nome },
    outrasCasas,
    turnos: leitura.turnos.map((turno) => ({
      id: turno.id,
      funcao: turno.vaga.funcao,
      profissional: turno.contraparte.nome,
      periodo: formatarPeriodo(turno.vaga.inicio_em, turno.vaga.fim_em),
      estado: turno.estado ?? null,
      chegada: chegadaDo(turno),
    })),
  };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function TurnosDaCasa({ loaderData }: Route.ComponentProps) {
  const { estado, casa, outrasCasas, turnos } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.lista.titulo}</h1>
      {casa ? <p className="text-lg font-semibold">{casa.nome}</p> : null}
      {estado === "sem_casa" ? <p role="status">{t.lista.semCasa}</p> : estado !== "ok" ? <p role="alert">{t.avisos[estado]}</p> : null}
      {estado === "ok" && turnos.length === 0 ? <p role="status">{t.lista.vazia}</p> : null}
      <ul className="flex flex-col gap-3">
        {turnos.map((turno) => (
          <li key={turno.id}>
            <Link
              to={`/casa/turnos/${turno.id}?casa=${casa?.id ?? ""}`}
              className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4"
            >
              <span className="text-lg font-bold">
                {turno.funcao} · {turno.profissional}
              </span>
              <span>{turno.periodo}</span>
              {turno.estado ? <span className="font-semibold">{t.estado[turno.estado]}</span> : null}
              <span className="text-tinta-suave">{t.chegada[turno.chegada]}</span>
            </Link>
          </li>
        ))}
      </ul>
      {outrasCasas.map((outra) => (
        <Link key={outra.id} to={`/casa/turnos?casa=${outra.id}`} className={classeDoLink}>
          {t.lista.trocarDeCasa} {outra.nome}
        </Link>
      ))}
    </main>
  );
}
