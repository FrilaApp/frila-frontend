import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/perguntas";
import { carregarCondicoes } from "./carregar";
import { RodapePublico } from "./componentes";

const t = textos.publico.perguntas;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "description", content: t.descricao }];
}

export const loader = carregarCondicoes;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Perguntas({ loaderData }: Route.ComponentProps) {
  const c = loaderData;
  const itens: Array<[string, string]> = [
    [t.oQueEPergunta, t.oQueEResposta],
    [t.ondePergunta, t.ondeResposta],
    [t.quemPergunta, t.quemResposta],
    [t.ondeUsarPergunta, t.ondeUsarResposta],
    [t.entrarPergunta, t.entrarResposta],
    [t.vagaPergunta, t.vagaResposta],
    [t.modosPergunta, t.modosResposta],
    [t.presencaPergunta, t.presencaResposta],
    [t.localizacaoPergunta, t.localizacaoResposta],
    [t.avaliacaoPergunta, t.avaliacaoResposta],
    [t.cancelarPergunta, t.cancelarResposta],
    // Condição do marketing: só com a chamada direta ligada na web.
    ...(c.chamadaDireta ? ([[t.chamadaDiretaPergunta, t.chamadaDiretaResposta]] as Array<[string, string]>) : []),
    [t.problemaPergunta, t.problemaResposta],
    [t.suspensaoPergunta, t.suspensaoResposta],
    // A frase da exclusão de conta só entra quando a web tiver a exclusão (paridade 2.11).
    [t.dadosPergunta, c.exclusaoNaWeb ? `${t.dadosResposta} ${t.dadosExclusao}` : t.dadosResposta],
    [t.suportePergunta, t.suporteResposta],
  ];
  return (
    <main className="mx-auto flex min-h-dvh max-w-2xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <dl className="flex flex-col gap-4">
        {itens.map(([pergunta, resposta]) => (
          <div key={pergunta} className="flex flex-col gap-1">
            <dt className="text-lg font-bold">{pergunta}</dt>
            <dd>{resposta}</dd>
          </div>
        ))}
      </dl>
      <RodapePublico linkDaAppStore={c.linkDaAppStore} />
    </main>
  );
}
