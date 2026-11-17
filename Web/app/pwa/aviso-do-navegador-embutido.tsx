import { useState } from "react";
import { useHref, useLocation } from "react-router";

import { textos } from "../textos/pt-BR";
import { useAgente, useOrigem, usePlataforma } from "./navegador";
import { ehAndroid, linkParaONavegador } from "./plataforma";

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** Item 1.8: no navegador de dentro de uma rede social, pede para abrir no navegador de verdade. */
export function AvisoDoNavegadorEmbutido() {
  const plataforma = usePlataforma();
  const agente = useAgente();
  const origem = useOrigem();
  const local = useLocation();
  const caminho = useHref(`${local.pathname}${local.search}`);
  const [fechado, setFechado] = useState(false);
  if (plataforma !== "embutido" || fechado) return null;

  return (
    <aside role="status" className="flex flex-col gap-2 border-b border-borda bg-superficie p-4">
      <p>{textos.pwa.embutido.aviso}</p>
      <p className="flex flex-wrap gap-2">
        {agente && origem && ehAndroid(agente) ? (
          <a href={linkParaONavegador(`${origem}${caminho}`)} className="inline-flex min-h-11 items-center rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao">
            {textos.pwa.embutido.abrirNoNavegador}
          </a>
        ) : null}
        <button type="button" onClick={() => setFechado(true)} className="min-h-11 px-4 font-semibold underline underline-offset-4">
          {textos.pwa.embutido.fechar}
        </button>
      </p>
    </aside>
  );
}
