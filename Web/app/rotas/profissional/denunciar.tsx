import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import { agirNaDenuncia, carregarDenuncia, TelaDeDenuncia } from "../moderacao";
import type { Route } from "./+types/denunciar";

const t = textos.profissional.moderacao;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** O profissional denuncia ou bloqueia a casa (o `id` público que a vaga ou o turno mostrou). */
export function loader({ context, request }: Route.LoaderArgs) {
  exigirSessao(context);
  return carregarDenuncia(request);
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  return agirNaDenuncia(apiDoUsuario(sessao.acesso), await request.formData(), "estabelecimento");
}

export default function Denunciar({ loaderData, actionData }: Route.ComponentProps) {
  return <TelaDeDenuncia dados={loaderData} resposta={actionData} t={t} bloqueadosEm="/bloqueados" voltarPara="/" />;
}
