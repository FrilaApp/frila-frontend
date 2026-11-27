import { data, Form, Link, redirect, useNavigation } from "react-router";

import { contextoDaSessao } from "../contexto";
import {
  appleEntrarLigado,
  authDesteAmbiente,
  emailsDeDemonstracao,
  googleLigadoNesteAmbiente,
} from "../servidor/deste-ambiente";
import { BASE } from "../servidor/porteiro";
import {
  cookieDoDispositivo,
  cookiesDaSessao,
  ehPedidoSeguro,
  lerCookieDoDispositivo,
  visitanteDoPedido,
} from "../servidor/sessao";
import { textos } from "../textos/pt-BR";
import { PassoCodigoOtp } from "./passo-codigo-otp";
import type { Route } from "./+types/entrar";

type Erro = keyof typeof textos.entrar.erros;
type Passo =
  | { passo: "email"; email: string; erro?: Erro; tentativaId?: string }
  | { passo: "codigo"; email: string; reenviado?: boolean; erro?: Erro; tentativaId?: string }
  | {
      passo: "desafio";
      email: string;
      desafioId: string;
      reenviado?: boolean;
      reenviarEmSegundos?: number;
      erro?: Erro;
      tentativaId?: string;
    };

const FORMATO_DO_EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const TERMOS = "https://frilabr.com/termos";
const PRIVACIDADE = "https://frilabr.com/privacidade";

