import { Fragment, useEffect, useRef } from "react";
import { Form, Link, redirect, type ShouldRevalidateFunctionArgs, useNavigation } from "react-router";

import { lerMinhaConta } from "../../servidor/conta";
import { lerRegioes } from "../../servidor/contratante/busca";
import { lerFuncoes, porCategoria } from "../../servidor/contratante/catalogo";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import {
  adicionarHorario,
  criarPerfil,
  definirRegioes,
  definirServicos,
  lerFuncoesMarcadas,
  lerJanelas,
  lerPontoBase,
  lerRegioesAtendidas,
  lerSeTemPerfil,
  lerServicos,
  type Passo,
  PASSOS,
  passoDoFormulario,
  type RegioesAtendidas,
  type Servico,
  textoDaJanela,
  UNIDADES,
  type Valores,
  valoresDoFormulario,
  VAZIO,
} from "../../servidor/profissional/cadastro";
import { centroDaRegiao, type Coordenada } from "../../servidor/profissional/cadastro-centros";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/cadastro";

const t = textos.profissionalCadastro;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const [conta, perfil, funcoes, regioes] = await Promise.all([lerMinhaConta(api), lerSeTemPerfil(api), lerFuncoes(api), lerRegioes(api)]);
  if (perfil === "sem_sessao") throw redirect("/entrar");
  if (conta.estado === "sem_conta") throw redirect("/cadastro");
  const contratante = conta.estado === "ok" && conta.perfil === "contratante";
  return {
    // Quem decide é o servidor, no envio: aqui a tela só adianta o aviso.
    situacao: contratante ? ("perfil_incompativel" as const) : perfil === "tem" ? ("ja_tem_perfil" as const) : ("pode_criar" as const),
    funcoes: funcoes.estado === "ok" ? porCategoria(funcoes.funcoes).map((grupo) => ({ categoria: grupo.categoria, funcoes: grupo.funcoes.map(({ id, nome }) => ({ id, nome })) })) : [],
    // O centro de cada região fica no servidor: ao navegador vai só se ela serve de ponto base.
    regioes: (regioes ?? []).map(({ id, nome }) => ({ id, nome, comCentro: centroDaRegiao(id) !== null })),
  };
}

type Retorno = { passo: Passo; erro: string | null; valores: Valores };
type Lido = { funcoes: string[]; pontoBase: Coordenada | null; atendidas: RegioesAtendidas | null; servicos: Servico[] };
type Conferencia = { ok: true; lido: Lido } | { ok: false; passo: Passo; erro: string };

/** Confere os passos pedidos, na ordem, contra os catálogos. Só lê o catálogo de que os passos precisam. */
async function conferir(api: ReturnType<typeof apiDoUsuario>, passos: readonly Passo[], valores: Valores, passoAtual: Passo): Promise<Conferencia> {
  const tem = (...quais: Passo[]) => quais.some((qual) => passos.includes(qual));
  const [catalogo, regioes] = await Promise.all([tem("funcoes", "servicos") ? lerFuncoes(api) : null, tem("ponto", "regioes") ? lerRegioes(api) : null]);
  if ((tem("funcoes", "servicos") && catalogo?.estado !== "ok") || (tem("ponto", "regioes") && !regioes)) return { ok: false, passo: passoAtual, erro: t.erros.catalogo };
  const funcoesDoCatalogo = catalogo?.estado === "ok" ? catalogo.funcoes : [];
  const idsDasRegioes = (regioes ?? []).map((regiao) => regiao.id);
  const lido: Lido = { funcoes: valores.funcoes, pontoBase: null, atendidas: null, servicos: [] };

  for (const passo of passos) {
    if (passo === "funcoes") {
      const funcoes = lerFuncoesMarcadas(valores, funcoesDoCatalogo.map((funcao) => funcao.id));
      if (!funcoes) return { ok: false, passo, erro: t.erros.semFuncao };
      lido.funcoes = funcoes;
    }
    if (passo === "ponto") {
      lido.pontoBase = lerPontoBase(valores, idsDasRegioes);
      if (!lido.pontoBase) return { ok: false, passo, erro: t.erros.semPontoBase };
    }
    if (passo === "regioes") {
      lido.atendidas = lerRegioesAtendidas(valores, idsDasRegioes);
      if (!lido.atendidas) return { ok: false, passo, erro: t.erros.regioes };
    }
    if (passo === "servicos") {
      const servicos = lerServicos(valores.servicos, lido.funcoes);
      if (!servicos.ok) {
        if (servicos.problema === "muitos") return { ok: false, passo, erro: t.erros.servico.muitos };
        const funcao = funcoesDoCatalogo.find(({ id }) => id === servicos.funcaoId)?.nome ?? "";
        return { ok: false, passo, erro: t.erros.servicoDaFuncao.replace("{funcao}", funcao).replace("{aviso}", t.erros.servico[servicos.problema]) };
      }
      lido.servicos = servicos.servicos;
    }
  }
  return { ok: true, lido };
}

