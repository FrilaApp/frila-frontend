import { describe, expect, it, vi } from "vitest";

import { criarApi } from "~/servidor/api";
import { lerConfiguracaoComVariaveis, lerConfiguracaoDoApp, PRAZO_MS } from "~/servidor/configuracao";
import { VERSAO_DA_WEB } from "~/versao";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };

function apiQueResponde(resposta: () => Response | Promise<Response>) {
  const pedidos: Request[] = [];
  const api = criarApi(ambiente, {
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { api, pedidos };
}

const configuracaoDeExemplo = {
  plataforma: "web",
  versao_minima: "1.0.0",
  versao_recomendada: "1.0.0",
  url_da_loja: "https://frilabr.com/app",
};

describe("leitura de configuracao_do_app", () => {
  it("lê a linha ios quando pedida (só para o link da loja, url_da_loja)", async () => {
    const ios = { ...configuracaoDeExemplo, plataforma: "ios", url_da_loja: "https://apps.apple.com/br/app/frila/id1" };
    const { api, pedidos } = apiQueResponde(() => Response.json(ios));
    expect(await lerConfiguracaoDoApp(api, { plataforma: "ios" })).toEqual({ estado: "ok", configuracao: ios });
    expect(new URL(pedidos[0]?.url ?? "").searchParams.get("plataforma")).toBe("ios");
  });

  it("pede a plataforma web com a versão da web, a chave publicável e nenhum token de usuário", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(configuracaoDeExemplo));

    const leitura = await lerConfiguracaoDoApp(api);

    expect(leitura).toEqual({ estado: "ok", configuracao: configuracaoDeExemplo });
    const url = new URL(pedidos[0]?.url ?? "");
    expect(url.origin + url.pathname).toBe("https://exemplo.supabase.co/rest/v1/rpc/configuracao_do_app");
    expect(url.searchParams.get("plataforma")).toBe("web");
    expect(url.searchParams.get("versao_app")).toBe(VERSAO_DA_WEB);
    expect(pedidos[0]?.headers.get("apikey")).toBe("sb_publishable_teste");
    expect(pedidos[0]?.headers.get("Authorization")).toBe("Bearer sb_publishable_teste");
  });

  it("trata o 404 do contrato: a web ainda não tem configuração", async () => {
    const { api } = apiQueResponde(() =>
      Response.json({ code: "nao_encontrado", message: "sem configuração", details: "plataforma" }, { status: 404 }),
    );
    expect(await lerConfiguracaoDoApp(api)).toEqual({ estado: "sem_configuracao" });
  });

  it("não trava a abertura quando o servidor falha", async () => {
    const erro500 = apiQueResponde(() => Response.json({ code: "XX000", message: "erro" }, { status: 500 }));
    expect(await lerConfiguracaoDoApp(erro500.api)).toEqual({ estado: "indisponivel" });

    const semRede = apiQueResponde(() => Promise.reject(new TypeError("fetch failed")));
    expect(await lerConfiguracaoDoApp(semRede.api)).toEqual({ estado: "indisponivel" });
  });

  it("desiste quando o servidor não responde dentro do prazo", async () => {
    let sinalDoPedido: AbortSignal | undefined;
    const api = criarApi(ambiente, {
      // Servidor que nunca responde: só o prazo encerra o pedido.
      fetch: (entrada, inicio) =>
        new Promise<Response>((_, rejeitar) => {
          sinalDoPedido = new Request(entrada, inicio).signal;
          sinalDoPedido.addEventListener("abort", () => rejeitar(sinalDoPedido?.reason));
        }),
    });

    const inicio = Date.now();
    const leitura = await lerConfiguracaoDoApp(api, { prazoMs: 30 });

    expect(leitura).toEqual({ estado: "indisponivel" });
    expect(sinalDoPedido?.aborted).toBe(true);
    expect(Date.now() - inicio).toBeLessThan(1000);
    expect(PRAZO_MS).toBe(3000);
  });

  it("avisa quando o Worker está sem o endereço do servidor", async () => {
    expect(await lerConfiguracaoDoApp(null)).toEqual({ estado: "nao_configurado" });
    expect(await lerConfiguracaoComVariaveis({})).toEqual({ estado: "nao_configurado" });
  });

  it("chave de serviço posta por engano vira estado de falha, sem nenhum pedido ao servidor", async () => {
    const pedidos = vi.fn<typeof fetch>();
    const silencio = vi.spyOn(console, "error").mockImplementation(() => undefined);

    const leitura = await lerConfiguracaoComVariaveis(
      { SUPABASE_URL: "https://exemplo.supabase.co", SUPABASE_CHAVE_PUBLICAVEL: "sb_secret_teste" },
      { fetch: pedidos },
    );

    expect(leitura).toEqual({ estado: "chave_recusada" });
    expect(pedidos).not.toHaveBeenCalled();
    expect(silencio).toHaveBeenCalledOnce();
    silencio.mockRestore();
  });
});
