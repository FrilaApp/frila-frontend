import { Form, Link, redirect, useNavigation } from "react-router";

import { lerRegioes } from "../../servidor/contratante/busca";
import { type CampoDaCasa, cadastrarCasa, lerFormularioDaCasa, lerPonto, TIPOS, type ValoresDaCasa, valoresDoFormulario } from "../../servidor/contratante/cadastro-casa";
import { lerMinhasCasas } from "../../servidor/contratante/casa";
import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/cadastro-casa";
import { PontoDaCasa } from "./ponto-da-casa";

const t = textos.contratanteCadastro;
type Erros = Partial<Record<CampoDaCasa, string>> & { geral?: string };

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const [casas, regioes] = await Promise.all([lerMinhasCasas(api), lerRegioes(api)]);
  if (casas.estado === "sem_sessao") throw redirect("/entrar");
  return {
    // Conta de profissional não cadastra casa (o servidor recusa com perfil_incompativel): a tela já avisa.
    perfilProfissional: casas.estado === "perfil_profissional",
    regioes: (regioes ?? []).map((regiao) => regiao.nome),
  };
}

const VAZIO: ValoresDaCasa = { nome: "", documento: "", tipo: "", endereco: "", regiao_administrativa: "", latitude: "", longitude: "" };

export async function action({ context, request }: Route.ActionArgs): Promise<{ erros: Erros; valores: ValoresDaCasa }> {
  const sessao = exigirSessao(context);
  const api = apiDoUsuario(sessao);
  const valores = valoresDoFormulario(await request.formData());
  const volta = (erros: Erros) => ({ erros, valores });

  const regioes = await lerRegioes(api);
  if (!regioes) return volta({ geral: t.erros.regioes });
  const lido = lerFormularioDaCasa(valores, regioes.map((regiao) => regiao.nome));
  if (!lido.ok) {
    const erros: Erros = { geral: t.erros.temErro };
    for (const [campo, problema] of Object.entries(lido.erros) as Array<[CampoDaCasa, string]>) {
      erros[campo] = campo === "ponto" ? (problema === "fora_do_brasil" ? t.erros.fora_do_brasil : t.erros.sem_ponto) : t.erros[campo];
    }
    return volta(erros);
  }

  const resultado = await cadastrarCasa(api, lido.casa);
  if (resultado.ok) throw redirect(`/painel?casa=${resultado.casaId}`);
  if (resultado.motivo === "sem_sessao") throw redirect("/entrar");
  if (resultado.motivo === "campo") return volta({ geral: t.erros.temErro, [resultado.campo]: resultado.campo === "ponto" ? t.erros.ponto : t.erros[resultado.campo] });
  return volta({ geral: t.erros[resultado.motivo] });
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoRotulo = "flex flex-col gap-2 font-semibold";

function Aviso({ id, texto }: { id: string; texto?: string }) {
  return texto ? (
    <p id={id} role="alert" className="font-semibold">
      {texto}
    </p>
  ) : null;
}

const sobre = (erros: Erros, campo: CampoDaCasa, ajuda?: string) => ({
  "aria-invalid": erros[campo] ? true : undefined,
  "aria-describedby": [erros[campo] ? `erro-${campo}` : null, ajuda].filter(Boolean).join(" ") || undefined,
});

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function CadastroDaCasa({ loaderData, actionData }: Route.ComponentProps) {
  const salvando = useNavigation().state !== "idle";
  const erros: Erros = actionData?.erros ?? {};
  const valores = actionData?.valores ?? VAZIO;
  // Depois de uma recusa, o ponto lido no toque volta ao formulário (é o mesmo, não uma leitura nova).
  const pontoLido = lerPonto(valores);

  if (loaderData.perfilProfissional) {
    return (
      <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 p-6">
        <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
        <p role="status">{t.erros.perfil_incompativel}</p>
        <Link to="/" className="min-h-11 font-semibold underline underline-offset-4">
          {textos.contratante.painel.voltarAoInicio}
        </Link>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col gap-6 p-6">
      <Link to="/painel" className="min-h-11 font-semibold underline underline-offset-4">
        {t.voltar}
      </Link>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      {loaderData.regioes.length === 0 ? <p role="status">{t.erros.regioes}</p> : null}

      <Form method="post" className="flex flex-col gap-5" noValidate>
        <Aviso id="erro-geral" texto={erros.geral} />

        <label className={classeDoRotulo}>
          {t.nome}
          <input name="nome" type="text" required autoComplete="organization" defaultValue={valores.nome} className={classeDoCampo} {...sobre(erros, "nome")} />
          <Aviso id="erro-nome" texto={erros.nome} />
        </label>

        <label className={classeDoRotulo}>
          {t.documento}
          <span id="ajuda-documento" className="text-sm font-normal text-tinta-suave">
            {t.ajudaDoDocumento}
          </span>
          <input name="documento" type="text" inputMode="numeric" required autoComplete="off" defaultValue={valores.documento} className={classeDoCampo} {...sobre(erros, "documento", "ajuda-documento")} />
          <Aviso id="erro-documento" texto={erros.documento} />
        </label>

        <label className={classeDoRotulo}>
          {t.tipo}
          <select name="tipo" required defaultValue={valores.tipo} className={classeDoCampo} {...sobre(erros, "tipo")}>
            <option value="">{t.escolhaOTipo}</option>
            {TIPOS.map((tipo) => (
              <option key={tipo} value={tipo}>
                {t.tipos[tipo]}
              </option>
            ))}
          </select>
          <Aviso id="erro-tipo" texto={erros.tipo} />
        </label>

        <label className={classeDoRotulo}>
          {t.endereco}
          <span id="ajuda-endereco" className="text-sm font-normal text-tinta-suave">
            {t.ajudaDoEndereco}
          </span>
          <input name="endereco" type="text" required autoComplete="street-address" defaultValue={valores.endereco} className={classeDoCampo} {...sobre(erros, "endereco", "ajuda-endereco")} />
          <Aviso id="erro-endereco" texto={erros.endereco} />
        </label>

        <label className={classeDoRotulo}>
          {t.regiao}
          <span id="ajuda-regiao" className="text-sm font-normal text-tinta-suave">
            {t.ajudaDaRegiao}
          </span>
          <select name="regiao_administrativa" required defaultValue={valores.regiao_administrativa} className={classeDoCampo} {...sobre(erros, "regiao_administrativa", "ajuda-regiao")}>
            <option value="">{t.escolhaARegiao}</option>
            {loaderData.regioes.map((regiao) => (
              <option key={regiao} value={regiao}>
                {regiao}
              </option>
            ))}
          </select>
          <Aviso id="erro-regiao_administrativa" texto={erros.regiao_administrativa} />
        </label>

        <PontoDaCasa inicial={pontoLido.ok ? pontoLido.ponto : null} erro={erros.ponto} />

        <button type="submit" disabled={salvando} className="min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60">
          {salvando ? t.salvando : t.salvar}
        </button>
      </Form>
    </main>
  );
}
