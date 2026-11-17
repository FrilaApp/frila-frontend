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
import { escolherCasa, lerCadastroDaCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { lerFuncoes, porCategoria } from "../../servidor/contratante/catalogo";
import {
  type CampoDosTermos,
  chamarProfissional,
  type FalhaDaChamada,
  lerTermos,
  lerTermosDaVagaAberta,
  pedidoDoTrabalho,
  pedidoPelaVaga,
  RECADO_MAXIMO,
  type TermosDaVagaAberta,
  type TermosDigitados,
  termosDoFormulario,
} from "../../servidor/contratante/chamar";
import { ehUuid } from "../../servidor/contratante/publicar-vaga";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/busca";
import { enviandoEste, preencher } from "./comum";

const t = textos.contratanteBusca;
const tc = t.chamada;

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

/** O que a chamada deu para este profissional. */
type Situacao =
  | { tipo: "enviada" }
  | { tipo: "falha"; motivo: Exclude<FalhaDaChamada, "sem_sessao"> }
  | { tipo: "vaga_aberta"; vagaId: string; termos: string }
  | { tipo: "vaga_aberta_sem_termos" }
  | { tipo: "recorrencia" };

/** O cartão como a tela mostra: só o que ajuda a decidir quem chamar (CD-B07). Nunca contato nem sobrenome. */
type Cartao = {
  id: string;
  nome: string;
  servico: string;
  preco: string;
  regioes: string;
  distancia: string;
  reputacao: string;
  disponivel: boolean;
  /** Uma chave por profissional: o reenvio devolve a mesma chamada. */
  chave: string;
  /** A vaga já aberta pela qual a casa aceitou chamar (termos da vaga). */
  vagaId?: string;
  situacao?: Situacao;
};

function cartaoParaTela(cartao: CartaoProfissional): Cartao {
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
    chave: crypto.randomUUID(),
  };
}

/**
 * A lista volta no formulário (campo `cartoes`), para chamar sem buscar de novo (a busca gasta o limite). É texto de
 * tela; o que vai ao servidor (o id e a chave) é conferido aqui e de novo pelo servidor.
 */
function cartoesDoFormulario(bruto: string): Cartao[] | null {
  try {
    const lista: unknown = JSON.parse(bruto);
    if (!Array.isArray(lista) || lista.length > 20) return null;
    const texto = (valor: unknown) => (typeof valor === "string" ? valor : "");
    const cartoes = lista.map((item: Record<string, unknown>): Cartao => ({
      id: texto(item.id), nome: texto(item.nome), servico: texto(item.servico), preco: texto(item.preco), regioes: texto(item.regioes),
      distancia: texto(item.distancia), reputacao: texto(item.reputacao), disponivel: item.disponivel === true, chave: texto(item.chave),
      ...(ehUuid(texto(item.vagaId)) ? { vagaId: texto(item.vagaId) } : {}),
      ...(item.situacao && typeof item.situacao === "object" && (item.situacao as Situacao).tipo === "enviada" ? { situacao: { tipo: "enviada" as const } } : {}),
    }));
    return cartoes.every((c) => ehUuid(c.id) && ehUuid(c.chave)) ? cartoes : null;
  } catch {
    return null;
  }
}

const INCLUSOS_VAZIOS = { inclui_refeicao: false, inclui_transporte: false, exige_material_proprio: false };
const TERMOS_VAZIOS: TermosDigitados = { dia: "", inicio: "", fim: "", valor: "", responsavel_local: "", recado: "", total: false, ...INCLUSOS_VAZIOS };

function resumoDosTermos(termos: TermosDaVagaAberta): string {
  const inclusos =
    termos.inclui_refeicao && termos.inclui_transporte
      ? tc.refeicaoETransporte
      : termos.inclui_refeicao
        ? tc.soRefeicao
        : termos.inclui_transporte
          ? tc.soTransporte
          : tc.semInclusos;
  const partes = [termos.funcao, formatarPeriodo(termos.inicioEm, termos.fimEm), formatarValor(termos.valorCentavos), inclusos];
  if (termos.exige_material_proprio) partes.push(tc.levaMaterial);
  return partes.join(" · ");
}

