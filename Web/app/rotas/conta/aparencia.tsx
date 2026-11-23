import { Form, Link, redirect, useNavigation } from "react-router";

import { cookieDaAparencia, lerAparencia } from "../../servidor/aparencia";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/aparencia";

const t = textos.aparencia;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export function loader({ context, request }: Route.LoaderArgs) {
  exigirSessao(context);
  return { aparencia: lerAparencia(request) };
}

export async function action({ context, request }: Route.ActionArgs) {
  exigirSessao(context);
  const formulario = await request.formData();
  return redirect("/conta/aparencia", {
    status: 303,
    headers: { "Set-Cookie": cookieDaAparencia(formulario.get("aparencia"), request) },
  });
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function TelaAparencia({ loaderData }: Route.ComponentProps) {
  const salvando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p id="explicacao-aparencia" className="text-tinta-suave">{t.explicacao}</p>
      <Form method="post" className="flex flex-col gap-4" onChange={(evento) => evento.currentTarget.requestSubmit()} aria-busy={salvando}>
        <fieldset disabled={salvando} aria-describedby="explicacao-aparencia" className="rounded-cartao border border-borda bg-superficie p-4">
          <legend className="sr-only">{t.titulo}</legend>
          {(["claro", "escuro"] as const).map((aparencia) => (
            <label key={aparencia} className="flex min-h-12 items-center gap-3">
              <input type="radio" name="aparencia" value={aparencia} defaultChecked={loaderData.aparencia === aparencia} className="size-5 shrink-0 accent-tinta focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-tinta" />
              <span>{t[aparencia]}</span>
            </label>
          ))}
        </fieldset>
        <button type="submit" disabled={salvando} className="min-h-12 rounded-controle border border-borda px-4 text-lg font-semibold disabled:opacity-60">
          {salvando ? t.salvando : t.salvar}
        </button>
      </Form>
      <Link to="/conta" className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">{t.voltar}</Link>
    </main>
  );
}
