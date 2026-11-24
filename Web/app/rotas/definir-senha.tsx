import { Form, redirect, useNavigation } from "react-router";

import { lerMinhaConta } from "../servidor/conta";
import { apiDoUsuario, authDesteAmbiente } from "../servidor/deste-ambiente";
import { exigirSessao } from "../servidor/guarda";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/definir-senha";

type Erro = keyof typeof textos.definirSenha.erros;
type Estado = { erro?: Erro };

export function meta() {
  return [{ title: textos.definirSenha.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export function loader({ context }: Route.LoaderArgs) {
  exigirSessao(context);
  return null;
}

export async function action({ request, context }: Route.ActionArgs): Promise<Estado> {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const senha = String(formulario.get("senha") ?? "");
  const confirmacao = String(formulario.get("confirmacao") ?? "");

  if (senha.length < 8) {
    return { erro: "senha_curta" };
  }
  if (senha !== confirmacao) {
    return { erro: "senhas_diferentes" };
  }

  const auth = authDesteAmbiente();
  if (!auth) {
    return { erro: "indisponivel" };
  }

  const resultado = await auth.atualizarSenha(sessao.acesso, senha);
  if (!resultado.ok) {
    if (resultado.motivo === "sessao_invalida") {
      throw redirect("/entrar");
    }
    return { erro: resultado.motivo };
  }

  const conta = await lerMinhaConta(apiDoUsuario(sessao.acesso));
  if (conta.estado === "sem_conta") {
    throw redirect("/cadastro");
  }
  throw redirect("/");
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function DefinirSenha({ actionData }: Route.ComponentProps) {
  const navegacao = useNavigation();
  const enviando = navegacao.state !== "idle";
  const erro = actionData?.erro ? textos.definirSenha.erros[actionData.erro] : null;

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>

      <Form method="post" className="flex flex-col gap-4" noValidate>
        <h1 className="font-titulo text-3xl font-bold">{textos.definirSenha.titulo}</h1>
        <p className="text-tinta-suave">{textos.definirSenha.corpo}</p>

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
