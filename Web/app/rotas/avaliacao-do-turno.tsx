import { useEffect, useState } from "react";
import { Form } from "react-router";

export type TextosDaAvaliacao = { titulo: string; pergunta: string; sim: string; nao: string; enviar: string; dica: string; enviando: string };

const classeDoBotao = "min-h-12 w-full rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao disabled:opacity-60";

/**
 * A avaliação depois do turno, nos dois lados, como o iOS (TelaAvaliacao): escolher Sim ou Não, poder trocar, e só
 * então enviar. O voto não tem volta (resposta diferente é 409), então o toque na opção não envia nada.
 * Sem JavaScript, os rádios são obrigatórios e o navegador não deixa enviar sem escolha; com ele, o botão fica
 * desligado até a escolha (como o iOS).
 */
export function FormularioDaAvaliacao({ turnoId, enviando, textos }: { turnoId: string; enviando: boolean; textos: TextosDaAvaliacao }) {
  const [escolha, setEscolha] = useState<"sim" | "nao" | null>(null);
  const [hidratado, setHidratado] = useState(false);
  useEffect(() => setHidratado(true), []);
  return (
    <Form method="post" className="flex flex-col gap-3 rounded-cartao border border-borda p-4">
      <h2 className="font-semibold">{textos.titulo}</h2>
      <fieldset className="flex flex-col gap-2" aria-describedby="dica-da-avaliacao">
        <legend className="mb-2">{textos.pergunta}</legend>
        {(["sim", "nao"] as const).map((valor) => (
          <label key={valor} className="flex min-h-12 items-center gap-3 rounded-controle border border-borda px-4 text-lg font-semibold">
            <input
              type="radio"
              name="resposta"
              value={valor}
              required
              checked={escolha === valor}
              onChange={() => setEscolha(valor)}
              className="size-5"
            />
            {valor === "sim" ? textos.sim : textos.nao}
          </label>
        ))}
      </fieldset>
      {escolha === null ? (
        <p id="dica-da-avaliacao" className="text-sm text-tinta-suave">
          {textos.dica}
        </p>
      ) : null}
      <input type="hidden" name="intencao" value="avaliar" />
      <input type="hidden" name="turno_id" value={turnoId} />
      <button type="submit" disabled={enviando || (hidratado && escolha === null)} className={classeDoBotao}>
        {enviando ? textos.enviando : textos.enviar}
      </button>
    </Form>
  );
}
