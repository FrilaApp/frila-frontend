import { Form, Link, redirect, useNavigation } from "react-router";

import { escolherCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { type Convite, convidarMembro, lerMembros, type MudancaDeMembro, mudarMembro, PAPEIS, type Papel } from "../../servidor/contratante/membros";
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
  const leitura = await lerMinhasCasas(apiDoUsuario(sessao));
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  // Sem casa, conta de profissional ou servidor fora: o painel explica cada caso.
  const casa = leitura.estado === "ok" ? escolherCasa(leitura.casas, new URL(request.url).searchParams.get("casa")) : null;
  if (!casa) throw redirect("/painel");
  const lista = casa.papel === "administrador" ? await lerMembros(apiDoUsuario(sessao), casa.id) : { estado: "so_administrador" as const, membros: [] };
  const estado = lista.estado;
  if (estado === "sem_sessao") throw redirect("/entrar");
  const consulta = new URL(request.url).searchParams;
  return {
    casa: { id: casa.id, nome: casa.nome, administrador: casa.papel === "administrador" },
    ...lista,
    estado,
    aviso: consulta.has("removido") ? t.removido : consulta.has("transferido") ? t.transferido : null,
  };
}

type Retorno =
  | { link: string; ate: string; email: string; papel: Papel }
  | { falha: Exclude<Extract<Convite | MudancaDeMembro, { ok: false }>["motivo"], "sem_sessao"> | "confirmacao"; email?: string; papel?: string };

function formatarPrazo(expiraEm: string | null | undefined): string {
  if (!expiraEm) return "";
  const data = new Date(expiraEm);
  return Number.isNaN(data.getTime()) ? "" : instante.format(data);
}

/** Monta a mensagem do convite com o aviso do ROPA e o link na última linha. */
export function mensagemDoConvite({
  casa,
  papel,
  email,
  prazo,
  link,
}: {
  casa: string;
  papel: string;
  email: string;
  prazo?: string | null;
  link: string;
}): string {
  const textoPrazo = prazo?.trim() ?? "";
  return preencher(textoPrazo ? t.mensagemDoConvite : t.mensagemDoConviteSemPrazo, {
    casa,
    papel: papel.trim().toLowerCase(),
    email: email.trim(),
    prazo: textoPrazo,
    link,
  });
}

/** O link leva o token no fragmento (`#…`): abrir o link não manda o token a servidor nenhum. */
export async function action({ request, context }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const intencao = String(formulario.get("intencao") ?? "convidar");
  if (intencao !== "convidar") {
    if (intencao !== "remover" && intencao !== "transferir") return { falha: "indisponivel" };
    if (formulario.get("confirmado") !== "sim") return { falha: "confirmacao" };
    const casaId = String(formulario.get("casa") ?? "");
    const resultado = await mudarMembro(apiDoUsuario(sessao), casaId, String(formulario.get("membro_id") ?? ""), intencao);
    if (!resultado.ok) {
      if (resultado.motivo === "sem_sessao") throw redirect("/entrar");
      return { falha: resultado.motivo };
    }
    // O redirect volta ao loader: lista e papel da conta são relidos, inclusive ao remover a si próprio.
    throw redirect(`/casa/membros?casa=${casaId}&${intencao === "remover" ? "removido" : "transferido"}=1`);
  }
  const email = String(formulario.get("email") ?? "").trim();
  const papel = String(formulario.get("papel") ?? "");
  const convite = await convidarMembro(apiDoUsuario(sessao), String(formulario.get("casa") ?? ""), email, papel);
  if (!convite.ok) {
    if (convite.motivo === "sem_sessao") throw redirect("/entrar");
    return { falha: convite.motivo, email, papel };
  }
  return {
    link: `${new URL(request.url).origin}/app/convite#${convite.token}`,
    ate: formatarPrazo(convite.expiraEm),
    email,
    papel: papel as Papel,
  };
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function MembrosDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const gerando = useNavigation().state !== "idle";
  const { casa, membros, estado, aviso } = loaderData;
  const falha = actionData && "falha" in actionData ? actionData : null;
  const pronto = actionData && "link" in actionData ? actionData : null;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <Link to={`/painel?casa=${casa.id}`} className={classeDoLink}>
        {t.voltar}
      </Link>
      <p className="font-titulo text-xl font-bold">{casa.nome}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {falha ? <p id="falha-membros" role="alert" className="font-semibold">{t.erros[falha.falha]}</p> : null}
      {aviso ? <p role="status">{aviso}</p> : null}
      <section className="flex flex-col gap-4" aria-labelledby="lista-de-membros">
        <h2 id="lista-de-membros" className="font-titulo text-xl font-bold">{t.lista}</h2>
        {estado !== "ok" ? <p role="status">{t.falhasDaLista[estado]}</p> : membros.length === 0 ? <p>{t.vazia}</p> : (
          <ul className="flex flex-col gap-4">
            {membros.map((membro) => (
              <li key={membro.membro_id} className="flex flex-col gap-3 rounded-cartao border border-borda bg-superficie p-4">
                <p className="font-semibold">{membro.nome}</p>
                <p>{t.papeis[membro.papel]}{membro.e_voce ? ` · ${t.voce}` : ""}</p>
                {casa.administrador ? (["remover", "transferir"] as const).filter((intencao) => intencao === "remover" || !membro.e_voce).map((intencao) => (
                  <details key={intencao}>
                    <summary className="min-h-11 cursor-pointer py-2 font-semibold underline underline-offset-4">{preencher(t[intencao], { nome: membro.nome })}</summary>
                    <Form method="post" className="flex flex-col gap-3" aria-busy={gerando}>
                      <input type="hidden" name="casa" value={casa.id} />
                      <input type="hidden" name="membro_id" value={membro.membro_id} />
                      <input type="hidden" name="intencao" value={intencao} />
                      <label className="flex min-h-12 items-center gap-3">
                        <input type="checkbox" required name="confirmado" value="sim" className="size-5 shrink-0" />
                        <span>{intencao === "remover" ? t.confirmarRemocao : t.confirmarTransferencia}</span>
                      </label>
                      <button type="submit" disabled={gerando} aria-label={preencher(t[intencao], { nome: membro.nome })} className={classeDoBotao}>{gerando ? t.enviando : t.confirmar}</button>
                    </Form>
                  </details>
                )) : null}
              </li>
            ))}
          </ul>
        )}
      </section>
      <p>{t.explicacao}</p>
      {!casa.administrador ? (
        <p role="status">{t.soAdministrador}</p>
      ) : (
        <Form method="post" className="flex flex-col gap-4">
          <input type="hidden" name="casa" value={casa.id} />
          <input type="hidden" name="intencao" value="convidar" />
          <label className={classeDoRotulo}>
            {t.email}
            <input name="email" type="email" required autoComplete="off" defaultValue={falha?.email ?? ""} className={classeDoCampo} aria-invalid={falha?.falha === "email" ? true : undefined} aria-describedby={falha?.falha === "email" ? "falha-membros" : undefined} />
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
            {t.rotuloDaMensagem}
            <textarea
              readOnly
              rows={6}
              value={mensagemDoConvite({
                casa: casa.nome,
                papel: pronto.papel,
                email: pronto.email,
                prazo: pronto.ate,
                link: pronto.link,
              })}
              className={`${classeDoCampo} py-3 text-base`}
            />
          </label>
        </section>
      ) : null}
    </main>
  );
}
