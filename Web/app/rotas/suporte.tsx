import { data, Form, Link, redirect, useNavigation } from "react-router";

import { apiDoUsuario } from "../servidor/deste-ambiente";
import { exigirSessao } from "../servidor/guarda";
import { formatarPeriodo } from "../servidor/profissional/formato";
import { dataCivil, protocoloCurto } from "../servidor/protocolo";
import { abrirSuporte, CATEGORIAS, emailDoSuporte, lerTurnoDoSuporte, type TurnoDoSuporte } from "../servidor/suporte";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/suporte";

const t = textos.suporte;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

const casaDoEndereco = (request: Request) => new URL(request.url).searchParams.get("casa");
const resumo = (turno: TurnoDoSuporte) => ({
  funcao: turno.vaga.funcao,
  outraParte: turno.contraparte.nome,
  horario: formatarPeriodo(turno.vaga.inicio_em, turno.vaga.fim_em),
  local: `${turno.vaga.local} · ${turno.vaga.regiao_administrativa}`,
});

/** Do lado da casa a tela vem com ?casa= (a lista dos turnos é por casa); sem ele, é a do profissional. */
export async function loader({ context, params, request }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const casa = casaDoEndereco(request);
  const turno = await lerTurnoDoSuporte(apiDoUsuario(sessao), params.turnoId, casa);
  if (turno === "nao_encontrado") return data({ estado: "nao_encontrado" as const, turno: null, casa, chave: "" }, { status: 404 });
  if (turno === "indisponivel") return { estado: "indisponivel" as const, turno: null, casa, chave: "" };
  // A chave nasce aqui e volta no reenvio: o mesmo chamado não abre duas vezes.
  return { estado: "ok" as const, turno: { id: turno.id, ...resumo(turno) }, casa, chave: crypto.randomUUID() };
}

export async function action({ context, params, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const formulario = await request.formData();
  const chave = String(formulario.get("chave") ?? "");
  const categoria = String(formulario.get("categoria") ?? "");
  const aberto = await abrirSuporte(api, params.turnoId, categoria, chave);
  if (!aberto.ok && aberto.motivo === "sem_sessao") throw redirect("/entrar");
  if (!aberto.ok) return { resultado: aberto.motivo === "sem_sessao" ? ("indisponivel" as const) : aberto.motivo, chave };
  const casa = casaDoEndereco(request);
  const turno = await lerTurnoDoSuporte(api, params.turnoId, casa);
  const dados = typeof turno === "string" ? { funcao: "", outraParte: "", horario: "", local: "" } : resumo(turno);
  const motivo = t.categorias[categoria as keyof typeof t.categorias];
  return {
    numero: protocoloCurto(aberto.protocolo.ocorrencia_id),
    prazo: dataCivil(aberto.protocolo.prazo_resposta_ate),
    email: emailDoSuporte(aberto.protocolo, { turnoId: params.turnoId, ...dados, lado: casa ? "casa" : "profissional", motivo }),
  };
}

const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Suporte({ loaderData, actionData }: Route.ComponentProps) {
  const { estado, turno, casa } = loaderData;
  const enviando = useNavigation().state !== "idle";
  const feito = actionData && "email" in actionData && actionData.email ? actionData : null;
  const recusa = actionData && "resultado" in actionData ? actionData.resultado : null;
  const chave = (actionData && "chave" in actionData && actionData.chave) || loaderData.chave;
  const voltar = casa ? `/casa/turnos/${turno?.id ?? ""}?casa=${casa}` : `/turnos/${turno?.id ?? ""}`;
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <section className="flex flex-col gap-1 rounded-cartao border border-borda p-4">
        <p className="font-semibold">{t.emergencia}</p>
        <a href="tel:190" className={classeDoLink}>
          {t.ligar190}
        </a>
        <a href="tel:180" className={classeDoLink}>
          {t.ligar180}
        </a>
      </section>
      {estado === "nao_encontrado" ? <p>{t.naoEncontrado}</p> : estado !== "ok" ? <p role="alert">{t.indisponivel}</p> : null}
      {recusa ? (
        <p role="alert" className="font-semibold">
          {t.resultado[recusa]}
        </p>
      ) : null}
      {recusa === "conta_suspensa" ? (
        <Link to="/conta/suspensa" className={classeDoLink}>
          {textos.suspensao.verSituacao}
        </Link>
      ) : null}
      {turno && feito?.email ? (
        <section className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
          <p role="status" className="font-semibold">
            {t.protocolo.replace("{numero}", feito.numero ?? "").replace("{prazo}", feito.prazo ?? "")}
          </p>
          <a href={feito.email.link} className={`${classeDoBotao} inline-flex items-center justify-center`}>
            {t.abrirEmail}
          </a>
          <p className="text-sm">{t.copiar}</p>
          <pre className="whitespace-pre-wrap rounded-controle border border-borda bg-superficie p-3 text-sm">
            {`${t.para}: suporte@frilabr.com\n${t.assunto}: ${feito.email.assunto}\n\n${feito.email.corpo}`}
          </pre>
        </section>
      ) : turno ? (
        <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
          <p className="font-semibold">
            {turno.funcao} · {turno.outraParte}
          </p>
          <p>{turno.horario}</p>
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-2 font-semibold">{t.motivo}</legend>
            {CATEGORIAS.map((categoria) => (
              <label key={categoria} className="flex min-h-11 items-center gap-3">
                <input type="radio" name="categoria" value={categoria} required className="size-5" />
                {t.categorias[categoria]}
              </label>
            ))}
          </fieldset>
          <input type="hidden" name="chave" value={chave} />
          <p className="text-sm text-tinta-suave">{t.comoFunciona}</p>
          <p className="text-sm text-tinta-suave">{t.avisoDoPrazo}</p>
          <button type="submit" disabled={enviando} className={classeDoBotao}>
            {enviando ? t.enviando : t.registrar}
          </button>
        </Form>
      ) : null}
      {turno ? (
        <Link to={voltar} className={classeDoLink}>
          {t.voltar}
        </Link>
      ) : null}
    </main>
  );
}
