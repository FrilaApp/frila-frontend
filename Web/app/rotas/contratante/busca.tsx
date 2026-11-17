import { Form, Link, redirect, useNavigation } from "react-router";

import {
  buscarProfissionais,
  type CampoDaBusca,
  type CartaoProfissional,
  type FalhaDaBusca,
  type FiltrosDaBusca,
  filtrosDoFormulario,
  lerFiltros,
  lerRegioes,
} from "../../servidor/contratante/busca";
import { escolherCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { lerFuncoes, porCategoria } from "../../servidor/contratante/catalogo";
import { ehUuid } from "../../servidor/contratante/publicar-vaga";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { formatarValor } from "../../servidor/profissional/formato";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/busca";
import { preencher } from "./comum";

const t = textos.contratanteBusca;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ request, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const leitura = await lerMinhasCasas(api);
  if (leitura.estado === "sem_sessao") throw redirect("/entrar");
  // Sem casa, conta de profissional ou servidor fora: o painel explica cada caso.
  const casa = leitura.estado === "ok" ? escolherCasa(leitura.casas, new URL(request.url).searchParams.get("casa")) : null;
  if (!casa) throw redirect("/painel");
  const [funcoes, regioes] = await Promise.all([lerFuncoes(api), lerRegioes(api)]);
  return {
    casa: { id: casa.id, nome: casa.nome },
    grupos: funcoes.estado === "ok" ? porCategoria(funcoes.funcoes) : [],
    regioes: regioes ?? [],
    catalogoIndisponivel: funcoes.estado !== "ok" || !regioes,
  };
}

/** O cartão como a tela mostra: só o que ajuda a decidir quem chamar (CD-B07). Nunca contato nem sobrenome. */
function cartaoParaTela(cartao: CartaoProfissional) {
  const { servico, reputacao } = cartao;
  const unidade = t.unidade[servico.unidade];
  const preco =
    servico.unidade === "a_combinar" || servico.valor_centavos == null
      ? t.unidade.a_combinar
      : preencher(t.preco, {
          valor: servico.valor_max_centavos
            ? preencher(t.faixaDePreco, { min: formatarValor(servico.valor_centavos), max: formatarValor(servico.valor_max_centavos) })
            : formatarValor(servico.valor_centavos),
          unidade,
        });
  return {
    id: cartao.id,
    nome: cartao.nome,
    servico: servico.funcao.nome,
    preco,
    regioes: cartao.atende_todo_df ? t.atendeTodoDf : preencher(t.atende, { regioes: cartao.regioes.map((r) => r.nome).join(", ") }),
    distancia: t.distancia[cartao.distancia_faixa],
    reputacao: reputacao.total > 0 ? preencher(t.chamariamDeNovo, { positivas: reputacao.positivas, total: reputacao.total }) : t.semAvaliacoes,
    disponivel: cartao.disponivel_no_horario === true,
  };
}

type Retorno =
  | { estado: "ok"; filtros: FiltrosDaBusca; cartoes: ReturnType<typeof cartaoParaTela>[]; proximoCursor: string | null }
  | { estado: "erro"; filtros: FiltrosDaBusca; campo?: CampoDaBusca; falha?: Exclude<FalhaDaBusca, "sem_sessao"> };

