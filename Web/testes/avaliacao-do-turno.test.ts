import type { ReactElement } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";

// Sem DOM no projeto: o useState é simulado (a ordem dos ganchos é fixa) e a árvore devolvida é percorrida.
const ganchos = vi.hoisted(() => ({ valores: [] as unknown[], i: 0, efeito: false, form: null as unknown }));
vi.mock("react", async (original) => ({
  ...(await original<typeof import("react")>()),
  useState: (inicial: unknown) => {
    const k = ganchos.i++;
    if (!(k in ganchos.valores)) ganchos.valores[k] = inicial;
    return [ganchos.valores[k], (valor: unknown) => (ganchos.valores[k] = valor)];
  },
  // Com `efeito`, roda o efeito da hidratação na hora, com o formulário falso em `form`.
  useEffect: (fn: () => void) => (ganchos.efeito ? fn() : undefined),
  useRef: () => ({ current: ganchos.form }),
}));
vi.mock("react-router", () => ({ Form: "form" }));

const { FormularioDaAvaliacao } = await import("../app/rotas/avaliacao-do-turno");

const TEXTOS = { titulo: "Como foi?", pergunta: "Chamaria este profissional de novo?", sim: "Sim", nao: "Não", enviar: "Enviar avaliação", dica: "Escolha Sim ou Não para avaliar.", enviando: "Enviando…" };
type No = ReactElement<Record<string, unknown>>;
const ESCOLHA = 0;
const HIDRATADO = 1;

function elementos(no: unknown): No[] {
  if (Array.isArray(no)) return no.flatMap(elementos);
  if (!no || typeof no !== "object" || !("props" in no)) return [];
  const el = no as No;
  return [el, ...elementos(el.props.children)];
}
function desenhar(enviando = false) {
  ganchos.i = 0;
  const todos = elementos(FormularioDaAvaliacao({ turnoId: "t1", enviando, textos: TEXTOS }));
  const radios = todos.filter((el) => el.type === "input" && el.props.type === "radio");
  const botoes = todos.filter((el) => el.type === "button");
  return { todos, radios, botoes };
}

beforeEach(() => {
  ganchos.valores = [];
  ganchos.efeito = false;
  ganchos.form = null;
});

describe("avaliação depois do turno: escolher, trocar e só então enviar (como o iOS)", () => {
  it("o toque na opção não envia: Sim e Não são rádios, e há um único botão de enviar, sem valor de resposta", () => {
    const { radios, botoes } = desenhar();
    expect(radios.map((r) => [r.props.name, r.props.value, r.props.required])).toEqual([
      ["resposta", "sim", true],
      ["resposta", "nao", true],
    ]);
    expect(botoes).toHaveLength(1);
    expect(botoes[0]?.props).toMatchObject({ type: "submit", children: "Enviar avaliação" });
    expect(botoes[0]?.props.name).toBeUndefined();
    expect(botoes[0]?.props.value).toBeUndefined();
  });

  it("sem JavaScript o botão não trava (o navegador exige a escolha); hidratado, fica desligado até escolher", () => {
    expect(desenhar().botoes[0]?.props.disabled).toBe(false);
    ganchos.valores[HIDRATADO] = true;
    const antes = desenhar();
    expect(antes.botoes[0]?.props.disabled).toBe(true);
    expect(antes.todos.some((el) => el.props.children === "Escolha Sim ou Não para avaliar.")).toBe(true);
  });

  it("escolher Não e trocar para Sim antes de enviar", () => {
    ganchos.valores[HIDRATADO] = true;
    (desenhar().radios[1]?.props.onChange as () => void)();
    expect(ganchos.valores[ESCOLHA]).toBe("nao");
    const comNao = desenhar();
    expect(comNao.botoes[0]?.props.disabled).toBe(false);
    (comNao.radios[0]?.props.onChange as () => void)();
    expect(ganchos.valores[ESCOLHA]).toBe("sim");
  });

  it("enquanto envia, o botão desliga", () => {
    ganchos.valores[ESCOLHA] = "sim";
    expect(desenhar(true).botoes[0]?.props).toMatchObject({ disabled: true, children: "Enviando…" });
  });
  it("MENOR 3: os rádios não são controlados, então a hidratação não desmarca a escolha feita antes dela", () => {
    expect(desenhar().radios.every((r) => !("checked" in r.props))).toBe(true);
  });

  it("MENOR 3: marcado antes da hidratação, o efeito lê o rádio marcado no formulário e liga o botão", () => {
    ganchos.form = { querySelector: (seletor: string) => (seletor === 'input[name="resposta"]:checked' ? { value: "nao" } : null) };
    ganchos.efeito = true;
    desenhar();
    expect(ganchos.valores[ESCOLHA]).toBe("nao");
    expect(ganchos.valores[HIDRATADO]).toBe(true);
    ganchos.efeito = false;
    expect(desenhar().botoes[0]?.props.disabled).toBe(false);
  });
});
