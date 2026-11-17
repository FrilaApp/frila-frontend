import { beforeEach, describe, expect, it, vi } from "vitest";

import { loader } from "../app/rotas/conta/relatorio";
import { action as baixar } from "../app/rotas/conta/relatorio-arquivo";
import { lerPedido } from "../app/servidor/conta/relatorio";
import { argumentos, CASA, ok, recusa, redirecionamento } from "./contratante-apoio";

const funcoes = vi.hoisted(() => ({ POST: vi.fn() }));
const api = vi.hoisted(() => ({ GET: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ funcoesDoUsuario: () => funcoes, apiDoUsuario: () => api }));

const arquivo = (conteudo: string, tipo: string) => ({
  data: new Response(conteudo).body,
  response: new Response(null, { status: 200, headers: { "Content-Type": tipo } }),
});

beforeEach(() => {
  funcoes.POST.mockReset();
  api.GET.mockReset();
});

describe("relatório dos turnos: a página", () => {
  it("quem tem casa escolhe a casa; o profissional baixa os próprios turnos; padrão de 15 dias", async () => {
    api.GET.mockResolvedValue(ok([{ id: CASA, nome: "Bar Sintético", papel: "operador" }]));
    const casa = await loader(argumentos("/conta/relatorio"));
    expect(casa.casas).toEqual([{ id: CASA, nome: "Bar Sintético" }]);
    expect(casa.casaEscolhida).toBe(CASA);
    const dias = (Date.parse(casa.ate) - Date.parse(casa.de)) / 86_400_000;
    expect(dias).toBe(14);
    api.GET.mockResolvedValue(recusa(422, "perfil_incompativel"));
    expect((await loader(argumentos("/conta/relatorio?erro=vazio"))).casas).toEqual([]);
    expect((await loader(argumentos("/conta/relatorio?erro=vazio"))).erro).toBe("Nenhum turno nesse período. Escolha outras datas.");
    expect((await loader(argumentos("/conta/relatorio?erro=<script>"))).erro).toBeNull();
  });
});

describe("relatório dos turnos: o arquivo", () => {
  it("os dias do DF viram instantes do começo ao fim; casa e formato conferidos", () => {
    expect(lerPedido({ de: "2026-11-01", ate: "2026-11-15", formato: "pdf", casa: CASA })).toEqual({
      de: "2026-11-01T03:00:00.000Z", ate: "2026-11-16T02:59:59.000Z", formato: "pdf", estabelecimento_id: CASA,
    });
    expect(lerPedido({ de: "2026-11-01", ate: "2026-11-15", formato: "csv", casa: "" })).not.toHaveProperty("estabelecimento_id");
    expect(lerPedido({ de: "01/11", ate: "2026-11-15", formato: "csv", casa: "" })).toBeNull();
    expect(lerPedido({ de: "2026-11-01", ate: "2026-11-15", formato: "xls", casa: "" })).toBeNull();
    expect(lerPedido({ de: "2026-11-01", ate: "2026-11-15", formato: "csv", casa: "x" })).toBeNull();
  });

  it("baixa o arquivo do servidor como anexo no-store", async () => {
    funcoes.POST.mockResolvedValue(arquivo("data;funcao\n", "text/csv; charset=utf-8"));
    const resposta = (await baixar(argumentos("/conta/relatorio/arquivo", { de: "2026-11-01", ate: "2026-11-15", formato: "csv", casa: CASA }))) as Response;
    expect(funcoes.POST).toHaveBeenCalledWith("/exportar-turnos", expect.objectContaining({ parseAs: "stream", body: expect.objectContaining({ formato: "csv", estabelecimento_id: CASA }) }));
    expect(resposta.headers.get("Content-Disposition")).toBe('attachment; filename="frila-turnos-2026-11-01-a-2026-11-15.csv"');
    expect(resposta.headers.get("Content-Type")).toBe("text/csv; charset=utf-8");
    expect(resposta.headers.get("Cache-Control")).toBe("no-store");
    expect(await resposta.text()).toBe("data;funcao\n");
  });

  it("período sem turnos (204), mais de 30 dias e datas ruins voltam com o aviso", async () => {
    const pedido = { de: "2026-11-01", ate: "2026-11-15", formato: "pdf", casa: CASA };
    funcoes.POST.mockResolvedValue({ data: undefined, response: new Response(null, { status: 204 }) });
    expect(await redirecionamento(baixar(argumentos("/conta/relatorio/arquivo", pedido)))).toBe(`/conta/relatorio?erro=vazio&casa=${CASA}`);
    funcoes.POST.mockResolvedValue(recusa(422, "intervalo_maximo_excedido"));
    expect(await redirecionamento(baixar(argumentos("/conta/relatorio/arquivo", pedido)))).toBe(`/conta/relatorio?erro=intervalo&casa=${CASA}`);
    funcoes.POST.mockResolvedValue(recusa(403, "sem_permissao"));
    expect(await redirecionamento(baixar(argumentos("/conta/relatorio/arquivo", pedido)))).toBe(`/conta/relatorio?erro=sem_permissao&casa=${CASA}`);
    funcoes.POST.mockResolvedValue(recusa(401));
    expect(await redirecionamento(baixar(argumentos("/conta/relatorio/arquivo", pedido)))).toBe("/entrar");
    funcoes.POST.mockReset();
    expect(await redirecionamento(baixar(argumentos("/conta/relatorio/arquivo", { ...pedido, de: "" })))).toBe(`/conta/relatorio?erro=datas&casa=${CASA}`);
    expect(funcoes.POST).not.toHaveBeenCalled();
  });
});
