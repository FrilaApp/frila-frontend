import { Form, Link } from "react-router";

import { lerMinhasCasas } from "../../servidor/contratante/casa";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/relatorio";

const t = textos.relatorioTurnos;
const ERROS = new Set(Object.keys(t.erros));
const diaDoDf = (data: Date) => new Date(data.getTime() - 3 * 60 * 60 * 1000).toISOString().slice(0, 10);

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** Os dois lados: quem é membro de casas escolhe a casa; o profissional baixa os próprios turnos. */
export async function loader({ context, request }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const busca = new URL(request.url).searchParams;
  const leitura = await lerMinhasCasas(apiDoUsuario(sessao.acesso));
  const casas = leitura.estado === "ok" ? leitura.casas.map((casa) => ({ id: casa.id, nome: casa.nome })) : [];
  const erro = busca.get("erro");
  // Padrão: os últimos 15 dias, como o servidor.
  const hoje = new Date();
  return {
    casas,
    casaEscolhida: busca.get("casa") ?? casas[0]?.id ?? "",
    de: diaDoDf(new Date(hoje.getTime() - 14 * 24 * 60 * 60 * 1000)),
    ate: diaDoDf(hoje),
    erro: erro && ERROS.has(erro) ? t.erros[erro as keyof typeof t.erros] : null,
  };
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function RelatorioDosTurnos({ loaderData }: Route.ComponentProps) {
  const { casas } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p>{t.corpo}</p>
      {loaderData.erro ? (
        <p role="alert" className="font-semibold">
          {loaderData.erro}
        </p>
      ) : null}
      {/* Recarrega a página de propósito: o navegador baixa o arquivo que a resposta traz. */}
      <Form method="post" action="/conta/relatorio/arquivo" reloadDocument className="flex flex-col gap-4">
        {casas.length > 0 ? (
          <label className={classeDoRotulo}>
            {t.deQuem}
            <select name="casa" defaultValue={loaderData.casaEscolhida} className={classeDoCampo}>
              {casas.map((casa) => (
                <option key={casa.id} value={casa.id}>
                  {casa.nome}
                </option>
              ))}
            </select>
          </label>
        ) : (
          <p>
            {t.deQuem}: <strong>{t.meusTurnos}</strong>
          </p>
        )}
        <p id="ajuda-periodo" className="text-sm text-tinta-suave">
          {t.ajudaDoPeriodo}
        </p>
        <div className="grid grid-cols-2 gap-3">
          <label className={classeDoRotulo}>
            {t.de}
            <input name="de" type="date" required defaultValue={loaderData.de} aria-describedby="ajuda-periodo" className={classeDoCampo} />
          </label>
          <label className={classeDoRotulo}>
            {t.ate}
            <input name="ate" type="date" required defaultValue={loaderData.ate} aria-describedby="ajuda-periodo" className={classeDoCampo} />
          </label>
        </div>
        <fieldset className="flex flex-col gap-2">
          <legend className="font-semibold">{t.formato}</legend>
          {(["pdf", "csv"] as const).map((formato) => (
            <label key={formato} className="flex min-h-12 items-center gap-3 rounded-controle border border-borda bg-superficie px-4">
              <input type="radio" name="formato" value={formato} defaultChecked={formato === "pdf"} className="size-5 shrink-0" />
              <span>{t.formatos[formato]}</span>
            </label>
          ))}
        </fieldset>
        <button type="submit" className={classeDoBotao}>
          {t.baixar}
        </button>
      </Form>
      <Link to="/conta" className="inline-flex min-h-11 items-center font-semibold underline underline-offset-4">
        {t.voltar}
      </Link>
    </main>
  );
}
