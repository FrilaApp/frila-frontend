package br.com.frila.feature.vagas.feed

import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaAbertaDto
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class CalculoValorHoraTest {

    private fun criarVaga(
        inicioEm: String,
        fimEm: String,
        valorCentavos: Long,
    ) = VagaAbertaDto(
        id = "test-vaga-1",
        funcao = FuncaoDto(id = "f1", nome = "garçom", categoria = "Salão"),
        estabelecimento = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = "Bar Teste",
            reputacao = ReputacaoDto(positivas = 5, total = 5, taxaComparecimento = 1.0, turnosConsiderados = 5, turnosRealizados = 5),
        ),
        inicioEm = inicioEm,
        fimEm = fimEm,
        local = "Asa Sul",
        regiaoAdministrativa = "Plano Piloto",
        distanciaKm = 2.0,
        valorCentavos = valorCentavos,
        posicoesAbertas = 1,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
        modo = "urgencia",
    )

    @Test
    fun `calcula valor hora exato para duracao inteira`() {
        // 4 horas, R$ 120,00 total = R$ 30,00/h
        val vaga = criarVaga(
            inicioEm = "2026-11-01T18:00:00Z",
            fimEm = "2026-11-01T22:00:00Z",
            valorCentavos = 12_000L,
        )
        assertEquals(30.0, vaga.calcularValorHoraReais(), 0.001)
    }

    @Test
    fun `calcula valor hora exato para duracao fracionaria de 90 minutos`() {
        // 1.5 horas (90 minutos), R$ 45,00 total = R$ 30,00/h
        val vaga = criarVaga(
            inicioEm = "2026-11-01T18:00:00Z",
            fimEm = "2026-11-01T19:30:00Z",
            valorCentavos = 4_500L,
        )
        assertEquals(30.0, vaga.calcularValorHoraReais(), 0.001)
    }

    @Test
    fun `calcula valor hora exato para duracao fracionaria de 2 horas e meia`() {
        // 2.5 horas (150 minutos), R$ 100,00 total = R$ 40,00/h
        val vaga = criarVaga(
            inicioEm = "2026-11-01T20:00:00Z",
            fimEm = "2026-11-01T22:30:00Z",
            valorCentavos = 10_000L,
        )
        assertEquals(40.0, vaga.calcularValorHoraReais(), 0.001)
    }

    @Test
    fun `vaga com datas invertidas ou duracao zero usa fallback de 1 hora sem divisao por zero`() {
        // Fim igual ao início (0 minutos): fallback 1.0 hora -> R$ 80,00/h
        val vagaZero = criarVaga(
            inicioEm = "2026-11-01T18:00:00Z",
            fimEm = "2026-11-01T18:00:00Z",
            valorCentavos = 8_000L,
        )
        assertEquals(80.0, vagaZero.calcularValorHoraReais(), 0.001)

        // Fim anterior ao início: fallback 1.0 hora
        val vagaInvertida = criarVaga(
            inicioEm = "2026-11-01T22:00:00Z",
            fimEm = "2026-11-01T18:00:00Z",
            valorCentavos = 5_000L,
        )
        assertEquals(50.0, vagaInvertida.calcularValorHoraReais(), 0.001)
    }

    @Test
    fun `vaga com timestamp corrompido ou invalido usa fallback de 1 hora`() {
        val vagaCorrompida = criarVaga(
            inicioEm = "data-invalida",
            fimEm = "2026-11-01T22:00:00Z",
            valorCentavos = 7_000L,
        )
        assertEquals(70.0, vagaCorrompida.calcularValorHoraReais(), 0.001)
    }
}