const AVISO_DO_HORARIO = { sem_dia: t.erros.horarioSemDia, invalido: t.erros.horarioInvalido, igual: t.erros.horarioIgual } as const;

export async function action({ context, request }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const formulario = await request.formData();
  const passo = passoDoFormulario(formulario);
  let valores = valoresDoFormulario(formulario);
  const fica = (onde: Passo, erro: string | null): Retorno => ({ passo: onde, erro, valores });
  const posicao = PASSOS.indexOf(passo);
  const ir = formulario.get("ir");

  const remover = formulario.get("remover");
  if (typeof remover === "string") {
    valores = { ...valores, janelas: valores.janelas.filter((janela) => janela !== remover) };
    return fica("horarios", null);
  }
  if (ir === "voltar") return fica(PASSOS[Math.max(posicao - 1, 0)] ?? "funcoes", null);

  // O horário do formulário entra na grade no "Adicionar" e também no "Continuar", se a pessoa marcou algum dia
  // e esqueceu de adicionar (o app faz o mesmo).
  if (passo === "horarios" && (ir === "adicionar_horario" || valores.novo_horario.dias.length > 0)) {
    const novo = adicionarHorario(valores);
    if (!novo.ok) return fica("horarios", AVISO_DO_HORARIO[novo.problema]);
    valores = { ...valores, janelas: novo.janelas, novo_horario: VAZIO.novo_horario };
    if (ir === "adicionar_horario") return fica("horarios", null);
  }

  // Cada passo confere o que é dele; o último confere todos de novo, porque os anteriores vêm de campos escondidos.
  const ultimo = passo === "servicos";
  const conferido = await conferir(api, ultimo ? PASSOS : [passo], valores, passo);
  if (!conferido.ok) return fica(conferido.passo, conferido.erro);
  const { funcoes, pontoBase, atendidas, servicos } = conferido.lido;
  valores = { ...valores, funcoes };
  if (!ultimo || !pontoBase || !atendidas) return fica(PASSOS[posicao + 1] ?? passo, null);

  const criado = await criarPerfil(api, funcoes, pontoBase, lerJanelas(valores.janelas));
  if (!criado.ok) {
    if (criado.motivo === "sem_sessao") throw redirect("/entrar");
    if (criado.motivo === "funcoes") return fica("funcoes", t.erros.funcoes);
    if (criado.motivo === "ponto_base") return fica("ponto", t.erros.pontoBase);
    return fica(passo, t.erros[criado.motivo]);
  }

  // Com as regiões ou os serviços desligados no servidor (chave do perfil rico), não há o que a pessoa refazer:
  // o perfil já vale, e ela segue.
  const gravadas = await definirRegioes(api, atendidas);
  if (!gravadas.ok && gravadas.motivo === "sem_sessao") throw redirect("/entrar");
  if (!gravadas.ok && gravadas.motivo !== "recurso_desligado") return fica(passo, t.erros.regioesNaoSalvas);

  // Sem serviço oferecido, nada é enviado: mandar a lista vazia apagaria os serviços de um perfil que já existia.
  if (servicos.length > 0) {
    const salvos = await definirServicos(api, servicos);
    if (!salvos.ok && salvos.motivo === "sem_sessao") throw redirect("/entrar");
    if (!salvos.ok && salvos.motivo === "campo") return fica(passo, `${t.erros.servicosNaoSalvos} ${t.erros.servico[salvos.campo]}`);
    if (!salvos.ok && salvos.motivo === "indisponivel") return fica(passo, `${t.erros.servicosNaoSalvos} ${t.erros.tenteDeNovo}`);
  }
  throw redirect("/vagas");
}

// Os passos não mudam o que o loader lê (conta, perfil e catálogos): depois de uma resposta da ação, não relê.
export function shouldRevalidate({ actionResult, defaultShouldRevalidate }: ShouldRevalidateFunctionArgs) {
  return actionResult ? false : defaultShouldRevalidate;
}

