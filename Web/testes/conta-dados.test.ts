import { beforeEach, describe, expect, it, vi } from "vitest";

import { action as excluir } from "../app/rotas/conta/dados";
import { action as exportar } from "../app/rotas/conta/meus-dados";
import { criarFuncoesDoUsuario, excluirConta, exportarMeusDados } from "../app/servidor/conta/dados";
import { argumentos, ok, recusa, redirecionamento } from "./contratante-apoio";

const funcoes = vi.hoisted(() => ({ POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ funcoesDoUsuario: () => funcoes }));

const AMBIENTE = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_sintetica" };
const dados = { gerado_em: "2026-11-17T08:00:00Z", conta: { nome: "Pessoa Sintética" }, turnos: [], avaliacoes_dadas: [], avaliacoes_recebidas: [], dispositivos: [] };

beforeEach(() => funcoes.POST.mockReset());

describe("conta: as Edge Functions com o token de quem entrou", () => {
  it("exportar e excluir vão a functions/v1 com o token do usuário e a chave publicável", async () => {
    const buscar = vi.fn(async () => new Response(JSON.stringify(dados), { status: 200, headers: { "Content-Type": "application/json" } }));
    const cliente = criarFuncoesDoUsuario(AMBIENTE, "token-sintetico", { fetch: buscar as unknown as typeof fetch });
    expect(await exportarMeusDados(cliente)).toEqual({ ok: true, dados });
    const pedido = (buscar.mock.calls[0] as unknown as [Request])[0];
    expect(pedido.url).toBe("https://exemplo.supabase.co/functions/v1/exportar-meus-dados");
    expect(pedido.method).toBe("POST");
    expect(pedido.headers.get("Authorization")).toBe("Bearer token-sintetico");
    expect(pedido.headers.get("apikey")).toBe("sb_publishable_sintetica");

    const apagar = vi.fn(async () => new Response(JSON.stringify({ perfil_removido_em: "x", dados_apagados_ate: "2026-12-02", turnos_cancelados: 0 }), { status: 202, headers: { "Content-Type": "application/json" } }));
    expect(await excluirConta(criarFuncoesDoUsuario(AMBIENTE, "token-sintetico", { fetch: apagar as unknown as typeof fetch }))).toEqual({ ok: true });
    const corpo = await (apagar.mock.calls[0] as unknown as [Request])[0].json();
    expect(corpo).toEqual({ confirmar: true });
  });
});

describe("conta: exportar os dados", () => {
  it("baixa o JSON como anexo, sem guardar (no-store)", async () => {
    funcoes.POST.mockResolvedValue(ok(dados));
    const resposta = (await exportar(argumentos("/conta/meus-dados", {}))) as Response;
    expect(resposta.headers.get("Content-Disposition")).toMatch(/^attachment; filename="frila-meus-dados-\d{4}-\d{2}-\d{2}\.json"$/);
    expect(resposta.headers.get("Cache-Control")).toBe("no-store");
    expect(JSON.parse(await resposta.text())).toEqual(dados);
  });

  it("sem conta, servidor fora e sessão vencida", async () => {
    funcoes.POST.mockResolvedValue(recusa(404, "nao_encontrado"));
    expect(await redirecionamento(exportar(argumentos("/conta/meus-dados", {})))).toBe("/conta?exportar=sem_conta");
    funcoes.POST.mockResolvedValue(recusa(500));
    expect(await redirecionamento(exportar(argumentos("/conta/meus-dados", {})))).toBe("/conta?exportar=falhou");
    funcoes.POST.mockResolvedValue(recusa(401));
    expect(await redirecionamento(exportar(argumentos("/conta/meus-dados", {})))).toBe("/entrar");
  });
});

describe("conta: excluir", () => {
  it("só com a ciência marcada", async () => {
    expect(await excluir(argumentos("/conta", {}))).toEqual({ falha: "sem_confirmacao" });
    expect(funcoes.POST).not.toHaveBeenCalled();
  });

  it("excluída: apaga os cookies da sessão e vai para a entrada", async () => {
    funcoes.POST.mockResolvedValue({ data: { perfil_removido_em: "x", dados_apagados_ate: "2026-12-02", turnos_cancelados: 1 }, response: new Response(null, { status: 202 }) });
    try {
      await excluir(argumentos("/conta", { ciente: "sim" }));
      throw new Error("esperava um redirect");
    } catch (resposta) {
      if (!(resposta instanceof Response)) throw resposta;
      expect(resposta.headers.get("Location")).toBe("/entrar");
      const cookies = resposta.headers.getSetCookie();
      expect(cookies).toHaveLength(3);
      for (const linha of cookies) expect(linha).toMatch(/Max-Age=0/);
    }
    expect(funcoes.POST).toHaveBeenCalledWith("/excluir-conta", expect.objectContaining({ body: { confirmar: true } }));
  });

  it("administrador único e servidor fora não excluem", async () => {
    funcoes.POST.mockResolvedValue(recusa(409, "administrador_unico"));
    expect(await excluir(argumentos("/conta", { ciente: "sim" }))).toEqual({ falha: "administrador_unico" });
    funcoes.POST.mockResolvedValue(recusa(500));
    expect(await excluir(argumentos("/conta", { ciente: "sim" }))).toEqual({ falha: "indisponivel" });
  });
});
