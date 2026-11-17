import { Form, Link, redirect, useNavigation } from "react-router";

import { escolherCasa, lerCadastroDaCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { lerFuncoes, porCategoria } from "../../servidor/contratante/catalogo";
import {
  type CampoDoEvento,
  type ErrosDaEscala,
  ITEM_VAZIO,
  lerFormularioDaEscala,
  MAXIMO_DE_POSICOES_POR_VAGA,
  MAXIMO_DE_VAGAS,
  montarNovaEscala,
  nomeDoCampo,
  publicarEscala,
  type ValoresDaEscala,
  valoresDaEscala,
} from "../../servidor/contratante/escala";
import { type CampoDaVaga, ehUuid, type ProblemaDoCampo, type ValoresDaVaga } from "../../servidor/contratante/publicar-vaga";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/publicar-escala";
import { enviandoEste, preencher } from "./comum";

const t = textos.contratanteEscala;
const tv = textos.contratante.publicar;

type ErrosDoItem = Partial<Record<CampoDaVaga, string>>;
type Erros = { geral?: string; evento: Partial<Record<CampoDoEvento, string>>; itens: ErrosDoItem[] };
type Retorno =
  | { publicada: number; casaId: string }
  | { publicada?: undefined; erros: Erros; valores: ValoresDaEscala; chave: string; versao: string };

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

  const [cadastro, funcoes] = await Promise.all([lerCadastroDaCasa(api, casa.id), lerFuncoes(api)]);
  if (cadastro.estado === "sem_sessao") throw redirect("/entrar");
  if (cadastro.estado !== "ok") throw redirect(`/painel?casa=${casa.id}`);

  return {
    casa: { id: casa.id, nome: casa.nome, endereco: cadastro.casa.endereco, regiao: cadastro.casa.regiao_administrativa },
    grupos: funcoes.estado === "ok" ? porCategoria(funcoes.funcoes) : [],
    funcoesIndisponiveis: funcoes.estado !== "ok",
    // Uma chave para a escala inteira: reenviar devolve a mesma escala, sem publicar de novo.
    chave: crypto.randomUUID(),
  };
}

/** Texto de cada campo recusado. Na escala, o limite de pessoas por vaga é 100, e não 200. */
function textoDoItem(campo: CampoDaVaga, problema: ProblemaDoCampo): string {
  if (campo === "posicoes") return t.erros.posicoes;
  return campo === "dia" && problema === "obrigatorio" ? tv.erros.dia : tv.erros[campo];
}

function errosDaTela(lidos: ErrosDaEscala): Erros {
  return {
    geral: t.erros.temErro,
    evento: Object.fromEntries(Object.keys(lidos.evento).map((campo) => [campo, t.erros[campo as CampoDoEvento]])),
    itens: lidos.itens.map((item) =>
      Object.fromEntries((Object.entries(item) as Array<[CampoDaVaga, ProblemaDoCampo]>).map(([campo, problema]) => [campo, textoDoItem(campo, problema)])),
    ),
  };
}

