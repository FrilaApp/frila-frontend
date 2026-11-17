import { contextoDaSessao } from "../contexto";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { avisoEhDestaSessao, lerTokenDoAparelho } from "../servidor/push";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/avisos-vinculo";

/**
 * O service worker pergunta, a cada push, se pode mostrar o conteúdo (item 6.1, RN15). A resposta vale só para este
 * aviso: nada fica guardado no navegador que uma página, outra aba ou uma resposta atrasada possa trocar.
 * Volta também o texto neutro do catálogo, para o aviso que não pode mostrar o conteúdo.
 */
export async function action({ request, context }: Route.ActionArgs) {
  const sessao = context.get(contextoDaSessao);
  let vinculoDoAviso: unknown;
  try {
    vinculoDoAviso = ((await request.json()) as { vinculo_id?: unknown }).vinculo_id ?? null;
  } catch {
    vinculoDoAviso = null;
  }
  const mostrar = sessao ? await avisoEhDestaSessao(apiDoUsuario(sessao.acesso), lerTokenDoAparelho(request), vinculoDoAviso) : false;
  return Response.json(
    { mostrar, neutro: { titulo: textos.pwa.avisos.neutroTitulo, corpo: textos.pwa.avisos.neutroCorpo } },
    { headers: { "Cache-Control": "no-store" } },
  );
}
