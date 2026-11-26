import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createMemoryRouter, RouterProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { action as convidar, loader } from "../app/rotas/contratante/membros";
import Convite, { action as aceitar, loader as abrirConvite } from "../app/rotas/convite";
import { textos } from "../app/textos/pt-BR";
import { argumentos, CASA, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const TOKEN = "a".repeat(64);
const casas = (papel = "administrador") => ok([{ id: CASA, nome: "Bar Sintético", papel }]);

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("pessoas da casa: convidar", () => {
  it("o loader diz se quem abriu é administrador", async () => {
    api.GET.mockResolvedValue(casas("operador"));
    expect((await loader(argumentos(`/casa/membros?casa=${CASA}`))).casa).toEqual({ id: CASA, nome: "Bar Sintético", administrador: false });
  });

  it("gera o convite e devolve o link com o token no fragmento (#), nunca na query", async () => {
    api.POST.mockResolvedValue(ok({ convite_id: "c1", token: TOKEN, expira_em: "2026-11-24T08:00:00Z" }));
    const retorno = await convidar(argumentos("/casa/membros", { casa: CASA, email: "  pessoa@example.com  ", papel: "operador" }));
    expect(api.POST).toHaveBeenCalledWith("/rpc/convidar_membro", expect.objectContaining({ body: { estabelecimento_id: CASA, email: "pessoa@example.com", papel: "operador" } }));
    if (!("link" in retorno)) throw new Error("esperava o link");
    expect(retorno.link).toBe(`https://frilabr.com/app/convite#${TOKEN}`);
    expect(retorno.ate).toMatch(/\d{2}\/\d{2}/);
    expect(retorno.email).toBe("pessoa@example.com");
    expect(retorno.papel).toBe("operador");
  });

  it("sem validade na resposta, o convite ainda retorna sem quebrar e sem prazo", async () => {
    api.POST.mockResolvedValue(ok({ convite_id: "c1", token: TOKEN, expira_em: "" }));
    const retorno = await convidar(argumentos("/casa/membros", { casa: CASA, email: "admin@example.com", papel: "administrador" }));
    if (!("link" in retorno)) throw new Error("esperava o link");
    expect(retorno.ate).toBe("");
    expect(retorno.email).toBe("admin@example.com");
    expect(retorno.papel).toBe("administrador");
  });

  it("e-mail ou papel ruim não chegam ao servidor; as recusas viram texto", async () => {
    expect(await convidar(argumentos("/casa/membros", { casa: CASA, email: "x", papel: "operador" }))).toMatchObject({ falha: "email", email: "x" });
    expect(await convidar(argumentos("/casa/membros", { casa: CASA, email: "p@example.com", papel: "dono" }))).toMatchObject({ falha: "papel" });
    expect(api.POST).not.toHaveBeenCalled();
    api.POST.mockResolvedValue(recusa(403, "sem_permissao"));
    expect(await convidar(argumentos("/casa/membros", { casa: CASA, email: "p@example.com", papel: "operador" }))).toMatchObject({ falha: "so_administrador" });
    api.POST.mockResolvedValue(recusa(500));
    expect(await convidar(argumentos("/casa/membros", { casa: CASA, email: "p@example.com", papel: "operador" }))).toMatchObject({ falha: "indisponivel" });
    api.POST.mockResolvedValue(recusa(401));
    expect(await redirecionamento(convidar(argumentos("/casa/membros", { casa: CASA, email: "p@example.com", papel: "operador" })))).toBe("/entrar");
  });
});

describe("convite: aceitar", () => {
  it("abre sem sessão (mostra como entrar) e com sessão", async () => {
    expect(abrirConvite(argumentos("/convite", undefined, false))).toEqual({ entrou: false });
    expect(abrirConvite(argumentos("/convite"))).toEqual({ entrou: true });
  });

  it("aceita pelo corpo do POST e vai ao painel da casa", async () => {
    api.POST.mockResolvedValue(ok({ status: "membro_adicionado", estabelecimento_id: CASA, papel: "operador" }));
    expect(await redirecionamento(aceitar(argumentos("/convite", { token: TOKEN.toUpperCase() })))).toBe(`/painel?casa=${CASA}`);
    expect(api.POST).toHaveBeenCalledWith("/rpc/aceitar_convite_membro", expect.objectContaining({ body: { token: TOKEN } }));
  });

  it("código ruim não chega ao servidor; vencido, usado e conta de profissional viram texto", async () => {
    expect(await aceitar(argumentos("/convite", { token: "123" }))).toEqual({ falha: "convite_invalido" });
    expect(api.POST).not.toHaveBeenCalled();
    api.POST.mockResolvedValue(recusa(422, "convite_invalido"));
    expect(await aceitar(argumentos("/convite", { token: TOKEN }))).toEqual({ falha: "convite_invalido" });
    api.POST.mockResolvedValue(recusa(422, "perfil_incompativel"));
    expect(await aceitar(argumentos("/convite", { token: TOKEN }))).toEqual({ falha: "perfil_incompativel" });
    expect(await redirecionamento(aceitar(argumentos("/convite", { token: TOKEN }, false)))).toBe("/entrar");
  });

  it("403 convite_de_outro_email mostra a mensagem exata na tela do convite", async () => {
    api.POST.mockResolvedValue(recusa(403, "convite_de_outro_email"));
    const retorno = await aceitar(argumentos("/convite", { token: TOKEN }));
    expect(retorno).toEqual({ falha: "convite_de_outro_email" });

    const loaderData = abrirConvite(argumentos("/convite"));
    const router = createMemoryRouter([{
      path: "/convite",
      Component: () => createElement(Convite, { loaderData, actionData: retorno } as never),
    }], { initialEntries: ["/convite"] });
    try {
      const html = renderToStaticMarkup(createElement(RouterProvider, { router }));
      expect(html).toContain("Este convite foi feito para outro e-mail. Entre com o e-mail que recebeu o convite.");
      expect(html).not.toContain(textos.contratanteMembros.convite.erros.indisponivel);
    } finally {
      router.dispose();
    }

    api.POST.mockResolvedValue(recusa(403, "outro_motivo"));
    expect(await aceitar(argumentos("/convite", { token: TOKEN }))).toEqual({ falha: "indisponivel" });
  });
});
