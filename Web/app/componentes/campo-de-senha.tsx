import { useEffect, useRef, useState } from "react";

export type CampoDeSenhaProps = {
  id: string;
  name: string;
  autoComplete: "new-password" | "current-password";
  required?: boolean;
  minLength?: number;
  ariaInvalid?: boolean;
  ariaDescribedBy?: string;
  className?: string;
  /** Quando true (ex.: formulário enviando), força retorno imediato para oculto. */
  ocultarAoEnviar?: boolean;
  rotuloMostrar?: string;
  rotuloOcultar?: string;
};

function IconeOlho({ visivel }: { visivel: boolean }) {
  if (visivel) {
    return (
      <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
        focusable="false"
      >
        <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" />
        <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" />
        <path d="M14.12 14.12a3 3 0 1 1-4.24-4.24" />
        <line x1="1" y1="1" x2="23" y2="23" />
      </svg>
    );
  }
  return (
    <svg
      width="20"
      height="20"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
  );
}

/**
 * Campo de senha reutilizável com botão mostrar/ocultar (padrão sempre oculto).
 * - Sem JavaScript, o botão não é renderizado (progressive enhancement).
 * - Volta para oculto ao sair da tela, ao ir para segundo plano e ao enviar.
 * - Preserva valor, posição do cursor/seleção, autocomplete e desativa autocorreção/spellcheck.
 * - Não replica a senha em atributos ou nós extras do DOM.
 */
export function CampoDeSenha({
  id,
  name,
  autoComplete,
  required,
  minLength,
  ariaInvalid,
  ariaDescribedBy,
  className = "",
  ocultarAoEnviar = false,
  rotuloMostrar = "Mostrar senha",
  rotuloOcultar = "Ocultar senha",
}: CampoDeSenhaProps) {
  const [hidratado, setHidratado] = useState(false);
  const [visivel, setVisivel] = useState(false);
  const inputRef = useRef<HTMLInputElement | null>(null);
  const selecaoPendenteRef = useRef<{ inicio: number | null; fim: number | null; manterFoco: boolean } | null>(null);

  useEffect(() => {
    setHidratado(true);
  }, []);

  // Volta a oculto quando o formulário entra em envio.
  useEffect(() => {
    if (ocultarAoEnviar) {
      setVisivel(false);
    }
  }, [ocultarAoEnviar]);

  // Volta a oculto ao ir para segundo plano ou sair da página.
  useEffect(() => {
    if (!visivel) return;
    const ocultar = () => setVisivel(false);
    const aoMudarVisibilidade = () => {
      if (document.hidden) ocultar();
    };
    document.addEventListener("visibilitychange", aoMudarVisibilidade);
    window.addEventListener("pagehide", ocultar);
    return () => {
      document.removeEventListener("visibilitychange", aoMudarVisibilidade);
      window.removeEventListener("pagehide", ocultar);
    };
  }, [visivel]);

  // Restaura posição do cursor/seleção após alternar type="password" <-> "text".
  useEffect(() => {
    const pendente = selecaoPendenteRef.current;
    const el = inputRef.current;
    if (!pendente || !el) return;
    selecaoPendenteRef.current = null;
    if (pendente.manterFoco) {
      el.focus({ preventScroll: true });
    }
    if (pendente.inicio !== null && pendente.fim !== null) {
      try {
        el.setSelectionRange(pendente.inicio, pendente.fim);
      } catch {
        // Alguns navegadores antigos podem recusar setSelectionRange em transição; ignorar sem perder o valor.
      }
    }
  }, [visivel]);

  function alternarVisibilidade() {
    const el = inputRef.current;
    if (el) {
      selecaoPendenteRef.current = {
        inicio: el.selectionStart,
        fim: el.selectionEnd,
        manterFoco: document.activeElement === el,
      };
    }
    setVisivel((atual) => !atual);
  }

  return (
    <div className="relative flex items-center">
      <input
        ref={inputRef}
        id={id}
        name={name}
        type={visivel ? "text" : "password"}
        autoComplete={autoComplete}
        autoCorrect="off"
        autoCapitalize="none"
        spellCheck={false}
        required={required}
        minLength={minLength}
        aria-invalid={ariaInvalid ? true : undefined}
        aria-describedby={ariaDescribedBy}
        className={`${className}${hidratado ? " pr-14" : ""}`}
      />
      {hidratado ? (
        <button
          type="button"
          onMouseDown={(event) => {
            // Evita perder o foco do campo ao clicar no botão de alternância.
            event.preventDefault();
          }}
          onClick={alternarVisibilidade}
          aria-label={visivel ? rotuloOcultar : rotuloMostrar}
          aria-pressed={visivel}
          aria-controls={id}
          className="absolute right-1 inline-flex min-h-11 min-w-11 items-center justify-center rounded-controle text-tinta-suave hover:text-tinta focus-visible:outline-2 focus-visible:outline-offset-2"
        >
          <IconeOlho visivel={visivel} />
        </button>
      ) : null}
    </div>
  );
}
