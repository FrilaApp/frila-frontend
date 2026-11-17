/**
 * Achados da revisão do #835 (Lince Codex) sobre o escopo dos cookies:
 * - os cookies têm de chegar também a /app.data (o pedido de dados da página inicial);
 * - cookie plantado por subdomínio (Domain=frilabr.com) não pode virar a sessão.
 * A corrida "resposta atrasada depois do sair" está em `sessao-auth.test.ts`: quem decide a sessão é o Auth.
 */
import { describe, expect, it } from "vitest";

import { cookiesDaSessao, cookiesDeSaida, lerCookiesDaSessao, type Sessao } from "../app/servidor/sessao";

const agora = Math.floor(Date.now() / 1000);
const antiga: Sessao = {
  access_token: `cabecalho.${btoa(JSON.stringify({ sub: "usuario", exp: agora + 20 }))}.assinatura`,
  refresh_token: "r0",
  expires_in: 20,
  token_type: "bearer",
};

/** O caminho do cookie casa com o do pedido? (RFC 6265, 5.1.4) */
function caminhoCasa(caminhoDoCookie: string, caminhoDoPedido: string): boolean {
  if (caminhoDoPedido === caminhoDoCookie) return true;
  if (!caminhoDoPedido.startsWith(caminhoDoCookie)) return false;
  return caminhoDoCookie.endsWith("/") || caminhoDoPedido[caminhoDoCookie.length] === "/";
}

describe("revisão do #835: escopo dos cookies", () => {
  it("os cookies chegam a todos os caminhos da web, inclusive /app.data", () => {
    for (const linha of cookiesDaSessao(antiga, true)) {
      const caminho = /;\s*Path=([^;]+)/.exec(linha)?.[1] ?? "";
      for (const pedido of ["/app", "/app/", "/app.data", "/app/_.data", "/app/entrar.data"]) {
        expect(caminhoCasa(caminho, pedido), `${pedido} com Path=${caminho}`).toBe(true);
      }
    }
  });

  it("em HTTPS os cookies são presos ao host: __Host-, Secure, Path=/ e sem Domain", () => {
    for (const linha of [...cookiesDaSessao(antiga, true), ...cookiesDeSaida(true)]) {
      expect(linha).toMatch(/^__Host-frila-/);
      expect(linha).toContain("; Secure");
      expect(linha).toContain("; Path=/;");
      expect(linha).not.toContain("Domain=");
    }
  });

  it("cookie que um subdomínio pode plantar (__Secure- ou sem prefixo) não vira sessão", () => {
    const plantado = new Request("https://frilabr.com/app/", {
      headers: { Cookie: "__Secure-frila-acesso=dominio; frila-acesso=dominio; __Secure-frila-renovacao=dominio" },
    });
    expect(lerCookiesDaSessao(plantado)).toEqual({ acesso: null, renovacao: null });
    const doHost = new Request("https://frilabr.com/app/", {
      headers: { Cookie: "__Secure-frila-acesso=dominio; __Host-frila-acesso=host" },
    });
    expect(lerCookiesDaSessao(doHost).acesso).toBe("host");
  });
});
