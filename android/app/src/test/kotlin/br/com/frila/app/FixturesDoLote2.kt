package br.com.frila.app

import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.rede.VagaDto

/** Dados sintéticos dos testes de navegação e de Koin do Lote 2 (L2-8). Nada aqui é de gente de verdade. */
internal fun casaDeTeste(id: String = "e1") = PerfilPublicoDto(
    id = id,
    tipo = "estabelecimento",
    nome = "Bar do Zé",
    reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
)

internal fun vagaDaLista(id: String = "vaga-1") = VagaAbertaDto(
    id = id,
    funcao = FuncaoDto(id = "f1", nome = "garçom", categoria = "Salão"),
    estabelecimento = casaDeTeste(),
    inicioEm = "2026-11-01T21:00:00Z",
    fimEm = "2026-11-02T03:00:00Z",
    local = "SQN 108",
    regiaoAdministrativa = "Asa Norte",
    distanciaKm = 1.0,
    valorCentavos = 16_000,
    posicoesAbertas = 1,
    inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
    modo = "selecao",
)

/** A vaga como `detalhe_vaga` a devolve. */
internal fun vagaDoServidor(id: String = "vaga-1", estado: String = "publicada", posicoesAbertas: Int = 2) = VagaDto(
    id = id,
    estabelecimento = casaDeTeste(),
    funcao = FuncaoDto(id = "f1", nome = "Garçom", categoria = "salao"),
    inicioEm = "2026-12-01T21:00:00Z",
    fimEm = "2026-12-02T03:00:00Z",
    local = "CLS 405 Bloco C",
    regiaoAdministrativa = "Plano Piloto",
    ponto = CoordenadaDto(-15.81, -47.89),
    distanciaKm = null,
    valorCentavos = 16_000,
    posicoes = 3,
    posicoesAbertas = posicoesAbertas,
    inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
    responsavelLocal = "Procure a gerente no balcão",
    traje = "Camisa preta",
    observacoes = "Chegar 15 minutos antes",
    modo = "selecao",
    estado = estado,
    oculta = false,
    publicadoEm = "2026-11-17T12:00:00Z",
)
