import { apiDoUsuario } from "../../../servidor/deste-ambiente";
import { exigirSessao } from "../../../servidor/guarda";
import { textos } from "../../../textos/pt-BR";
import { carregarBloqueios, desbloquear, TelaDeBloqueados } from "../../moderacao";
import type { Route } from "./+types/bloqueados";

const t = textos.contratanteModeracao;

export function meta() {
  return [{ title: t.tituloDosBloqueados }, { name: "robots", content: "noindex" }];
}

/** Os profissionais que a casa bloqueou (o bloqueio vale para todo o estabelecimento), com o desbloquear. */
export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  return carregarBloqueios(apiDoUsuario(sessao.acesso), "profissional");
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  return desbloquear(apiDoUsuario(sessao.acesso), await request.formData(), "profissional");
}

export default function BloqueadosDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  return <TelaDeBloqueados dados={loaderData} resposta={actionData} t={t} voltarPara="/casa/turnos" />;
}
