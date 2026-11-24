import { Form, Link, redirect, useNavigation } from "react-router";

import { contextoDaSessao } from "../contexto";
import { authDesteAmbiente, emailsDeDemonstracao } from "../servidor/deste-ambiente";
import { cookiesDaSessao, ehPedidoSeguro } from "../servidor/sessao";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/criar-conta";

type Erro = keyof typeof textos.criarConta.erros;
type Passo = { passo: "email"; email: string; erro?: Erro } | { passo: "codigo"; email: string; erro?: Erro };

const FORMATO_DO_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const TERMOS = "https://frilabr.com/termos";
const PRIVACIDADE = "https://frilabr.com/privacidade";

export function meta() {
  return [{ title: textos.criarConta.tituloDaAba }, { name: "robots", content: "noindex" }];
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

  if (!FORMATO_DO_EMAIL.test(email) || email.length > 254) {
    return { passo: "email", email, erro: "email_invalido" };
  }
  const auth = authDesteAmbiente();
  if (!auth) {
    return { passo: "email", email, erro: "indisponivel" };
  }
  if (emailsDeDemonstracao().has(email)) {
    return { passo: "email", email, erro: "conta_demo" };
  }

  if (intencao === "pedir") {
    const pedido = await auth.pedirCodigo(email, { criarUsuario: true });
    return pedido.ok ? { passo: "codigo", email } : { passo: "email", email, erro: pedido.motivo };
  }

  if (!/^\d{6}$/.test(codigo)) {
    return { passo: "codigo", email, erro: "codigo_incompleto" };
  }
  const entrada = await auth.confirmarCodigo(email, codigo);
  if (!entrada.ok) {
    const erro: Erro = entrada.motivo === "limite" || entrada.motivo === "indisponivel" ? entrada.motivo : "codigo_invalido";
    return { passo: "codigo", email, erro };
  }

  const cabecalhos = new Headers();
  for (const linha of cookiesDaSessao(entrada.sessao, ehPedidoSeguro(request))) cabecalhos.append("Set-Cookie", linha);
  throw redirect("/definir-senha?origem=cadastro", { headers: cabecalhos });
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoLink = "min-h-11 font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function CriarConta({ actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const enviando = navegacao.state !== "idle";
  const estado: Passo = actionData ?? { passo: "email", email: "" };
  const erro = estado.erro ? textos.criarConta.erros[estado.erro] : null;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>

      {estado.passo === "email" ? (
        <Form method="post" className="flex flex-col gap-4" noValidate>
          <h1 className="font-titulo text-3xl font-bold">{textos.criarConta.titulo}</h1>
          <p className="text-tinta-suave">{textos.criarConta.corpo}</p>
          <label className="flex flex-col gap-2 font-semibold" htmlFor="email">
            {textos.criarConta.rotuloDoEmail}
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
            {enviando ? textos.criarConta.enviando : textos.criarConta.pedirCodigo}
          </button>
          <div className="pt-2 text-center">
            <Link to="/entrar" className={classeDoLink}>
              {textos.criarConta.jaTemConta}
            </Link>
          </div>
        </Form>
      ) : (
        <div className="flex flex-col gap-4">
          <Form method="post" className="flex flex-col gap-4" noValidate>
            <h1 className="font-titulo text-3xl font-bold">{textos.criarConta.tituloDoCodigo}</h1>
            <p className="text-tinta-suave">
              {textos.criarConta.corpoDoCodigo} <strong className="break-all text-tinta">{estado.email}</strong>.
            </p>
            <input type="hidden" name="email" value={estado.email} />
            <label className="flex flex-col gap-2 font-semibold" htmlFor="codigo">
              {textos.criarConta.rotuloDoCodigo}
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
            {erro ? (
              <p id="erro" role="alert" className="font-semibold">
                {erro}
              </p>
            ) : null}
            <button type="submit" name="intencao" value="confirmar" disabled={enviando} className={classeDoBotao}>
              {enviando ? textos.criarConta.conferindo : textos.criarConta.confirmar}
            </button>
          </Form>
          <Form method="post" className="flex flex-wrap gap-x-6 gap-y-2">
            <input type="hidden" name="email" value={estado.email} />
            <button type="submit" name="intencao" value="pedir" disabled={enviando} className={classeDoLink}>
              {textos.criarConta.reenviar}
            </button>
            <Link to="/criar-conta" className={`${classeDoLink} inline-flex items-center`}>
              {textos.criarConta.trocarEmail}
            </Link>
          </Form>
        </div>
      )}

      <footer className="text-sm text-tinta-suave">
        {textos.criarConta.termos}{" "}
        <a href={TERMOS} target="_blank" rel="noopener noreferrer" className={classeDoLink}>
          {textos.criarConta.linkDosTermos}
        </a>{" "}
        e a{" "}
        <a href={PRIVACIDADE} target="_blank" rel="noopener noreferrer" className={classeDoLink}>
          {textos.criarConta.linkDaPrivacidade}
        </a>
        .
      </footer>
    </main>
  );
}
