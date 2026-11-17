import { describe, expect, it } from "vitest";

import { respostaAntesDoApp } from "~/servidor/porteiro";

const pedido = (caminho: string) => new Request(`https://frilabr.com${caminho}`);

const envio = (caminho: string, origem?: string) =>
  new Request(`https://frilabr.com${caminho}`, { method: "POST", headers: origem ? { Origin: origem } : {} });

describe("porteiro do Worker", () => {
  it("só aceita pedido que muda dado vindo do próprio endereço", () => {
    expect(respostaAntesDoApp(envio("/app/entrar", "https://frilabr.com"), { webLigada: true })).toBeNull();
    expect(respostaAntesDoApp(envio("/app/entrar", "https://outro.example"), { webLigada: true })?.status).toBe(403);
    expect(respostaAntesDoApp(envio("/app/entrar"), { webLigada: true })?.status).toBe(403);
    expect(respostaAntesDoApp(envio("/app/entrar", "null"), { webLigada: true })?.status).toBe(403);
    expect(respostaAntesDoApp(envio("/app/sair", "https://frilabr.com.outro.example"), { webLigada: true })?.status).toBe(403);
  });

  it("manda para /app/ o que chega fora de /app", () => {
    const resposta = respostaAntesDoApp(pedido("/"), { webLigada: true });
    expect(resposta?.status).toBe(302);
    expect(resposta?.headers.get("Location")).toBe("https://frilabr.com/app/");
  });

  it("deixa passar o pedido de dados da página inicial, com a chave ligada ou desligada", () => {
    for (const webLigada of [true, false]) {
      expect(respostaAntesDoApp(pedido("/app.data"), { webLigada })).toBeNull();
      expect(respostaAntesDoApp(pedido("/app/_.data"), { webLigada })).toBeNull();
    }
    expect(respostaAntesDoApp(pedido("/app/entrar.data"), { webLigada: false })?.status).toBe(302);
    expect(respostaAntesDoApp(pedido("/apple.data"), { webLigada: true })?.status).toBe(302);
  });

  it("não confunde /aplicativo com /app", () => {
    const resposta = respostaAntesDoApp(pedido("/aplicativo"), { webLigada: true });
    expect(resposta?.status).toBe(302);
  });

  it("com a chave ligada, deixa passar qualquer rota de /app", () => {
    expect(respostaAntesDoApp(pedido("/app/"), { webLigada: true })).toBeNull();
    expect(respostaAntesDoApp(pedido("/app/vagas/123"), { webLigada: true })).toBeNull();
  });

  it("com a chave desligada, só a página inicial e a rota de saúde passam", () => {
    expect(respostaAntesDoApp(pedido("/app"), { webLigada: false })).toBeNull();
    expect(respostaAntesDoApp(pedido("/app/"), { webLigada: false })).toBeNull();
    expect(respostaAntesDoApp(pedido("/app/saude"), { webLigada: false })).toBeNull();
  });

  it("com a chave desligada, as outras rotas voltam para a página inicial", () => {
    const resposta = respostaAntesDoApp(pedido("/app/entrar"), { webLigada: false });
    expect(resposta?.status).toBe(302);
    expect(resposta?.headers.get("Location")).toBe("https://frilabr.com/app/");
    expect(resposta?.headers.get("Cache-Control")).toBe("no-store");
  });
});
