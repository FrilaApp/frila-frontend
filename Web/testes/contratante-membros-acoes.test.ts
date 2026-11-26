import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createMemoryRouter, RouterProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import MembrosDaCasa, { action, loader, mensagemDoConvite } from "../app/rotas/contratante/membros";
import { textos } from "../app/textos/pt-BR";
import { argumentos, CASA, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const MEMBRO = "b027f000-0000-4000-8000-0000000000d1";
const membro = { membro_id: MEMBRO, nome: "Ana Sintética", papel: "operador", desde: "2026-11-17T10:00:00Z", e_voce: false };
const t = textos.contratanteMembros;
const pedido = (intencao: string, extra: Record<string, string> = {}) => argumentos("/casa/membros", { intencao, casa: CASA, membro_id: MEMBRO, confirmado: "sim", ...extra });

function servidor(lista: unknown = ok([membro]), papel = "administrador") {
  api.GET.mockImplementation(async (caminho: string) => caminho === "/rpc/meus_estabelecimentos" ? ok([{ id: CASA, nome: "Casa Sintética", papel }]) : lista);
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
  servidor();
});

describe("membros: leitura pelo contrato", () => {
  it("lê os membros da casa sem expor sessão ou campos extras", async () => {
    servidor(ok([{ ...membro, email: "nao-devolver@example.com", usuario_id: "nao-devolver" }]));
    const dados = await loader(argumentos(`/casa/membros?casa=${CASA}`));
    expect(dados).toMatchObject({ estado: "ok", membros: [membro] });
    expect(api.GET).toHaveBeenLastCalledWith("/rpc/membros_do_estabelecimento", expect.objectContaining({ params: { query: { estabelecimento_id: CASA } }, signal: expect.any(AbortSignal) }));
    expect(JSON.stringify(dados)).not.toMatch(/nao-devolver|sintetico|usuario_id|acesso/);
  });

  it("operador não pede a lista restrita; lista vazia é válida", async () => {
    servidor(ok([]), "operador");
    expect(await loader(argumentos("/casa/membros"))).toMatchObject({ casa: { administrador: false }, membros: [], estado: "so_administrador" });
    expect(api.GET).toHaveBeenCalledTimes(1);
    servidor(ok([]));
    expect(await loader(argumentos("/casa/membros"))).toMatchObject({ estado: "ok", membros: [] });
  });

  it.each([[403, null, "so_administrador"], [403, "conta_suspensa", "conta_suspensa"], [500, null, "indisponivel"]])("leitura %s/%s tem estado %s", async (status, detalhe, estado) => {
    servidor(recusa(Number(status), "sem_permissao", detalhe as string | null));
    expect(await loader(argumentos("/casa/membros"))).toMatchObject({ estado, membros: [] });
  });

  it("sessão vencida na leitura manda entrar", async () => {
    servidor(recusa(401));
    expect(await redirecionamento(loader(argumentos("/casa/membros")))).toBe("/entrar");
  });
});

