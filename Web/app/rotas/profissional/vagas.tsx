import { Form, Link } from "react-router";

import { apiDoUsuario } from "../../servidor/deste-ambiente";
import { exigirSessao } from "../../servidor/guarda";
import { formatarDistancia, formatarPeriodo, formatarValor } from "../../servidor/profissional/formato";
import { filtrosDaUrl, listarVagasAbertas, VAGAS_POR_PAGINA } from "../../servidor/profissional/vagas";
import { textos } from "../../textos/pt-BR";
import type { Route } from "./+types/vagas";

const t = textos.profissional.vagas;
const DISTANCIAS = [5, 10, 15, 25] as const;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

/** Vagas abertas, da mais perto para a mais longe do ponto base. A web não pede a posição do navegador. */
export async function loader({ context, request }: Route.LoaderArgs) {
  const sessao = exigirSessao(context);
  const filtros = filtrosDaUrl(new URL(request.url));
  const leitura = await listarVagasAbertas(apiDoUsuario(sessao.acesso), filtros);
  // Só o que a tela mostra, já formatado no servidor.
  const vagas =
    leitura.estado === "ok"
      ? leitura.vagas.map((vaga) => ({
          id: vaga.id,
          funcao: vaga.funcao.nome,
          casa: vaga.estabelecimento.nome,
          regiao: vaga.regiao_administrativa,
          periodo: formatarPeriodo(vaga.inicio_em, vaga.fim_em),
          valor: formatarValor(vaga.valor_centavos),
          distancia: formatarDistancia(vaga.distancia_km),
          posicoes: vaga.posicoes_abertas,
          modo: vaga.modo,
        }))
      : [];
  return {
    estado: leitura.estado,
    vagas,
    filtros,
    proximo: leitura.estado === "ok" && leitura.temMais ? filtros.deslocamento + VAGAS_POR_PAGINA : null,
  };
}

function linkComFiltros(filtros: { data: string | null; distanciaMaxKm: number | null }, deslocamento: number): string {
  const busca = new URLSearchParams();
  if (filtros.data) busca.set("data", filtros.data);
  if (filtros.distanciaMaxKm) busca.set("distancia", String(filtros.distanciaMaxKm));
  if (deslocamento > 0) busca.set("deslocamento", String(deslocamento));
  const texto = busca.toString();
  return texto ? `/vagas?${texto}` : "/vagas";
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao = "min-h-12 rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

const AVISO_DO_ESTADO = {
  sem_ponto_base: t.semPontoBase,
  perfil_incompativel: t.perfilIncompativel,
  conta_suspensa: t.contaSuspensa,
  indisponivel: t.indisponivel,
} as const;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export default function Vagas({ loaderData }: Route.ComponentProps) {
  const { estado, vagas, filtros, proximo } = loaderData;

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>

      {estado === "ok" ? (
        <>
          <p className="text-tinta-suave">{t.corpo}</p>
          <Form method="get" className="flex flex-col gap-3 rounded-cartao border border-borda bg-superficie p-4">
            <h2 className="font-semibold">{t.filtros}</h2>
            <label className="flex flex-col gap-2 font-semibold" htmlFor="data">
              {t.data}
              <input id="data" name="data" type="date" defaultValue={filtros.data ?? ""} className={classeDoCampo} />
            </label>
            <label className="flex flex-col gap-2 font-semibold" htmlFor="distancia">
              {t.distancia}
              <select id="distancia" name="distancia" defaultValue={filtros.distanciaMaxKm ?? ""} className={classeDoCampo}>
                <option value="">{t.qualquerDistancia}</option>
                {DISTANCIAS.map((km) => (
                  <option key={km} value={km}>
                    {t.distanciaEmKm.replace("{km}", String(km))}
                  </option>
                ))}
              </select>
            </label>
            <div className="flex flex-wrap items-center gap-4">
              <button type="submit" className={classeDoBotao}>
                {t.aplicar}
              </button>
              {filtros.data || filtros.distanciaMaxKm ? (
                <Link to="/vagas" className={classeDoLink}>
                  {t.limpar}
                </Link>
              ) : null}
            </div>
          </Form>

          {vagas.length === 0 ? <p role="status">{t.vazia}</p> : null}
          <ul className="flex flex-col gap-3">
            {vagas.map((vaga) => (
              <li key={vaga.id}>
                <Link
                  to={`/vagas/${vaga.id}`}
                  className="flex flex-col gap-1 rounded-cartao border border-borda bg-superficie p-4"
                >
                  <span className="text-lg font-bold">
                    {vaga.funcao} · {vaga.valor}
                  </span>
                  <span>{vaga.periodo}</span>
                  <span className="text-tinta-suave">
                    {vaga.casa} · {vaga.regiao} · {t.distanciaDaVaga.replace("{distancia}", vaga.distancia)}
                  </span>
                  <span className="text-sm text-tinta-suave">
                    {t.posicoes.replace("{n}", String(vaga.posicoes))} · {vaga.modo === "urgencia" ? t.urgencia : t.selecao}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
          <div className="flex flex-wrap gap-4">
            {proximo !== null ? (
              <Link to={linkComFiltros(filtros, proximo)} className={classeDoLink}>
                {t.mais}
              </Link>
            ) : null}
            {filtros.deslocamento > 0 ? (
              <Link to={linkComFiltros(filtros, 0)} className={classeDoLink}>
                {t.voltarAoComeco}
              </Link>
            ) : null}
          </div>
        </>
      ) : (
        <p role="alert">{AVISO_DO_ESTADO[estado]}</p>
      )}
      {estado === "conta_suspensa" ? (
        <Link to="/conta/suspensa" className={classeDoLink}>
          {textos.suspensao.verSituacao}
        </Link>
      ) : null}

      <Link to="/conta" className={classeDoLink}>
        {textos.contaDados.abrir}
      </Link>

      <Link to="/" className={classeDoLink}>
        {t.voltarAoInicio}
      </Link>
    </main>
  );
}
