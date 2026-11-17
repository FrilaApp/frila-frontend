import { describe, expect, it } from "vitest";

import { criarApi } from "~/servidor/api";
import { aceitarTermos, criarConta, lerMinhaConta } from "~/servidor/conta";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const dados = { perfil: "contratante", nome: "Ana Cunha", telefone: "+5561999990000", nascimento: "1990-04-12", termos_versao: "2026-11-16" } as const;
const usuario = { id: "u1", perfil: "contratante", nome: "Ana Cunha", telefone: "+5561999990000", email: "ana@example.com", nascimento: "1990-04-12", estado: "ativo", termos_versao: "2026-11-16" };

function apiQueResponde(resposta: () => Response | Promise<Response>) {
  const pedidos: Request[] = [];
  const api = criarApi(ambiente, {
    token: "token-do-usuario",
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { api, pedidos };
}
const recusa = (status: number, code: string, details: string | null = null) => () =>
  Response.json({ code, message: code, details, hint: null }, { status });

describe("conta", () => {
  it("lê a conta com o token de quem entrou", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(usuario));
    expect(await lerMinhaConta(api)).toEqual({ estado: "ok", nome: "Ana Cunha", perfil: "contratante", termosVersao: "2026-11-16" });
    expect(pedidos[0]?.headers.get("Authorization")).toBe("Bearer token-do-usuario");
    expect(pedidos[0]?.headers.get("apikey")).toBe("sb_publishable_teste");
  });

  it("sessão sem conta é o 404 do contrato; o resto é indisponível", async () => {
    expect(await lerMinhaConta(apiQueResponde(recusa(404, "nao_encontrado")).api)).toEqual({ estado: "sem_conta" });
    expect(await lerMinhaConta(apiQueResponde(recusa(500, "XX000")).api)).toEqual({ estado: "indisponivel" });
    expect(await lerMinhaConta(apiQueResponde(() => Promise.reject(new TypeError("fetch failed"))).api)).toEqual({ estado: "indisponivel" });
    expect(await lerMinhaConta(null)).toEqual({ estado: "indisponivel" });
  });

  it("cria a conta mandando exatamente os campos do contrato", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json(usuario));
    expect(await criarConta(api, dados)).toEqual({ ok: true });
    expect(pedidos[0]?.url).toBe("https://exemplo.supabase.co/rest/v1/rpc/criar_conta");
    expect(await pedidos[0]?.json()).toEqual(dados);
  });

  it("traduz cada recusa do servidor", async () => {
    const com = (resposta: () => Response) => criarConta(apiQueResponde(resposta).api, dados);
    expect(await com(recusa(422, "menor_de_idade"))).toEqual({ ok: false, motivo: "menor_de_idade" });
    expect(await com(recusa(422, "campo_invalido", "nome"))).toEqual({ ok: false, motivo: "campo", campo: "nome", tipo: "invalido" });
    expect(await com(recusa(422, "campo_obrigatorio", "telefone"))).toEqual({ ok: false, motivo: "campo", campo: "telefone", tipo: "obrigatorio" });
    expect(await com(recusa(422, "campo_invalido", "termos_versao"))).toEqual({ ok: false, motivo: "campo", campo: "termos_versao", tipo: "invalido" });
    expect(await com(recusa(422, "campo_invalido", "campo_que_a_web_nao_tem"))).toEqual({ ok: false, motivo: "indisponivel" });
    expect(await com(recusa(409, "conflito"))).toEqual({ ok: false, motivo: "ja_existe" });
    expect(await com(recusa(401, "PGRST301"))).toEqual({ ok: false, motivo: "sem_sessao" });
    expect(await com(recusa(500, "XX000"))).toEqual({ ok: false, motivo: "indisponivel" });
  });

  it("registra o aceite da versão que a tela mostrou", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json({ termos_versao: "2026-11-16", aceito_em: "2026-11-17T03:00:00Z" }));
    expect(await aceitarTermos(api, "2026-11-16")).toEqual({ ok: true });
    expect(await pedidos[0]?.json()).toEqual({ termos_versao: "2026-11-16" });
    expect(await aceitarTermos(apiQueResponde(recusa(422, "campo_invalido", "termos_versao")).api, "2026-11-16")).toEqual({ ok: false });
  });
});
