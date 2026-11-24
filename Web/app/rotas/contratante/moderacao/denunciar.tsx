import { apiDoUsuario } from "../../../servidor/deste-ambiente";
import { exigirSessao } from "../../../servidor/guarda";
import { textos } from "../../../textos/pt-BR";
import { agirNaDenuncia, carregarDenuncia, TelaDeDenuncia } from "../../moderacao";
import type { Route } from "./+types/denunciar";

const t = textos.contratanteModeracao;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** A casa denuncia ou bloqueia o profissional do turno (3.18). O bloqueio vale para toda a casa. */
export function loader({ context, request }: Route.LoaderArgs) {
  exigirSessao(context);
  const casa = new URL(request.url).searchParams.get("casa") ?? "";
  return { ...carregarDenuncia(request), casa: /^[0-9a-f-]{36}$/i.test(casa) ? casa : null };
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  return agirNaDenuncia(apiDoUsuario(sessao), await request.formData(), "profissional");
}

export default function DenunciarProfissional({ loaderData, actionData }: Route.ComponentProps) {
  const casa = loaderData.casa ? `?casa=${loaderData.casa}` : "";
  return <TelaDeDenuncia dados={loaderData} resposta={actionData} t={t} bloqueadosEm={`/casa/bloqueados${casa}`} voltarPara={`/casa/turnos${casa}`} />;
}
