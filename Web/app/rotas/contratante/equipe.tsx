import { Form, Link, redirect, useNavigation } from "react-router";

import { escolherCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { type FalhaNaEquipe, lerEquipe, mudarEquipe } from "../../servidor/contratante/equipe";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/equipe";
import { enviandoEste, preencher } from "./comum";

const t = textos.contratanteEquipe;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ request, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const leitura = await lerMinhasCasas(api);
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  const busca = new URL(request.url).searchParams;
  // Sem casa, conta de profissional ou servidor fora: o painel explica cada caso.
  const casa = leitura.estado === "ok" ? escolherCasa(leitura.casas, busca.get("casa")) : null;
  if (!casa) throw redirect("/painel");

  const equipe = await lerEquipe(api, casa.id);
  if (equipe.estado === "sem_sessao") throw redirect("/entrar");
  const aviso = busca.get("incluido") === "1" ? t.incluido : busca.get("removido") === "1" ? t.removido : null;
  return {
    casa: { id: casa.id, nome: casa.nome, administrador: casa.papel === "administrador" },
    estado: equipe.estado,
    membros: equipe.estado === "ok" ? equipe.membros.map((m) => ({ id: m.id, nome: m.nome, funcoes: m.funcoes ?? [] })) : [],
    aviso,
  };
}

/**
 * Incluir chega do detalhe do turno da casa (presença verificada); remover, desta tela. Deu certo: volta a esta tela
 * com o aviso no endereço (recarregar não repete o pedido). Recusa: a tela mostra o motivo do servidor.
 */
export async function action({ request, context }: Route.ActionArgs): Promise<{ falha: Exclude<FalhaNaEquipe, "sem_sessao"> }> {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const intencao = String(formulario.get("intencao") ?? "");
  const casaId = String(formulario.get("casa") ?? "");
  const profissionalId = String(formulario.get("profissional_id") ?? "");
  if (intencao !== "incluir" && intencao !== "remover") return { falha: "indisponivel" };
  const feito = await mudarEquipe(apiDoUsuario(sessao.acesso), intencao, casaId, profissionalId);
  if (feito.ok) throw redirect(`/casa/equipe?casa=${casaId}&${intencao === "incluir" ? "incluido" : "removido"}=1`);
  if (feito.motivo === "sem_sessao") throw redirect("/entrar");
  return { falha: feito.motivo };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoSecundario = "min-h-11 self-start rounded-controle border border-borda px-4 font-semibold disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function EquipeDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const { casa, membros } = loaderData;
  const falha = actionData?.falha;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{casa.nome}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p>{t.explicacao}</p>
      {loaderData.aviso && !falha ? (
        <p role="status" className="font-semibold">
          {loaderData.aviso}
        </p>
      ) : null}
      {falha ? (
        <p role="alert" className="font-semibold">
          {t.erros[falha]}
        </p>
      ) : null}
      {!casa.administrador ? <p>{t.soAdministradorAltera}</p> : null}

      {loaderData.estado === "sem_permissao" ? <p role="alert">{t.erros.semPermissao}</p> : null}
      {loaderData.estado === "indisponivel" ? <p role="alert">{t.erros.carregar}</p> : null}
      {loaderData.estado === "ok" && membros.length === 0 ? (
        <section className="flex flex-col gap-1">
          <h2 className="font-semibold">{t.vazioTitulo}</h2>
          <p>{t.vazioMensagem}</p>
        </section>
      ) : null}

      {membros.length > 0 ? (
        <ul className="flex flex-col gap-3">
          {membros.map((membro) => {
            const removendo = enviandoEste(navegacao, "remover") && navegacao.formData?.get("profissional_id") === membro.id;
            return (
              <li key={membro.id} className="flex flex-col gap-2 rounded-cartao border border-borda bg-superficie p-4">
                <p className="text-lg font-semibold">{membro.nome}</p>
                {membro.funcoes.length > 0 ? <p className="text-tinta-suave">{membro.funcoes.join(", ")}</p> : null}
                {casa.administrador ? (
                  <Form method="post" className="flex flex-col gap-2">
                    <input type="hidden" name="casa" value={casa.id} />
                    <input type="hidden" name="profissional_id" value={membro.id} />
                    <p id={`efeito-${membro.id}`} className="text-sm text-tinta-suave">
                      {preencher(t.efeitoRemocao, { nome: membro.nome })}
                    </p>
                    <button type="submit" name="intencao" value="remover" disabled={removendo} aria-describedby={`efeito-${membro.id}`} className={classeDoSecundario}>
                      {removendo ? t.removendo : t.remover}
                    </button>
                  </Form>
                ) : null}
              </li>
            );
          })}
        </ul>
      ) : null}

      <Link to={`/painel?casa=${casa.id}`} className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
