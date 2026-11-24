import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import { carregarBloqueios, desbloquear, TelaDeBloqueados } from "../moderacao";
import type { Route } from "./+types/bloqueados";

const t = textos.profissional.moderacao;

export function meta() {
  return [{ title: t.tituloDosBloqueados }, { name: "robots", content: "noindex" }];
}

/** Só as casas (o lado do profissional bloqueia casas); o par vai ao desbloquear como o servidor mandou. */
export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  return carregarBloqueios(apiDoUsuario(sessao), "estabelecimento");
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  return desbloquear(apiDoUsuario(sessao), await request.formData(), "estabelecimento");
}

export default function Bloqueados({ loaderData, actionData }: Route.ComponentProps) {
  return <TelaDeBloqueados dados={loaderData} resposta={actionData} t={t} voltarPara="/" />;
}
