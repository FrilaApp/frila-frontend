package br.com.frila.feature.vagas.candidaturas

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CandidaturaDto
import br.com.frila.core.rede.ErroDaApi
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * ARHvBJEK: a candidatura aceita cujo turno foi cancelado é cruzada com `meus_turnos` pelo `turno_id` (o contrato diz que
 * cruzar pela vaga não identifica o turno). Os estados vêm como mapa `turno id -> estado`; `estado` ausente é `null`.
 */
class MinhasCandidaturasTurnoCanceladoTest {

    private var leiturasDeTurnos = 0
    private var estadosDosTurnos: suspend () -> Map<String, String?> = { emptyMap() }

    private fun viewModel(buscar: suspend () -> List<CandidaturaDto>) = MinhasCandidaturasViewModel(
        buscar = buscar,
        buscarEstadosDosTurnos = { leiturasDeTurnos++; estadosDosTurnos() },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun itens(vm: MinhasCandidaturasViewModel) =
        (vm.estado.value.lista as ListaDeCandidaturas.Carregadas).let { it.pendentes + it.anteriores }.associateBy { it.id }

    private fun falhaDeRede() = ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "x")

    @Test
    fun `a aceita cujo turno foi cancelado marca turnoCancelado, a de turno de pe nao`() {
        estadosDosTurnos = { mapOf("t1" to "cancelada", "t2" to "confirmada") }
        val vm = viewModel { listOf(candidatura("c1", "aceita", turnoId = "t1"), candidatura("c2", "aceita", turnoId = "t2")) }

        vm.carregar()

        assertTrue(itens(vm).getValue("c1").turnoCancelado)
        assertFalse(itens(vm).getValue("c2").turnoCancelado)
    }

    @Test
    fun `cruza pelo turno_id e nao pela vaga, duas candidaturas na mesma vaga com turnos diferentes`() {
        estadosDosTurnos = { mapOf("t1" to "cancelada", "t2" to "confirmada") }
        val mesmaVaga = candidatura("c1", "aceita", turnoId = "t1").vaga
        val vm = viewModel {
            listOf(candidatura("c1", "aceita", turnoId = "t1"), candidatura("c2", "aceita", turnoId = "t2").copy(vaga = mesmaVaga))
        }

        vm.carregar()

        assertEquals(itens(vm).getValue("c1").vagaId, itens(vm).getValue("c2").vagaId)
        assertTrue(itens(vm).getValue("c1").turnoCancelado)
        assertFalse(itens(vm).getValue("c2").turnoCancelado)
    }

    @Test
    fun `estado do turno ausente nao e suposto cancelado nem confirmado, e turno fora da lista tambem nao`() {
        estadosDosTurnos = { mapOf("t1" to null) }
        val vm = viewModel { listOf(candidatura("c1", "aceita", turnoId = "t1"), candidatura("c2", "aceita", turnoId = "t-que-nao-veio")) }

        vm.carregar()

        assertFalse(itens(vm).getValue("c1").turnoCancelado)
        assertFalse(itens(vm).getValue("c2").turnoCancelado)
    }

    @Test
    fun `so a candidatura aceita pode ter turno cancelado, mesmo com turno_id cancelado na lista`() {
        estadosDosTurnos = { mapOf("t1" to "cancelada") }
        val vm = viewModel {
            listOf(candidatura("c1", "recusada", turnoId = "t1"), candidatura("c2", "pendente", turnoId = "t1"), candidatura("c3", "retirada", turnoId = "t1"))
        }

        vm.carregar()

        assertTrue(itens(vm).values.none { it.turnoCancelado })
    }

    @Test
    fun `aceita sem turno_id, servidor antigo, nao cruza com nada`() {
        estadosDosTurnos = { mapOf("t1" to "cancelada") }
        val vm = viewModel { listOf(candidatura("c1", "aceita")) }

        vm.carregar()

        assertFalse(itens(vm).getValue("c1").turnoCancelado)
        assertEquals(DestinoDaCandidatura.MeusTurnos, itens(vm).getValue("c1").destino)
    }

    @Test
    fun `a leitura dos turnos comeca sem esperar a das candidaturas, em paralelo`() {
        val portao = CompletableDeferred<Unit>()
        val vm = viewModel { portao.await(); listOf(candidatura("c1", "aceita", turnoId = "t1")) }

        vm.carregar()

        assertEquals(1, leiturasDeTurnos, "a leitura de turnos deveria ter comecado com a das candidaturas ainda em voo")
        portao.complete(Unit)
    }

    @Test
    fun `falha na leitura dos turnos e silenciosa, a lista aparece sem erro e sem turno cancelado`() {
        estadosDosTurnos = { throw falhaDeRede() }
        val vm = viewModel { listOf(candidatura("c1", "aceita", turnoId = "t1")) }

        vm.carregar()

        assertFalse(vm.estado.value.desatualizada)
        assertFalse(itens(vm).getValue("c1").turnoCancelado)
    }

    @Test
    fun `falha na releitura dos turnos mantem o que ja se sabia, leitura que sucede substitui`() {
        var lidos: suspend () -> Map<String, String?> = { mapOf("t1" to "cancelada") }
        estadosDosTurnos = { lidos() }
        val vm = viewModel { listOf(candidatura("c1", "aceita", turnoId = "t1")) }
        vm.carregar()
        assertTrue(itens(vm).getValue("c1").turnoCancelado)

        lidos = { throw falhaDeRede() }
        vm.atualizar()
        assertTrue(itens(vm).getValue("c1").turnoCancelado, "a falha nao apaga o que ja se sabia")

        lidos = { mapOf("t1" to "confirmada") }
        vm.atualizar()
        assertFalse(itens(vm).getValue("c1").turnoCancelado, "a leitura que sucede substitui o que se sabia")

        lidos = { emptyMap() }
        vm.atualizar()
        assertFalse(itens(vm).getValue("c1").turnoCancelado, "a leitura que sucede, mesmo vazia, substitui")
    }

    @Test
    fun `a releitura em silencio tambem cruza com os turnos`() {
        var lidos: suspend () -> Map<String, String?> = { mapOf("t1" to "confirmada") }
        estadosDosTurnos = { lidos() }
        val vm = viewModel { listOf(candidatura("c1", "aceita", turnoId = "t1")) }
        vm.carregar()
        assertFalse(itens(vm).getValue("c1").turnoCancelado)

        lidos = { mapOf("t1" to "cancelada") }
        vm.atualizarEmSilencio()

        assertTrue(itens(vm).getValue("c1").turnoCancelado)
        assertEquals(2, leiturasDeTurnos)
    }

    @Test
    fun `falha das candidaturas continua sendo erro de tela, e a dos turnos nao muda isso`() {
        estadosDosTurnos = { throw falhaDeRede() }
        val vm = viewModel { throw falhaDeRede() }

        vm.carregar()

        assertTrue(vm.estado.value.lista is ListaDeCandidaturas.Erro)
    }

    @Test
    fun `sem leitura de turnos injetada, nada e lido e nenhuma candidatura vem como turno cancelado`() {
        val vm = MinhasCandidaturasViewModel(
            buscar = { listOf(candidatura("c1", "aceita", turnoId = "t1")) },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        vm.carregar()

        assertFalse(itens(vm).getValue("c1").turnoCancelado)
        assertEquals(0, leiturasDeTurnos)
    }
}