describe.each(["remover", "transferir"])("membros: %s", (intencao) => {
  it("envia o corpo contratado e o Router relê a lista após o sucesso", async () => {
    let lista = [membro];
    api.GET.mockImplementation(async (caminho: string) => caminho === "/rpc/meus_estabelecimentos" ? ok([{ id: CASA, nome: "Casa Sintética", papel: "administrador" }]) : ok(lista));
    api.POST.mockImplementation(async () => {
      lista = intencao === "remover" ? [] : [{ ...membro, papel: "administrador" }];
      return ok({ status: intencao === "remover" ? "membro_removido" : "administracao_transferida" });
    });
    const { context } = argumentos("/casa/membros") as { context: unknown };
    const router = createMemoryRouter([{
      id: "membros", path: "/casa/membros",
      loader: (args) => loader({ ...args, context } as never),
      action: (args) => action({ ...args, context } as never),
    }], { initialEntries: [`/casa/membros?casa=${CASA}`] });
    try {
      await vi.waitFor(() => expect(router.state.initialized).toBe(true));
      const formulario = new FormData();
      for (const [nome, valor] of Object.entries({ intencao, casa: CASA, membro_id: MEMBRO, confirmado: "sim" })) formulario.set(nome, valor);
      await router.navigate("/casa/membros", { formMethod: "post", formData: formulario });
      expect(router.state.errors).toBeNull();
      expect(api.POST).toHaveBeenCalledExactlyOnceWith(`/rpc/${intencao === "remover" ? "remover_membro" : "transferir_administracao"}`, expect.objectContaining({ body: { estabelecimento_id: CASA, [intencao === "remover" ? "membro_id" : "novo_admin_id"]: MEMBRO }, signal: expect.any(AbortSignal) }));
      expect(api.GET.mock.calls.filter(([caminho]) => caminho === "/rpc/membros_do_estabelecimento")).toHaveLength(2);
      expect(router.state.loaderData.membros).toMatchObject({ membros: lista, aviso: intencao === "remover" ? t.removido : t.transferido });
    } finally { router.dispose(); }
  });

  it.each([[403, "sem_permissao", "so_administrador"], [404, "nao_encontrado", "nao_encontrado"], [500, "x", "indisponivel"]])("recusa %s vira texto do Frila", async (status, codigo, falha) => {
    api.POST.mockResolvedValue(recusa(Number(status), String(codigo)));
    expect(await action(pedido(intencao))).toMatchObject({ falha });
    expect(t.erros[falha as keyof typeof t.erros]).toBeTruthy();
  });

  it("sem confirmação ou com id inválido não envia; 401 manda entrar", async () => {
    expect(await action(pedido(intencao, { confirmado: "" }))).toMatchObject({ falha: "confirmacao" });
    expect(await action(pedido(intencao, { membro_id: "x" }))).toMatchObject({ falha: "nao_encontrado" });
    expect(api.POST).not.toHaveBeenCalled();
    api.POST.mockResolvedValue(recusa(401));
    expect(await redirecionamento(action(pedido(intencao)))).toBe("/entrar");
  });

  it("falha de rede tem fallback", async () => {
    api.POST.mockRejectedValue(new TypeError("rede"));
    expect(await action(pedido(intencao))).toMatchObject({ falha: "indisponivel" });
  });
});

it("não remove o último administrador: mostra a recusa do contrato", async () => {
  api.POST.mockResolvedValue(recusa(422, "ultimo_administrador"));
  expect(await action(pedido("remover"))).toMatchObject({ falha: "ultimo_administrador" });
});

it("intenção desconhecida não chama operação alguma", async () => {
  expect(await action(pedido("apagar"))).toMatchObject({ falha: "indisponivel" });
  expect(api.POST).not.toHaveBeenCalled();
});

it("a tela reserva ações ao administrador e pede confirmação em formulário nativo", async () => {
  const renderizar = async (papel: string, falha?: string) => {
    servidor(ok([membro]), papel);
    const loaderData = await loader(argumentos("/casa/membros"));
    const router = createMemoryRouter([{
      path: "/casa/membros",
      Component: () => createElement(MembrosDaCasa, { loaderData, actionData: falha ? { falha } : undefined } as never),
    }], { initialEntries: ["/casa/membros"] });
    try { return renderToStaticMarkup(createElement(RouterProvider, { router })); }
    finally { router.dispose(); }
  };
  const admin = await renderizar("administrador", "ultimo_administrador");
  expect(admin).toContain(membro.nome);
  expect(admin).toContain('name="intencao" value="remover"');
  expect(admin).toContain('name="intencao" value="transferir"');
  expect(admin).toMatch(/type="checkbox"[^>]*required=""[^>]*name="confirmado"/);
  expect(admin).toContain(t.erros.ultimo_administrador);
  const operador = await renderizar("operador");
  expect(operador).not.toContain('name="intencao"');
  expect(operador).toContain(t.soAdministrador);
});

