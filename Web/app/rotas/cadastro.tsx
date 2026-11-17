import { Form, redirect, useNavigation } from "react-router";

import { type CampoDoCadastro, criarConta, lerMinhaConta, type Perfil } from "../servidor/conta";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { exigirSessao } from "../servidor/guarda";
import { telefoneParaE164 } from "../servidor/telefone";
import { textos } from "../textos/pt-BR";
import { VERSAO_DOS_TERMOS } from "../versao";
import type { Route } from "./+types/cadastro";

type Campo = Exclude<CampoDoCadastro, "termos_versao"> | "aceite";
type Erros = Partial<Record<Campo, string>> & { geral?: string };
type Valores = { perfil: string; nome: string; telefone: string; nascimento: string };
type Retorno = { erros: Erros; valores: Valores };

const TERMOS = "https://frilabr.com/termos";
const PRIVACIDADE = "https://frilabr.com/privacidade";
const t = textos.cadastro;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const conta = await lerMinhaConta(apiDoUsuario(sessao.acesso));
  if (conta.estado === "ok") {
    throw redirect("/");
  }
  return { email: sessao.email, indisponivel: conta.estado === "indisponivel" };
}

export async function action({ request, context }: Route.ActionArgs): Promise<Retorno> {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const valores: Valores = {
    perfil: String(formulario.get("perfil") ?? ""),
    nome: String(formulario.get("nome") ?? "").trim().replace(/\s+/g, " "),
    telefone: String(formulario.get("telefone") ?? "").trim(),
    nascimento: String(formulario.get("nascimento") ?? ""),
  };

  // Aqui só se confere se dá para montar o pedido. A regra (idade, nome aceito, versão dos termos) é do servidor.
  const erros: Erros = {};
  const perfil = valores.perfil === "profissional" || valores.perfil === "contratante" ? (valores.perfil as Perfil) : null;
  const telefone = telefoneParaE164(valores.telefone);
  if (!perfil) erros.perfil = t.erros.perfil;
  if (valores.nome.length < 2) erros.nome = t.erros.nomeObrigatorio;
  if (!telefone) erros.telefone = t.erros.telefone;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(valores.nascimento)) erros.nascimento = t.erros.nascimentoObrigatorio;
  if (formulario.get("aceite") !== "sim") erros.aceite = t.erros.aceite;
  if (!perfil || !telefone || Object.keys(erros).length > 0) {
    return { erros, valores };
  }

  const resultado = await criarConta(apiDoUsuario(sessao.acesso), {
    perfil,
    nome: valores.nome,
    telefone,
    nascimento: valores.nascimento,
    termos_versao: VERSAO_DOS_TERMOS,
  });
  if (resultado.ok || resultado.motivo === "ja_existe") {
    throw redirect("/");
  }
  if (resultado.motivo === "sem_sessao") {
    throw redirect("/entrar");
  }
  if (resultado.motivo === "menor_de_idade") {
    return { erros: { nascimento: t.erros.menorDeIdade }, valores };
  }
  if (resultado.motivo === "campo") {
    const doServidor: Record<CampoDoCadastro, Erros> = {
      perfil: { perfil: t.erros.perfil },
      nome: { nome: resultado.tipo === "obrigatorio" ? t.erros.nomeObrigatorio : t.erros.nomeInvalido },
      telefone: { telefone: t.erros.telefone },
      nascimento: { nascimento: resultado.tipo === "obrigatorio" ? t.erros.nascimentoObrigatorio : t.erros.nascimentoInvalido },
      termos_versao: { geral: t.erros.termosDesatualizados },
    };
    return { erros: doServidor[resultado.campo], valores };
  }
  return { erros: { geral: t.erros.indisponivel }, valores };
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-4 text-lg font-bold text-tinta disabled:opacity-60";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";

