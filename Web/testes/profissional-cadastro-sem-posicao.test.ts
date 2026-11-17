import { RouterContextProvider } from "react-router";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { contextoDaSessao } from "../app/contexto";
import { action } from "../app/rotas/profissional/cadastro";
import { dentroDoDF } from "../app/servidor/contratante/cadastro-casa";
import { CENTRO_DA_REGIAO, centroDaRegiao } from "../app/servidor/profissional/cadastro-centros";
import { ok, recusa } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

/** Todo o código do cadastro do profissional: rota, servidor e textos. */
const fontes = import.meta.glob<string>(["../app/rotas/profissional/cadastro*", "../app/servidor/profissional/cadastro*", "../app/textos/profissional-cadastro*"], {
  query: "?raw",
  import: "default",
  eager: true,
});

const GARCOM = "365ace5a-c202-4969-ad70-7f3f4dfa57a3";

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("cadastro do profissional: nenhuma posição do navegador", () => {
  it("o código do cadastro não lê a localização nem usa as telas que leem", () => {
    expect(Object.keys(fontes).length).toBeGreaterThanOrEqual(4);
    for (const [arquivo, fonte] of Object.entries(fontes)) {
      expect(fonte, arquivo).not.toMatch(/geolocation|getCurrentPosition|watchPosition|navigator\b/i);
      expect(fonte, arquivo).not.toMatch(/from "[^"]*(localizacao|ponto-da-casa)"/);
    }
  });

  it("o ponto base enviado é o centro da região escolhida, mesmo que o formulário traga coordenadas", async () => {
    api.GET.mockImplementation(async (caminho: string) =>
      caminho === "/funcao" ? ok([{ id: GARCOM, nome: "Garçom", categoria: "Salão" }]) : caminho === "/regiao_administrativa" ? ok([{ id: 1, numero: "I", nome: "Plano Piloto" }]) : recusa(500),
    );
    api.POST.mockResolvedValue(ok({ id: "p1" }));
    const context = new RouterContextProvider();
    context.set(contextoDaSessao, { acesso: "sintetico", usuarioId: "u1", email: "pro@example.com" });
    const request = new Request("https://frilabr.com/app/perfil/cadastro", {
      method: "POST",
      headers: { Origin: "https://frilabr.com" },
      body: new URLSearchParams([["passo", "regioes"], ["ir", "avancar"], ["funcoes", GARCOM], ["ponto_regiao", "1"], ["latitude", "-23.5505"], ["longitude", "-46.6333"], ["ponto_base", "-23.5505,-46.6333"]]),
    });
    await expect(action({ request, context, params: {}, url: new URL(request.url), matches: [] } as never)).rejects.toHaveProperty("status", 302);
    expect(api.POST.mock.calls[0]).toEqual(["/rpc/criar_perfil_profissional", expect.objectContaining({ body: { funcoes: [GARCOM], ponto_base: { latitude: -15.793889, longitude: -47.882778 }, disponibilidades: [] } })]);
  });
});

describe("centros das Regiões Administrativas", () => {
  it("vão da RA I à RA XXXV, todos dentro do Distrito Federal", () => {
    expect(Object.keys(CENTRO_DA_REGIAO).map(Number)).toEqual(Array.from({ length: 35 }, (_, i) => i + 1));
    for (const [id, centro] of Object.entries(CENTRO_DA_REGIAO)) expect(dentroDoDF(centro), `RA ${id}`).toBe(true);
  });

  it("região sem centro na tabela não vira ponto", () => {
    expect(centroDaRegiao(1)).toEqual({ latitude: -15.793889, longitude: -47.882778 });
    expect(centroDaRegiao(36)).toBeNull();
    expect(centroDaRegiao(0)).toBeNull();
  });
});
