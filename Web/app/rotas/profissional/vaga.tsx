import { data, Link } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { formatarDistancia, formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { aceitaCandidatura, lerVaga } from "../../servidor/profissional/vagas";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/vaga";

const t = textos.profissional.vaga;
const tv = textos.profissional.vagas;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** Detalhe da vaga. O que aparece (endereço incluso) é o que o servidor devolve para esta pessoa. */
export async function loader({ context, params }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const leitura = await lerVaga(apiDoUsuario(sessao.acesso), params.vagaId);
  if (leitura.estado === "nao_encontrada") {
    return data({ estado: "nao_encontrada" as const, vaga: null }, { status: 404 });
  }
  if (leitura.estado !== "ok") {
    return { estado: leitura.estado, vaga: null };
  }
  const vaga = leitura.vaga;
  const itens: Array<string | null> = [
    vaga.inclusos.inclui_refeicao ? t.refeicao : null,
    vaga.inclusos.inclui_transporte ? t.transporte : null,
    vaga.inclusos.exige_material_proprio ? t.materialProprio : null,
  ];
  const inclusos = itens.filter((item): item is string => item !== null);
  return {
    estado: "ok" as const,
    vaga: {
      id: vaga.id,
      funcao: vaga.funcao.nome,
      casa: vaga.estabelecimento.nome,
      periodo: formatarPeriodo(vaga.inicio_em, vaga.fim_em),
      valor: formatarValor(vaga.valor_centavos),
      local: vaga.local,
      regiao: vaga.regiao_administrativa,
      distancia: vaga.distancia_km === null || vaga.distancia_km === undefined ? null : formatarDistancia(vaga.distancia_km),
      responsavel: vaga.responsavel_local,
      traje: vaga.traje ?? null,
      observacoes: vaga.observacoes ?? null,
      inclusos,
      modo: vaga.modo,
      posicoes: vaga.posicoes_abertas,
      oculta: vaga.oculta,
      aceitaCandidatura: aceitaCandidatura(vaga),
    },
  };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

const AVISO_DO_ESTADO = {
  perfil_incompativel: tv.perfilIncompativel,
  conta_suspensa: tv.contaSuspensa,
  indisponivel: tv.indisponivel,
} as const;

function Linha({ rotulo, valor }: { rotulo: string; valor: string }) {
  return (
    <>
      <dt className="font-semibold">{rotulo}</dt>
      <dd className="mb-2">{valor}</dd>
    </>
  );
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function DetalheDaVaga({ loaderData }: Route.ComponentProps) {
  const { estado, vaga } = loaderData;

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      {estado === "nao_encontrada" ? (
        <>
          <h1 className="font-titulo text-3xl font-bold">{t.naoEncontradaTitulo}</h1>
          <p>{t.naoEncontradaCorpo}</p>
        </>
      ) : estado !== "ok" || !vaga ? (
        <p role="alert">{AVISO_DO_ESTADO[estado]}</p>
      ) : (
        <>
          <h1 className="font-titulo text-3xl font-bold">
            {vaga.funcao} · {vaga.valor}
          </h1>
          {vaga.oculta ? <p role="status">{t.oculta}</p> : null}
          <dl className="rounded-cartao border border-borda bg-superficie p-4">
            <Linha rotulo={t.quando} valor={vaga.periodo} />
            <Linha rotulo={t.casa} valor={vaga.casa} />
            <Linha
              rotulo={t.onde}
              valor={[vaga.local, vaga.regiao, vaga.distancia ? tv.distanciaDaVaga.replace("{distancia}", vaga.distancia) : null]
                .filter(Boolean)
                .join(" · ")}
            />
            <Linha rotulo={t.valor} valor={vaga.valor} />
            <Linha rotulo={t.inclusos} valor={vaga.inclusos.length > 0 ? vaga.inclusos.join(", ") : t.nadaIncluso} />
            <Linha rotulo={t.responsavel} valor={vaga.responsavel} />
            {vaga.traje ? <Linha rotulo={t.traje} valor={vaga.traje} /> : null}
            {vaga.observacoes ? <Linha rotulo={t.observacoes} valor={vaga.observacoes} /> : null}
            <Linha
              rotulo={t.modo}
              valor={`${vaga.modo === "urgencia" ? tv.urgencia : tv.selecao} · ${tv.posicoes.replace("{n}", String(vaga.posicoes))}`}
            />
          </dl>
          {vaga.aceitaCandidatura ? null : <p role="status">{t.fechada}</p>}
        </>
      )}
      <Link to="/vagas" className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