function Aviso({ id, texto }: { id: string; texto?: string }) {
  return texto ? (
    <p id={id} role="alert" className="font-semibold">
      {texto}
    </p>
  ) : null;
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Cadastro({ loaderData, actionData }: Route.ComponentProps) {
  const enviando = useNavigation().state !== "idle";
  const erros = actionData?.erros ?? {};
  const valores = actionData?.valores ?? { perfil: "", nome: "", telefone: "", nascimento: "" };

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p className="text-tinta-suave">
        {t.corpo} <strong className="break-all text-tinta">{loaderData.email ?? textos.conta.semEmail}</strong>.
      </p>
      {loaderData.indisponivel ? <p role="status">{t.contaIndisponivel}</p> : null}

      <Form method="post" className="flex flex-col gap-5" noValidate>
        <Aviso id="erro-geral" texto={erros.geral} />

        <fieldset className="flex flex-col gap-2" aria-describedby={erros.perfil ? "erro-perfil" : "ajuda-perfil"}>
          <legend className="font-semibold">{t.perfil}</legend>
          <p id="ajuda-perfil" className="text-sm text-tinta-suave">
            {t.ajudaDoPerfil}
          </p>
          {(["contratante", "profissional"] as const).map((opcao) => (
            <label key={opcao} className="flex min-h-12 items-center gap-3 rounded-controle border border-borda bg-superficie px-4">
              <input type="radio" name="perfil" value={opcao} defaultChecked={valores.perfil === opcao} className="size-5" required />
              <span>
                <strong>{textos.conta.perfil[opcao]}</strong>: {t.opcoesDoPerfil[opcao]}
              </span>
            </label>
          ))}
          <Aviso id="erro-perfil" texto={erros.perfil} />
        </fieldset>

        <label className={classeDoRotulo} htmlFor="nome">
          {t.nome}
          <input
            id="nome"
            name="nome"
            type="text"
            autoComplete="name"
            required
            defaultValue={valores.nome}
            aria-invalid={erros.nome ? true : undefined}
            aria-describedby={erros.nome ? "erro-nome" : undefined}
            className={classeDoCampo}
          />
          <Aviso id="erro-nome" texto={erros.nome} />
        </label>

        <label className={classeDoRotulo} htmlFor="telefone">
          {t.telefone}
          <span id="ajuda-telefone" className="text-sm font-normal text-tinta-suave">
            {t.ajudaDoTelefone}
          </span>
          <input
            id="telefone"
            name="telefone"
            type="tel"
            autoComplete="tel-national"
            inputMode="tel"
            required
            defaultValue={valores.telefone}
            aria-invalid={erros.telefone ? true : undefined}
            aria-describedby={erros.telefone ? "erro-telefone ajuda-telefone" : "ajuda-telefone"}
            className={classeDoCampo}
          />
          <Aviso id="erro-telefone" texto={erros.telefone} />
        </label>

        <label className={classeDoRotulo} htmlFor="nascimento">
          {t.nascimento}
          <span id="ajuda-nascimento" className="text-sm font-normal text-tinta-suave">
            {t.ajudaDoNascimento}
          </span>
          <input
            id="nascimento"
            name="nascimento"
            type="date"
            autoComplete="bday"
            required
            defaultValue={valores.nascimento}
            aria-invalid={erros.nascimento ? true : undefined}
            aria-describedby={erros.nascimento ? "erro-nascimento ajuda-nascimento" : "ajuda-nascimento"}
            className={classeDoCampo}
          />
          <Aviso id="erro-nascimento" texto={erros.nascimento} />
        </label>

        <div className="flex flex-col gap-2">
          <label className="flex min-h-12 items-start gap-3">
            <input
              type="checkbox"
              name="aceite"
              value="sim"
              required
              className="mt-1 size-5 shrink-0"
              aria-describedby={erros.aceite ? "erro-aceite links-dos-termos" : "links-dos-termos"}
            />
            <span>{t.aceite}</span>
          </label>
          <p id="links-dos-termos" className="text-sm text-tinta-suave">
            <a href={TERMOS} target="_blank" rel="noreferrer" className="underline underline-offset-4">
              {textos.entrar.linkDosTermos}
            </a>{" "}
            ·{" "}
            <a href={PRIVACIDADE} target="_blank" rel="noreferrer" className="underline underline-offset-4">
              {textos.entrar.linkDaPrivacidade}
            </a>{" "}
            {t.abreEmOutraAba}
          </p>
          <Aviso id="erro-aceite" texto={erros.aceite} />
        </div>

        <button type="submit" disabled={enviando} className={classeDoBotao}>
          {enviando ? t.enviando : t.criar}
        </button>
      </Form>

      <Form method="post" action="/sair">
        <button type="submit" className="min-h-11 font-semibold underline underline-offset-4">
          {t.sairEUsarOutroEmail}
        </button>
      </Form>
    </main>
  );
}