const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoBotaoSecundario = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg font-bold disabled:opacity-60";
const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";
const classeDaCaixa = "flex min-h-11 items-center gap-3";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoBloco = "flex flex-col gap-3 rounded-cartao border border-borda p-4";

// Nos serviços, cada campo some quando a unidade escolhida no bloco não o usa. É só CSS (`:has`), sem JavaScript:
// em navegador que não conhece `:has`, a regra é descartada, o campo fica à vista e o servidor ignora o que sobra.
const SO_COM_VALOR = "group-has-[option:is([value=nao],[value$=combinar]):checked]:hidden";
const SO_NA_DIARIA = "group-has-[option:is([value=nao],[value=hora],[value=evento],[value=pacote],[value^=por],[value$=combinar]):checked]:hidden";
const SO_POR_PESSOA = "group-has-[option:is([value=nao],[value=hora],[value=diaria],[value=evento],[value=pacote],[value$=combinar]):checked]:hidden";
const SO_NO_PACOTE = "group-has-[option:is([value=nao],[value=hora],[value=diaria],[value=evento],[value^=por],[value$=combinar]):checked]:hidden";

function Escondidos({ nome, valores }: { nome: string; valores: readonly string[] }) {
  return valores.map((valor) => <input key={valor} type="hidden" name={nome} value={valor} />);
}

/** Os serviços já preenchidos, para viajarem nos outros passos. */
function ServicosEscondidos({ servicos }: { servicos: Valores["servicos"] }) {
  return Object.entries(servicos).map(([funcaoId, servico]) => (
    <Fragment key={funcaoId}>
      <input type="hidden" name={`unidade:${funcaoId}`} value={servico.unidade} />
      <input type="hidden" name={`valor:${funcaoId}`} value={servico.valor} />
      <input type="hidden" name={`horas:${funcaoId}`} value={servico.horas} />
      <input type="hidden" name={`pessoas:${funcaoId}`} value={servico.pessoas} />
      <input type="hidden" name={`pacote:${funcaoId}`} value={servico.pacote} />
    </Fragment>
  ));
}

