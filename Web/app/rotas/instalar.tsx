import { Link } from "react-router";

import { pedirInstalacao, useInstalouAgora, usePlataforma, usePodeInstalar } from "../pwa/navegador";
import { textos } from "../textos/pt-BR";

export function meta() {
  return [{ title: textos.pwa.instalar.tituloDaAba }, { name: "robots", content: "noindex" }];
}

const t = textos.pwa.instalar;

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** Item 1.9: instalar na tela de início. O Chrome tem o pedido próprio; o iPhone só pelo menu Compartilhar. */
export default function Instalar() {
  const plataforma = usePlataforma();
  const podeInstalar = usePodeInstalar();
  const instalouAgora = useInstalouAgora();

  return (
    <main className="mx-auto flex min-h-dvh max-w-xl flex-col justify-center gap-4 p-6">
      <h1 className="font-titulo text-3xl font-bold">{t.titulo}</h1>
      <p className="text-tinta-suave">{t.corpo}</p>

      {instalouAgora ? (
        <p role="status" className="font-semibold">
          {t.instalou}
        </p>
      ) : plataforma === "instalada" ? (
        <p className="font-semibold">{t.jaInstalado}</p>
      ) : plataforma === "embutido" ? (
        // O aviso do topo (raiz) já explica como sair do navegador embutido.
        <p>{textos.pwa.embutido.aviso}</p>
      ) : plataforma === "iphone" ? (
        <section className="flex flex-col gap-3 rounded-cartao border border-borda bg-superficie p-4">
          <h2 className="font-titulo text-xl font-bold">{t.tituloDoIphone}</h2>
          <ol className="flex list-decimal flex-col gap-2 pl-6">
            <li>{t.passosDoIphone.compartilhar}</li>
            <li>{t.passosDoIphone.adicionar}</li>
            <li>{t.passosDoIphone.confirmar}</li>
          </ol>
        </section>
      ) : podeInstalar ? (
        <p>
          <button
            type="button"
            onClick={() => void pedirInstalacao()}
            className="min-h-12 rounded-controle bg-acao px-6 text-xl font-bold text-sobre-acao"
          >
            {t.botao}
          </button>
        </p>
      ) : plataforma === "outro" ? (
        <p>{t.outroNavegador}</p>
      ) : null}

      <p>
        <Link to="/" className="inline-flex min-h-12 items-center font-semibold underline underline-offset-4">
          {t.voltar}
        </Link>
      </p>
    </main>
  );
}
