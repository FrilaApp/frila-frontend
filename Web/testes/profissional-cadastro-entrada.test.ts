import { beforeEach, describe, expect, it, vi } from "vitest";

import { loader as carregarPerfil } from "../app/rotas/profissional/perfil";
import { argumentos, ok, recusa } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const LOJA = "https://apps.apple.com/br/app/frila/id0000000000";

/** Profissional sem perfil (404 do contrato) e a linha "ios" da configuração, que traz o link da loja. */
function semPerfil(configuracao: unknown) {
  api.GET.mockImplementation(async (caminho: string) => (caminho === "/rpc/configuracao_do_app" ? configuracao : recusa(404, "nao_encontrado")));
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("perfil sem cadastro: a tela oferece a App Store", () => {
  it("sem perfil, o link da loja vem da linha ios da configuração", async () => {
    semPerfil(ok({ plataforma: "ios", versao_minima: "1.0.0", versao_recomendada: "1.1.0", url_da_loja: LOJA }));
    expect(await carregarPerfil(argumentos("/perfil"))).toEqual({ estado: "sem_perfil", perfil: null, linkDaAppStore: LOJA });
    expect(api.GET).toHaveBeenCalledWith("/rpc/configuracao_do_app", expect.objectContaining({ params: { query: expect.objectContaining({ plataforma: "ios" }) } }));
  });

  it("endereço que não é da App Store, ou configuração fora do ar, ficam sem link", async () => {
    semPerfil(ok({ plataforma: "ios", versao_minima: "1.0.0", versao_recomendada: "1.1.0", url_da_loja: "https://exemplo.invalid/loja" }));
    expect((await carregarPerfil(argumentos("/perfil"))).linkDaAppStore).toBeNull();
    semPerfil(recusa(500));
    expect(await carregarPerfil(argumentos("/perfil"))).toEqual({ estado: "sem_perfil", perfil: null, linkDaAppStore: null });
  });

  it("as outras recusas não pedem a configuração", async () => {
    api.GET.mockImplementation(async () => recusa(422, "perfil_incompativel"));
    expect(await carregarPerfil(argumentos("/perfil"))).toEqual({ estado: "perfil_incompativel", perfil: null, linkDaAppStore: null });
    expect(api.GET).toHaveBeenCalledTimes(1);
  });
});