type Lista = {
  estado: "ok";
  filtros: FiltrosDaBusca;
  cartoes: Cartao[];
  proximoCursor: string | null;
  termos: TermosDigitados;
  errosDosTermos: Partial<Record<CampoDosTermos, true>>;
  aviso?: string;
};
type Retorno = Lista | { estado: "erro"; filtros: FiltrosDaBusca; campo?: CampoDaBusca; falha?: Exclude<FalhaDaBusca, "sem_sessao"> };

export async function action({ request, context }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const formulario = await request.formData();
  const filtros = filtrosDoFormulario(formulario);
  const casaId = String(formulario.get("casa") ?? "");
  const intencao = String(formulario.get("intencao") ?? "buscar");
  if (!ehUuid(casaId)) return { estado: "erro", filtros, falha: "sem_permissao" };

  if (intencao === "buscar") {
    const cursor = String(formulario.get("cursor") ?? "") || undefined;
    const lido = lerFiltros(filtros);
    if (!lido.ok) return { estado: "erro", filtros, campo: lido.campo };
    const resultado = await buscarProfissionais(api, casaId, lido.corpo, cursor);
    if (resultado.ok) {
      // O horário da busca já vem nos termos da chamada (a pessoa pode mudar).
      const termos = { ...TERMOS_VAZIOS, dia: filtros.dia, inicio: filtros.inicio, fim: filtros.fim };
      return { estado: "ok", filtros, cartoes: resultado.itens.map(cartaoParaTela), proximoCursor: resultado.proximoCursor, termos, errosDosTermos: {} };
    }
    if (resultado.motivo === "sem_sessao") throw redirect("/entrar");
    if (resultado.motivo === "campo") return { estado: "erro", filtros, campo: resultado.campo };
    return { estado: "erro", filtros, falha: resultado.motivo };
  }

  // Daqui para baixo, a lista já está na tela: chamar, chamar pela vaga aberta, ou o Enter (só confere).
  const cartoes = cartoesDoFormulario(String(formulario.get("cartoes") ?? ""));
  const termos = termosDoFormulario(formulario);
  const proximoCursor = String(formulario.get("proximo_cursor") ?? "") || null;
  if (!cartoes) return { estado: "erro", filtros, falha: "cursor_invalido" };
  const lista = (mudancas: Partial<Lista> = {}): Lista => ({ estado: "ok", filtros, cartoes, proximoCursor, termos, errosDosTermos: {}, ...mudancas });
  // O botão de cada cartão diz o gesto e de quem: `chamar:<id>`, `usar_vaga:<id>:<vaga>` ou `confirmar:<id>` (aviso J7).
  const [gesto = "", profissionalId = "", vagaId = ""] = intencao.split(":");
  const cartao = cartoes.find((c) => c.id === profissionalId);
  if (!["chamar", "usar_vaga", "confirmar"].includes(gesto) || !cartao || cartao.situacao?.tipo === "enviada") return lista();
  if (gesto === "usar_vaga" && ehUuid(vagaId)) cartao.vagaId = vagaId;
  const confirmo = gesto === "confirmar";

  let corpo;
  if (cartao.vagaId) {
    // Pela vaga aberta, os termos são os dela: só o recado vai.
    if (termos.recado.length > RECADO_MAXIMO) return lista({ errosDosTermos: { recado: true } });
    corpo = pedidoPelaVaga(casaId, cartao.id, cartao.vagaId, cartao.chave, termos.recado, confirmo);
  } else {
    const lido = lerTermos(termos);
    if (!lido.ok) return lista({ errosDosTermos: lido.erros });
    if (!ehUuid(filtros.funcao_id)) return lista({ aviso: tc.erros.formularioVelho });
    const cadastro = await lerCadastroDaCasa(api, casaId);
    if (cadastro.estado === "sem_sessao") throw redirect("/entrar");
    if (cadastro.estado !== "ok") return lista({ aviso: cadastro.estado === "sem_permissao" ? tc.erros.sem_permissao : tc.erros.cadastroDaCasa });
    corpo = pedidoDoTrabalho(cadastro.casa, cartao.id, filtros.funcao_id, lido.termos, cartao.chave, confirmo);
  }

  const resultado = await chamarProfissional(api, corpo);
  if (resultado.ok) {
    cartao.situacao = { tipo: "enviada" };
  } else if (resultado.motivo === "sem_sessao") {
    throw redirect("/entrar");
  } else if (resultado.motivo === "trabalho_ja_aberto") {
    // Nunca repete sozinho: mostra os termos da vaga aberta e espera a casa confirmar.
    const termosDaVaga = await lerTermosDaVagaAberta(api, resultado.vagaId);
    cartao.situacao = termosDaVaga ? { tipo: "vaga_aberta", vagaId: resultado.vagaId, termos: resumoDosTermos(termosDaVaga) } : { tipo: "vaga_aberta_sem_termos" };
  } else if (resultado.motivo === "recorrencia") {
    cartao.situacao = { tipo: "recorrencia" };
  } else {
    cartao.situacao = { tipo: "falha", motivo: resultado.motivo };
  }
  return lista();
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoSecundario = "min-h-11 rounded-controle border border-borda px-4 font-semibold disabled:opacity-60";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

const SEM_FILTROS: FiltrosDaBusca = { funcao_id: "", regiao_id: "", dia: "", inicio: "", fim: "" };

function Aviso({ id, texto }: { id: string; texto?: string }) {
  return texto ? (
    <p id={id} role="alert" className="font-semibold">
      {texto}
    </p>
  ) : null;
}

/** Os filtros da busca, escondidos, para a página seguinte e para a chamada (a função do trabalho). */
function FiltrosEscondidos({ filtros }: { filtros: FiltrosDaBusca }) {
  return (Object.keys(filtros) as Array<keyof FiltrosDaBusca>).map((nome) => <input key={nome} type="hidden" name={nome} value={filtros[nome]} />);
}

/** O botão em andamento é deste cartão? (o valor do botão termina no gesto e no id dele). */
const enviandoPara = (navegacao: { formData?: FormData }, id: string) => String(navegacao.formData?.get("intencao") ?? "").split(":")[1] === id;

function SituacaoDoCartao({ cartao, enviando }: { cartao: Cartao; enviando: boolean }) {
  const s = cartao.situacao;
  if (!s) return null;
  if (s.tipo === "enviada") return <p role="status" className="font-semibold">{tc.enviada}</p>;
  if (s.tipo === "falha") return <p role="alert" className="font-semibold">{tc.erros[s.motivo]}</p>;
  if (s.tipo === "vaga_aberta_sem_termos") return <p role="alert" className="font-semibold">{tc.vagaAbertaSemTermos}</p>;
  if (s.tipo === "vaga_aberta") {
    return (
      <div role="alert" className="flex flex-col gap-2">
        <p className="font-semibold">{preencher(tc.vagaAberta, { termos: s.termos })}</p>
        <button type="submit" name="intencao" value={`usar_vaga:${cartao.id}:${s.vagaId}`} formNoValidate disabled={enviando} className={classeDoSecundario}>
          {preencher(tc.usarVaga, { nome: cartao.nome })}
        </button>
      </div>
    );
  }
  return (
    <div role="alert" className="flex flex-col gap-2">
      <p className="font-semibold">{tc.j7Titulo}</p>
      <p>{tc.j7Mensagem}</p>
      <button type="submit" name="intencao" value={`confirmar:${cartao.id}`} formNoValidate disabled={enviando} className={classeDoSecundario}>
        {tc.j7Confirmar}
      </button>
    </div>
  );
}

function TermosDaChamada({ termos, erros }: { termos: TermosDigitados; erros: Partial<Record<CampoDosTermos, true>> }) {
  const sobre = (campo: CampoDosTermos, ajuda?: string) => ({
    "aria-invalid": erros[campo] ? true : undefined,
    "aria-describedby": [erros[campo] ? `erro-${campo}` : null, ajuda].filter(Boolean).join(" ") || undefined,
  });
  const erro = (campo: CampoDosTermos) => (erros[campo] ? tc.erros[campo] : undefined);
  return (
    <fieldset className="flex flex-col gap-4 rounded-cartao border border-borda p-4">
      <legend className="px-1 font-titulo text-xl font-bold">{tc.titulo}</legend>
      <p>{tc.explicacao}</p>
      <label className={classeDoRotulo}>
        {t.dia}
        <input name="dia" type="date" defaultValue={termos.dia} className={classeDoCampo} {...sobre("dia")} />
      </label>
      <div className="grid grid-cols-2 gap-3">
        <label className={classeDoRotulo}>
          {t.inicio}
          <input name="inicio" type="time" defaultValue={termos.inicio} className={classeDoCampo} {...sobre("dia")} />
        </label>
        <label className={classeDoRotulo}>
          {t.termino}
          <input name="fim" type="time" defaultValue={termos.fim} className={classeDoCampo} {...sobre("dia")} />
        </label>
      </div>
      <Aviso id="erro-dia" texto={erro("dia")} />
      <label className={classeDoRotulo}>
        {tc.valor}
        <span id="ajuda-valor-total" className="text-sm font-normal text-tinta-suave">
          {tc.ajudaDoValor}
        </span>
        <input name="valor" type="text" inputMode="decimal" defaultValue={termos.valor} className={classeDoCampo} {...sobre("valor", "ajuda-valor-total")} />
        <Aviso id="erro-valor" texto={erro("valor")} />
      </label>
      <label className="flex min-h-12 items-center gap-3">
        <input type="checkbox" name="total" value="sim" defaultChecked={termos.total} className="size-5 shrink-0" {...sobre("total")} />
        <span>{tc.total}</span>
      </label>
      <Aviso id="erro-total" texto={erro("total")} />
      <label className={classeDoRotulo}>
        {tc.responsavel}
        <input name="responsavel_local" type="text" defaultValue={termos.responsavel_local} className={classeDoCampo} {...sobre("responsavel_local")} />
        <Aviso id="erro-responsavel_local" texto={erro("responsavel_local")} />
      </label>
      <div className="flex flex-col gap-1">
        {(
          [
            ["inclui_refeicao", tc.incluiRefeicao],
            ["inclui_transporte", tc.incluiTransporte],
            ["exige_material_proprio", tc.exigeMaterialProprio],
          ] as const
        ).map(([nome, rotulo]) => (
          <label key={nome} className="flex min-h-12 items-center gap-3">
            <input type="checkbox" name={nome} value="sim" defaultChecked={termos[nome]} className="size-5 shrink-0" />
            <span>{rotulo}</span>
          </label>
        ))}
      </div>
      <label className={classeDoRotulo}>
        {tc.recado}
        <textarea name="recado" rows={3} maxLength={RECADO_MAXIMO} defaultValue={termos.recado} className={`${classeDoCampo} py-3`} {...sobre("recado")} />
        <Aviso id="erro-recado" texto={erro("recado")} />
      </label>
    </fieldset>
  );
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function BuscaDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const ocupado = navegacao.state !== "idle";
  const buscando = enviandoEste(navegacao, "buscar");
  const { casa, grupos, regioes } = loaderData;
  const filtros = actionData?.filtros ?? SEM_FILTROS;
  const campo = actionData?.estado === "erro" ? actionData.campo : undefined;
  const falha = actionData?.estado === "erro" ? actionData.falha : undefined;
  const erroDoCampo = (nome: CampoDaBusca) => (campo === nome ? t.erros[nome] : undefined);
  const invalido = (nome: CampoDaBusca) => (campo === nome ? { "aria-invalid": true, "aria-describedby": `erro-${nome}` } : {});
  const lista = actionData?.estado === "ok" ? actionData : null;

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
        <input type="hidden" name="intencao" value="buscar" />
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

        <button type="submit" disabled={ocupado} className={classeDoBotao}>
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

      {lista ? (
        <section className="flex flex-col gap-3" aria-labelledby="titulo-profissionais">
          <h2 id="titulo-profissionais" className="font-titulo text-xl font-bold">
            {t.profissionais}
          </h2>
          {lista.cartoes.length === 0 ? (
            <>
              <p role="status">{t.nenhumEncontrado}</p>
              <Link to={`/painel/publicar?casa=${casa.id}`} className={classeDoLink}>
                {t.publicarParaTodos}
              </Link>
            </>
          ) : (
            // Um formulário com os termos e um botão por profissional. A lista volta no campo `cartoes`.
            <Form method="post" className="flex flex-col gap-4" noValidate>
              <input type="hidden" name="casa" value={casa.id} />
              <FiltrosEscondidos filtros={lista.filtros} />
              <input type="hidden" name="cartoes" value={JSON.stringify(lista.cartoes)} />
              <input type="hidden" name="proximo_cursor" value={lista.proximoCursor ?? ""} />
              {/* O Enter num campo envia pelo primeiro botão: este só confere, e não chama ninguém. */}
              <button type="submit" name="intencao" value="conferir" tabIndex={-1} aria-hidden="true" className="sr-only">
                {t.buscar}
              </button>
              {lista.aviso ? <p role="alert" className="font-semibold">{lista.aviso}</p> : null}
              <TermosDaChamada termos={lista.termos} erros={lista.errosDosTermos} />
              <ul className="flex flex-col gap-3">
                {lista.cartoes.map((cartao) => {
                  const enviandoEle = enviandoPara(navegacao, cartao.id);
                  // Com um aviso pedindo outra ação (termos da vaga aberta, J7), o "Chamar" sai: fica só a ação do aviso.
                  const podeChamar = !cartao.situacao || cartao.situacao.tipo === "falha" || cartao.situacao.tipo === "vaga_aberta_sem_termos";
                  return (
                    <li key={cartao.id} className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4">
                      <p className="text-lg font-semibold">{cartao.nome}</p>
                      <p>
                        {cartao.servico} · {cartao.preco}
                      </p>
                      {cartao.disponivel ? <p className="font-semibold">{t.disponivelNesseHorario}</p> : null}
                      <p className="text-tinta-suave">{cartao.distancia}</p>
                      <p className="text-tinta-suave">{cartao.regioes}</p>
                      <p className="text-tinta-suave">{cartao.reputacao}</p>
                      {podeChamar ? (
                        <button type="submit" name="intencao" value={`chamar:${cartao.id}`} disabled={ocupado} className={`${classeDoBotao} mt-2`}>
                          {enviandoEle ? tc.enviando : preencher(tc.chamar, { nome: cartao.nome })}
                        </button>
                      ) : null}
                      <SituacaoDoCartao cartao={cartao} enviando={ocupado} />
                    </li>
                  );
                })}
              </ul>
            </Form>
          )}
          {lista.proximoCursor ? (
            // A página seguinte vai com os mesmos filtros e o cursor; ela não conta como busca nova.
            <Form method="post">
              <input type="hidden" name="casa" value={casa.id} />
              <input type="hidden" name="intencao" value="buscar" />
              <FiltrosEscondidos filtros={lista.filtros} />
              <input type="hidden" name="cursor" value={lista.proximoCursor} />
              <button type="submit" disabled={ocupado} className={classeDoSecundario}>
                {t.proximaPagina}
              </button>
            </Form>
          ) : null}
        </section>
      ) : null}
    </main>
  );
}
