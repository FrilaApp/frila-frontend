import { Form, Link, redirect, useNavigation } from "react-router";

import type { Api } from "../servidor/api";
import {
  bloquearCasa,
  denunciarCasa,
  ehUuid,
  type Falha,
  listarBloqueios,
  MINIMO_DO_RELATO,
  MOTIVOS_DA_DENUNCIA,
  type MotivoDaDenuncia,
  type TipoDeAlvo,
} from "../servidor/profissional/moderacao";
import { textos } from "../textos/pt-BR";

/**
 * Denunciar e bloquear, comum aos dois lados (o profissional denuncia a casa; a casa denuncia o profissional, 3.18).
 * Cada rota passa o tipo do alvo, os textos dela e os seus endereços; a regra e as chaves são as mesmas.
 */
export type TextosDaModeracao = {
  titulo: string;
  emergencia: string;
  ligar190: string;
  ligar180: string;
  motivo: string;
  motivos: Record<MotivoDaDenuncia, string>;
  relato: string;
  ajudaDoRelato: string;
  bloquearJunto: string;
  enviar: string;
  soBloquear: string;
  sobreBloquear: string;
  enviando: string;
  denunciaEnviada: string;
  bloqueada: string;
  alvoInvalido: string;
  resultado: Record<Exclude<Falha, "sem_sessao">, string>;
  bloqueados: string;
  nenhumBloqueio: string;
  desbloquear: string;
  desbloqueada: string;
  voltar: string;
};

/** O alvo vem do endereço (o `id` público que a vaga, o turno ou o perfil mostrou). A chave é uma por formulário. */
export function carregarDenuncia(request: Request) {
  const url = new URL(request.url);
  const alvo = url.searchParams.get("alvo") ?? "";
  const turno = url.searchParams.get("turno") ?? "";
  return { alvo: ehUuid(alvo) ? alvo : null, turno: ehUuid(turno) ? turno : null, chave: crypto.randomUUID() };
}

export async function agirNaDenuncia(api: Api | null, formulario: FormData, alvoTipo: TipoDeAlvo) {
  const alvoId = String(formulario.get("alvo") ?? "");
  // A chave desta submissão volta para a tela: um novo envio (depois de erro) usa a MESMA, e o servidor não duplica.
  const chave = String(formulario.get("chave") ?? "");
  const bloquear = formulario.get("intencao") === "bloquear" || formulario.get("bloquear") === "sim";
  // Repetir só o bloqueio: o protocolo já confirmado volta do formulário e continua na tela, mesmo se falhar de novo.
  const protocoloAnterior = String(formulario.get("protocolo") ?? "");
  let protocolo: string | null = /^[0-9A-F]{8}$/.test(protocoloAnterior) ? protocoloAnterior : null;
  if (formulario.get("intencao") !== "bloquear") {
    const motivo = String(formulario.get("motivo") ?? "");
    const denuncia = await denunciarCasa(api, {
      alvoId,
      alvoTipo,
      turnoId: String(formulario.get("turno") ?? "") || null,
      motivo: (MOTIVOS_DA_DENUNCIA as readonly string[]).includes(motivo) ? (motivo as MotivoDaDenuncia) : "outro",
      relato: String(formulario.get("relato") ?? ""),
      chave,
    });
    if (!denuncia.ok) {
      if (denuncia.motivo === "sem_sessao") throw redirect("/entrar");
      return { protocolo: null, bloqueada: false, erro: denuncia.motivo, chave, bloqueioPendente: false };
    }
    protocolo = denuncia.protocolo;
  }
  if (bloquear) {
    const bloqueio = await bloquearCasa(api, alvoId, false, alvoTipo);
    if (!bloqueio.ok && bloqueio.motivo === "sem_sessao") throw redirect("/entrar");
    if (!bloqueio.ok) {
      // A denúncia (se houve) já está salva: a tela mostra o protocolo e só oferece repetir o bloqueio.
      return { protocolo, bloqueada: false, erro: bloqueio.motivo === "sem_sessao" ? ("indisponivel" as const) : bloqueio.motivo, chave, bloqueioPendente: true };
    }
  }
  return { protocolo, bloqueada: bloquear, erro: null, chave, bloqueioPendente: false };
}

