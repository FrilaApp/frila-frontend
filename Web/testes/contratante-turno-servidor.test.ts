import { describe, expect, it } from "vitest";

import { criarApi } from "../app/servidor/api";
import { listarMinhasCasas, listarTurnosDaCasa } from "../app/servidor/contratante/turno/turnos";

const ambiente = { url: "https://exemplo.supabase.co", chavePublicavel: "sb_publishable_teste" };
const CASA_ID = "1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f";

function apiQueResponde(resposta: () => Response) {
  const pedidos: Request[] = [];
  const api = criarApi(ambiente, {
    token: "token-da-casa",
    fetch: async (entrada, inicio) => {
      pedidos.push(new Request(entrada, inicio));
      return resposta();
    },
  });
  return { api, pedidos };
}
const recusa = (status: number, code: string, details: string | null = null) => () =>
  Response.json({ code, message: code, details, hint: null }, { status });

describe("casas da conta", () => {
  it("lista as casas; profissional e conta suspensa viram aviso", async () => {
    const casa = { id: CASA_ID, nome: "Casa Sintética", papel: "operador" };
    expect(await listarMinhasCasas(apiQueResponde(() => Response.json([casa])).api)).toEqual({ estado: "ok", casas: [casa] });
    expect((await listarMinhasCasas(apiQueResponde(recusa(422, "perfil_incompativel")).api)).estado).toBe("perfil_incompativel");
    expect((await listarMinhasCasas(apiQueResponde(recusa(403, "sem_permissao", "conta_suspensa")).api)).estado).toBe("conta_suspensa");
    expect((await listarMinhasCasas(apiQueResponde(recusa(500, "x")).api)).estado).toBe("indisponivel");
    expect((await listarMinhasCasas(null)).estado).toBe("indisponivel");
  });
});

describe("turnos da casa", () => {
  it("pede os turnos pela casa; quem não é membro recebe aviso", async () => {
    const { api, pedidos } = apiQueResponde(() => Response.json([]));
    expect(await listarTurnosDaCasa(api, CASA_ID)).toEqual({ estado: "ok", turnos: [] });
    const url = new URL(pedidos[0]?.url ?? "");
    expect(url.pathname).toBe("/rest/v1/rpc/meus_turnos");
    expect(url.searchParams.get("estabelecimento_id")).toBe(CASA_ID);
    expect((await listarTurnosDaCasa(apiQueResponde(recusa(403, "sem_permissao")).api, CASA_ID)).estado).toBe("sem_permissao");
    const invalido = apiQueResponde(() => Response.json([]));
    expect((await listarTurnosDaCasa(invalido.api, "../x")).estado).toBe("sem_permissao");
    expect(invalido.pedidos).toHaveLength(0);
  });
});
