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

/**
 * Lê a posição uma vez. Prazo total de 10 s (o do navegador e o nosso são o mesmo): o que vier primeiro responde,
 * uma vez só. Qualquer falha devolve nulo (o servidor trata como "sem localização").
 */
function lerDistanciaAte(destino: Ponto): Promise<number | null> {
  return new Promise((resolver) => {
    if (typeof navigator === "undefined" || !("geolocation" in navigator)) {
      resolver(null);
      return;
    }
    let respondeu = false;
    const responder = (metros: number | null) => {
      if (respondeu) return;
      respondeu = true;
      clearTimeout(desistir);
      resolver(metros);
    };
    const desistir = setTimeout(() => responder(null), PRAZO_DA_LOCALIZACAO_MS);
    navigator.geolocation.getCurrentPosition(
      (posicao) => responder(distanciaEmMetros({ latitude: posicao.coords.latitude, longitude: posicao.coords.longitude }, destino)),
      () => responder(null),
      { enableHighAccuracy: true, timeout: PRAZO_DA_LOCALIZACAO_MS, maximumAge: 0 },
    );
  });
}

/**
 * Formulário de presença: no envio, mede a distância e preenche `distancia_m`. Um envio por vez: enquanto lê ou envia,
 * os botões ficam inertes e outro toque é ignorado (o envio nativo é sempre barrado). A distância é sempre a da
 * leitura deste toque: o campo é zerado antes de ler, então nada de metros de uma leitura anterior.
 */
export function FormularioDePresenca({
  destino,
  textoLendo,
  children,
  ...props
}: ComponentProps<typeof Form> & { destino: Ponto | null; textoLendo: string }) {
  const enviar = useSubmit();
  const campo = useRef<HTMLInputElement>(null);
  const [ocupado, setOcupado] = useState(false);
  return (
    <Form
      method="post"
      {...props}
      onSubmit={(evento) => {
        if (!destino) return;
        evento.preventDefault();
        if (ocupado) return;
        const formulario = evento.currentTarget;
        if (campo.current) campo.current.value = "";
        setOcupado(true);
        void lerDistanciaAte(destino)
          .then(async (metros) => {
            if (campo.current) campo.current.value = metros === null ? "" : String(metros);
            await enviar(formulario);
          })
          .finally(() => setOcupado(false));
      }}
    >
      <input ref={campo} type="hidden" name="distancia_m" defaultValue="" />
      {ocupado ? <p role="status">{textoLendo}</p> : null}
      <div inert={ocupado} className="contents">
        {children}
      </div>
    </Form>
  );
}