type DadosDaDenuncia = ReturnType<typeof carregarDenuncia>;
type RespostaDaDenuncia = Awaited<ReturnType<typeof agirNaDenuncia>>;

const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoBotaoSecundario = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-6 text-lg font-bold disabled:opacity-60";
const classeDoLink = "inline-flex min-h-11 items-center font-semibold underline underline-offset-4";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export function TelaDeDenuncia({
  dados,
  resposta,
  t,
  bloqueadosEm,
  voltarPara,
}: {
  dados: DadosDaDenuncia;
  resposta: RespostaDaDenuncia | undefined;
  t: TextosDaModeracao;
  bloqueadosEm: string;
  voltarPara: string;
}) {
  const { alvo, turno } = dados;
  // Depois de um envio, vale a chave daquele envio (a do loader é nova a cada leitura).
  const chave = resposta?.chave || dados.chave;
  const enviando = useNavigation().state !== "idle";
  const concluiu = resposta && !resposta.erro;
  const soFaltaBloquear = Boolean(resposta?.erro && resposta.bloqueioPendente);
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <section className="flex flex-col gap-3 rounded-cartao border border-borda bg-superficie p-4">
        <p className="font-semibold">{t.emergencia}</p>
        <p className="flex flex-wrap gap-4">
          <a href="tel:190" className={classeDoLink}>
            {t.ligar190}
          </a>
          <a href="tel:180" className={classeDoLink}>
            {t.ligar180}
          </a>
        </p>
      </section>
      {resposta?.erro ? <p role="alert">{t.resultado[resposta.erro]}</p> : null}
      {resposta?.protocolo && !concluiu ? (
        <p role="status" className="font-semibold">
          {t.denunciaEnviada.replace("{protocolo}", resposta.protocolo)}
        </p>
      ) : null}
      {soFaltaBloquear && alvo ? (
        <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
          <input type="hidden" name="alvo" value={alvo} />
          <input type="hidden" name="chave" value={chave} />
          <input type="hidden" name="protocolo" value={resposta?.protocolo ?? ""} />
          <input type="hidden" name="intencao" value="bloquear" />
          <button type="submit" disabled={enviando} className={classeDoBotaoSecundario}>
            {enviando ? t.enviando : t.soBloquear}
          </button>
        </Form>
      ) : concluiu ? (
        <div role="status" className="flex flex-col gap-2 font-semibold">
          {resposta.protocolo ? <p>{t.denunciaEnviada.replace("{protocolo}", resposta.protocolo)}</p> : null}
          {resposta.bloqueada ? <p>{t.bloqueada}</p> : null}
        </div>
      ) : !alvo ? (
        <p role="alert">{t.alvoInvalido}</p>
      ) : (
        <>
          <Form method="post" className="flex flex-col gap-4">
            <input type="hidden" name="alvo" value={alvo} />
            <input type="hidden" name="turno" value={turno ?? ""} />
            <input type="hidden" name="chave" value={chave} />
            <fieldset className="flex flex-col gap-2">
              <legend className="font-semibold">{t.motivo}</legend>
              {MOTIVOS_DA_DENUNCIA.map((motivo) => (
                <label key={motivo} className="flex min-h-12 items-center gap-3 rounded-controle border border-borda bg-superficie px-4">
                  <input type="radio" name="motivo" value={motivo} required className="size-5" />
                  <span>{t.motivos[motivo]}</span>
                </label>
              ))}
            </fieldset>
            <label className="flex flex-col gap-2 font-semibold" htmlFor="relato">
              {t.relato}
              <span id="ajuda-do-relato" className="text-sm font-normal text-tinta-suave">
                {t.ajudaDoRelato}
              </span>
              <textarea
                id="relato"
                name="relato"
                required
                minLength={MINIMO_DO_RELATO}
                rows={5}
                aria-describedby="ajuda-do-relato"
                className="w-full rounded-controle border border-borda bg-superficie p-3 text-lg"
              />
            </label>
            <label className="flex min-h-12 items-center gap-3">
              <input type="checkbox" name="bloquear" value="sim" className="size-5" />
              <span>{t.bloquearJunto}</span>
            </label>
            <button type="submit" disabled={enviando} className={classeDoBotao}>
              {enviando ? t.enviando : t.enviar}
            </button>
          </Form>
          <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
            <p>{t.sobreBloquear}</p>
            <input type="hidden" name="alvo" value={alvo} />
            <input type="hidden" name="intencao" value="bloquear" />
            <button type="submit" disabled={enviando} className={classeDoBotaoSecundario}>
              {enviando ? t.enviando : t.soBloquear}
            </button>
          </Form>
        </>
      )}
      <Link to={bloqueadosEm} className={classeDoLink}>
        {t.bloqueados}
      </Link>
      <Link to={voltarPara} className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}

