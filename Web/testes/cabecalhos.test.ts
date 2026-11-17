import { describe, expect, it } from "vitest";

import { cabecalhosFixos, comCabecalhosDeSeguranca, gerarNonce, politicaDeConteudo } from "~/servidor/cabecalhos";

describe("cabeçalhos de segurança", () => {
  it("gera um nonce diferente a cada chamada", () => {
    const nonces = new Set(Array.from({ length: 50 }, gerarNonce));
    expect(nonces.size).toBe(50);
    for (const nonce of nonces) expect(nonce).toMatch(/^[A-Za-z0-9+/]{22}==$/);
  });

  it("a CSP só deixa rodar script do próprio endereço com o nonce da resposta", () => {
    const csp = politicaDeConteudo("abc123");
    expect(csp).toContain("script-src 'self' 'nonce-abc123'");
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain("frame-ancestors 'none'");
    expect(csp).toContain("object-src 'none'");
    expect(csp).toContain("base-uri 'self'");
    expect(csp).not.toContain("unsafe-inline");
    expect(csp).not.toContain("unsafe-eval");
    expect(csp).not.toContain("*");
  });

  it("põe os cabeçalhos fixos em qualquer resposta, sem mudar status nem corpo", async () => {
    const resposta = comCabecalhosDeSeguranca(new Response("corpo", { status: 404 }));
    expect(resposta.status).toBe(404);
    expect(await resposta.text()).toBe("corpo");
    for (const [nome, valor] of Object.entries(cabecalhosFixos)) {
      expect(resposta.headers.get(nome), nome).toBe(valor);
    }
    expect(resposta.headers.get("Cache-Control")).toBe("private, no-store");
  });

  it("não troca o Cache-Control que a rota definiu", () => {
    const resposta = comCabecalhosDeSeguranca(new Response(null, { headers: { "Cache-Control": "public, max-age=60" } }));
    expect(resposta.headers.get("Cache-Control")).toBe("public, max-age=60");
  });

  it("o HSTS não fala pelos subdomínios nem pede preload", () => {
    expect(cabecalhosFixos["Strict-Transport-Security"]).toBe("max-age=31536000");
  });
});
