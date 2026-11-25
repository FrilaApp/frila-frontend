import { Form, redirect, useNavigation } from "react-router";

import { lerMinhaConta } from "../servidor/conta";
import { apiDoUsuario, authDesteAmbiente, emailsDeDemonstracao } from "../servidor/deste-ambiente";
import { exigirSessao } from "../servidor/guarda";
import {
  cookieDoDispositivo,
  cookiesDaSessao,
  cookiesDeSaida,
  ehPedidoSeguro,
  lerClaimsDoToken,
  lerCookieDoDispositivo,
  lerCookiesDaSessao,
  sessaoAtualDe,
} from "../servidor/sessao";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/definir-senha";

type Erro = keyof typeof textos.definirSenha.erros;
type Origem = "cadastro" | "recuperacao" | "pendente" | "alteracao";
type Estado = { erro?: Erro; origem?: Origem };

function lerOrigem(url: URL): Origem {
  const valor = url.searchParams.get("origem");
  if (valor === "cadastro" || valor === "recuperacao" || valor === "pendente") return valor;
  return "alteracao";
}

function textoPorOrigem(origem: Origem) {
  if (origem === "recuperacao") {
    return { titulo: textos.definirSenha.tituloRecuperacao, corpo: textos.definirSenha.corpoRecuperacao };
  }
  if (origem === "alteracao") {
    return { titulo: textos.definirSenha.tituloAlteracao, corpo: textos.definirSenha.corpoAlteracao };
  }
  return { titulo: textos.definirSenha.titulo, corpo: textos.definirSenha.corpo };
}

export function meta() {
  return [{ title: textos.definirSenha.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export function loader({ request, context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  if (sessao.email && emailsDeDemonstracao().has(sessao.email.toLowerCase())) {
    throw redirect("/");
  }
  return { origem: lerOrigem(new URL(request.url)) };
}

export async function action({ request, context }: Route.ActionArgs): Promise<Estado> {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const origemCampo = String(formulario.get("origem") ?? "");
  const origem: Origem =
    origemCampo === "cadastro" || origemCampo === "recuperacao" || origemCampo === "pendente" || origemCampo === "alteracao"
      ? origemCampo
      : lerOrigem(new URL(request.url));

  if (sessao.email && emailsDeDemonstracao().has(sessao.email.toLowerCase())) {
    return { erro: "conta_demo", origem };
  }

  const senha = String(formulario.get("senha") ?? "");
  const confirmacao = String(formulario.get("confirmacao") ?? "");

  if (senha.length < 8) {
    return { erro: "senha_curta", origem };
  }
  if (senha !== confirmacao) {
    return { erro: "senhas_diferentes", origem };
  }

  const auth = authDesteAmbiente();
  if (!auth) {
    return { erro: "indisponivel", origem };
  }

  const seguro = ehPedidoSeguro(request);
  const { renovacao } = lerCookiesDaSessao(request);
  const deviceTokenAtual = lerCookieDoDispositivo(request);
  const claims = lerClaimsDoToken(sessao.acesso);
  // Segurança: em troca real de senha (claim precisa_definir_senha === false ou origem === alteracao), nunca preservar device_token.
  const ehFluxoPendente = claims.temClaimSenhaPendente
    ? claims.precisaDefinirSenha
    : origem === "cadastro" || origem === "recuperacao" || origem === "pendente";
  const manterDispositivoAtual = ehFluxoPendente && Boolean(deviceTokenAtual);

  const resultado = await auth.definirSenha({
    acesso: sessao.acesso,
    novaSenha: senha,
    manterDispositivoAtual,
    deviceTokenAtual,
    refreshToken: renovacao,
    visitante: sessao.visitante,
  });
  if (!resultado.ok) {
    if (resultado.motivo === "sessao_invalida") {
      // Apaga cookies locais ao invalidar sessão para impedir loop de redirecionamento com /entrar.
      const cabecalhos = new Headers();
      for (const linha of cookiesDeSaida(seguro)) cabecalhos.append("Set-Cookie", linha);
      throw redirect("/entrar", { headers: cabecalhos });
    }
    return { erro: resultado.motivo, origem };
  }

  const sessaoAtualizada = resultado.sessao
    ? sessaoAtualDe(resultado.sessao.access_token, sessao.visitante)
    : sessao;
  const conta = await lerMinhaConta(apiDoUsuario(sessaoAtualizada));
  const destino = conta.estado === "sem_conta" ? "/cadastro" : "/";

  const cabecalhos = new Headers();
  if (resultado.sessao) {
    for (const linha of cookiesDaSessao(resultado.sessao, seguro)) cabecalhos.append("Set-Cookie", linha);
  }
  if (!manterDispositivoAtual && deviceTokenAtual) {
    cabecalhos.append("Set-Cookie", cookieDoDispositivo(null, seguro));
  }
  const init = [...cabecalhos.entries()].length > 0 ? { headers: cabecalhos } : undefined;
  throw redirect(destino, init);
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function DefinirSenha({ loaderData, actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const enviando = navegacao.state !== "idle";
  const origem: Origem = actionData?.origem ?? loaderData?.origem ?? "alteracao";
  const textosDaTela = textoPorOrigem(origem);
  const erro = actionData?.erro ? textos.definirSenha.erros[actionData.erro] : null;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>

      <Form method="post" className="flex flex-col gap-4" noValidate>
        <input type="hidden" name="origem" value={origem} />
        <h1 className="font-titulo text-3xl font-bold">{textosDaTela.titulo}</h1>
        <p className="text-tinta-suave">{textosDaTela.corpo}</p>

        <label className="flex flex-col gap-2 font-semibold" htmlFor="senha">
          {textos.definirSenha.rotuloDaSenha}
          <input
            id="senha"
            name="senha"
            type="password"
            autoComplete="new-password"
            required
            minLength={8}
            aria-invalid={erro ? true : undefined}
            aria-describedby={erro ? "erro" : "ajuda-senha"}
            className={classeDoCampo}
          />
          <span id="ajuda-senha" className="text-sm font-normal text-tinta-suave">
            {textos.definirSenha.ajudaDaSenha}
          </span>
        </label>

        <label className="flex flex-col gap-2 font-semibold" htmlFor="confirmacao">
          {textos.definirSenha.rotuloDaConfirmacao}
          <input
            id="confirmacao"
            name="confirmacao"
            type="password"
            autoComplete="new-password"
            required
            minLength={8}
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

        <button type="submit" disabled={enviando} className={classeDoBotao}>
          {enviando ? textos.definirSenha.salvando : textos.definirSenha.salvar}
        </button>
      </Form>
    </main>
  );
}