/** Os bloqueios de quem chama, só do tipo que esta tela desfaz (o servidor guarda os dois sentidos). */
export async function carregarBloqueios(api: Api | null, alvoTipo: TipoDeAlvo) {
  const leitura = await listarBloqueios(api);
  if (leitura.estado !== "ok") return { estado: leitura.estado, bloqueios: [] };
  return {
    estado: "ok" as const,
    bloqueios: leitura.bloqueios.filter((b) => b.alvo_tipo === alvoTipo).map((b) => ({ alvoId: b.alvo_id, nome: b.nome })),
  };
}

export async function desbloquear(api: Api | null, formulario: FormData, alvoTipo: TipoDeAlvo) {
  const resultado = await bloquearCasa(api, String(formulario.get("alvo") ?? ""), true, alvoTipo);
  if (!resultado.ok && resultado.motivo === "sem_sessao") throw redirect("/entrar");
  return { erro: resultado.ok ? null : resultado.motivo === "sem_sessao" ? ("indisponivel" as const) : resultado.motivo };
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
export function TelaDeBloqueados({
  dados,
  resposta,
  t,
  voltarPara,
}: {
  dados: Awaited<ReturnType<typeof carregarBloqueios>>;
  resposta: Awaited<ReturnType<typeof desbloquear>> | undefined;
  t: TextosDaModeracao;
  voltarPara: string;
}) {
  const { estado, bloqueios } = dados;
  const enviando = useNavigation().state !== "idle";
  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col gap-5 p-6">
      <p className="font-titulo text-xl font-bold">{textos.marca}</p>
      <h1 className="font-titulo text-3xl font-bold">{t.bloqueados}</h1>
      {resposta ? <p role="status">{resposta.erro ? t.resultado[resposta.erro] : t.desbloqueada}</p> : null}
      {estado !== "ok" ? <p role="alert">{t.resultado[estado]}</p> : null}
      {estado === "ok" && bloqueios.length === 0 ? <p role="status">{t.nenhumBloqueio}</p> : null}
      <ul className="flex flex-col gap-3">
        {bloqueios.map((b) => (
          <li key={b.alvoId} className="flex items-center justify-between gap-3 rounded-cartao border border-borda bg-superficie p-4">
            <span className="font-semibold">{b.nome}</span>
            <Form method="post">
              <input type="hidden" name="alvo" value={b.alvoId} />
              <button type="submit" disabled={enviando} className="min-h-11 px-3 font-semibold underline underline-offset-4">
                {t.desbloquear}
              </button>
            </Form>
          </li>
        ))}
      </ul>
      <Link to={voltarPara} className={classeDoLink}>
        {t.voltar}
      </Link>
    </main>
  );
}