export async function action({ request, context }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const filtros = filtrosDoFormulario(formulario);
  const casaId = String(formulario.get("casa") ?? "");
  const cursor = String(formulario.get("cursor") ?? "") || undefined;
  if (!ehUuid(casaId)) return { estado: "erro", filtros, falha: "sem_permissao" };
  const lido = lerFiltros(filtros);
  if (!lido.ok) return { estado: "erro", filtros, campo: lido.campo };

  const resultado = await buscarProfissionais(apiDoUsuario(sessao.acesso), casaId, lido.corpo, cursor);
  if (resultado.ok) return { estado: "ok", filtros, cartoes: resultado.itens.map(cartaoParaTela), proximoCursor: resultado.proximoCursor };
  if (resultado.motivo === "sem_sessao") throw redirect("/entrar");
  if (resultado.motivo === "campo") return { estado: "erro", filtros, campo: resultado.campo };
  return { estado: "erro", filtros, falha: resultado.motivo };
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

const SEM_FILTROS: FiltrosDaBusca = { funcao_id: "", regiao_id: "", dia: "", inicio: "", fim: "" };

function Aviso({ id, texto }: { id: string; texto?: string }) {
  return texto ? (
    <p id={id} role="alert" className="font-semibold">
      {texto}
    </p>
  ) : null;
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function BuscaDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const buscando = useNavigation().state !== "idle";
  const { casa, grupos, regioes } = loaderData;
  const filtros = actionData?.filtros ?? SEM_FILTROS;
  const campo = actionData?.estado === "erro" ? actionData.campo : undefined;
  const falha = actionData?.estado === "erro" ? actionData.falha : undefined;
  const erroDoCampo = (nome: CampoDaBusca) => (campo === nome ? t.erros[nome] : undefined);
  const invalido = (nome: CampoDaBusca) => (campo === nome ? { "aria-invalid": true, "aria-describedby": `erro-${nome}` } : {});

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <Link to={`/painel?casa=${casa.id}`} className={classeDoLink}>
        {t.voltar}
      </Link>
      <p className="font-titulo text-xl font-bold">{casa.nome}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p>{t.explicacao}</p>
      {loaderData.catalogoIndisponivel ? <p role="status">{t.erros.catalogo}</p> : null}

      <Form method="post" className="flex flex-col gap-4" noValidate>
        <input type="hidden" name="casa" value={casa.id} />
        <label className={classeDoRotulo}>
          {t.servico}
          <select name="funcao_id" required defaultValue={filtros.funcao_id} className={classeDoCampo} {...invalido("funcao_id")}>
            <option value="">{t.escolhaOServico}</option>
            {grupos.map((grupo) => (
              <optgroup key={grupo.categoria} label={grupo.categoria}>
                {grupo.funcoes.map((funcao) => (
                  <option key={funcao.id} value={funcao.id}>
                    {funcao.nome}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
          <Aviso id="erro-funcao_id" texto={erroDoCampo("funcao_id")} />
        </label>

        <label className={classeDoRotulo}>
          {t.regiao}
          <select name="regiao_id" defaultValue={filtros.regiao_id} className={classeDoCampo} {...invalido("regiao_id")}>
            <option value="">{t.regiaoDaCasa}</option>
            {regioes.map((regiao) => (
              <option key={regiao.id} value={regiao.id}>
                {regiao.nome}
              </option>
            ))}
          </select>
          <Aviso id="erro-regiao_id" texto={erroDoCampo("regiao_id")} />
        </label>

        <fieldset className="flex flex-col gap-3" aria-describedby="ajuda-horario">
          <legend className="font-semibold">{t.horario}</legend>
          <p id="ajuda-horario" className="text-sm text-tinta-suave">
            {t.ajudaDoHorario}
          </p>
          <label className={classeDoRotulo}>
            {t.dia}
            <input name="dia" type="date" defaultValue={filtros.dia} className={classeDoCampo} {...invalido("horario")} />
          </label>
          <div className="grid grid-cols-2 gap-3">
            <label className={classeDoRotulo}>
              {t.inicio}
              <input name="inicio" type="time" defaultValue={filtros.inicio} className={classeDoCampo} {...invalido("horario")} />
            </label>
            <label className={classeDoRotulo}>
              {t.termino}
              <input name="fim" type="time" defaultValue={filtros.fim} className={classeDoCampo} {...invalido("horario")} />
            </label>
          </div>
          <Aviso id="erro-horario" texto={erroDoCampo("horario")} />
        </fieldset>

        <button type="submit" disabled={buscando} className={classeDoBotao}>
          {buscando ? t.buscando : t.buscar}
        </button>
      </Form>

      {falha ? (
        <div role="alert" className="flex flex-col gap-2 font-semibold">
          <p>{t.erros[falha]}</p>
          {falha === "termos_pendentes" ? (
            <Link to="/" className={classeDoLink}>
              {t.erros.irAosTermos}
            </Link>
          ) : null}
        </div>
      ) : null}

      {actionData?.estado === "ok" ? (
        <section className="flex flex-col gap-3" aria-labelledby="titulo-profissionais">
          <h2 id="titulo-profissionais" className="font-titulo text-xl font-bold">
            {t.profissionais}
          </h2>
          {actionData.cartoes.length === 0 ? (
            <>
              <p role="status">{t.nenhumEncontrado}</p>
              <Link to={`/painel/publicar?casa=${casa.id}`} className={classeDoLink}>
                {t.publicarParaTodos}
              </Link>
            </>
          ) : (
            <ul className="flex flex-col gap-3">
              {actionData.cartoes.map((cartao) => (
                <li key={cartao.id} className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4">
                  <p className="text-lg font-semibold">{cartao.nome}</p>
                  <p>
                    {cartao.servico} · {cartao.preco}
                  </p>
                  {cartao.disponivel ? <p className="font-semibold">{t.disponivelNesseHorario}</p> : null}
                  <p className="text-tinta-suave">{cartao.distancia}</p>
                  <p className="text-tinta-suave">{cartao.regioes}</p>
                  <p className="text-tinta-suave">{cartao.reputacao}</p>
                </li>
              ))}
            </ul>
          )}
          {actionData.proximoCursor ? (
            // A página seguinte vai com os mesmos filtros e o cursor; ela não conta como busca nova.
            <Form method="post">
              <input type="hidden" name="casa" value={casa.id} />
              {(Object.keys(actionData.filtros) as Array<keyof FiltrosDaBusca>).map((nome) => (
                <input key={nome} type="hidden" name={nome} value={actionData.filtros[nome]} />
              ))}
              <input type="hidden" name="cursor" value={actionData.proximoCursor} />
              <button type="submit" disabled={buscando} className="min-h-11 rounded-controle border border-borda px-4 font-semibold disabled:opacity-60">
                {t.proximaPagina}
              </button>
            </Form>
          ) : null}
        </section>
      ) : null}
    </main>
  );
}