export async function action({ request, context }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const formulario = await request.formData();
  const valores = valoresDaEscala(formulario);
  const casaId = String(formulario.get("casa") ?? "");
  const chave = String(formulario.get("chave") ?? "");
  const intencao = String(formulario.get("intencao") ?? "publicar");
  const semErro = (): Erros => ({ evento: {}, itens: valores.itens.map(() => ({})) });
  // `versao` nova a cada resposta: a tela remonta os campos com os valores devolvidos (depois de remover uma vaga).
  const volta = (erros: Erros, v: ValoresDaEscala = valores): Retorno => ({ erros, valores: v, chave, versao: crypto.randomUUID() });

  if (intencao === "adicionar") {
    if (valores.itens.length >= MAXIMO_DE_VAGAS) return volta(semErro());
    const itens = [...valores.itens, { ...ITEM_VAZIO, dia: valores.data }];
    return volta({ evento: {}, itens: itens.map(() => ({})) }, { ...valores, itens });
  }
  if (intencao.startsWith("remover:")) {
    const indice = Number(intencao.slice("remover:".length));
    if (valores.itens.length <= 1 || !Number.isInteger(indice)) return volta(semErro());
    const itens = valores.itens.filter((_, i) => i !== indice);
    return volta({ evento: {}, itens: itens.map(() => ({})) }, { ...valores, itens });
  }

  if (!ehUuid(casaId) || !ehUuid(chave)) return volta({ ...semErro(), geral: tv.erros.formularioVelho });
  const lido = lerFormularioDaEscala(valores);
  if (!lido.ok) return volta(errosDaTela(lido.erros));

  const cadastro = await lerCadastroDaCasa(api, casaId);
  if (cadastro.estado === "sem_sessao") throw redirect("/entrar");
  if (cadastro.estado === "sem_permissao") return volta({ ...semErro(), geral: tv.erros.semPermissao });
  if (cadastro.estado !== "ok") return volta({ ...semErro(), geral: tv.erros.indisponivel });

  const resultado = await publicarEscala(api, montarNovaEscala(lido, cadastro.casa, chave));
  if (resultado.ok) return { publicada: resultado.vagas, casaId };
  const erros = semErro();
  switch (resultado.motivo) {
    case "sem_sessao":
      throw redirect("/entrar");
    case "evento":
      erros.evento[resultado.campo] = t.erros[resultado.campo];
      return volta({ ...erros, geral: t.erros.temErro });
    case "item":
      erros.itens[resultado.indice] = { [resultado.campo]: textoDoItem(resultado.campo, resultado.tipo) };
      return volta({ ...erros, geral: t.erros.temErro });
    case "horario_invalido":
      erros.itens[resultado.indice] = { dia: tv.erros.horarioInvalido };
      return volta({ ...erros, geral: t.erros.temErro });
    case "selecao_sem_antecedencia":
      erros.itens[resultado.indice] = { modo: tv.erros.selecaoSemAntecedencia };
      return volta({ ...erros, geral: t.erros.temErro });
    case "quantidade":
      return volta({ ...erros, geral: t.erros.quantidade });
    case "soma_de_posicoes":
      return volta({ ...erros, geral: t.erros.somaDePosicoes });
    case "cadastro_da_casa":
      return volta({ ...erros, geral: tv.erros.cadastroDaCasa });
    case "perfil_incompativel":
      return volta({ ...erros, geral: tv.erros.perfilIncompativel });
    case "sem_permissao":
      return volta({ ...erros, geral: tv.erros.semPermissao });
    case "conta_suspensa":
      return volta({ ...erros, geral: tv.erros.contaSuspensa });
    default:
      return volta({ ...erros, geral: tv.erros.indisponivel });
  }
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoSecundario = "min-h-11 self-start font-semibold underline underline-offset-4";

function Aviso({ id, texto }: { id: string; texto?: string }) {
  return texto ? (
    <p id={id} role="alert" className="font-semibold">
      {texto}
    </p>
  ) : null;
}

/** Atributos de acessibilidade do campo com erro. */
const sobre = (id: string, erro?: string, ajuda?: string) => ({
  "aria-invalid": erro ? true : undefined,
  "aria-describedby": [erro ? `erro-${id}` : null, ajuda].filter(Boolean).join(" ") || undefined,
});

type Grupos = Route.ComponentProps["loaderData"]["grupos"];

function ItemDaEscala(props: { i: number; total: number; valores: ValoresDaVaga; erros: ErrosDoItem; grupos: Grupos; podeRemover: boolean }) {
  const { i, total, valores, erros, grupos } = props;
  const nome = (campo: string) => nomeDoCampo(i, campo);
  const id = (campo: string) => `v${i}-${campo}`;
  return (
    <fieldset className="flex flex-col gap-4 rounded-cartao border border-borda p-4">
      <legend className="px-1 font-titulo text-xl font-bold">{preencher(t.vaga, { n: i + 1, total })}</legend>

      <label className={classeDoRotulo} htmlFor={id("funcao_id")}>
        {tv.funcao}
        <select id={id("funcao_id")} name={nome("funcao_id")} required defaultValue={valores.funcao_id} className={classeDoCampo} {...sobre(id("funcao_id"), erros.funcao_id)}>
          <option value="">{tv.escolhaAFuncao}</option>
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
        <Aviso id={`erro-${id("funcao_id")}`} texto={erros.funcao_id} />
      </label>

      <div className="flex flex-col gap-3">
        <label className={classeDoRotulo}>
          {tv.dia}
          <input name={nome("dia")} type="date" required defaultValue={valores.dia} className={classeDoCampo} {...sobre(id("dia"), erros.dia, "ajuda-horario")} />
        </label>
        <Aviso id={`erro-${id("dia")}`} texto={erros.dia} />
        <div className="grid grid-cols-2 gap-3">
          <label className={classeDoRotulo}>
            {tv.inicio}
            <input name={nome("inicio")} type="time" required defaultValue={valores.inicio} className={classeDoCampo} {...sobre(id("inicio"), erros.inicio)} />
          </label>
          <label className={classeDoRotulo}>
            {tv.fim}
            <input name={nome("fim")} type="time" required defaultValue={valores.fim} className={classeDoCampo} {...sobre(id("fim"), erros.fim)} />
          </label>
        </div>
        <Aviso id={`erro-${id("inicio")}`} texto={erros.inicio} />
        <Aviso id={`erro-${id("fim")}`} texto={erros.fim} />
      </div>

      <label className={classeDoRotulo}>
        {tv.valor}
        <input name={nome("valor")} type="text" inputMode="decimal" required defaultValue={valores.valor} className={classeDoCampo} {...sobre(id("valor"), erros.valor, "ajuda-valor")} />
        <Aviso id={`erro-${id("valor")}`} texto={erros.valor} />
      </label>

      <label className={classeDoRotulo}>
        {tv.posicoes}
        <input
          name={nome("posicoes")}
          type="number"
          min={1}
          max={MAXIMO_DE_POSICOES_POR_VAGA}
          required
          defaultValue={valores.posicoes}
          className={classeDoCampo}
          {...sobre(id("posicoes"), erros.posicoes, "ajuda-posicoes")}
        />
        <Aviso id={`erro-${id("posicoes")}`} texto={erros.posicoes} />
      </label>

      <fieldset className="flex flex-col gap-2">
        <legend className="font-semibold">{tv.modo}</legend>
        {(["urgencia", "selecao"] as const).map((modo) => (
          <label key={modo} className="flex min-h-12 items-center gap-3 rounded-controle border border-borda bg-superficie px-4">
            <input type="radio" name={nome("modo")} value={modo} defaultChecked={valores.modo === modo} className="size-5 shrink-0" />
            <span>{tv.modos[modo]}</span>
          </label>
        ))}
        <Aviso id={`erro-${id("modo")}`} texto={erros.modo} />
      </fieldset>

      <label className={classeDoRotulo}>
        {tv.responsavelLocal}
        <input name={nome("responsavel_local")} type="text" required defaultValue={valores.responsavel_local} className={classeDoCampo} {...sobre(id("responsavel_local"), erros.responsavel_local)} />
        <Aviso id={`erro-${id("responsavel_local")}`} texto={erros.responsavel_local} />
      </label>

      <div className="flex flex-col gap-1">
        {(
          [
            ["inclui_refeicao", tv.incluiRefeicao],
            ["inclui_transporte", tv.incluiTransporte],
            ["exige_material_proprio", tv.exigeMaterialProprio],
          ] as const
        ).map(([campo, rotulo]) => (
          <label key={campo} className="flex min-h-12 items-center gap-3">
            <input type="checkbox" name={nome(campo)} value="sim" defaultChecked={valores[campo]} className="size-5 shrink-0" />
            <span>{rotulo}</span>
          </label>
        ))}
      </div>

      <label className={classeDoRotulo}>
        {tv.traje}
        <input name={nome("traje")} type="text" defaultValue={valores.traje} className={classeDoCampo} {...sobre(id("traje"), erros.traje)} />
        <Aviso id={`erro-${id("traje")}`} texto={erros.traje} />
      </label>

      <label className={classeDoRotulo}>
        {tv.observacoes}
        <textarea name={nome("observacoes")} rows={3} defaultValue={valores.observacoes} className={`${classeDoCampo} py-3`} {...sobre(id("observacoes"), erros.observacoes)} />
        <Aviso id={`erro-${id("observacoes")}`} texto={erros.observacoes} />
      </label>

      {props.podeRemover ? (
        <button type="submit" name="intencao" value={`remover:${i}`} formNoValidate className={classeDoSecundario}>
          {t.remover}
        </button>
      ) : null}
    </fieldset>
  );
}

const ESCALA_VAZIA: ValoresDaEscala = { nome: "", data: "", itens: [ITEM_VAZIO] };

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function PublicarEscala({ loaderData, actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const publicando = enviandoEste(navegacao, "publicar");
  const { casa, grupos } = loaderData;

  if (actionData?.publicada !== undefined) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 p-6">
        <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
        <p role="status" className="font-semibold">
          {actionData.publicada === 1 ? t.publicadaUma : preencher(t.publicada, { n: actionData.publicada })}
        </p>
        <Link to={`/painel?casa=${actionData.casaId}`} className={classeDoBotao + " inline-flex items-center justify-center"}>
          {t.irAoPainel}
        </Link>
      </main>
    );
  }

  const valores = actionData?.valores ?? ESCALA_VAZIA;
  const erros: Erros = actionData?.erros ?? { evento: {}, itens: [] };
  const total = valores.itens.length;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 p-6">
      <Link to={`/painel?casa=${casa.id}`} className="min-h-11 font-semibold underline underline-offset-4">
        {t.voltar}
      </Link>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p>{t.subtitulo}</p>
      <p>
        <strong>{casa.nome}</strong>. {t.endereco} {casa.endereco}, {casa.regiao}.
      </p>

      <Form key={actionData?.versao ?? "inicio"} method="post" className="flex flex-col gap-5" noValidate>
        <input type="hidden" name="casa" value={casa.id} />
        <input type="hidden" name="chave" value={actionData?.chave ?? loaderData.chave} />
        <input type="hidden" name="itens" value={total} />
        {/* O Enter num campo envia pelo primeiro botão do formulário: este publica, e não "Remover" nem "Adicionar". */}
        <button type="submit" name="intencao" value="publicar" tabIndex={-1} aria-hidden="true" className="sr-only">
          {t.publicar}
        </button>
        <Aviso id="erro-geral" texto={erros.geral} />

        <label className={classeDoRotulo}>
          {t.nome}
          <span id="ajuda-nome" className="text-sm font-normal text-tinta-suave">
            {t.ajudaDoNome}
          </span>
          <input name="nome" type="text" required minLength={3} maxLength={100} defaultValue={valores.nome} className={classeDoCampo} {...sobre("nome", erros.evento.nome, "ajuda-nome")} />
          <Aviso id="erro-nome" texto={erros.evento.nome} />
        </label>

        <label className={classeDoRotulo}>
          {t.data}
          <input name="data" type="date" required defaultValue={valores.data} className={classeDoCampo} {...sobre("data", erros.evento.data)} />
          <Aviso id="erro-data" texto={erros.evento.data} />
        </label>

        <p id="ajuda-horario" className="text-sm text-tinta-suave">
          {tv.ajudaDoHorario}
        </p>
        <p id="ajuda-valor" className="text-sm text-tinta-suave">
          {tv.ajudaDoValor}
        </p>
        <p id="ajuda-posicoes" className="text-sm text-tinta-suave">
          {t.posicoesNaEscala}
        </p>
        {loaderData.funcoesIndisponiveis ? <p role="status">{tv.funcoesIndisponiveis}</p> : null}

        {valores.itens.map((item, i) => (
          <ItemDaEscala key={i} i={i} total={total} valores={item} erros={erros.itens[i] ?? {}} grupos={grupos} podeRemover={total > 1} />
        ))}

        {total < MAXIMO_DE_VAGAS ? (
          <button type="submit" name="intencao" value="adicionar" formNoValidate className={classeDoSecundario}>
            {t.adicionar}
          </button>
        ) : (
          <p>{preencher(t.limite, { n: MAXIMO_DE_VAGAS })}</p>
        )}

        <button type="submit" name="intencao" value="publicar" disabled={publicando} className={classeDoBotao}>
          {publicando ? t.publicando : t.publicar}
        </button>
      </Form>
    </main>
  );
}
