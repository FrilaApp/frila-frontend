import { Form, Link, redirect, useNavigation } from "react-router";

import { escolherCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { cancelarChamada, type FalhaNaChamada, publicarParaTodos } from "../../servidor/contratante/chamadas";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { listarChamadas } from "../../servidor/profissional/chamadas";
import { formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/chamadas";
import { enviandoEste, preencher } from "./comum";

const t = textos.contratanteChamadas;
const instante = new Intl.DateTimeFormat("pt-BR", { timeZone: "America/Sao_Paulo", weekday: "short", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** Estados em que a vaga direta ainda pode virar vaga para todos (o servidor confere: 409 vaga_encerrada). */
const PODE_PUBLICAR = new Set(["aberta", "recusada", "expirada", "cancelada"]);

export async function loader({ request, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const busca = new URL(request.url).searchParams;
  const leitura = await lerMinhasCasas(api);
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  // Sem casa, conta de profissional ou servidor fora: o painel explica cada caso.
  const casa = leitura.estado === "ok" ? escolherCasa(leitura.casas, busca.get("casa")) : null;
  if (!casa) throw redirect("/painel");

  const chamadas = await listarChamadas(api, busca.get("cursor"));
  const aviso = busca.get("cancelada") === "1" ? t.cancelada : busca.get("publicada") === "1" ? t.publicada : null;
  if (chamadas.estado !== "ok") return { casa: { id: casa.id, nome: casa.nome }, estado: "indisponivel" as const, itens: [], proximoCursor: null, aviso };
  // A leitura traz as chamadas de todas as casas da conta: a tela mostra as desta.
  const itens = chamadas.itens
    .filter((chamada) => chamada.estabelecimento_id === casa.id)
    .map((chamada) => ({
      id: chamada.id,
      vagaId: chamada.vaga_id,
      nome: chamada.outra_parte.nome,
      funcao: chamada.funcao.nome,
      periodo: formatarPeriodo(chamada.inicio_em, chamada.fim_em),
      valor: formatarValor(chamada.valor_centavos),
      estado: t.estado[chamada.estado],
      respondaAte: chamada.estado === "aberta" ? preencher(t.respondaAte, { quando: instante.format(new Date(chamada.expira_em)) }) : null,
      motivo: chamada.estado === "recusada" && chamada.motivo_recusa ? preencher(t.motivo, { motivo: t.motivos[chamada.motivo_recusa] }) : null,
      podeCancelar: chamada.estado === "aberta",
      podePublicar: PODE_PUBLICAR.has(chamada.estado),
      // Uma chave por vaga nesta tela; o servidor também devolve a mesma vaga nova pela vaga direta.
      chave: crypto.randomUUID(),
    }));
  return { casa: { id: casa.id, nome: casa.nome }, estado: "ok" as const, itens, proximoCursor: chamadas.proximoCursor, aviso };
}

export async function action({ request, context }: Route.ActionArgs): Promise<{ falha: Exclude<FalhaNaChamada, "sem_sessao"> }> {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const formulario = await request.formData();
  const intencao = String(formulario.get("intencao") ?? "");
  const casaId = String(formulario.get("casa") ?? "");
  const feito =
    intencao === "cancelar"
      ? await cancelarChamada(api, String(formulario.get("chamada_id") ?? ""))
      : intencao === "publicar"
        ? await publicarParaTodos(api, String(formulario.get("vaga_id") ?? ""), String(formulario.get("chave") ?? ""))
        : ({ ok: false, motivo: "indisponivel" } as const);
  if (feito.ok) throw redirect(`/casa/chamadas?casa=${casaId}&${intencao === "cancelar" ? "cancelada" : "publicada"}=1`);
  if (feito.motivo === "sem_sessao") throw redirect("/entrar");
  return { falha: feito.motivo };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoSecundario = "min-h-11 self-start rounded-controle border border-borda px-4 font-semibold disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function ChamadasDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const ocupado = navegacao.state !== "idle";
  const { casa, itens } = loaderData;
  const deste = (campo: string, valor: string) => navegacao.formData?.get(campo) === valor;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <Link to={`/painel?casa=${casa.id}`} className={classeDoLink}>
        {t.voltar}
      </Link>
      <p className="font-titulo text-xl font-bold">{casa.nome}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {loaderData.aviso && !actionData ? (
        <p role="status" className="font-semibold">
          {loaderData.aviso}
        </p>
      ) : null}
      {actionData ? (
        <p role="alert" className="font-semibold">
          {t.erros[actionData.falha]}
        </p>
      ) : null}
      {loaderData.estado === "indisponivel" ? <p role="alert">{t.erros.carregar}</p> : null}
      {loaderData.estado === "ok" && itens.length === 0 ? <p>{t.vazio}</p> : null}

      <ul className="flex flex-col gap-3">
        {itens.map((item) => (
          <li key={item.id} className="flex flex-col gap-2 rounded-cartao border border-borda bg-superficie p-4">
            <p className="text-lg font-semibold">{item.nome}</p>
            <p>
              {item.funcao} · {item.periodo} · {item.valor}
            </p>
            <p className="font-semibold">{item.estado}</p>
            {item.respondaAte ? <p className="text-tinta-suave">{item.respondaAte}</p> : null}
            {item.motivo ? <p className="text-tinta-suave">{item.motivo}</p> : null}
            {item.podeCancelar ? (
              <Form method="post" className="flex flex-col gap-1">
                <input type="hidden" name="casa" value={casa.id} />
                <input type="hidden" name="chamada_id" value={item.id} />
                <p id={`efeito-cancelar-${item.id}`} className="text-sm text-tinta-suave">
                  {t.efeitoDoCancelar}
                </p>
                <button type="submit" name="intencao" value="cancelar" disabled={ocupado} aria-describedby={`efeito-cancelar-${item.id}`} className={classeDoSecundario}>
                  {enviandoEste(navegacao, "cancelar") && deste("chamada_id", item.id) ? t.cancelando : t.cancelar}
                </button>
              </Form>
            ) : null}
            {item.podePublicar ? (
              <Form method="post" className="flex flex-col gap-1">
                <input type="hidden" name="casa" value={casa.id} />
                <input type="hidden" name="vaga_id" value={item.vagaId} />
                <input type="hidden" name="chave" value={item.chave} />
                <p id={`efeito-publicar-${item.id}`} className="text-sm text-tinta-suave">
                  {t.efeitoDoPublicar}
                </p>
                <button type="submit" name="intencao" value="publicar" disabled={ocupado} aria-describedby={`efeito-publicar-${item.id}`} className={classeDoSecundario}>
                  {enviandoEste(navegacao, "publicar") && deste("vaga_id", item.vagaId) ? t.publicando : t.publicar}
                </button>
              </Form>
            ) : null}
          </li>
        ))}
      </ul>

      {loaderData.proximoCursor ? (
        <Link to={`/casa/chamadas?casa=${casa.id}&cursor=${encodeURIComponent(loaderData.proximoCursor)}`} className={classeDoLink}>
          {t.verMais}
        </Link>
      ) : null}
      <Link to={`/casa/busca?casa=${casa.id}`} className={classeDoLink}>
        {t.chamarOutra}
      </Link>
    </main>
  );
}
