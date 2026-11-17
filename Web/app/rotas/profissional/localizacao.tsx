/**
 * Presença com a distância medida no navegador, SÓ no toque (nunca em segundo plano, nunca na lista de vagas).
 * Vai ao servidor só a distância em metros até o local da vaga, nunca a coordenada (minimização da LGPD).
 * Sem JavaScript, sem permissão, sem sinal ou passado o prazo, o campo vai vazio, e o servidor decide (sem localização).
 */
import { type ComponentProps, useRef, useState } from "react";
import { Form, useSubmit } from "react-router";

export type Ponto = { latitude: number; longitude: number };

const PRAZO_DA_LOCALIZACAO_MS = 10_000;

/** Distância em metros entre dois pontos (fórmula de haversine). */
export function distanciaEmMetros(a: Ponto, b: Ponto): number {
  const raio = 6_371_000;
  const rad = (graus: number) => (graus * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLon = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLon / 2) ** 2;
  return Math.round(2 * raio * Math.asin(Math.sqrt(h)));
}

/** Lê a posição uma vez, com prazo. Qualquer falha devolve nulo (o servidor trata como "sem localização"). */
function lerDistanciaAte(destino: Ponto): Promise<number | null> {
  return new Promise((resolver) => {
    if (typeof navigator === "undefined" || !("geolocation" in navigator)) {
      resolver(null);
      return;
    }
    const desistir = setTimeout(() => resolver(null), PRAZO_DA_LOCALIZACAO_MS + 1000);
    navigator.geolocation.getCurrentPosition(
      (posicao) => {
        clearTimeout(desistir);
        resolver(distanciaEmMetros({ latitude: posicao.coords.latitude, longitude: posicao.coords.longitude }, destino));
      },
      () => {
        clearTimeout(desistir);
        resolver(null);
      },
      { enableHighAccuracy: true, timeout: PRAZO_DA_LOCALIZACAO_MS, maximumAge: 0 },
    );
  });
}

/** Formulário de presença: no envio, mede a distância e preenche o campo `distancia_m`. */
export function FormularioDePresenca({
  destino,
  textoLendo,
  children,
  ...props
}: ComponentProps<typeof Form> & { destino: Ponto | null; textoLendo: string }) {
  const enviar = useSubmit();
  const campo = useRef<HTMLInputElement>(null);
  const [lendo, setLendo] = useState(false);
  return (
    <Form
      method="post"
      {...props}
      onSubmit={(evento) => {
        if (!destino || lendo) return;
        evento.preventDefault();
        const formulario = evento.currentTarget;
        setLendo(true);
        void lerDistanciaAte(destino).then((metros) => {
          if (campo.current) campo.current.value = metros === null ? "" : String(metros);
          setLendo(false);
          void enviar(formulario);
        });
      }}
    >
      <input ref={campo} type="hidden" name="distancia_m" defaultValue="" />
      {lendo ? <p role="status">{textoLendo}</p> : null}
      {children}
    </Form>
  );
}
