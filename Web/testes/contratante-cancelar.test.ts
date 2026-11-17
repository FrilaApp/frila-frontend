import { beforeEach, describe, expect, it, vi } from "vitest";

import { action, loader } from "../app/rotas/contratante/vaga";
import { podeCancelarVaga } from "../app/servidor/contratante/painel";
import { textos } from "../app/textos/pt-BR";
import { argumentos, CASA, CHAVE, ok, recusa, redirecionamento } from "./contratante-apoio";

const api = vi.hoisted(() => ({ GET: vi.fn(), POST: vi.fn() }));
vi.mock("../app/servidor/deste-ambiente", () => ({ apiDoUsuario: () => api }));

const ta = textos.contratante.acoes;
const VAGA = "de829c0f-b442-445b-95d7-0fb70df2e22e";
const aqui = `/painel/vagas/${VAGA}`;
const comVaga = (args: ReturnType<typeof argumentos>) => ({ ...(args as object), params: { vagaId: VAGA } }) as never;
const enviar = (dados: Record<string, string>) => action(comVaga(argumentos(aqui, { casa: CASA, ...dados })));

beforeEach(() => {
  api.GET.mockReset();
  api.POST.mockReset();
});

describe("vaga da casa: cancelar", () => {
  it("cancela com o motivo e volta à vaga com o aviso", async () => {
    api.POST.mockResolvedValue(ok({ vaga_id: VAGA, estado: "cancelada", posicoes_canceladas: 1 }));
    expect(await redirecionamento(enviar({ intencao: "cancelar", motivo: "  Evento adiado  " }))).toBe(`${aqui}?casa=${CASA}&cancelada=1`);
    expect(api.POST).toHaveBeenCalledWith("/rpc/cancelar_vaga", expect.objectContaining({ body: { vaga_id: VAGA, motivo: "Evento adiado" } }));
  });

  it("motivo curto não chega ao servidor; cada recusa volta com o motivo digitado", async () => {
    expect(await enviar({ intencao: "cancelar", motivo: "ok" })).toEqual({ erro: ta.erros.motivo_curto, onde: "cancelar", motivo: "ok" });
    expect(api.POST).not.toHaveBeenCalled();
    const com = async (resposta: unknown) => {
      api.POST.mockResolvedValue(resposta);
      return (await enviar({ intencao: "cancelar", motivo: "Motivo sintético" })).erro;
    };
    expect(await com(recusa(409, "vaga_encerrada"))).toBe(ta.erros.vaga_encerrada);
    expect(await com(recusa(422, "campo_invalido", "motivo"))).toBe(ta.erros.motivo_recusado);
    expect(await com(recusa(422, "campo_obrigatorio", "motivo"))).toBe(ta.erros.motivo_curto);
    expect(await com(recusa(404, "nao_encontrado"))).toBe(ta.erros.nao_encontrada);
    expect(await com(recusa(403, "sem_permissao"))).toBe(ta.erros.sem_permissao);
    expect(await com(recusa(500, "XX000"))).toBe(ta.erros.indisponivel);
  });

  it("conta suspensa tem aviso próprio, igual ao de republicar", async () => {
    api.POST.mockResolvedValue(recusa(403, "sem_permissao", "conta_suspensa"));
    expect(await enviar({ intencao: "cancelar", motivo: "Motivo sintético" })).toEqual({ erro: ta.erros.conta_suspensa, onde: "cancelar", motivo: "Motivo sintético" });
  });
});

