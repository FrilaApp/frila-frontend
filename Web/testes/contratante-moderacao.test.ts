import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action as desbloquearNaCasa, loader as carregarBloqueados } from "../app/rotas/contratante/moderacao/bloqueados";
import { action as denunciarNaCasa, loader as carregarDenuncia } from "../app/rotas/contratante/moderacao/denunciar";
import { action as bloquearNoProfissional } from "../app/rotas/profissional/bloqueados";

const PRO = "5a6b7c8d-9e0f-4a1b-8c2d-3e4f5a6b7c8d";
const CASA = "1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f";
const TURNO = "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d";
const CHAVE = "3f2e1d0c-9b8a-4765-8432-10fedcba9876";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));
const argumentos = (caminho: string, dados: Record<string, string> | null = null, logado = true) => {
  const context = new RouterContextProvider();
  context.set(contextoDaSessao, logado ? { acesso: "token-sintetico", usuarioId: "u1", email: "c@example.com" } : null);
  const url = `https://frilabr.com/app${caminho}`;
  const request = dados
    ? new Request(url, { method: "POST", headers: { Origin: "https://frilabr.com" }, body: new URLSearchParams(dados) })
    : new Request(url);
  return { request, context, params: {}, url: new URL(url), matches: [] } as never;
};
const ok = (corpo: unknown) => ({ data: corpo, response: new Response(null, { status: 200 }) });

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("a casa denuncia e bloqueia o profissional (3.18)", () => {
  it("sem sessão, manda entrar sem consultar o servidor", async () => {
    // O loader é síncrono: o "manda entrar" sai como exceção, então vai embrulhado numa função assíncrona.
    await expect((async () => carregarDenuncia(argumentos(`/casa/denunciar?alvo=${PRO}`, null, false)))()).rejects.toHaveProperty("status", 302);
    await expect(denunciarNaCasa(argumentos("/casa/denunciar", { alvo: PRO, chave: CHAVE }, false))).rejects.toHaveProperty("status", 302);
    await expect(carregarBloqueados(argumentos("/casa/bloqueados", null, false))).rejects.toHaveProperty("status", 302);
    expect(api.POST).not.toHaveBeenCalled();
  });

  it("o alvo, o turno e a casa vêm do endereço; id torto vira nulo", async () => {
    expect(await carregarDenuncia(argumentos(`/casa/denunciar?alvo=${PRO}&turno=${TURNO}&casa=${CASA}`))).toMatchObject({ alvo: PRO, turno: TURNO, casa: CASA });
    expect(await carregarDenuncia(argumentos("/casa/denunciar?alvo=../x&casa=//fora"))).toMatchObject({ alvo: null, casa: null });
  });

  it("a denúncia vai com alvo_tipo profissional, o turno e a chave; com 'bloquear junto', bloqueia o profissional", async () => {
    api.POST.mockResolvedValueOnce(ok({ ocorrencia_id: "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88" })).mockResolvedValueOnce(ok({}));
    const feito = await denunciarNaCasa(
      argumentos("/casa/denunciar", { alvo: PRO, turno: TURNO, chave: CHAVE, motivo: "assedio", relato: "Relato sintético da casa.", bloquear: "sim" }),
    );
    expect(feito).toMatchObject({ protocolo: "6F1C2A4E", bloqueada: true, erro: null, chave: CHAVE });
    expect(api.POST.mock.calls[0]?.[0]).toBe("/rpc/denunciar");
    expect(api.POST.mock.calls[0]?.[1]).toMatchObject({ body: { alvo_tipo: "profissional", alvo_id: PRO, turno_id: TURNO, motivo: "assedio", chave: CHAVE } });
    expect(api.POST.mock.calls[1]).toMatchObject(["/rpc/bloquear", { body: { alvo_tipo: "profissional", alvo_id: PRO } }]);
    expect(JSON.stringify(feito)).not.toContain("Relato sintético");
  });

  it("os bloqueados da casa mostram só profissionais; desbloquear vai com alvo_tipo profissional", async () => {
    api.GET.mockResolvedValue(
      ok([
        { alvo_tipo: "profissional", alvo_id: PRO, nome: "Pessoa S.", criado_em: "x" },
        { alvo_tipo: "estabelecimento", alvo_id: CASA, nome: "Outra Casa", criado_em: "x" },
      ]),
    );
    expect(await carregarBloqueados(argumentos("/casa/bloqueados"))).toEqual({ estado: "ok", bloqueios: [{ alvoId: PRO, nome: "Pessoa S." }] });
    api.POST.mockResolvedValueOnce(ok({}));
    expect(await desbloquearNaCasa(argumentos("/casa/bloqueados", { alvo: PRO }))).toEqual({ erro: null });
    expect(api.POST.mock.calls[0]).toMatchObject(["/rpc/desbloquear", { body: { alvo_tipo: "profissional", alvo_id: PRO } }]);
  });

  it("o lado do profissional continua desbloqueando casa (estabelecimento)", async () => {
    api.POST.mockResolvedValueOnce(ok({}));
    await bloquearNoProfissional(argumentos("/bloqueados", { alvo: CASA }));
    expect(api.POST.mock.calls[0]).toMatchObject(["/rpc/desbloquear", { body: { alvo_tipo: "estabelecimento", alvo_id: CASA } }]);
  });
});
