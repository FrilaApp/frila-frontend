import { env } from "cloudflare:workers";
import { data, Link } from "react-router";

import { contextoDaSessao } from "../../contexto";
import { ambienteDoSupabase } from "../../servidor/ambiente";
import { criarApi } from "../../servidor/api";
import { formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { dadosEstruturados, lerVagaPublica, podeIndexar, vagaEncerrada, vagaRemovida } from "../../servidor/vaga-publica";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/vaga";

const t = textos.vagaPublica;

/**
 * A vaga pelo link, sem login. Lida SEM o token de quem entrou (só a chave publicável). Fora do índice dos
 * buscadores até VAGA_PUBLICA_NO_INDICE = "1" (portão: as frases da Política, seção 4, item 1, e seção 2).
 */
export async function loader({ context, params }: Route.LoaderArgs) {
  const ambiente = ambienteDoSupabase(env);
  const leitura = await lerVagaPublica(ambiente ? criarApi(ambiente) : null, params.vagaId);
  const entrou = context.get(contextoDaSessao) !== null;
  if (leitura.estado === "nao_encontrada") return data({ estado: "nao_encontrada" as const, vaga: null, entrou }, { status: 404 });
  if (leitura.estado !== "ok") return { estado: "indisponivel" as const, vaga: null, entrou };
  const v = leitura.vaga;
  // Cancelada, encerrada ou já começada: 410, para o buscador tirar o link (e quem chega vê que não está mais disponível).
  if (vagaRemovida(v)) return data({ estado: "removida" as const, vaga: null, entrou }, { status: 410 });
  const inclusos: Array<string | null> = [
    v.inclusos.inclui_refeicao ? t.refeicao : null,
    v.inclusos.inclui_transporte ? t.transporte : null,
    v.inclusos.exige_material_proprio ? t.materialProprio : null,
  ];
  const periodo = formatarPeriodo(v.inicio_em, v.fim_em);
  const valor = formatarValor(v.valor_centavos);
  const indexar = podeIndexar(v, (env as { VAGA_PUBLICA_NO_INDICE?: string }).VAGA_PUBLICA_NO_INDICE);
  const descricao = t.descricaoCompleta.replace("{funcao}", v.funcao.nome).replace("{periodo}", periodo).replace("{valor}", valor);
  return {
    estado: "ok" as const,
    entrou,
    // Só com o portão aberto E a vaga aberta (podeIndexar): com o portão fechado, nada de dados estruturados.
    dados: indexar ? dadosEstruturados(v, descricao) : null,
    vaga: {
      id: v.id,
      funcao: v.funcao.nome,
      valor,
      periodo,
      regiao: v.regiao_administrativa,
      // Sem nome quando o contrato manda nulo (CPF, ou vaga que não está aberta).
      casa: v.estabelecimento_nome,
      inclusos: inclusos.filter((item): item is string => item !== null),
      encerrada: vagaEncerrada(v),
      indexar,
    },
  };
}

export function meta({ loaderData }: Route.MetaArgs) {
  const vaga = loaderData?.vaga;
  if (!vaga) {
    const titulo = loaderData?.estado === "removida" ? t.tituloDaAbaRemovida : t.tituloDaAbaSemVaga;
    return [{ title: titulo }, { name: "robots", content: "noindex" }];
  }
  const titulo = t.tituloDaAba.replace("{funcao}", vaga.funcao).replace("{valor}", vaga.valor);
  const descricao = t.descricao.replace("{funcao}", vaga.funcao);
  return [
    { title: titulo },
    { name: "description", content: descricao },
    { name: "robots", content: vaga.indexar ? "index, follow" : "noindex" },
    // Cartão de compartilhamento (a imagem e o nome do site vêm da raiz).
    { property: "og:title", content: titulo },
    { property: "og:description", content: descricao },
    { property: "og:type", content: "website" },
    ...(loaderData && "dados" in loaderData && loaderData.dados ? [{ "script:ld+json": loaderData.dados }] : []),
  ];
}

const classeDoBotao = "inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function VagaPeloLink({ loaderData }: Route.ComponentProps) {
  const { estado, vaga, entrou } = loaderData;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      {estado === "removida" ? (
        <>
          <h1 className="font-titulo text-3xl font-bold">{t.removidaTitulo}</h1>
          <p>{t.removidaCorpo}</p>
          <Link to="/vagas" className={classeDoLink}>
            {t.verOutras}
          </Link>
        </>
      ) : estado === "nao_encontrada" ? (
        <>
          <h1 className="font-titulo text-3xl font-bold">{t.naoEncontradaTitulo}</h1>
          <p>{t.naoEncontradaCorpo}</p>
        </>
      ) : estado !== "ok" || !vaga ? (
        <p role="alert">{t.indisponivel}</p>
      ) : (
        <>
          <h1 className="font-titulo text-3xl font-bold">
            {vaga.funcao} · {vaga.valor}
          </h1>
          {vaga.encerrada ? <p role="status" className="font-semibold">{t.encerrada}</p> : null}
          <dl className="rounded-cartao border border-borda bg-superficie p-4">
            <dt className="font-semibold">{t.quando}</dt>
            <dd className="mb-2">{vaga.periodo}</dd>
            {vaga.casa ? (
              <>
                <dt className="font-semibold">{t.casa}</dt>
                <dd className="mb-2">{vaga.casa}</dd>
              </>
            ) : null}
            {vaga.regiao ? (
              <>
                <dt className="font-semibold">{t.regiao}</dt>
                <dd className="mb-2">{vaga.regiao}</dd>
              </>
            ) : null}
            <dt className="font-semibold">{t.valor}</dt>
            <dd className="mb-2">{vaga.valor}</dd>
            <dt className="font-semibold">{t.inclui}</dt>
            <dd>{vaga.inclusos.length > 0 ? vaga.inclusos.join(", ") : t.nadaIncluso}</dd>
          </dl>
          <p className="text-sm text-tinta-suave">{t.enderecoDepois}</p>
          {vaga.encerrada ? (
            <Link to="/vagas" className={classeDoLink}>
              {t.verOutras}
            </Link>
          ) : (
            <p>
              <Link to={entrou ? `/vagas/${vaga.id}` : "/entrar"} className={classeDoBotao}>
                {entrou ? t.verNoApp : t.candidatar}
              </Link>
            </p>
          )}
        </>
      )}
    </main>
  );
}
