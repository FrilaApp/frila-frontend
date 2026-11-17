import { useEffect, useRef } from "react";
import { Form, Link, redirect, useNavigation } from "react-router";

import { contextoDaSessao } from "../contexto";
import { aceitarConvite } from "../servidor/contratante/membros";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { exigirSessao } from "../servidor/guarda";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/convite";

const t = textos.contratanteMembros.convite;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** Abre sem sessão também: quem ainda não entrou vê como aceitar. O token não passa por aqui (fica no fragmento). */
export function loader({ context }: Route.LoaderArgs) {
  return { entrou: context.get(contextoDaSessao) !== null };
}

export async function action({ request, context }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const aceite = await aceitarConvite(apiDoUsuario(sessao.acesso), String(formulario.get("token") ?? "").trim().toLowerCase());
  if (aceite.ok) throw redirect(aceite.casaId ? `/painel?casa=${aceite.casaId}` : "/painel");
  if (aceite.motivo === "sem_sessao") throw redirect("/entrar");
  return { falha: aceite.motivo };
}

const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Convite({ loaderData, actionData }: Route.ComponentProps) {
  const aceitando = useNavigation().state !== "idle";
  const campo = useRef<HTMLInputElement>(null);
  // O link traz o código depois do #: o navegador não o manda ao servidor, e a página o põe no campo.
  useEffect(() => {
    const codigo = window.location.hash.slice(1);
    if (campo.current && /^[0-9a-f]{64}$/i.test(codigo) && !campo.current.value) campo.current.value = codigo;
  }, []);
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p>{t.corpo}</p>
      {loaderData.entrou ? (
        <Form method="post" className="flex flex-col gap-4">
          {actionData ? (
            <p role="alert" className="font-semibold">
              {t.erros[actionData.falha]}
            </p>
          ) : null}
          <label className="flex flex-col gap-2 font-semibold">
            {t.codigo}
            <span id="ajuda-codigo" className="text-sm font-normal text-tinta-suave">
              {t.ajudaDoCodigo}
            </span>
            <input ref={campo} name="token" type="text" required autoComplete="off" spellCheck={false} aria-describedby="ajuda-codigo" className="min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-base" />
          </label>
          <button type="submit" disabled={aceitando} className={classeDoBotao}>
            {aceitando ? t.aceitando : t.aceitar}
          </button>
        </Form>
      ) : (
        <>
          <p>{t.entrarAntes}</p>
          <Link to="/entrar" className="inline-flex min-h-12 items-center justify-center rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao">
            {t.entrar}
          </Link>
        </>
      )}
    </main>
  );
}
