import { useEffect, useRef } from "react";
import { Form, Link, redirect, useNavigation } from "react-router";

import { lerMinhaConta } from "../../servidor/conta";
import { lerRegioes } from "../../servidor/contratante/busca";
import { lerFuncoes, porCategoria } from "../../servidor/contratante/catalogo";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import {
  criarPerfil,
  definirRegioes,
  lerFuncoesMarcadas,
  lerPontoBase,
  lerRegioesAtendidas,
  lerSeTemPerfil,
  type Passo,
  PASSOS,
  passoDoFormulario,
  type Valores,
  valoresDoFormulario,
  VAZIO,
} from "../../servidor/profissional/cadastro";
import { centroDaRegiao } from "../../servidor/profissional/cadastro-centros";
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

export async function action({ context, request }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao.acesso);
  const formulario = await request.formData();
  const passo = passoDoFormulario(formulario);
  const valores = valoresDoFormulario(formulario);
  const fica = (onde: Passo, erro: string | null, com: Valores = valores): Retorno => ({ passo: onde, erro, valores: com });
  const posicao = PASSOS.indexOf(passo);

  if (formulario.get("ir") === "voltar") return fica(PASSOS[Math.max(posicao - 1, 0)] ?? "funcoes", null);

  // Cada passo confere o que é dele; o último confere os três de novo, porque os anteriores vêm de campos escondidos.
  const ultimo = passo === "regioes";
  let funcoes: string[] | null = null;
  if (passo === "funcoes" || ultimo) {
    const catalogo = await lerFuncoes(api);
    if (catalogo.estado !== "ok") return fica(passo, t.erros.catalogo);
    funcoes = lerFuncoesMarcadas(valores, catalogo.funcoes.map((funcao) => funcao.id));
    if (!funcoes) return fica("funcoes", t.erros.semFuncao);
    if (!ultimo) return fica("ponto", null, { ...valores, funcoes });
  }

  const regioesDoCatalogo = await lerRegioes(api);
  if (!regioesDoCatalogo) return fica(passo, t.erros.catalogo);
  const ids = regioesDoCatalogo.map((regiao) => regiao.id);
  const pontoBase = lerPontoBase(valores, ids);
  if (!pontoBase) return fica("ponto", t.erros.semPontoBase);
  if (!ultimo || !funcoes) return fica("regioes", null);
  const atendidas = lerRegioesAtendidas(valores, ids);
  if (!atendidas) return fica("regioes", t.erros.regioes);

  const criado = await criarPerfil(api, funcoes, pontoBase);
  if (!criado.ok) {
    if (criado.motivo === "sem_sessao") throw redirect("/entrar");
    if (criado.motivo === "funcoes") return fica("funcoes", t.erros.funcoes);
    if (criado.motivo === "ponto_base") return fica("ponto", t.erros.pontoBase);
    return fica("regioes", t.erros[criado.motivo]);
  }

  const gravadas = await definirRegioes(api, atendidas);
  if (!gravadas.ok && gravadas.motivo === "sem_sessao") throw redirect("/entrar");
  // Com as regiões desligadas no servidor (chave do perfil rico), não há o que a pessoa refazer: o perfil já vale.
  if (gravadas.ok || gravadas.motivo === "recurso_desligado") throw redirect("/vagas");
  return fica("regioes", t.erros.regioesNaoSalvas);
}

const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoBotaoDeVoltar = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg font-bold disabled:opacity-60";
const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDaCaixa = "flex min-h-11 items-center gap-3";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

function Escondidos({ nome, valores }: { nome: string; valores: readonly string[] }) {
  return valores.map((valor) => <input key={valor} type="hidden" name={nome} value={valor} />);
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

  // Depois de um envio, a tela é a do passo (o perfil pode ter sido criado e faltar só salvar as regiões).
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
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 p-6">
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {semCatalogo ? <p role="alert">{t.erros.catalogo}</p> : null}

      <Form method="post" className="flex flex-col gap-5" noValidate>
        <input type="hidden" name="passo" value={passo} />
        {passo === "funcoes" ? null : <Escondidos nome="funcoes" valores={valores.funcoes} />}
        {passo === "ponto" ? null : <input type="hidden" name="ponto_regiao" value={valores.ponto_regiao} />}
        {passo === "regioes" ? null : (
          <>
            {valores.atende_todo_df ? <input type="hidden" name="atende_todo_df" value="sim" /> : null}
            <Escondidos nome="regioes" valores={valores.regioes} />
          </>
        )}

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
          <label key="ponto" className="flex flex-col gap-2 font-semibold">
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
            <p className="text-sm text-tinta-suave">{t.regioes.horarios}</p>
          </div>
        ) : null}

        {/* O botão de seguir vem primeiro: é ele que a tecla Enter aciona. */}
        <button type="submit" name="ir" value="avancar" disabled={enviando} className={classeDoBotao}>
          {enviando ? t.enviando : passo === "regioes" ? t.criar : t.continuar}
        </button>
        {passo === "funcoes" ? null : (
          <button type="submit" name="ir" value="voltar" disabled={enviando} className={classeDoBotaoDeVoltar}>
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