describe("vaga da casa: quando oferecer o cancelamento", () => {
  const AGORA = new Date("2026-11-26T20:00:00Z");
  const antes = "2026-11-26T22:00:00Z";
  const depois = "2026-11-26T19:00:00Z";

  it("só enquanto a vaga está aberta ou completa e ainda não começou (como no iOS)", () => {
    expect(podeCancelarVaga({ estado: "publicada", inicioEm: antes }, AGORA)).toBe(true);
    expect(podeCancelarVaga({ estado: "preenchida", inicioEm: antes }, AGORA)).toBe(true);
    expect(podeCancelarVaga({ estado: "preenchida", inicioEm: depois }, AGORA)).toBe(false);
    expect(podeCancelarVaga({ estado: "publicada", inicioEm: depois }, AGORA)).toBe(false);
    expect(podeCancelarVaga({ estado: "encerrada", inicioEm: antes }, AGORA)).toBe(false);
    expect(podeCancelarVaga({ estado: "cancelada", inicioEm: antes }, AGORA)).toBe(false);
  });

  it("começar agora, no instante exato, já não oferece", () => {
    expect(podeCancelarVaga({ estado: "preenchida", inicioEm: AGORA.toISOString() }, AGORA)).toBe(false);
  });

  it("o loader entrega a decisão pronta, calculada com o relógio de agora", async () => {
    vi.useFakeTimers();
    try {
      const painel = ok({
        estabelecimento_id: CASA, checkins_pendentes: [],
        vagas: [{
          vaga: { id: VAGA, funcao: "garçom", local: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto", inicio_em: "2026-11-26T22:00:00Z", fim_em: "2026-11-27T02:00:00Z", valor_centavos: 14000 },
          republicavel_em_urgencia: 0, modo: "urgencia", estado: "preenchida", oculta: false, alerta_vaga_vazia: false, candidatos_pendentes: 0, posicoes: [],
        }],
      });
      const casas = ok([{ id: CASA, nome: "Bar Sintético", papel: "administrador" }]);
      api.GET.mockImplementation(async (caminho: string) => (caminho === "/rpc/meus_estabelecimentos" ? casas : painel));
      for (const [agora, esperado] of [["2026-11-26T20:00:00Z", true], ["2026-11-26T22:30:00Z", false]] as const) {
        vi.setSystemTime(new Date(agora));
        const dados = await loader(comVaga(argumentos(`${aqui}?casa=${CASA}`)));
        expect(dados.estado === "ok" && dados.podeCancelar).toBe(esperado);
      }
    } finally {
      vi.useRealTimers();
    }
  });
});

describe("vaga da casa: repetir em outro dia", () => {
  it("manda só o dia e o horário novos, em UTC, com a chave da tela", async () => {
    api.POST.mockResolvedValue(ok({ vaga_id: "nova", posicoes: ["p"] }));
    const destino = await redirecionamento(enviar({ intencao: "repetir", chave: CHAVE, dia: "2026-12-05", inicio: "18:00", fim: "23:00" }));
    expect(destino).toBe(`/painel?casa=${CASA}&publicada=1`);
    expect(api.POST).toHaveBeenCalledWith("/rpc/republicar_vaga", expect.objectContaining({
      body: { vaga_id: VAGA, inicio_em: "2026-12-05T21:00:00.000Z", fim_em: "2026-12-06T02:00:00.000Z", chave: CHAVE },
    }));
  });

  it("horário incompleto ou sem chave não sai; recusa devolve a mesma chave", async () => {
    expect((await enviar({ intencao: "repetir", chave: CHAVE, dia: "", inicio: "18:00", fim: "23:00" })).erro).toBe(ta.erros.dia);
    expect((await enviar({ intencao: "repetir", chave: "", dia: "2026-12-05", inicio: "18:00", fim: "23:00" })).erro).toBe(ta.erros.formularioVelho);
    expect(api.POST).not.toHaveBeenCalled();
    const com = async (resposta: unknown) => {
      api.POST.mockResolvedValue(resposta);
      return enviar({ intencao: "repetir", chave: CHAVE, dia: "2026-12-05", inicio: "18:00", fim: "23:00" });
    };
    expect(await com(recusa(422, "horario_invalido"))).toEqual({ erro: ta.erros.horario_invalido, onde: "repetir", chave: CHAVE, campos: "2026-12-05|18:00|23:00" });
    expect((await com(recusa(422, "selecao_sem_antecedencia"))).erro).toBe(ta.erros.selecao_sem_antecedencia);
    expect((await com(recusa(422, "vaga_oculta"))).erro).toBe(ta.erros.vaga_oculta);
    expect((await com(recusa(422, "campo_invalido", "observacoes"))).erro).toBe(ta.erros.texto_recusado);
    expect((await com(recusa(403, "sem_permissao", "conta_suspensa"))).erro).toBe(ta.erros.conta_suspensa);
    expect((await com(recusa(500))).chave).toBe(CHAVE);
    api.POST.mockResolvedValue(recusa(401, "PGRST301"));
    expect(await redirecionamento(enviar({ intencao: "repetir", chave: CHAVE, dia: "2026-12-05", inicio: "18:00", fim: "23:00" }))).toBe("/entrar");
  });
});

describe("vaga da casa: campo_invalido na cópia diz qual dado foi recusado", () => {
  const motivoDe = async (details: string | null) => {
    api.POST.mockResolvedValue(recusa(422, "campo_invalido", details));
    return (await enviar({ intencao: "repetir", chave: CHAVE, dia: "2026-12-05", inicio: "18:00", fim: "23:00" })).erro;
  };

  it("texto, valor, lugares, função e endereço da casa têm cada um o seu aviso", async () => {
    for (const texto of ["observacoes", "traje", "responsavel_local"]) expect(await motivoDe(texto)).toBe(ta.erros.texto_recusado);
    expect(await motivoDe("valor_centavos")).toBe(ta.erros.valor_recusado);
    expect(await motivoDe("posicoes")).toBe(ta.erros.posicoes_recusadas);
    expect(await motivoDe("funcao_id")).toBe(ta.erros.funcao_recusada);
    for (const casa of ["ponto", "local", "regiao_administrativa"]) expect(await motivoDe(casa)).toBe(ta.erros.cadastro_da_casa);
    expect(await motivoDe("inicio_em")).toBe(ta.erros.horario_invalido);
  });

  it("campo que a tela não conhece cai num aviso geral, sem culpar o texto", async () => {
    expect(await motivoDe("modo")).toBe(ta.erros.dado_recusado);
    expect(await motivoDe(null)).toBe(ta.erros.dado_recusado);
    expect(ta.erros.dado_recusado).not.toBe(ta.erros.texto_recusado);
  });

  it("os quatro avisos novos são todos diferentes", () => {
    const avisos = [ta.erros.valor_recusado, ta.erros.posicoes_recusadas, ta.erros.funcao_recusada, ta.erros.cadastro_da_casa];
    expect(new Set(avisos).size).toBe(4);
  });
});

describe("vaga da casa: a chave acompanha o horário enviado", () => {
  const horario = { dia: "2026-12-05", inicio: "18:00", fim: "23:00" };
  const repetir = (dados: Record<string, string>) => enviar({ intencao: "repetir", chave: CHAVE, ...dados });

  it("depois de um indisponível, o mesmo horário reenvia a mesma chave", async () => {
    api.POST.mockResolvedValue(recusa(500));
    const primeira = await repetir(horario);
    expect(primeira).toMatchObject({ onde: "repetir", chave: CHAVE, campos: "2026-12-05|18:00|23:00" });
    await repetir({ ...horario, campos_da_chave: String((primeira as { campos: string }).campos) });
    expect(api.POST.mock.calls.map(([, pedido]) => pedido.body.chave)).toEqual([CHAVE, CHAVE]);
  });

  it("dia, início ou fim diferentes do que a chave levou ganham chave nova (a cópia antiga não volta no lugar)", async () => {
    api.POST.mockResolvedValue(recusa(500));
    const campos = "2026-12-05|18:00|23:00";
    for (const mudanca of [{ dia: "2026-12-06" }, { inicio: "19:00" }, { fim: "22:00" }]) {
      api.POST.mockClear();
      const retorno = await repetir({ ...horario, ...mudanca, campos_da_chave: campos });
      const enviada = api.POST.mock.calls[0]?.[1].body.chave;
      expect(enviada).not.toBe(CHAVE);
      expect(retorno).toMatchObject({ onde: "repetir", chave: enviada });
    }
  });

  it("a recusa por horário inválido não gasta a chave", async () => {
    const retorno = await repetir({ ...horario, dia: "", campos_da_chave: "2026-12-05|18:00|23:00" });
    expect(retorno).toMatchObject({ erro: ta.erros.dia, onde: "repetir", chave: CHAVE });
    expect(api.POST).not.toHaveBeenCalled();
  });
});

describe("vaga da casa: republicar os lugares restantes em urgência", () => {
  it("manda só a vaga e a chave; o servidor decide modo, horário, valor e quantidade", async () => {
    api.POST.mockResolvedValue(ok({ vaga_id: "nova", posicoes: ["p"] }));
    expect(await redirecionamento(enviar({ intencao: "restantes", chave: CHAVE }))).toBe(`/painel?casa=${CASA}&publicada=1`);
    expect(api.POST).toHaveBeenCalledWith("/rpc/republicar_posicoes_restantes", expect.objectContaining({ body: { vaga_id: VAGA, chave: CHAVE } }));
  });

  it("traduz o motivo de republicacao_indisponivel", async () => {
    const com = async (details: string) => {
      api.POST.mockResolvedValue(recusa(422, "republicacao_indisponivel", details));
      return (await enviar({ intencao: "restantes", chave: CHAVE })).erro;
    };
    expect(await com("ja_republicada")).toBe(ta.erros.ja_republicada);
    expect(await com("sem_posicoes_restantes")).toBe(ta.erros.sem_posicoes_restantes);
    expect(await com("selecao_em_curso")).toBe(ta.erros.republicacao_indisponivel);
  });

  it("o loader mostra o botão só quando o servidor diz quantos lugares sobram", async () => {
    const painel = (republicavel: number | null) => ok({
      estabelecimento_id: CASA, checkins_pendentes: [],
      vagas: [{
        vaga: { id: VAGA, funcao: "garçom", local: "Rua Sintética, 1", regiao_administrativa: "Plano Piloto", inicio_em: "2026-11-28T06:00:00Z", fim_em: "2026-11-28T08:00:00Z", valor_centavos: 14000 },
        republicavel_em_urgencia: republicavel, modo: "selecao", estado: "encerrada", oculta: false, alerta_vaga_vazia: false, candidatos_pendentes: 0, posicoes: [],
      }],
    });
    const casas = ok([{ id: CASA, nome: "Bar Sintético", papel: "administrador" }]);
    for (const [republicavel, esperado] of [[2, 2], [null, 0]] as const) {
      api.GET.mockImplementation(async (caminho: string) => (caminho === "/rpc/meus_estabelecimentos" ? casas : painel(republicavel)));
      const dados = await loader(comVaga(argumentos(`${aqui}?casa=${CASA}`)));
      expect(dados.estado === "ok" && dados.vaga.republicavelEmUrgencia).toBe(esperado);
      expect(dados.estado === "ok" && dados.chaves.repetir).not.toBe(dados.estado === "ok" && dados.chaves.restantes);
    }
  });
});
