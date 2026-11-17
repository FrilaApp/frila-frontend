import { Form, Link, redirect, useNavigation } from "react-router";

import { escolherCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { type Convite, convidarMembro, PAPEIS } from "../../servidor/contratante/membros";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/membros";
import { preencher } from "./comum";

const t = textos.contratanteMembros;
const instante = new Intl.DateTimeFormat("pt-BR", { timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ request, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await lerMinhasCasas(apiDoUsuario(sessao.acesso));
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  // Sem casa, conta de profissional ou servidor fora: o painel explica cada caso.
  const casa = leitura.estado === "ok" ? escolherCasa(leitura.casas, new URL(request.url).searchParams.get("casa")) : null;
  if (!casa) throw redirect("/painel");
  return { casa: { id: casa.id, nome: casa.nome, administrador: casa.papel === "administrador" } };
}

type Retorno = { link: string; ate: string } | { falha: Exclude<Extract<Convite, { ok: false }>["motivo"], "sem_sessao">; email: string; papel: string };

/** O link leva o token no fragmento (`#…`): abrir o link não manda o token a servidor nenhum. */
export async function action({ request, context }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const email = String(formulario.get("email") ?? "").trim();
  const papel = String(formulario.get("papel") ?? "");
  const convite = await convidarMembro(apiDoUsuario(sessao.acesso), String(formulario.get("casa") ?? ""), email, papel);
  if (!convite.ok) {
    if (convite.motivo === "sem_sessao") throw redirect("/entrar");
    return { falha: convite.motivo, email, papel };
  }
  return { link: `${new URL(request.url).origin}/app/convite#${convite.token}`, ate: instante.format(new Date(convite.expiraEm)) };
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function MembrosDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const gerando = useNavigation().state !== "idle";
  const { casa } = loaderData;
  const falha = actionData && "falha" in actionData ? actionData : null;
  const pronto = actionData && "link" in actionData ? actionData : null;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <Link to={`/painel?casa=${casa.id}`} className={classeDoLink}>
        {t.voltar}
      </Link>
      <p className="font-titulo text-xl font-bold">{casa.nome}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p>{t.explicacao}</p>
      {!casa.administrador ? (
        <p role="status">{t.soAdministrador}</p>
      ) : (
        <Form method="post" className="flex flex-col gap-4">
          <input type="hidden" name="casa" value={casa.id} />
          {falha ? (
            <p role="alert" className="font-semibold">
              {t.erros[falha.falha]}
            </p>
          ) : null}
          <label className={classeDoRotulo}>
            {t.email}
            <input name="email" type="email" required autoComplete="off" defaultValue={falha?.email ?? ""} className={classeDoCampo} aria-invalid={falha?.falha === "email" ? true : undefined} />
          </label>
          <fieldset className="flex flex-col gap-2">
            <legend className="font-semibold">{t.papel}</legend>
            {PAPEIS.map((papel) => (
              <label key={papel} className="flex min-h-12 items-center gap-3 rounded-controle border border-borda bg-superficie px-4">
                <input type="radio" name="papel" value={papel} defaultChecked={(falha?.papel || "operador") === papel} className="size-5 shrink-0" />
                <span>{t.papeis[papel]}</span>
              </label>
            ))}
          </fieldset>
          <button type="submit" disabled={gerando} className={classeDoBotao}>
            {gerando ? t.gerando : t.convidar}
          </button>
        </Form>
      )}
      {pronto ? (
        <section role="status" className="flex flex-col gap-2 rounded-cartao border border-borda bg-superficie p-4">
          <p className="font-semibold">{preencher(t.pronto, { quando: pronto.ate })}</p>
          <label className={classeDoRotulo}>
            {t.rotuloDoLink}
            <input type="text" readOnly value={pronto.link} className={`${classeDoCampo} text-base`} />
          </label>
        </section>
      ) : null}
    </main>
  );
}
