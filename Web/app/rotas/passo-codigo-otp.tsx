import { useEffect, useRef, useState, type ReactNode } from "react";
import { Form, useSubmit } from "react-router";

export const ESPERA_REENVIO_PADRAO_SEGUNDOS = 60;
export const LIMITE_REENVIOS_OTP = 3;

export function resolverEsperaReenvioSegundos(reenviarEmSegundos?: number): number {
  return typeof reenviarEmSegundos === "number" && Number.isFinite(reenviarEmSegundos) && reenviarEmSegundos > 0
    ? Math.floor(reenviarEmSegundos)
    : ESPERA_REENVIO_PADRAO_SEGUNDOS;
}

export function processarConclusaoTentativaOtp(opcoes: {
  intencao: "confirmar" | "reenviar" | null;
  codigoAtual: string;
  erro: string | null;
  reenviado: boolean;
  esperaEfetiva: number;
  reenviosRealizados: number;
}): {
  codigoComErro?: string | null;
  segundosRestantes?: number;
  reenviosRealizados?: number;
  limparCodigo?: boolean;
} {
  if (opcoes.intencao === "reenviar") {
    if (opcoes.erro) {
      return { segundosRestantes: opcoes.esperaEfetiva };
    }
    if (opcoes.reenviado) {
      return {
        reenviosRealizados: Math.min(LIMITE_REENVIOS_OTP, opcoes.reenviosRealizados + 1),
        segundosRestantes: opcoes.esperaEfetiva,
        codigoComErro: null,
        limparCodigo: true,
      };
    }
    return {};
  }

  if (opcoes.erro) {
    return { codigoComErro: opcoes.codigoAtual };
  }
  return {};
}

const classeDoCampo = "min-h-12 w-full rounded-controle border border-borda bg-superficie px-4 text-lg";
const classeDoBotao =
  "min-h-12 w-full rounded-controle bg-acao px-4 text-xl font-bold text-sobre-acao disabled:opacity-60";
const classeDoLink = "min-h-11 font-semibold underline underline-offset-4 disabled:opacity-50";

export function normalizarCodigoOtp(valor: string): string {
  return valor.replace(/\D/g, "").slice(0, 6);
}

export function podeConfirmarCodigoOtp(codigo: string, enviando: boolean): boolean {
  return !enviando && /^\d{6}$/.test(codigo);
}

export function deveAutoSubmeterCodigoOtp(opcoes: {
  codigo: string;
  enviando: boolean;
  emComposicao?: boolean;
  codigoComErro: string | null;
  ultimoSubmetido: string | null;
}): boolean {
  if (opcoes.enviando || opcoes.emComposicao) return false;
  if (!/^\d{6}$/.test(opcoes.codigo)) return false;
  if (opcoes.codigoComErro !== null && opcoes.codigo === opcoes.codigoComErro) return false;
  if (opcoes.ultimoSubmetido !== null && opcoes.codigo === opcoes.ultimoSubmetido) return false;
  return true;
}

export function formatarContagemReenvio(segundos: number): string {
  const seguro = Math.max(0, Math.floor(segundos));
  const minutos = Math.floor(seguro / 60);
  const resto = String(seguro % 60).padStart(2, "0");
  return `Reenviar código em ${minutos}:${resto}`;
}

export interface PassoCodigoOtpProps {
  titulo: string;
  descricao: ReactNode;
  email: string;
  rotuloDoCodigo: string;
  textoConfirmar: string;
  textoConferindo: string;
  textoReenviar: string;
  intencaoConfirmar: string;
  intencaoReenviar: string;
  enviando: boolean;
  erro: string | null;
  tentativaId?: string;
  reenviado?: boolean;
  reenviarEmSegundos?: number;
  mensagemReenvio?: string | null;
  mostrarLembrarDispositivo?: boolean;
  textoLembrarDispositivo?: string;
  desafioId?: string;
  incluirCampoReenvio?: boolean;
  acaoVoltar: ReactNode;
}

