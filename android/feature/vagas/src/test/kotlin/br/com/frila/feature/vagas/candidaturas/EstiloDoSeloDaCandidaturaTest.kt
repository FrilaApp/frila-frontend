package br.com.frila.feature.vagas.candidaturas

import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * ARHvBJEK: o estilo do selo de cada candidatura. É função pura, então se testa direto: a aceita de turno de pé é confirmada, a
 * pendente é contorno, e tudo o que fechou sem o profissional, inclusive o turno cancelado, é encerrado. O turno cancelado é
 * decidido pela flag, não pelo texto.
 */
class EstiloDoSeloDaCandidaturaTest {

    private fun item(texto: String, pendente: Boolean = false, turnoCancelado: Boolean = false) = ItemCandidatura(
        id = "c1", vagaId = "vaga-c1", funcao = "Garçom", local = "CLS 405 Bloco C", inicio = Instant.parse("2026-12-01T21:00:00Z"),
        fim = Instant.parse("2026-12-02T00:00:00Z"), valorCentavos = 16_000, pendente = pendente, textoDoEstado = texto,
        destino = DestinoDaCandidatura.Vaga("vaga-c1"), turnoCancelado = turnoCancelado,
    )

    @Test
    fun `a pendente e contorno`() {
        assertEquals(EstiloDoSelo.CONTORNO, estiloDoSelo(item(TextosCandidaturas.ESTADO_PENDENTE, pendente = true)))
    }

    @Test
    fun `a aceita de turno de pe e confirmada`() {
        assertEquals(EstiloDoSelo.CONFIRMADO, estiloDoSelo(item(TextosCandidaturas.ESTADO_ACEITA)))
    }

    @Test
    fun `recusada, retirada e expirada sao encerradas, nenhuma e confirmada`() {
        listOf(TextosCandidaturas.ESTADO_RECUSADA, TextosCandidaturas.ESTADO_RETIRADA, TextosCandidaturas.ESTADO_EXPIRADA).forEach {
            assertEquals(EstiloDoSelo.ENCERRADO, estiloDoSelo(item(it)), "estilo de \"$it\"")
        }
    }

    @Test
    fun `o turno cancelado e encerrado`() {
        assertEquals(EstiloDoSelo.ENCERRADO, estiloDoSelo(item(TextosCandidaturas.ESTADO_TURNO_CANCELADO, turnoCancelado = true)))
    }

    @Test
    fun `o turno cancelado e decidido pela flag e nao pelo texto, mesmo com o texto da confirmacao`() {
        assertEquals(EstiloDoSelo.ENCERRADO, estiloDoSelo(item(TextosCandidaturas.ESTADO_ACEITA, turnoCancelado = true)))
    }

    @Test
    fun `no fluxo real, a aceita de turno cancelado sai do view model com o selo encerrado e a de turno de pe com o confirmado`() {
        val vm = MinhasCandidaturasViewModel(
            buscar = { listOf(candidatura("c1", "aceita", turnoId = "t1"), candidatura("c2", "aceita", turnoId = "t2")) },
            buscarEstadosDosTurnos = { mapOf("t1" to "cancelada", "t2" to "confirmada") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        vm.carregar()

        val lista = vm.estado.value.lista as ListaDeCandidaturas.Carregadas
        val itens = (lista.pendentes + lista.anteriores).associateBy { it.id }
        assertEquals(EstiloDoSelo.ENCERRADO, estiloDoSelo(itens.getValue("c1")))
        assertEquals(EstiloDoSelo.CONFIRMADO, estiloDoSelo(itens.getValue("c2")))
    }
}