describe("convite pronto: mensagem com aviso do ROPA", () => {
  const TOKEN = "a".repeat(64);
  const LINK = `https://frilabr.com/app/convite#${TOKEN}`;

  function extrairMensagemDoCampo(html: string): string {
    const achado = /<textarea\b[^>]*>([\s\S]*?)<\/textarea>/.exec(html);
    if (achado?.[1] === undefined) throw new Error("esperava um <textarea> com a mensagem do convite");
    return achado[1];
  }

  async function renderizarConvitePronto({ expiraEm, email, papel }: { expiraEm: string; email: string; papel: string }) {
    api.POST.mockResolvedValue(ok({ convite_id: "c1", token: TOKEN, expira_em: expiraEm }));
    const loaderData = await loader(argumentos(`/casa/membros?casa=${CASA}`));
    const actionData = await action(argumentos("/casa/membros", { intencao: "convidar", casa: CASA, email, papel }));
    if (!("link" in actionData)) throw new Error("esperava o convite pronto");
    const router = createMemoryRouter([{
      path: "/casa/membros",
      Component: () => createElement(MembrosDaCasa, { loaderData, actionData } as never),
    }], { initialEntries: ["/casa/membros"] });
    try {
      const html = renderToStaticMarkup(createElement(RouterProvider, { router }));
      return { html, actionData, mensagem: extrairMensagemDoCampo(html) };
    } finally {
      router.dispose();
    }
  }

  it("com prazo: o campo só-leitura traz a mensagem exata com prazo e termina no link", async () => {
    const { html, actionData, mensagem } = await renderizarConvitePronto({
      expiraEm: "2026-11-24T08:00:00Z",
      email: "pessoa@example.com",
      papel: "operador",
    });
    const esperada =
      `Casa Sintética convidou você para a equipe da casa no Frila, como operador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail pessoa@example.com. O convite vale uma vez, até ${actionData.ate}. O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. Política de Privacidade: https://frilabr.com/privacidade\n${LINK}`;
    expect(html).toContain(t.rotuloDaMensagem);
    expect(html).toContain(t.pronto.replace("{quando}", actionData.ate));
    expect(html).toMatch(/<textarea\b[^>]*readOnly=""[^>]*>/i);
    expect(mensagem).toBe(esperada);
    expect(mensagem).not.toBe(LINK);
    expect(mensagem.endsWith(`\n${LINK}`)).toBe(true);
  });

  it("sem prazo: o campo só-leitura traz a frase curta sem validade", async () => {
    const { html, mensagem } = await renderizarConvitePronto({
      expiraEm: "",
      email: "pessoa@example.com",
      papel: "operador",
    });
    const esperada =
      `Casa Sintética convidou você para a equipe da casa no Frila, como operador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail pessoa@example.com. O convite vale uma vez. O Frila guarda seu e-mail só para conferir este convite e o apaga em até 30 dias depois de ele vencer ou ser aceito. Política de Privacidade: https://frilabr.com/privacidade\n${LINK}`;
    expect(html).toContain(t.prontoSemPrazo);
    expect(html).not.toContain("até :");
    expect(mensagem).toBe(esperada);
    expect(mensagem).not.toBe(LINK);
    expect(mensagem.endsWith(`\n${LINK}`)).toBe(true);
  });

  it("o papel sai em minúsculo para os dois papéis e o e-mail sai aparado", async () => {
    const operador = await renderizarConvitePronto({
      expiraEm: "2026-11-24T08:00:00Z",
      email: "  operador@example.com  ",
      papel: "operador",
    });
    expect(operador.mensagem).toContain("como operador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail operador@example.com.");

    const administrador = await renderizarConvitePronto({
      expiraEm: "2026-11-24T08:00:00Z",
      email: "  admin@example.com  ",
      papel: "administrador",
    });
    expect(administrador.mensagem).toContain("como administrador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail admin@example.com.");

    expect(mensagemDoConvite({
      casa: "Casa Sintética",
      papel: " Administrador ",
      email: "  admin@example.com  ",
      prazo: "24/11, 05:00",
      link: LINK,
    })).toContain("como administrador. Para aceitar, abra o link abaixo e entre no Frila com o e-mail admin@example.com.");
  });
});