function PassoDosHorarios({ valores, enviando }: { valores: Valores; enviando: boolean }) {
  const h = t.horarios;
  const novo = valores.novo_horario;
  const janelas = lerJanelas(valores.janelas);
  return (
    <div className="flex flex-col gap-4">
      <section className="flex flex-col gap-2">
        <h3 className="font-semibold">{h.marcados}</h3>
        {janelas.length === 0 ? (
          <p>{h.nenhum}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {janelas.map((janela) => {
              const texto = textoDaJanela(janela);
              const horario = h.deAte.replace("{inicio}", janela.hora_inicio).replace("{fim}", janela.hora_fim);
              return (
                <li key={texto} className="flex items-center justify-between gap-3">
                  <input type="hidden" name="janelas" value={texto} />
                  <span>
                    {h.nomesDosDias[janela.dia_semana]}: {horario}
                    {janela.hora_fim < janela.hora_inicio ? ` ${h.diaSeguinte}` : null}
                  </span>
                  <button type="submit" name="remover" value={texto} disabled={enviando} className="min-h-11 shrink-0 px-2 font-semibold underline underline-offset-4">
                    {h.remover}
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <fieldset className={classeDoBloco}>
        <legend className="px-1 font-semibold">{h.novo}</legend>
        <fieldset className="flex flex-col">
          <legend className="font-semibold">{h.dias}</legend>
          {h.nomesDosDias.map((nome, dia) => (
            <label key={nome} className={classeDaCaixa}>
              <input type="checkbox" name="dias" value={dia} defaultChecked={novo.dias.includes(String(dia))} className="size-5 shrink-0" />
              {nome}
            </label>
          ))}
        </fieldset>
        <label className={classeDoRotulo}>
          {h.inicio}
          <input type="time" name="inicio" defaultValue={novo.inicio || "18:00"} className={classeDoCampo} />
        </label>
        <label className={classeDoRotulo}>
          {h.fim}
          <input type="time" name="fim" defaultValue={novo.fim || "00:00"} aria-describedby="ajuda-do-fim" className={classeDoCampo} />
          <span id="ajuda-do-fim" className="text-sm font-normal text-tinta-suave">
            {h.ajudaDoFim}
          </span>
        </label>
        <button type="submit" name="ir" value="adicionar_horario" disabled={enviando} className={classeDoBotaoSecundario}>
          {h.adicionar}
        </button>
      </fieldset>
    </div>
  );
}

function PassoDosServicos({ funcoes, servicos }: { funcoes: Array<{ id: string; nome: string }>; servicos: Valores["servicos"] }) {
  const s = t.servicos;
  return (
    <div className="flex flex-col gap-4">
      {funcoes.map(({ id, nome }) => {
        const servico = servicos[id];
        return (
          <fieldset key={id} className={`group ${classeDoBloco}`}>
            <legend className="px-1 font-semibold">{nome}</legend>
            <label className={classeDoRotulo}>
              {s.unidade}
              <select name={`unidade:${id}`} defaultValue={servico?.unidade ?? "nao"} className={classeDoCampo}>
                <option value="nao">{s.naoOferecer}</option>
                {UNIDADES.map((unidade) => (
                  <option key={unidade} value={unidade}>
                    {s.unidades[unidade]}
                  </option>
                ))}
              </select>
            </label>
            <label className={`${classeDoRotulo} ${SO_COM_VALOR}`}>
              {s.valor}
              <input type="text" inputMode="decimal" autoComplete="off" name={`valor:${id}`} defaultValue={servico?.valor ?? ""} aria-describedby={`faixa-${id}`} className={classeDoCampo} />
              <span id={`faixa-${id}`} className="text-sm font-normal text-tinta-suave">
                {s.faixa}
              </span>
            </label>
            <label className={`${classeDoRotulo} ${SO_NA_DIARIA}`}>
              {s.horas}
              <input type="number" inputMode="numeric" min={4} max={12} name={`horas:${id}`} defaultValue={servico?.horas || "8"} className={classeDoCampo} />
            </label>
            <label className={`${classeDoRotulo} ${SO_POR_PESSOA}`}>
              {s.pessoas}
              <input type="number" inputMode="numeric" min={1} max={2000} name={`pessoas:${id}`} defaultValue={servico?.pessoas || "1"} className={classeDoCampo} />
            </label>
            <label className={`${classeDoRotulo} ${SO_NO_PACOTE}`}>
              {s.pacote}
              <input type="text" maxLength={120} name={`pacote:${id}`} defaultValue={servico?.pacote ?? ""} className={classeDoCampo} />
            </label>
          </fieldset>
        );
      })}
      <p className="text-sm text-tinta-suave">{s.chamadasDiretas}</p>
    </div>
  );
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function CadastroDoProfissional({ loaderData, actionData }: Route.ComponentProps) {
  const enviando = useNavigation().state !== "idle";
  const passo = actionData?.passo ?? "funcoes";
  const valores = actionData?.valores ?? VAZIO;
  const erro = actionData?.erro ?? null;
  const tituloDoPasso = useRef<HTMLHeadingElement>(null);

  // A cada resposta (passo novo ou aviso), o foco vai ao título do passo: quem usa teclado ou leitor de tela
  // recomeça do começo do passo, e a página rola até ele.
  useEffect(() => {
    if (actionData) tituloDoPasso.current?.focus();
  }, [actionData]);

  // Depois de um envio, a tela é a do passo (o perfil pode ter sido criado e faltar só salvar regiões ou serviços).
  if (!actionData && loaderData.situacao !== "pode_criar") {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 p-6">
        <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
        <p role="status">{t.avisos[loaderData.situacao]}</p>
        {loaderData.situacao === "ja_tem_perfil" ? (
          <Link to="/perfil" className={classeDoLink}>
            {t.avisos.verPerfil}
          </Link>
        ) : null}
        <Link to="/" className={classeDoLink}>
          {t.voltarAoInicio}
        </Link>
      </main>
    );
  }

  const semCatalogo = loaderData.funcoes.length === 0 || loaderData.regioes.length === 0;
  const funcoesMarcadas = loaderData.funcoes.flatMap((grupo) => grupo.funcoes).filter((funcao) => valores.funcoes.includes(funcao.id));
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 p-6">
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {semCatalogo ? <p role="alert">{t.erros.catalogo}</p> : null}

      <Form method="post" className="flex flex-col gap-5" noValidate>
        {/* A tecla Enter aciona o primeiro botão de envio do formulário. Nos horários ele seria um "Remover":
            este, fora da vista e do teclado, faz o Enter adicionar o horário. */}
        {passo === "horarios" ? <button type="submit" name="ir" value="adicionar_horario" tabIndex={-1} aria-hidden="true" className="sr-only" /> : null}
        <input type="hidden" name="passo" value={passo} />
        {passo === "funcoes" ? null : <Escondidos nome="funcoes" valores={valores.funcoes} />}
        {passo === "ponto" ? null : <input type="hidden" name="ponto_regiao" value={valores.ponto_regiao} />}
        {passo === "horarios" ? null : <Escondidos nome="janelas" valores={valores.janelas} />}
        {passo === "regioes" ? null : (
          <>
            {valores.atende_todo_df ? <input type="hidden" name="atende_todo_df" value="sim" /> : null}
            <Escondidos nome="regioes" valores={valores.regioes} />
          </>
        )}
        {passo === "servicos" ? null : <ServicosEscondidos servicos={valores.servicos} />}

        <div>
          <p className="text-tinta-suave">{t.passoDe.replace("{atual}", String(PASSOS.indexOf(passo) + 1)).replace("{total}", String(PASSOS.length))}</p>
          <h2 ref={tituloDoPasso} tabIndex={-1} className="font-titulo text-2xl font-bold">
            {t[passo].titulo}
          </h2>
        </div>
        {erro ? (
          <p role="alert" className="font-semibold">
            {erro}
          </p>
        ) : null}
        <p id="ajuda-do-passo">{t[passo].ajuda}</p>

        {passo === "funcoes" ? (
          // A chave refaz os campos a cada passo: o que está marcado vem sempre do que o servidor devolveu.
          <div key="funcoes" className="flex flex-col gap-4">
            {loaderData.funcoes.map((grupo) => (
              <fieldset key={grupo.categoria} className="flex flex-col">
                <legend className="font-semibold">{grupo.categoria}</legend>
                {grupo.funcoes.map((funcao) => (
                  <label key={funcao.id} className={classeDaCaixa}>
                    <input type="checkbox" name="funcoes" value={funcao.id} defaultChecked={valores.funcoes.includes(funcao.id)} className="size-5 shrink-0" />
                    {funcao.nome}
                  </label>
                ))}
              </fieldset>
            ))}
          </div>
        ) : null}

        {passo === "ponto" ? (
          <label key="ponto" className={classeDoRotulo}>
            {t.ponto.regiao}
            <select name="ponto_regiao" required defaultValue={valores.ponto_regiao} aria-describedby="ajuda-do-passo" aria-invalid={erro ? true : undefined} className={classeDoCampo}>
              <option value="">{t.ponto.escolha}</option>
              {loaderData.regioes
                .filter((regiao) => regiao.comCentro)
                .map((regiao) => (
                  <option key={regiao.id} value={regiao.id}>
                    {regiao.nome}
                  </option>
                ))}
            </select>
          </label>
        ) : null}

        {/* A chave muda com a grade: depois de adicionar ou remover, o formulário do horário novo recomeça. */}
        {passo === "horarios" ? <PassoDosHorarios key={`horarios-${valores.janelas.join()}-${erro ?? ""}`} valores={valores} enviando={enviando} /> : null}

        {passo === "regioes" ? (
          <div key="regioes" className="flex flex-col gap-4">
            <label className={`${classeDaCaixa} font-semibold`}>
              <input type="checkbox" name="atende_todo_df" value="sim" defaultChecked={valores.atende_todo_df} className="size-5 shrink-0" />
              {t.regioes.todoDF}
            </label>
            <fieldset className="flex flex-col">
              <legend className="font-semibold">{t.regioes.lista}</legend>
              {loaderData.regioes.map((regiao) => (
                <label key={regiao.id} className={classeDaCaixa}>
                  <input type="checkbox" name="regioes" value={regiao.id} defaultChecked={valores.regioes.includes(String(regiao.id))} className="size-5 shrink-0" />
                  {regiao.nome}
                </label>
              ))}
            </fieldset>
          </div>
        ) : null}

        {passo === "servicos" ? <PassoDosServicos key="servicos" funcoes={funcoesMarcadas} servicos={valores.servicos} /> : null}

        {/* O botão de seguir vem antes do de voltar: fora dos horários, é ele que a tecla Enter aciona. */}
        <button type="submit" name="ir" value="avancar" disabled={enviando} className={classeDoBotao}>
          {enviando ? t.enviando : passo === "servicos" ? t.criar : t.continuar}
        </button>
        {passo === "funcoes" ? null : (
          <button type="submit" name="ir" value="voltar" disabled={enviando} className={classeDoBotaoSecundario}>
            {t.voltar}
          </button>
        )}
      </Form>
      <Link to="/" className={classeDoLink}>
        {t.voltarAoInicio}
      </Link>
    </main>
  );
}
