import { describe, expect, it } from "vitest";

import { respostaAntesDoApp } from "~/servidor/porteiro";

const pedido = (caminho: string) => new Request(`https://frilabr.com${caminho}`);

describe("porteiro do Worker", () => {
  it("manda para /app/ o que chega fora de /app", () => {
    const resposta = respostaAntesDoApp(pedido("/"), { webLigada: true });
    expect(resposta?.status).toBe(302);
    expect(resposta?.headers.get("Location")).toBe("https://frilabr.com/app/");
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
