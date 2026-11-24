import { Form, Link, redirect, useNavigation } from "react-router";

import { contextoDaSessao } from "../contexto";
import { authDesteAmbiente, emailsDeDemonstracao } from "../servidor/deste-ambiente";
import { cookiesDaSessao, ehPedidoSeguro } from "../servidor/sessao";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/entrar";

type Erro = keyof typeof textos.entrar.erros;
type Passo = { passo: "email"; email: string; erro?: Erro } | { passo: "codigo"; email: string; erro?: Erro };

const FORMATO_DO_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const TERMOS = "https://frilabr.com/termos";
const PRIVACIDADE = "https://frilabr.com/privacidade";

export function meta() {
  return [{ title: textos.entrar.tituloDaAba }, { name: "robots", content: "noindex" }];
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
  const senha = String(formulario.get("senha") ?? "");
  const codigo = String(formulario.get("codigo") ?? "").trim();
  const intencao = String(formulario.get("intencao") ?? "");

  if (!FORMATO_DO_EMAIL.test(email) || email.length > 254) {
    return { passo: "email", email, erro: "email_invalido" };
  }
  const auth = authDesteAmbiente();
  if (!auth) {
    return { passo: "email", email, erro: "indisponivel" };
  }
  const ehDemonstracao = emailsDeDemonstracao().has(email);

  if (intencao === "pedir") {
    // Apenas contas de demonstração usam código em /entrar; contas reais entram com senha (ou criam conta em /criar-conta).
    if (!ehDemonstracao) {
      return { passo: "email", email, erro: "codigo_apenas_demo" };
    }
    return { passo: "codigo", email };
  }

  if (intencao === "confirmar") {
    if (!ehDemonstracao) {
      return { passo: "email", email, erro: "codigo_apenas_demo" };
    }
    if (codigo.length === 0 || codigo.length > 64) {
      return { passo: "codigo", email, erro: "codigo_incompleto" };
    }
    const entrada = await auth.entrarDemonstracao(email, codigo);
    if (!entrada.ok) {
      return { passo: "codigo", email, erro: entrada.motivo };
    }

    const cabecalhos = new Headers();
    for (const linha of cookiesDaSessao(entrada.sessao, ehPedidoSeguro(request))) cabecalhos.append("Set-Cookie", linha);
    throw redirect("/", { headers: cabecalhos });
  }

  // Intenção padrão: login habitual por e-mail e senha
  if (ehDemonstracao) {
    return { passo: "email", email, erro: "conta_demo" };
  }
  if (senha.length === 0) {
    return { passo: "email", email, erro: "senha_invalida" };
  }
  const entrada = await auth.entrarComSenha(email, senha);
  if (!entrada.ok) {
    return { passo: "email", email, erro: entrada.motivo };
  }

  const cabecalhos = new Headers();
  for (const linha of cookiesDaSessao(entrada.sessao, ehPedidoSeguro(request))) cabecalhos.append("Set-Cookie", linha);
  throw redirect("/", { headers: cabecalhos });
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoLink = "min-h-11 font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Entrar({ actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const enviando = navegacao.state !== "idle";
  const estado: Passo = actionData ?? { passo: "email", email: "" };
  const erro = estado.erro ? textos.entrar.erros[estado.erro] : null;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>

      {estado.passo === "email" ? (
        <Form method="post" className="flex flex-col gap-4" noValidate>
          <h1 className="font-titulo text-3xl font-bold">{textos.entrar.titulo}</h1>
          <p className="text-tinta-suave">{textos.entrar.corpo}</p>
          <label className="flex flex-col gap-2 font-semibold" htmlFor="email">
            {textos.entrar.rotuloDoEmail}
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
          <label className="flex flex-col gap-2 font-semibold" htmlFor="senha">
            {textos.entrar.rotuloDaSenha}
            <input
              id="senha"
              name="senha"
              type="password"
              autoComplete="current-password"
              required
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
          <button type="submit" name="intencao" value="entrar" disabled={enviando} className={classeDoBotao}>
            {enviando ? textos.entrar.entrando : textos.entrar.entrarComSenha}
          </button>

          <div className="flex flex-wrap items-center justify-between gap-2 pt-1 text-sm">
            <Link to="/recuperar-senha" className={classeDoLink}>
              {textos.entrar.esqueciSenha}
            </Link>
            <Link to="/criar-conta" className={classeDoLink}>
              {textos.entrar.criarConta}
            </Link>
          </div>

          <div className="border-t border-borda pt-3">
            <button
              type="submit"
              name="intencao"
              value="pedir"
              disabled={enviando}
              className={`${classeDoLink} text-sm text-tinta-suave`}
            >
              {textos.entrar.pedirCodigo}
            </button>
          </div>
        </Form>
      ) : (
        <div className="flex flex-col gap-4">
          <Form method="post" className="flex flex-col gap-4" noValidate>
            <h1 className="font-titulo text-3xl font-bold">{textos.entrar.tituloDoCodigo}</h1>
            <p className="text-tinta-suave">
              {textos.entrar.corpoDoCodigo} <strong className="break-all text-tinta">{estado.email}</strong>.
            </p>
            <input type="hidden" name="email" value={estado.email} />
            <label className="flex flex-col gap-2 font-semibold" htmlFor="codigo">
              {textos.entrar.rotuloDoCodigo}
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
              {enviando ? textos.entrar.conferindo : textos.entrar.confirmar}
            </button>
          </Form>
          <Form method="post" className="flex flex-wrap gap-x-6 gap-y-2">
            <input type="hidden" name="email" value={estado.email} />
            <button type="submit" name="intencao" value="pedir" disabled={enviando} className={classeDoLink}>
              {textos.entrar.reenviar}
            </button>
            <a href="" className={`${classeDoLink} inline-flex items-center`}>
              {textos.entrar.trocarEmail}
            </a>
          </Form>
          <div className="pt-2">
            <Link to="/entrar" className={`${classeDoLink} text-sm`}>
              {textos.entrar.voltarAoLogin}
            </Link>
          </div>
        </div>
      )}

      <footer className="text-sm text-tinta-suave">
        {textos.entrar.termos}{" "}
        <a href={TERMOS} target="_blank" rel="noopener noreferrer" className={classeDoLink}>
          {textos.entrar.linkDosTermos}
        </a>{" "}
        e a{" "}
        <a href={PRIVACIDADE} target="_blank" rel="noopener noreferrer" className={classeDoLink}>
          {textos.entrar.linkDaPrivacidade}
        </a>
        .
      </footer>
    </main>
  );
}
