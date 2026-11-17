import { beforeEach, describe, expect, it, vi } from "vitest";

import { loader } from "../app/rotas/contratante/painel";
import { janelaDoPainel, vagasParaATela, type Painel } from "../app/servidor/contratante/painel";
import { argumentos, CASA, ok, OUTRA_CASA, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const casas = [
  { id: CASA, nome: "Bar Sintético", papel: "administrador" },
  { id: OUTRA_CASA, nome: "Buffet Sintético", papel: "operador" },
];
const posicao = (estado: string) => ({ id: crypto.randomUUID(), estado, profissional: null, turno_id: null, verificacao: null, em_atraso: false, a_caminho_em: null });
const vaga = (id: string, inicio: string, posicoes: string[]) => ({
  vaga: { id, funcao: "garçom", local: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto", inicio_em: inicio, fim_em: "2026-11-22T01:00:00Z", valor_centavos: 15000 },
  modo: "urgencia",
  estado: "publicada",
  oculta: false,
  alerta_vaga_vazia: true,
  candidatos_pendentes: 2,
  posicoes: posicoes.map(posicao),
});
const painel: Painel = {
  estabelecimento_id: CASA,
  vagas: [vaga("v2", "2026-11-22T21:00:00Z", ["aberta"]), vaga("v1", "2026-11-21T21:00:00Z", ["confirmada", "aberta", "cancelada"])],
  checkins_pendentes: ["t1"],
} as Painel;

function servidor(respostas: Record<string, unknown>) {
  api.GET.mockImplementation(async (caminho: string) => respostas[caminho] ?? recusa(500));
}

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("painel da casa: loader", () => {
  it("lê as casas e o painel da primeira, na janela de hoje e das próximas semanas", async () => {
    servidor({ "/rpc/meus_estabelecimentos": ok(casas), "/rpc/painel_estabelecimento": ok(painel) });
    const dados = await loader(argumentos("/painel"));
    expect(dados.estado).toBe("ok");
    if (dados.estado !== "ok") return;
    expect(dados.casa).toEqual({ id: CASA, nome: "Bar Sintético" });
    expect(dados.outrasCasas).toEqual([{ id: OUTRA_CASA, nome: "Buffet Sintético" }]);
    expect(dados.vagas.map((v) => v.id)).toEqual(["v1", "v2"]);
    expect(dados.checkinsPendentes).toBe(1);
    const consulta = api.GET.mock.calls.find(([caminho]) => caminho === "/rpc/painel_estabelecimento")?.[1];
    expect(consulta.params.query.estabelecimento_id).toBe(CASA);
    expect(Date.parse(consulta.params.query.ate)).toBeGreaterThan(Date.parse(consulta.params.query.de));
  });

  it("?casa= escolhe outra casa da conta; casa que não é da conta cai na primeira", async () => {
    servidor({ "/rpc/meus_estabelecimentos": ok(casas), "/rpc/painel_estabelecimento": ok(painel) });
    const dados = await loader(argumentos(`/painel?casa=${OUTRA_CASA}&publicada=1`));
    expect(dados.estado === "ok" && dados.casa.id).toBe(OUTRA_CASA);
    expect(dados.estado === "ok" && dados.publicada).toBe(true);
    const alheia = await loader(argumentos("/painel?casa=00000000-0000-4000-8000-000000000000"));
    expect(alheia.estado === "ok" && alheia.casa.id).toBe(CASA);
  });

  it("cada recusa vira um estado da tela, e nada do token sai", async () => {
    servidor({ "/rpc/meus_estabelecimentos": ok([]) });
    expect(await loader(argumentos("/painel"))).toEqual({ estado: "sem_casa" });
    servidor({ "/rpc/meus_estabelecimentos": recusa(422, "perfil_incompativel") });
    expect(await loader(argumentos("/painel"))).toEqual({ estado: "perfil_profissional" });
    servidor({ "/rpc/meus_estabelecimentos": recusa(403, "sem_permissao", "conta_suspensa") });
    expect(await loader(argumentos("/painel"))).toEqual({ estado: "conta_suspensa" });
    servidor({ "/rpc/meus_estabelecimentos": ok(casas), "/rpc/painel_estabelecimento": recusa(403, "sem_permissao") });
    expect(await loader(argumentos("/painel"))).toEqual({ estado: "sem_permissao" });
    servidor({ "/rpc/meus_estabelecimentos": ok(casas), "/rpc/painel_estabelecimento": recusa(500, "XX000") });
    expect(await loader(argumentos("/painel"))).toEqual({ estado: "indisponivel" });
    api.GET.mockRejectedValue(new DOMException("prazo", "TimeoutError"));
    const fora = await loader(argumentos("/painel"));
    expect(fora).toEqual({ estado: "indisponivel" });
    expect(JSON.stringify(fora)).not.toContain("sintetico");
  });

  it("sessão vencida no servidor manda entrar; sem sessão também", async () => {
    servidor({ "/rpc/meus_estabelecimentos": recusa(401, "PGRST301") });
    expect(await redirecionamento(loader(argumentos("/painel")))).toBe("/entrar");
    expect(await redirecionamento(loader(argumentos("/painel", undefined, false)))).toBe("/entrar");
  });
});

describe("painel da casa: o que a tela mostra", () => {
  it("formata no fuso do DF e conta só as posições que valem", () => {
    const [primeira] = vagasParaATela(painel);
    expect(primeira).toMatchObject({ id: "v1", horario: "18:00–22:00", valor: "R$\u00a0150,00" /* o Intl separa com espaço que não quebra */, posicoes: 2, ocupadas: 1, candidatosPendentes: 2, alertaVagaVazia: true });
    expect(primeira?.dia).toMatch(/21\/11/);
  });

  it("a janela vai de 12 horas antes a 14 dias depois", () => {
    const agora = new Date("2026-11-17T06:00:00Z");
    expect(janelaDoPainel(agora)).toEqual({ de: "2026-11-16T18:00:00.000Z", ate: "2026-12-01T06:00:00.000Z" });
  });
});
