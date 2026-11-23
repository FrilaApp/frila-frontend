import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createRoutesStub } from "react-router";
import { describe, expect, it, vi } from "vitest";

import { Layout, loader as carregarRaiz } from "../app/root";
import TelaAparencia, { action, loader } from "../app/rotas/conta/aparencia";
import { cookieDaAparencia, lerAparencia } from "../app/servidor/aparencia";
import { textos } from "../app/textos/pt-BR";
import { argumentos } from "./contratante-apoio";

vi.mock("../app/servidor/middleware-de-sessao", () => ({ middlewareDeSessao: vi.fn() }));
// A casca de documentos do framework não existe no stub de rotas. O Layout e o hook são reais.
vi.mock("react-router", async (original) => ({
  ...await original<typeof import("react-router")>(),
  Links: () => null, Meta: () => null, Scripts: () => null, ScrollRestoration: () => null,
}));

function pedido(cookie?: string, url = "https://frilabr.com/app/") {
  return new Request(url, { headers: cookie ? { Cookie: cookie } : {} });
}

describe("preferência de aparência", () => {
  it("sem escolha, usa Claro", () => {
    expect(lerAparencia(pedido())).toBe("claro");
  });

  it.each(["claro", "escuro"])("lê %s entre outros cookies, inclusive em /app.data", (valor) => {
    expect(lerAparencia(pedido(`outro=1; frila-aparencia=${valor}; mais=2`, "https://frilabr.com/app.data"))).toBe(valor);
  });

  it.each(["automatico", "", "ESCURO", "escuro=extra", "%65scuro", "<script>"])("cookie inválido (%s) cai em Claro", (valor) => {
    expect(lerAparencia(pedido(`frila-aparencia=${valor}`))).toBe("claro");
  });

  it("grava cookie próprio persistente, sem HttpOnly nem Domain, seguro em HTTPS", () => {
    const cookie = cookieDaAparencia("escuro", pedido());
    expect(cookie).toBe("frila-aparencia=escuro; Path=/; Max-Age=31536000; SameSite=Lax; Secure");
    expect(lerAparencia(pedido(cookie.split(";")[0]))).toBe("escuro");
    expect(cookieDaAparencia("claro", pedido(undefined, "http://localhost:5173/app/"))).not.toContain("Secure");
    expect(cookieDaAparencia("escuro; injetado=1", pedido())).toContain("frila-aparencia=claro;");
  });
});

describe("aparência no fluxo da conta", () => {
  it("o loader lê a escolha atual e exige sessão", () => {
    const request = pedido("frila-aparencia=escuro");
    expect(loader(Object.assign(argumentos("/conta/aparencia"), { request }))).toEqual({ aparencia: "escuro" });
    expect(() => loader(argumentos("/conta/aparencia", undefined, false))).toThrow();
  });

  it.each(["claro", "escuro", "automatico"])("o envio %s grava a preferência e volta para revalidar a raiz", async (valor) => {
    const resposta = await action(argumentos("/conta/aparencia", { aparencia: valor }));
    expect(resposta.status).toBe(303);
    expect(resposta.headers.get("Location")).toBe("/conta/aparencia");
    expect(lerAparencia(pedido(resposta.headers.get("Set-Cookie")?.split(";")[0]))).toBe(valor === "escuro" ? "escuro" : "claro");
  });

  it("sem sessão, não grava a escolha", async () => {
    await expect(action(argumentos("/conta/aparencia", { aparencia: "escuro" }, false))).rejects.toMatchObject({ status: 302 });
  });

  it.each(["claro", "escuro"] as const)("HTML traz dois radios rotulados na ordem do iOS e %s marcado", (aparencia) => {
    const Stub = createRoutesStub([{ path: "/conta/aparencia", Component: () => createElement(TelaAparencia, { loaderData: { aparencia } } as never) }]);
    const html = renderToStaticMarkup(createElement(Stub, { initialEntries: ["/conta/aparencia"] }));
    expect(html.match(/type="radio"/g)).toHaveLength(2);
    expect(html).toMatch(new RegExp(`name="aparencia"[^>]*checked=""[^>]*value="${aparencia}"`));
    expect(html.indexOf(textos.aparencia.claro)).toBeLessThan(html.indexOf(textos.aparencia.escuro));
    expect(html).toContain("<legend");
    expect(html).toContain('aria-describedby="explicacao-aparencia"');
    expect(html).toContain("focus-visible:outline-2");
    expect(html).toContain(textos.aparencia.salvar);
    expect(html).not.toContain("Automático");
    expect(html).not.toContain("<script");
  });
});

describe("aparência no HTML inicial", () => {
  it.each([undefined, "claro", "escuro", "invalido"])("o Layout recebe o cookie %s pelo loader, antes de qualquer efeito", (valor) => {
    const dados = carregarRaiz({ request: pedido(valor ? `frila-aparencia=${valor}` : undefined) } as never);
    const Stub = createRoutesStub([{ id: "root", path: "/", Component: () => createElement(Layout, { children: createElement("main") }) }]);
    const html = renderToStaticMarkup(createElement(Stub, { hydrationData: { loaderData: { root: dados } } }));
    expect(html).toContain(`<html lang="pt-BR" data-aparencia="${valor === "escuro" ? "escuro" : "claro"}">`);
  });
});
