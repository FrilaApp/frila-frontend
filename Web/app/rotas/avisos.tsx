import { env } from "cloudflare:workers";
import { useEffect, useRef, useState } from "react";
import { data, Link, redirect, useFetcher } from "react-router";

import { estadoDosAvisos, type EstadoDosAvisos, navegadorSuportaPush } from "../pwa/avisos";
import { usePlataforma } from "../pwa/navegador";
import { apiDoUsuario } from "../servidor/deste-ambiente";
import { exigirSessao } from "../servidor/guarda";
import { cookieDoAparelho, lerConfigDoPush, lerTokenDoAparelho, registrarAparelho, removerAparelho, tokenValido } from "../servidor/push";
import { ehPedidoSeguro } from "../servidor/sessao";
import { textos } from "../textos/pt-BR";
import type { Route } from "./+types/avisos";

const t = textos.pwa.avisos;

export function meta() {
  return [{ title: t.tituloDaAba }, { name: "robots", content: "noindex" }];
}

export async function loader({ context, request }: Route.LoaderArgs) {
  exigirSessao(context);
  // A config do app web do Firebase é pública (o navegador precisa dela para tirar o token); o token não volta daqui.
  return { config: lerConfigDoPush(env), registrado: lerTokenDoAparelho(request) !== null };
}

export async function action({ context, request }: Route.ActionArgs) {
  const sessao = exigirSessao(context);
  const formulario = await request.formData();
  const token = formulario.get("token_fcm");
  const seguro = ehPedidoSeguro(request);
  if (formulario.get("intencao") === "desligar") {
    const guardado = lerTokenDoAparelho(request);
    if (guardado) await removerAparelho(apiDoUsuario(sessao), guardado);
    return data({ ok: true as const }, { headers: { "Set-Cookie": cookieDoAparelho(null, seguro) } });
  }
  if (!tokenValido(token)) return { ok: false as const };
  const resultado = await registrarAparelho(apiDoUsuario(sessao), token);
  if (!resultado.ok && resultado.motivo === "sem_sessao") throw redirect("/entrar");
  if (!resultado.ok) return { ok: false as const };
  return data({ ok: true as const }, { headers: { "Set-Cookie": cookieDoAparelho(token, seguro) } });
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** Item 6.1: push no navegador. Pede a permissão no toque, tira o token do FCM e registra com `plataforma: web`. */
export default function Avisos({ loaderData }: Route.ComponentProps) {
  const { config, registrado } = loaderData;
  const plataforma = usePlataforma();
  const fetcher = useFetcher<typeof action>();
  const [estado, setEstado] = useState<EstadoDosAvisos | null>(null);
  const [falhou, setFalhou] = useState(false);
  const [ocupado, setOcupado] = useState(false);
  // Só renova uma vez por visita.
  const renovou = useRef(false);

  useEffect(() => {
    if (!plataforma) return;
    const suporta = navegadorSuportaPush();
    setEstado(
      estadoDosAvisos({ temConfig: config !== null, suporta, plataforma, permissao: suporta ? Notification.permission : "default", registrado }),
    );
  }, [plataforma, config, registrado]);

  useEffect(() => {
    if (fetcher.state !== "idle" || !fetcher.data) return;
    setOcupado(false);
    if (!fetcher.data.ok) setFalhou(true);
  }, [fetcher.state, fetcher.data]);

  async function registrar() {
    if (!config) return;
    renovou.current = true;
    setFalhou(false);
    setOcupado(true);
    try {
      // O pedido de permissão tem de sair do toque (o iPhone recusa fora dele).
      if (Notification.permission !== "granted" && (await Notification.requestPermission()) !== "granted") {
        setOcupado(false);
        setEstado(Notification.permission === "denied" ? "negado" : "desligado");
        return;
      }
      const { tirarToken } = await import("../pwa/token-do-push");
      const token = await tirarToken(config);
      fetcher.submit({ intencao: "ligar", token_fcm: token }, { method: "post" });
    } catch {
      setOcupado(false);
      setFalhou(true);
    }
  }

  async function desligar() {
    if (!config) return;
    setOcupado(true);
    try {
      const { apagarToken } = await import("../pwa/token-do-push");
      await apagarToken(config);
    } catch {
      // O registro no servidor sai de qualquer jeito (pelo cookie deste navegador).
    }
    fetcher.submit({ intencao: "desligar" }, { method: "post" });
  }

  // Com os avisos já ligados, renova o registro ao abrir a tela (o token do FCM pode mudar com o tempo).
  useEffect(() => {
    if (estado === "ligado" && !renovou.current) void registrar();
  }, [estado]);

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-center gap-4 p-6">
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p className="text-tinta-suave">{t.corpo}</p>

      {estado === "sem_config" ? <p>{t.semConfig}</p> : null}
      {estado === "sem_suporte" ? <p>{t.semSuporte}</p> : null}
      {estado === "embutido" ? <p>{textos.pwa.embutido.aviso}</p> : null}
      {estado === "negado" ? <p>{t.negado}</p> : null}
      {estado === "iphone_sem_instalar" ? (
        <>
          <p>{t.iphoneSemInstalar}</p>
          <p>
            <Link to="/instalar" className="inline-flex min-h-12 items-center rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao">
              {t.instalarPrimeiro}
            </Link>
          </p>
        </>
      ) : null}
      {estado === "desligado" ? (
        <>
          <p>{t.desligados}</p>
          <p>
            <button type="button" disabled={ocupado} onClick={() => void registrar()} className="min-h-12 rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao">
              {ocupado ? t.ligando : t.ligar}
            </button>
          </p>
        </>
      ) : null}
      {estado === "ligado" ? (
        <>
          <p role="status" className="font-semibold">
            {t.ligados}
          </p>
          <p>
            <button type="button" disabled={ocupado} onClick={() => void desligar()} className="min-h-12 rounded-controle border border-borda bg-superficie px-4 text-lg font-bold">
              {t.desligar}
            </button>
          </p>
        </>
      ) : null}
      {falhou ? <p role="alert">{t.falhou}</p> : null}

      <p>
        <Link to="/" className="inline-flex min-h-12 items-center font-semibold underline underline-offset-4">
          {textos.pwa.instalar.voltar}
        </Link>
      </p>
    </main>
  );
}
