import { Form, Link, redirect, useNavigation } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { bloquearCasa, denunciarCasa, ehUuid, MINIMO_DO_RELATO, MOTIVOS_DA_DENUNCIA, type MotivoDaDenuncia } from "../../servidor/profissional/moderacao";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/denunciar";

const t = textos.profissional.moderacao;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** O alvo vem do endereço (o `id` público da casa que a vaga ou o turno mostrou). A chave é uma por formulário. */
export function loader({ context, request }: Route.LoaderArgs) {
  exigirSessao(context);
  const url = new URL(request.url);
  const alvo = url.searchParams.get("alvo") ?? "";
  const turno = url.searchParams.get("turno") ?? "";
  return { alvo: ehUuid(alvo) ? alvo : null, turno: ehUuid(turno) ? turno : null, chave: crypto.randomUUID() };
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const formulario = await request.formData();
  const alvoId = String(formulario.get("alvo") ?? "");
  const bloquear = formulario.get("intencao") === "bloquear" || formulario.get("bloquear") === "sim";
  let protocolo: string | null = null;
  if (formulario.get("intencao") !== "bloquear") {
    const motivo = String(formulario.get("motivo") ?? "");
    const denuncia = await denunciarCasa(api, {
      alvoId,
      turnoId: String(formulario.get("turno") ?? "") || null,
      motivo: (MOTIVOS_DA_DENUNCIA as readonly string[]).includes(motivo) ? (motivo as MotivoDaDenuncia) : "outro",
      relato: String(formulario.get("relato") ?? ""),
      chave: String(formulario.get("chave") ?? ""),
    });
    if (!denuncia.ok) {
      if (denuncia.motivo === "sem_sessao") throw redirect("/entrar");
      return { protocolo: null, bloqueada: false, erro: denuncia.motivo };
    }
    protocolo = denuncia.protocolo;
  }
  if (bloquear) {
    const bloqueio = await bloquearCasa(api, alvoId);
    if (!bloqueio.ok && bloqueio.motivo === "sem_sessao") throw redirect("/entrar");
    if (!bloqueio.ok) return { protocolo, bloqueada: false, erro: bloqueio.motivo === "sem_sessao" ? ("indisponivel" as const) : bloqueio.motivo };
  }
  return { protocolo, bloqueada: bloquear, erro: null };
}

const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoBotaoSecundario = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-6 text-lg font-bold disabled:opacity-60";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Denunciar({ loaderData, actionData }: Route.ComponentProps) {
  const { alvo, turno, chave } = loaderData;
  const enviando = useNavigation().state !== "idle";
  const concluiu = actionData && !actionData.erro;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <section className="flex flex-col gap-3 rounded-cartao border border-borda bg-superficie p-4">
        <p className="font-semibold">{t.emergencia}</p>
        <p className="flex flex-wrap gap-4">
          <a href="tel:190" className={classeDoLink}>
            {t.ligar190}
          </a>
          <a href="tel:180" className={classeDoLink}>
            {t.ligar180}
          </a>
        </p>
      </section>
      {actionData?.erro ? <p role="alert">{t.resultado[actionData.erro]}</p> : null}
      {concluiu ? (
        <div role="status" className="flex flex-col gap-2 font-semibold">
          {actionData.protocolo ? <p>{t.denunciaEnviada.replace("{protocolo}", actionData.protocolo)}</p> : null}
          {actionData.bloqueada ? <p>{t.bloqueada}</p> : null}
        </div>
      ) : !alvo ? (
        <p role="alert">{t.alvoInvalido}</p>
      ) : (
        <>
          <Form method="post" className="flex flex-col gap-4">
            <input type="hidden" name="alvo" value={alvo} />
            <input type="hidden" name="turno" value={turno ?? ""} />
            <input type="hidden" name="chave" value={chave} />
            <fieldset className="flex flex-col gap-2">
              <legend className="font-semibold">{t.motivo}</legend>
              {MOTIVOS_DA_DENUNCIA.map((motivo) => (
                <label key={motivo} className="flex min-h-12 items-center gap-3 rounded-controle border border-borda bg-superficie px-4">
                  <input type="radio" name="motivo" value={motivo} required className="size-5" />
                  <span>{t.motivos[motivo]}</span>
                </label>
              ))}
            </fieldset>
            <label className="flex flex-col gap-2 font-semibold" htmlFor="relato">
              {t.relato}
              <span id="ajuda-do-relato" className="text-sm font-normal text-tinta-suave">
                {t.ajudaDoRelato}
              </span>
              <textarea
                id="relato"
                name="relato"
                required
                minLength={MINIMO_DO_RELATO}
                rows={5}
                aria-describedby="ajuda-do-relato"
                className="w-full rounded-controle border border-borda bg-superficie p-3 text-lg"
              />
            </label>
            <label className="flex min-h-12 items-center gap-3">
              <input type="checkbox" name="bloquear" value="sim" className="size-5" />
              <span>{t.bloquearJunto}</span>
            </label>
            <button type="submit" disabled={enviando} className={classeDoBotao}>
              {enviando ? t.enviando : t.enviar}
            </button>
          </Form>
          <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
            <p>{t.sobreBloquear}</p>
            <input type="hidden" name="alvo" value={alvo} />
            <input type="hidden" name="intencao" value="bloquear" />
            <button type="submit" disabled={enviando} className={classeDoBotaoSecundario}>
              {enviando ? t.enviando : t.soBloquear}
            </button>
          </Form>
        </>
      )}
      <Link to="/bloqueados" className={classeDoLink}>
        {t.bloqueados}
      </Link>
      <Link to="/" className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
