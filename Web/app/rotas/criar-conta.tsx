import { Form, Link, redirect, useNavigation } from "react-router";

import { contextoDaSessao } from "../contexto";
import { lerEsperaOtpDiretoDesteAmbiente } from "../servidor/abertura";
import { authDesteAmbiente, emailsDeDemonstracao } from "../servidor/deste-ambiente";
import { cookieDoDispositivo, cookiesDaSessao, ehPedidoSeguro, visitanteDoPedido } from "../servidor/sessao";
import { textos } from "../textos/pt-BR";
import { PassoCodigoOtp } from "./passo-codigo-otp";
import type { Route } from "./+types/criar-conta";

type Erro = keyof typeof textos.criarConta.erros;
type Passo =
  | { passo: "email"; email: string; erro?: Erro; tentativaId?: string }
  | { passo: "codigo"; email: string; reenviado?: boolean; reenviarEmSegundos?: number; erro?: Erro; tentativaId?: string };

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
  const ehReenvio = String(formulario.get("reenvio") ?? "") === "1";
  const tentativaId = String(formulario.get("tentativa_id") ?? "").trim() || undefined;
  const comTentativa = <T extends Passo>(passo: T): T => (tentativaId ? { ...passo, tentativaId } : passo);

  if (!FORMATO_DO_EMAIL.test(email) || email.length > 254) {
    return comTentativa({ passo: "email", email, erro: "email_invalido" });
  }
  const auth = authDesteAmbiente();
  if (!auth) {
    return comTentativa({ passo: "email", email, erro: "indisponivel" });
  }
  if (emailsDeDemonstracao().has(email)) {
    return comTentativa({ passo: "email", email, erro: "conta_demo" });
  }

  if (intencao === "pedir") {
    const pedido = await auth.pedirCodigo(email, { criarUsuario: true });
    if (!pedido.ok) {
      return comTentativa({ passo: ehReenvio ? "codigo" : "email", email, erro: pedido.motivo });
    }
    const reenviarEmSegundos = await lerEsperaOtpDiretoDesteAmbiente();
    return comTentativa({
      passo: "codigo",
      email,
      ...(ehReenvio ? { reenviado: true } : {}),
      ...(reenviarEmSegundos !== undefined ? { reenviarEmSegundos } : {}),
    });
  }

  if (!/^\d{6}$/.test(codigo)) {
    return comTentativa({ passo: "codigo", email, erro: "codigo_incompleto" });
  }
  const lembrarDispositivo = formulario.get("lembrar_dispositivo") === "sim";
  const entrada = await auth.confirmarDispositivoOtp({
    tipo: "cadastro",
    email,
    codigo,
    lembrarDispositivo,
    visitante: visitanteDoPedido(request),
  });
  if (!entrada.ok) {
    return comTentativa({ passo: "codigo", email, erro: entrada.motivo });
  }

  const seguro = ehPedidoSeguro(request);
  const cabecalhos = new Headers();
  for (const linha of cookiesDaSessao(entrada.sessao, seguro)) cabecalhos.append("Set-Cookie", linha);
  if (entrada.deviceToken) cabecalhos.append("Set-Cookie", cookieDoDispositivo(entrada.deviceToken, seguro));
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
        <PassoCodigoOtp
          titulo={textos.criarConta.tituloDoCodigo}
          descricao={
            <>
              {textos.criarConta.corpoDoCodigo} <strong className="break-all text-tinta">{estado.email}</strong>.
            </>
          }
          email={estado.email}
          rotuloDoCodigo={textos.criarConta.rotuloDoCodigo}
          textoConfirmar={textos.criarConta.confirmar}
          textoConferindo={textos.criarConta.conferindo}
          textoReenviar={textos.criarConta.reenviar}
          intencaoConfirmar="confirmar"
          intencaoReenviar="pedir"
          enviando={enviando}
          erro={erro}
          reenviado={estado.reenviado}
          reenviarEmSegundos={estado.reenviarEmSegundos}
          tentativaId={estado.tentativaId}
          mensagemReenvio="Novo código enviado para seu e-mail."
          mostrarLembrarDispositivo
          textoLembrarDispositivo={textos.criarConta.lembrarDispositivo}
          incluirCampoReenvio
          acaoVoltar={
            <Link to="/criar-conta" className={`${classeDoLink} inline-flex items-center`}>
              {textos.criarConta.trocarEmail}
            </Link>
          }
        />
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
