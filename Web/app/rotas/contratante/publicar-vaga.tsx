import { Form, Link, redirect, useNavigation } from "react-router";

import { escolherCasa, lerCadastroDaCasa, lerMinhasCasas } from "../../servidor/contratante/casa";
import { lerFuncoes, porCategoria } from "../../servidor/contratante/catalogo";
import {
  type CampoDaVaga,
  ehUuid,
  lerFormularioDaVaga,
  montarNovaVaga,
  publicarVaga,
  type ValoresDaVaga,
  valoresDoFormulario,
} from "../../servidor/contratante/publicar-vaga";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/publicar-vaga";

const t = textos.contratante.publicar;
type Erros = Partial<Record<CampoDaVaga, string>> & { geral?: string };
type Retorno = { erros: Erros; valores: ValoresDaVaga; chave: string };

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ request, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
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
    // Uma chave por formulário: reenviar (clique duplo, rede que caiu) devolve a mesma vaga, sem criar outra.
    chave: crypto.randomUUID(),
  };
}

export async function action({ request, context }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const formulario = await request.formData();
  const valores = valoresDoFormulario(formulario);
  const casaId = String(formulario.get("casa") ?? "");
  const chave = String(formulario.get("chave") ?? "");
  const volta = (erros: Erros): Retorno => ({ erros, valores, chave });

  if (!ehUuid(casaId) || !ehUuid(chave)) return volta({ geral: t.erros.formularioVelho });
  const lido = lerFormularioDaVaga(valores);
  if (!lido.ok) {
    const erros: Erros = {};
    for (const [campo, problema] of Object.entries(lido.erros) as Array<[CampoDaVaga, string]>) {
      erros[campo] = campo === "dia" && problema === "obrigatorio" ? t.erros.dia : t.erros[campo];
    }
    return volta(erros);
  }

  const cadastro = await lerCadastroDaCasa(api, casaId);
  if (cadastro.estado === "sem_sessao") throw redirect("/entrar");
  if (cadastro.estado === "sem_permissao") return volta({ geral: t.erros.semPermissao });
  if (cadastro.estado !== "ok") return volta({ geral: t.erros.indisponivel });

  const resultado = await publicarVaga(api, montarNovaVaga(lido.vaga, cadastro.casa, chave));
  if (resultado.ok) throw redirect(`/painel?casa=${casaId}&publicada=1`);
  switch (resultado.motivo) {
    case "sem_sessao":
      throw redirect("/entrar");
    case "campo":
      return volta({ [resultado.campo]: t.erros[resultado.campo] });
    case "horario_invalido":
      return volta({ dia: t.erros.horarioInvalido });
    case "selecao_sem_antecedencia":
      return volta({ modo: t.erros.selecaoSemAntecedencia });
    case "cadastro_da_casa":
      return volta({ geral: t.erros.cadastroDaCasa });
    case "perfil_incompativel":
      return volta({ geral: t.erros.perfilIncompativel });
    case "sem_permissao":
      return volta({ geral: t.erros.semPermissao });
    case "conta_suspensa":
      return volta({ geral: t.erros.contaSuspensa });
    default:
      return volta({ geral: t.erros.indisponivel });
  }
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";
const classeDaCaixa = "flex min-h-12 items-center gap-3";

function Aviso({ id, texto }: { id: string; texto?: string }) {
  return texto ? (
    <p id={id} role="alert" className="font-semibold">
      {texto}
    </p>
  ) : null;
}

/** Atributos de acessibilidade do campo com erro. */
const sobre = (erros: Erros, campo: CampoDaVaga, ajuda?: string) => ({
  "aria-invalid": erros[campo] ? true : undefined,
  "aria-describedby": [erros[campo] ? `erro-${campo}` : null, ajuda].filter(Boolean).join(" ") || undefined,
});

const VAZIO: ValoresDaVaga = {
  funcao_id: "", dia: "", inicio: "", fim: "", valor: "", posicoes: "1", modo: "urgencia", responsavel_local: "",
  traje: "", observacoes: "", inclui_refeicao: false, inclui_transporte: false, exige_material_proprio: false,
};

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function PublicarVaga({ loaderData, actionData }: Route.ComponentProps) {
  const enviando = useNavigation().state !== "idle";
  const erros = actionData?.erros ?? {};
  const valores = actionData?.valores ?? VAZIO;
  const { casa, grupos } = loaderData;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 p-6">
      <Link to={`/painel?casa=${casa.id}`} className="min-h-11 font-semibold underline underline-offset-4">
        {t.voltar}
      </Link>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p>
        <strong>{casa.nome}</strong>. {t.endereco} {casa.endereco}, {casa.regiao}.
      </p>

      <Form method="post" className="flex flex-col gap-5" noValidate>
        <input type="hidden" name="casa" value={casa.id} />
        <input type="hidden" name="chave" value={actionData?.chave ?? loaderData.chave} />
        <Aviso id="erro-geral" texto={erros.geral} />

        <label className={classeDoRotulo} htmlFor="funcao_id">
          {t.funcao}
          <select id="funcao_id" name="funcao_id" required defaultValue={valores.funcao_id} className={classeDoCampo} {...sobre(erros, "funcao_id")}>
            <option value="">{t.escolhaAFuncao}</option>
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
          {loaderData.funcoesIndisponiveis ? <span role="status">{t.funcoesIndisponiveis}</span> : null}
          <Aviso id="erro-funcao_id" texto={erros.funcao_id} />
        </label>

        <fieldset className="flex flex-col gap-3" aria-describedby="ajuda-horario">
          <legend className="font-semibold">{t.dia}</legend>
          <p id="ajuda-horario" className="text-sm text-tinta-suave">
            {t.ajudaDoHorario}
          </p>
          <input name="dia" type="date" aria-label={t.dia} required defaultValue={valores.dia} className={classeDoCampo} {...sobre(erros, "dia")} />
          <Aviso id="erro-dia" texto={erros.dia} />
          <div className="grid grid-cols-2 gap-3">
            <label className={classeDoRotulo}>
              {t.inicio}
              <input name="inicio" type="time" required defaultValue={valores.inicio} className={classeDoCampo} {...sobre(erros, "inicio")} />
            </label>
            <label className={classeDoRotulo}>
              {t.fim}
              <input name="fim" type="time" required defaultValue={valores.fim} className={classeDoCampo} {...sobre(erros, "fim")} />
            </label>
          </div>
          <Aviso id="erro-inicio" texto={erros.inicio} />
          <Aviso id="erro-fim" texto={erros.fim} />
        </fieldset>

        <label className={classeDoRotulo}>
          {t.valor}
          <span id="ajuda-valor" className="text-sm font-normal text-tinta-suave">
            {t.ajudaDoValor}
          </span>
          <input name="valor" type="text" inputMode="decimal" required defaultValue={valores.valor} className={classeDoCampo} {...sobre(erros, "valor", "ajuda-valor")} />
          <Aviso id="erro-valor" texto={erros.valor} />
        </label>

        <label className={classeDoRotulo}>
          {t.posicoes}
          <input name="posicoes" type="number" min={1} max={200} required defaultValue={valores.posicoes} className={classeDoCampo} {...sobre(erros, "posicoes")} />
          <Aviso id="erro-posicoes" texto={erros.posicoes} />
        </label>

        <fieldset className="flex flex-col gap-2">
          <legend className="font-semibold">{t.modo}</legend>
          {(["urgencia", "selecao"] as const).map((modo) => (
            <label key={modo} className="flex min-h-12 items-center gap-3 rounded-controle border border-borda bg-superficie px-4">
              <input type="radio" name="modo" value={modo} defaultChecked={valores.modo === modo} className="size-5 shrink-0" />
              <span>{t.modos[modo]}</span>
            </label>
          ))}
          <Aviso id="erro-modo" texto={erros.modo} />
        </fieldset>

        <label className={classeDoRotulo}>
          {t.responsavelLocal}
          <input name="responsavel_local" type="text" required defaultValue={valores.responsavel_local} className={classeDoCampo} {...sobre(erros, "responsavel_local")} />
          <Aviso id="erro-responsavel_local" texto={erros.responsavel_local} />
        </label>

        <div className="flex flex-col gap-1">
          {(
            [
              ["inclui_refeicao", t.incluiRefeicao],
              ["inclui_transporte", t.incluiTransporte],
              ["exige_material_proprio", t.exigeMaterialProprio],
            ] as const
          ).map(([nome, rotulo]) => (
            <label key={nome} className={classeDaCaixa}>
              <input type="checkbox" name={nome} value="sim" defaultChecked={valores[nome]} className="size-5 shrink-0" />
              <span>{rotulo}</span>
            </label>
          ))}
        </div>

        <label className={classeDoRotulo}>
          {t.traje}
          <input name="traje" type="text" defaultValue={valores.traje} className={classeDoCampo} {...sobre(erros, "traje")} />
          <Aviso id="erro-traje" texto={erros.traje} />
        </label>

        <label className={classeDoRotulo}>
          {t.observacoes}
          <textarea name="observacoes" rows={3} defaultValue={valores.observacoes} className={`${classeDoCampo} py-3`} {...sobre(erros, "observacoes")} />
          <Aviso id="erro-observacoes" texto={erros.observacoes} />
        </label>

        <button type="submit" disabled={enviando} className="min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60">
          {enviando ? t.publicando : t.publicar}
        </button>
      </Form>
    </main>
  );
}