export function PassoCodigoOtp({
  titulo,
  descricao,
  email,
  rotuloDoCodigo,
  textoConfirmar,
  textoConferindo,
  textoReenviar,
  intencaoConfirmar,
  intencaoReenviar,
  enviando,
  erro,
  tentativaId,
  reenviado = false,
  reenviarEmSegundos,
  mensagemReenvio = null,
  mostrarLembrarDispositivo = false,
  textoLembrarDispositivo = "",
  desafioId,
  incluirCampoReenvio = false,
  acaoVoltar,
}: PassoCodigoOtpProps) {
  const submit = useSubmit();
  const formRef = useRef<HTMLFormElement>(null);
  const ultimoSubmetidoRef = useRef<string | null>(null);
  const enviandoAnteriorRef = useRef(enviando);
  const ultimaIntencaoRef = useRef<"confirmar" | "reenviar" | null>(null);
  const ultimaTentativaProcessadaRef = useRef<string | null>(null);
  const intencaoPorTentativaRef = useRef<Map<string, "confirmar" | "reenviar">>(new Map());
  const sequenciaTentativaRef = useRef(0);
  const erroInicialTratadoRef = useRef(false);

  const [codigo, setCodigo] = useState("");
  const [emComposicao, setEmComposicao] = useState(false);
  const [codigoComErro, setCodigoComErro] = useState<string | null>(null);
  const [segundosRestantes, setSegundosRestantes] = useState<number>(0);
  const [reenviosRealizados, setReenviosRealizados] = useState<number>(0);

  const gerarTentativaId = (intencao: "confirmar" | "reenviar"): string => {
    sequenciaTentativaRef.current += 1;
    const id = `t-${sequenciaTentativaRef.current}`;
    intencaoPorTentativaRef.current.set(id, intencao);
    return id;
  };

  const esperaEfetiva = resolverEsperaReenvioSegundos(reenviarEmSegundos);

  // Inicia a contagem no cliente após hidratação (preserva formulário funcional sem JS no SSR).
  useEffect(() => {
    setSegundosRestantes(esperaEfetiva);
  }, [esperaEfetiva]);

  useEffect(() => {
    if (segundosRestantes <= 0) return;
    const id = window.setInterval(() => {
      setSegundosRestantes((atual) => (atual > 1 ? atual - 1 : 0));
    }, 1000);
    return () => window.clearInterval(id);
  }, [segundosRestantes]);

  const codigoAtualRef = useRef(codigo);
  codigoAtualRef.current = codigo;

  // Registra conclusão por identidade explícita da tentativa (`tentativaId`) retornada pela action,
  // sem depender de render intermediário `enviando: true -> false` nem de string de erro diferente.
  useEffect(() => {
    const concluiuPorTentativa = Boolean(tentativaId && tentativaId !== ultimaTentativaProcessadaRef.current);
    const concluiuPorTransicao = enviandoAnteriorRef.current && !enviando && !tentativaId;
    enviandoAnteriorRef.current = enviando;

    if (!erroInicialTratadoRef.current && erro) {
      erroInicialTratadoRef.current = true;
      setCodigoComErro(codigoAtualRef.current);
    }

    if (!concluiuPorTentativa && !concluiuPorTransicao) return;

    const intencao =
      (tentativaId ? intencaoPorTentativaRef.current.get(tentativaId) : undefined) ??
      ultimaIntencaoRef.current ??
      (reenviado ? "reenviar" : "confirmar");
    if (tentativaId) {
      ultimaTentativaProcessadaRef.current = tentativaId;
      intencaoPorTentativaRef.current.delete(tentativaId);
    }
    ultimaIntencaoRef.current = null;

    const resultado = processarConclusaoTentativaOtp({
      intencao,
      codigoAtual: codigoAtualRef.current,
      erro,
      reenviado,
      esperaEfetiva,
      reenviosRealizados,
    });
    if (resultado.reenviosRealizados !== undefined) {
      setReenviosRealizados(resultado.reenviosRealizados);
    }
    if (resultado.segundosRestantes !== undefined) {
      setSegundosRestantes(resultado.segundosRestantes);
    }
    if (resultado.limparCodigo) {
      setCodigo("");
      ultimoSubmetidoRef.current = null;
    }
    if (resultado.codigoComErro !== undefined) {
      setCodigoComErro(resultado.codigoComErro);
    }
  }, [tentativaId, enviando, erro, reenviado, esperaEfetiva, reenviosRealizados]);

  // Submete automaticamente uma única vez ao completar 6 dígitos novos fora de composição IME.
  useEffect(() => {
    if (
      deveAutoSubmeterCodigoOtp({
        codigo,
        enviando,
        emComposicao,
        codigoComErro,
        ultimoSubmetido: ultimoSubmetidoRef.current,
      }) &&
      formRef.current
    ) {
      const id = gerarTentativaId("confirmar");
      ultimoSubmetidoRef.current = codigo;
      ultimaIntencaoRef.current = "confirmar";
      const formData = new FormData(formRef.current);
      formData.set("intencao", intencaoConfirmar);
      formData.set("tentativa_id", id);
      void submit(formData, { method: "post" });
    }
  }, [codigo, enviando, emComposicao, codigoComErro, intencaoConfirmar, submit]);

  const confirmarHabilitado = podeConfirmarCodigoOtp(codigo, enviando);
  const atingiuLimiteReenvios = reenviosRealizados >= LIMITE_REENVIOS_OTP;
  const podeReenviar = !enviando && segundosRestantes <= 0 && !atingiuLimiteReenvios;

  return (
    <div className="flex flex-col gap-4">
      <Form
        ref={formRef}
        method="post"
        className="flex flex-col gap-4"
        noValidate
        onSubmit={(evento) => {
          ultimaIntencaoRef.current = "confirmar";
          const campoTentativa = evento.currentTarget.elements.namedItem("tentativa_id");
          if (campoTentativa instanceof HTMLInputElement) {
            campoTentativa.value = gerarTentativaId("confirmar");
          }
        }}
      >
        <h1 className="font-titulo text-3xl font-bold">{titulo}</h1>
        <p className="text-tinta-suave">{descricao}</p>
        <input type="hidden" name="email" value={email} />
        <input type="hidden" name="tentativa_id" defaultValue="" />
        {desafioId ? <input type="hidden" name="desafio_id" value={desafioId} /> : null}
        <label className="flex flex-col gap-2 font-semibold" htmlFor="codigo">
          {rotuloDoCodigo}
          <input
            id="codigo"
            name="codigo"
            type="text"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            required
            autoFocus
            value={codigo}
            onCompositionStart={() => setEmComposicao(true)}
            onCompositionEnd={(evento) => {
              setEmComposicao(false);
              const proximo = normalizarCodigoOtp(evento.currentTarget.value);
              if (proximo !== codigo) {
                setCodigoComErro(null);
                ultimoSubmetidoRef.current = null;
              }
              setCodigo(proximo);
            }}
            onChange={(evento) => {
              const proximo = normalizarCodigoOtp(evento.target.value);
              if (proximo !== codigo) {
                setCodigoComErro(null);
                ultimoSubmetidoRef.current = null;
              }
              setCodigo(proximo);
            }}
            aria-invalid={erro ? true : undefined}
            aria-describedby={erro ? "erro" : undefined}
            className={`${classeDoCampo} tracking-widest`}
          />
        </label>
        {mostrarLembrarDispositivo ? (
          <label className="flex min-h-11 items-center gap-3 text-sm">
            <input type="checkbox" name="lembrar_dispositivo" value="sim" className="size-5 shrink-0" />
            <span>{textoLembrarDispositivo}</span>
          </label>
        ) : null}
        {erro ? (
          <p id="erro" role="alert" className="font-semibold">
            {erro}
          </p>
        ) : null}
        {reenviado && !erro && mensagemReenvio ? (
          <p role="status" className="font-semibold">
            {mensagemReenvio}
          </p>
        ) : null}
        <button
          type="submit"
          name="intencao"
          value={intencaoConfirmar}
          disabled={!confirmarHabilitado}
          className={classeDoBotao}
        >
          {enviando ? textoConferindo : textoConfirmar}
        </button>
      </Form>
      <Form
        method="post"
        className="flex flex-wrap items-center gap-x-6 gap-y-2"
        onSubmit={(evento) => {
          ultimaIntencaoRef.current = "reenviar";
          const campoTentativa = evento.currentTarget.elements.namedItem("tentativa_id");
          if (campoTentativa instanceof HTMLInputElement) {
            campoTentativa.value = gerarTentativaId("reenviar");
          }
        }}
      >
        <input type="hidden" name="email" value={email} />
        <input type="hidden" name="tentativa_id" defaultValue="" />
        {desafioId ? <input type="hidden" name="desafio_id" value={desafioId} /> : null}
        {incluirCampoReenvio ? <input type="hidden" name="reenvio" value="1" /> : null}
        {atingiuLimiteReenvios ? (
          <span role="status" className="text-sm text-tinta-suave">
            Limite de reenvios atingido. Tente novamente mais tarde.
          </span>
        ) : segundosRestantes > 0 ? (
          <span aria-live="polite" className="text-sm text-tinta-suave">
            {formatarContagemReenvio(segundosRestantes)}
          </span>
        ) : (
          <button
            type="submit"
            name="intencao"
            value={intencaoReenviar}
            disabled={!podeReenviar}
            className={classeDoLink}
          >
            {textoReenviar}
          </button>
        )}
        {acaoVoltar}
      </Form>
    </div>
  );
}