export function meta() {
  return [{ title: textos.entrar.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export function loader({ request, context }: Route.LoaderArgs) {
  if (context.get(contextoDaSessao)) {
    throw redirect("/");
  }
  const erroParam = new URL(request.url).searchParams.get("erro");
  const erroUrl: Erro | undefined =
    erroParam && Object.prototype.hasOwnProperty.call(textos.entrar.erros, erroParam)
      ? (erroParam as Erro)
      : undefined;
  return {
    appleLigado: appleEntrarLigado(),
    googleLigado: googleLigadoNesteAmbiente(),
    erroUrl,
  };
}

export async function action({ request }: Route.ActionArgs) {
  const formulario = await request.formData();
  const email = String(formulario.get("email") ?? "").trim().toLowerCase();
  const senha = String(formulario.get("senha") ?? "");
  const codigo = String(formulario.get("codigo") ?? "").trim();
  const desafioId = String(formulario.get("desafio_id") ?? "").trim();
  const intencao = String(formulario.get("intencao") ?? "");
  const tentativaId = String(formulario.get("tentativa_id") ?? "").trim() || undefined;
  const comTentativa = <T extends Passo>(passo: T): T => (tentativaId ? { ...passo, tentativaId } : passo);
  const seguro = ehPedidoSeguro(request);
  const visitante = visitanteDoPedido(request);

  if (!FORMATO_DO_EMAIL.test(email) || email.length > 254) {
    return { passo: "email", email, erro: "email_invalido" } satisfies Passo;
  }
  const auth = authDesteAmbiente();
  if (!auth) {
    return { passo: "email", email, erro: "indisponivel" } satisfies Passo;
  }
  const ehDemonstracao = emailsDeDemonstracao().has(email);

  if (intencao === "pedir") {
    // Apenas contas de demonstração usam código em /entrar; contas reais entram com senha (ou criam conta em /criar-conta).
    if (!ehDemonstracao) {
      return { passo: "email", email, erro: "codigo_apenas_demo" } satisfies Passo;
    }
    return { passo: "codigo", email } satisfies Passo;
  }

  if (intencao === "confirmar") {
    if (!ehDemonstracao) {
      return { passo: "email", email, erro: "codigo_apenas_demo" } satisfies Passo;
    }
    if (codigo.length === 0 || codigo.length > 64) {
      return { passo: "codigo", email, erro: "codigo_incompleto" } satisfies Passo;
    }
    const entrada = await auth.entrarDemonstracao(email, codigo);
    if (!entrada.ok) {
      return { passo: "codigo", email, erro: entrada.motivo } satisfies Passo;
    }

    const cabecalhos = new Headers();
    for (const linha of cookiesDaSessao(entrada.sessao, seguro)) cabecalhos.append("Set-Cookie", linha);
    throw redirect("/", { headers: cabecalhos });
  }

  if (intencao === "confirmar_desafio") {
    if (ehDemonstracao) {
      return { passo: "email", email, erro: "conta_demo" } satisfies Passo;
    }
    if (!/^\d{6}$/.test(codigo)) {
      return { passo: "desafio", email, desafioId, erro: "codigo_incompleto" } satisfies Passo;
    }
    const lembrarDispositivo = formulario.get("lembrar_dispositivo") === "sim";
    const res = await auth.confirmarDispositivoOtp({
      tipo: "login_dispositivo",
      desafioId,
      codigo,
      lembrarDispositivo,
      visitante,
    });
    if (!res.ok) {
      if (res.motivo === "desafio_expirado" || res.motivo === "desafio_ja_usado") {
        return comTentativa({ passo: "email", email, erro: res.motivo }) satisfies Passo;
      }
      return comTentativa({ passo: "desafio", email, desafioId, erro: res.motivo }) satisfies Passo;
    }
    const cabecalhos = new Headers();
    for (const linha of cookiesDaSessao(res.sessao, seguro)) cabecalhos.append("Set-Cookie", linha);
    if (res.deviceToken) cabecalhos.append("Set-Cookie", cookieDoDispositivo(res.deviceToken, seguro));
    throw redirect(res.precisaDefinirSenha ? "/definir-senha?origem=pendente" : "/", { headers: cabecalhos });
  }

  if (intencao === "reenviar_desafio") {
    if (ehDemonstracao) {
      return { passo: "email", email, erro: "conta_demo" } satisfies Passo;
    }
    const res = await auth.reenviarDispositivoOtp({ desafioId, visitante });
    if (!res.ok) {
      if (res.motivo === "desafio_expirado" || res.motivo === "desafio_ja_usado") {
        return comTentativa({ passo: "email", email, erro: res.motivo }) satisfies Passo;
      }
      return comTentativa({ passo: "desafio", email, desafioId, erro: res.motivo }) satisfies Passo;
    }
    return comTentativa({
      passo: "desafio",
      email,
      desafioId,
      reenviado: true,
      reenviarEmSegundos: res.reenviarEmSegundos,
    }) satisfies Passo;
  }

  // Intenção padrão: login habitual por e-mail e senha com validação server-side de dispositivo confiável
  if (ehDemonstracao) {
    return { passo: "email", email, erro: "conta_demo" } satisfies Passo;
  }
  if (senha.length === 0) {
    return { passo: "email", email, erro: "senha_invalida" } satisfies Passo;
  }
  const deviceToken = lerCookieDoDispositivo(request);
  const entrada = await auth.autenticarSenha({ email, senha, deviceToken, visitante });
  if (!entrada.ok) {
    return { passo: "email", email, erro: entrada.motivo } satisfies Passo;
  }

  if (entrada.status === "desafio_otp") {
    const passoDesafio: Passo = {
      passo: "desafio",
      email,
      desafioId: entrada.desafioId,
      ...(entrada.reenviarEmSegundos !== undefined ? { reenviarEmSegundos: entrada.reenviarEmSegundos } : {}),
    };
    if (entrada.descartarDeviceToken) {
      return data(passoDesafio, { headers: { "Set-Cookie": cookieDoDispositivo(null, seguro) } });
    }
    return passoDesafio;
  }

  const cabecalhos = new Headers();
  for (const linha of cookiesDaSessao(entrada.sessao, seguro)) cabecalhos.append("Set-Cookie", linha);
  throw redirect(entrada.precisaDefinirSenha ? "/definir-senha?origem=pendente" : "/", { headers: cabecalhos });
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoBotaoSecundario =
  "inline-flex min-h-12 w-full items-center justify-center rounded-controle border border-borda bg-superficie px-4 text-lg font-semibold";
const classeDoLink = "min-h-11 font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Entrar({ actionData, loaderData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const enviando = navegacao.state !== "idle";
  const estado: Passo = actionData ?? { passo: "email", email: "", erro: loaderData?.erroUrl };
  const erro = estado.erro ? textos.entrar.erros[estado.erro] : null;
  const appleLigado = loaderData?.appleLigado === true;
  const googleLigado = loaderData?.googleLigado === true;

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
            <div id="erro" role="alert" className="flex flex-col gap-2 font-semibold">
              <p>{erro}</p>
              {estado.erro === "codigo_apenas_demo" ? (
                <Link to="/recuperar-senha" className={classeDoLink}>
                  {textos.entrar.esqueciSenha}
                </Link>
              ) : null}
            </div>
          ) : null}
          <button type="submit" name="intencao" value="entrar" disabled={enviando} className={classeDoBotao}>
            {enviando ? textos.entrar.entrando : textos.entrar.entrarComSenha}
          </button>

          {appleLigado ? (
            <a href={`${BASE}/entrar/apple`} className={classeDoBotaoSecundario}>
              {textos.entrar.entrarComApple}
            </a>
          ) : null}

          {googleLigado ? (
            // Link (GET) e não formulário: a política de conteúdo (`form-action 'self'`) barraria o redirecionamento ao Google.
            <a href={`${BASE}/entrar/google`} className={classeDoBotaoSecundario}>
              {textos.entrar.entrarComGoogle}
            </a>
          ) : null}

          {appleLigado || googleLigado ? (
            <p className="text-xs text-tinta-suave">{textos.entrar.avisoVinculoSocial}</p>
          ) : null}

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
      ) : estado.passo === "desafio" ? (
        <PassoCodigoOtp
          titulo={textos.entrar.tituloDoDesafio}
          descricao={
            <>
              {textos.entrar.corpoDoDesafio} <strong className="break-all text-tinta">{estado.email}</strong>
            </>
          }
          email={estado.email}
          desafioId={estado.desafioId}
          rotuloDoCodigo={textos.entrar.rotuloDoCodigo}
          textoConfirmar={textos.entrar.confirmar}
          textoConferindo={textos.entrar.conferindo}
          textoReenviar={textos.entrar.reenviar}
          intencaoConfirmar="confirmar_desafio"
          intencaoReenviar="reenviar_desafio"
          enviando={enviando}
          erro={erro}
          reenviado={estado.reenviado}
          reenviarEmSegundos={estado.reenviarEmSegundos}
          tentativaId={estado.tentativaId}
          mensagemReenvio={textos.entrar.mensagemReenvioDesafio}
          mostrarLembrarDispositivo
          textoLembrarDispositivo={textos.entrar.lembrarDispositivo}
          acaoVoltar={
            <Link to="/entrar" className={`${classeDoLink} inline-flex items-center`}>
              {textos.entrar.voltarAoLogin}
            </Link>
          }
        />
      ) : (
        <div className="flex flex-col gap-4">
          <PassoCodigoOtp
            titulo={textos.entrar.tituloDoCodigo}
            descricao={
              <>
                {textos.entrar.corpoDoCodigo} <strong className="break-all text-tinta">{estado.email}</strong>.
              </>
            }
            email={estado.email}
            rotuloDoCodigo={textos.entrar.rotuloDoCodigo}
            textoConfirmar={textos.entrar.confirmar}
            textoConferindo={textos.entrar.conferindo}
            textoReenviar={textos.entrar.reenviar}
            intencaoConfirmar="confirmar"
            intencaoReenviar="pedir"
            enviando={enviando}
            erro={erro}
            reenviado={estado.reenviado}
            acaoVoltar={
              <a href="" className={`${classeDoLink} inline-flex items-center`}>
                {textos.entrar.trocarEmail}
              </a>
            }
          />
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
