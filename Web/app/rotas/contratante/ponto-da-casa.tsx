/**
 * "Estou no endereço agora": a localização do navegador é lida UMA vez, só no toque, e vira o ponto da casa (dois
 * campos escondidos do formulário). Nada fica guardado no navegador, e a web não chama serviço de mapas nem de
 * endereço. Negou a permissão, sem sinal, leitura imprecisa ou fora do Brasil: aviso claro e nenhum ponto.
 */
import { useState } from "react";

import { dentroDoBrasil, dentroDoDF, PRECISAO_MAXIMA_M, type Ponto } from "../../servidor/contratante/cadastro-casa";
import { textos } from "../../textos/pt-BR";

const t = textos.contratanteCadastro.ponto;
const PRAZO_MS = 15_000;

export type EstadoDoPonto = "vazio" | "lendo" | "marcado" | "negado" | "sem_sinal" | "impreciso" | "fora_do_brasil" | "sem_suporte";

/** O que fazer com uma leitura do navegador (separado para teste). */
export function avaliarLeitura(coords: { latitude: number; longitude: number; accuracy: number }): { estado: EstadoDoPonto; ponto: Ponto | null } {
  if (!Number.isFinite(coords.accuracy) || coords.accuracy > PRECISAO_MAXIMA_M) return { estado: "impreciso", ponto: null };
  // Seis casas decimais bastam (cerca de 10 cm): o resto da leitura não vai ao servidor.
  const ponto = { latitude: Number(coords.latitude.toFixed(6)), longitude: Number(coords.longitude.toFixed(6)) };
  return dentroDoBrasil(ponto) ? { estado: "marcado", ponto } : { estado: "fora_do_brasil", ponto: null };
}

/** Código 1 do navegador é a permissão negada; o resto (sem sinal, prazo) é "não deu agora". */
export const estadoDoErro = (codigo: number): EstadoDoPonto => (codigo === 1 ? "negado" : "sem_sinal");

export function PontoDaCasa({ inicial, erro }: { inicial: Ponto | null; erro?: string }) {
  const [estado, setEstado] = useState<EstadoDoPonto>(inicial ? "marcado" : "vazio");
  const [ponto, setPonto] = useState<Ponto | null>(inicial);

  const ler = () => {
    if (estado === "lendo") return;
    if (typeof navigator === "undefined" || !("geolocation" in navigator)) {
      setEstado("sem_suporte");
      return;
    }
    setPonto(null);
    setEstado("lendo");
    navigator.geolocation.getCurrentPosition(
      (posicao) => {
        const leitura = avaliarLeitura(posicao.coords);
        setPonto(leitura.ponto);
        setEstado(leitura.estado);
      },
      (falha) => setEstado(estadoDoErro(falha.code)),
      { enableHighAccuracy: true, timeout: PRAZO_MS, maximumAge: 0 },
    );
  };

  const aviso = estado === "marcado" || estado === "vazio" || estado === "lendo" ? null : t.avisos[estado];
  return (
    <fieldset className="flex flex-col gap-3 rounded-cartao border border-borda p-4" aria-describedby="ajuda-ponto">
      <legend className="px-1 font-semibold">{t.titulo}</legend>
      <p id="ajuda-ponto" className="text-sm text-tinta-suave">
        {t.ajuda}
      </p>
      <input type="hidden" name="latitude" value={ponto ? String(ponto.latitude) : ""} />
      <input type="hidden" name="longitude" value={ponto ? String(ponto.longitude) : ""} />
      <button type="button" onClick={ler} disabled={estado === "lendo"} className="min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg font-semibold disabled:opacity-60">
        {estado === "lendo" ? t.lendo : ponto ? t.marcarDeNovo : t.botao}
      </button>
      <div aria-live="polite">
        {estado === "marcado" && ponto ? (
          <p role="status" className="font-semibold">
            {dentroDoDF(ponto) ? t.marcado : t.marcadoForaDoDF}
          </p>
        ) : null}
        {aviso ? (
          <p role="alert" className="font-semibold">
            {aviso}
          </p>
        ) : null}
        {!aviso && erro ? (
          <p role="alert" className="font-semibold">
            {erro}
          </p>
        ) : null}
      </div>
    </fieldset>
  );
}
