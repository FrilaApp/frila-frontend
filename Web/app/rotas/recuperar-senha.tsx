import { Form, Link, redirect, useNavigation } from "react-router";

import { contextoDaSessao } from "../contexto";
import { authDesteAmbiente, emailsDeDemonstracao } from "../servidor/deste-ambiente";
import { cookieDoDispositivo, cookiesDaSessao, ehPedidoSeguro, visitanteDoPedido } from "../servidor/sessao";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/recuperar-senha";

type Erro = keyof typeof textos.recuperarSenha.erros;
type Passo =
  | { passo: "email"; email: string; erro?: Erro }
  | { passo: "codigo"; email: string; reenviado?: boolean; erro?: Erro };

const FORMATO_DO_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function meta() {
  return [{ title: textos.recuperarSenha.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export function loader({ context }: Route.LoaderArgs) {
  if (context.get(contextoDaSessao)) {
    throw redirect("/");
  }
  return null;
}

export async function action({ request }: Route.ActionArgs): Promise<Passo> {
  const formulario = await request.formData();
  const email = String(formulario.get("email") ?? "").trim().toLowerCase();
  const codigo = String(formulario.get("codigo") ?? "").trim();
  const intencao = String(formulario.get("intencao") ?? "pedir");
  const ehReenvio = String(formulario.get("reenvio") ?? "") === "1";

  if (!FORMATO_DO_EMAIL.test(email) || email.length > 254) {
    return { passo: "email", email, erro: "email_invalido" };
  }
  const auth = authDesteAmbiente();
  if (!auth) {
    return { passo: ehReenvio ? "codigo" : "email", email, erro: "indisponivel" };
  }

  if (emailsDeDemonstracao().has(email)) {
    return { passo: "email", email, erro: "conta_demo" };
  }

  if (intencao === "pedir") {
    const pedido = await auth.pedirCodigoRecuperacao(email);
    if (!pedido.ok) {
      return { passo: ehReenvio ? "codigo" : "email", email, erro: pedido.motivo };
    }
    // Anti-enumeração: existente, inexistente e social-only produzem exatamente o mesmo passo/estado/UI.
    return ehReenvio ? { passo: "codigo", email, reenviado: true } : { passo: "codigo", email };
  }

  if (!/^\d{6}$/.test(codigo)) {
    return { passo: "codigo", email, erro: "codigo_incompleto" };
  }
  const lembrarDispositivo = formulario.get("lembrar_dispositivo") === "sim";
  const entrada = await auth.confirmarDispositivoOtp({
    tipo: "recuperacao",
    email,
    codigo,
    lembrarDispositivo,
    visitante: visitanteDoPedido(request),
  });
  if (!entrada.ok) {
    return { passo: "codigo", email, erro: entrada.motivo };
  }

  const seguro = ehPedidoSeguro(request);
  const cabecalhos = new Headers();
  for (const linha of cookiesDaSessao(entrada.sessao, seguro)) cabecalhos.append("Set-Cookie", linha);
  if (entrada.deviceToken) cabecalhos.append("Set-Cookie", cookieDoDispositivo(entrada.deviceToken, seguro));
  throw redirect("/definir-senha?origem=recuperacao", { headers: cabecalhos });
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoLink = "min-h-11 font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function RecuperarSenha({ actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const enviando = navegacao.state !== "idle";
  const estado: Passo = actionData ?? { passo: "email", email: "" };
  const erro = estado.erro ? textos.recuperarSenha.erros[estado.erro] : null;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>

      {estado.passo === "email" ? (
        <Form method="post" className="flex flex-col gap-4" noValidate>
          <h1 className="font-titulo text-3xl font-bold">{textos.recuperarSenha.titulo}</h1>
          <p className="text-tinta-suave">{textos.recuperarSenha.corpo}</p>
          <label className="flex flex-col gap-2 font-semibold" htmlFor="email">
            {textos.recuperarSenha.rotuloDoEmail}
            <input
              id="email"
              name="email"
              type="email"
              autoComplete="email"
              inputMode="email"
              autoCapitalize="none"
              spellCheck={false}
              required
              defaultValue={estado.email}
              aria-invalid={erro ? true : undefined}
              aria-describedby={erro ? "erro" : undefined}
              className={classeDoCampo}
            />
          </label>
          {erro ? (
            <p id="erro" role="alert" className="font-semibold">
              {erro}
            </p>
          ) : null}
          <button type="submit" name="intencao" value="pedir" disabled={enviando} className={classeDoBotao}>
            {enviando ? textos.recuperarSenha.enviando : textos.recuperarSenha.pedirCodigo}
          </button>
          <div className="pt-2 text-center">
            <Link to="/entrar" className={classeDoLink}>
              {textos.recuperarSenha.voltarAoEntrar}
            </Link>
          </div>
        </Form>
      ) : (
        <div className="flex flex-col gap-4">
          <Form method="post" className="flex flex-col gap-4" noValidate>
            <h1 className="font-titulo text-3xl font-bold">{textos.recuperarSenha.tituloDoCodigo}</h1>
            <p className="text-tinta-suave">
              {textos.recuperarSenha.corpoDoCodigo} <strong className="break-all text-tinta">{estado.email}</strong>.
            </p>
            <input type="hidden" name="email" value={estado.email} />
            <label className="flex flex-col gap-2 font-semibold" htmlFor="codigo">
              {textos.recuperarSenha.rotuloDoCodigo}
              <input
                id="codigo"
                name="codigo"
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                required
                autoFocus
                aria-invalid={erro ? true : undefined}
                aria-describedby={erro ? "erro" : undefined}
                className={`${classeDoCampo} tracking-widest`}
              />
            </label>
            <label className="flex min-h-11 items-center gap-3 text-sm">
              <input type="checkbox" name="lembrar_dispositivo" value="sim" className="size-5 shrink-0" />
              <span>{textos.recuperarSenha.lembrarDispositivo}</span>
            </label>
            {erro ? (
              <p id="erro" role="alert" className="font-semibold">
                {erro}
              </p>
            ) : null}
            {estado.reenviado && !erro ? (
              <p role="status" className="font-semibold">
                {textos.recuperarSenha.mensagemReenvio}
              </p>
            ) : null}
            <button type="submit" name="intencao" value="confirmar" disabled={enviando} className={classeDoBotao}>
              {enviando ? textos.recuperarSenha.conferindo : textos.recuperarSenha.confirmar}
            </button>
          </Form>
          <Form method="post" className="flex flex-wrap gap-x-6 gap-y-2">
            <input type="hidden" name="email" value={estado.email} />
            <input type="hidden" name="reenvio" value="1" />
            <button type="submit" name="intencao" value="pedir" disabled={enviando} className={classeDoLink}>
              {textos.recuperarSenha.reenviar}
            </button>
            <Link to="/recuperar-senha" className={`${classeDoLink} inline-flex items-center`}>
              {textos.recuperarSenha.trocarEmail}
            </Link>
          </Form>
        </div>
      )}
    </main>
  );
}
