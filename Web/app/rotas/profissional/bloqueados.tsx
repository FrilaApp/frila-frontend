import { Form, Link, redirect, useNavigation } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { bloquearCasa, listarBloqueios } from "../../servidor/profissional/moderacao";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/bloqueados";

const t = textos.profissional.moderacao;

export function meta() {
  return [{ title: t.tituloDosBloqueados }, { name: "robots", content: "noindex" }];
}

export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await listarBloqueios(apiDoUsuario(sessao.acesso));
  if (leitura.estado !== "ok") return { estado: leitura.estado, bloqueios: [] };
  // Só as casas (o lado do profissional bloqueia casas); o par vai ao desbloquear como o servidor mandou.
  return {
    estado: "ok" as const,
    bloqueios: leitura.bloqueios.filter((b) => b.alvo_tipo === "estabelecimento").map((b) => ({ alvoId: b.alvo_id, nome: b.nome })),
  };
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const resultado = await bloquearCasa(apiDoUsuario(sessao.acesso), String(formulario.get("alvo") ?? ""), true);
  if (!resultado.ok && resultado.motivo === "sem_sessao") throw redirect("/entrar");
  return { erro: resultado.ok ? null : resultado.motivo === "sem_sessao" ? ("indisponivel" as const) : resultado.motivo };
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Bloqueados({ loaderData, actionData }: Route.ComponentProps) {
  const { estado, bloqueios } = loaderData;
  const enviando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.bloqueados}</h1>
      {actionData ? <p role="status">{actionData.erro ? t.resultado[actionData.erro] : t.desbloqueada}</p> : null}
      {estado !== "ok" ? <p role="alert">{t.resultado[estado]}</p> : null}
      {estado === "ok" && bloqueios.length === 0 ? <p role="status">{t.nenhumBloqueio}</p> : null}
      <ul className="flex flex-col gap-3">
        {bloqueios.map((b) => (
          <li key={b.alvoId} className="flex items-center justify-between gap-3 rounded-cartao border border-borda bg-superficie p-4">
            <span className="font-semibold">{b.nome}</span>
            <Form method="post">
              <input type="hidden" name="alvo" value={b.alvoId} />
              <button type="submit" disabled={enviando} className="min-h-11 px-3 font-semibold underline underline-offset-4">
                {t.desbloquear}
              </button>
            </Form>
          </li>
        ))}
      </ul>
      <Link to="/" className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">
        {t.voltar}
      </Link>
    </main>
  );
}
