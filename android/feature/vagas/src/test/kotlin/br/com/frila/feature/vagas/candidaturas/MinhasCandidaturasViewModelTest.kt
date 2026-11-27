package br.com.frila.feature.vagas.candidaturas

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CandidaturaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.VagaResumoDto
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Uma candidatura como `minhas_candidaturas` a devolve, para os testes deste pacote. */
internal fun candidatura(id: String, estado: String, turnoId: String? = null, inicio: String = "2026-12-01T21:00:00Z") = CandidaturaDto(
    id = id,
    vaga = VagaResumoDto("vaga-$id", "Garçom", "CLS 405 Bloco C", "Plano Piloto", inicio, "2026-12-02T03:00:00Z", 16_000),
    estado = estado,
    criadaEm = "2026-11-16T10:00:00Z",
    turnoId = turnoId,
)

class MinhasCandidaturasViewModelTest {

    private var leituras = 0

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun viewModel(buscar: suspend () -> List<CandidaturaDto>) = MinhasCandidaturasViewModel(
        buscar = { leituras++; buscar() },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun carregadas(vm: MinhasCandidaturasViewModel) = vm.estado.value.lista as ListaDeCandidaturas.Carregadas

    @Test
    fun `as pendentes vem primeiro e as outras depois, na ordem do servidor, cada uma com o texto do seu estado`() {
        val vm = viewModel {
            listOf(
                candidatura("c1", "recusada"), candidatura("c2", "pendente"), candidatura("c3", "aceita", turnoId = "t3"),
                candidatura("c4", "pendente"), candidatura("c5", "retirada"), candidatura("c6", "expirada"),
            )
        }

        vm.carregar()

        val lista = carregadas(vm)
        assertEquals(listOf("c2", "c4"), lista.pendentes.map { it.id })
        assertEquals(listOf("c1", "c3", "c5", "c6"), lista.anteriores.map { it.id })
        assertTrue(lista.pendentes.all { it.pendente && it.textoDoEstado == TextosCandidaturas.ESTADO_PENDENTE })
        assertEquals(
            listOf(TextosCandidaturas.ESTADO_RECUSADA, TextosCandidaturas.ESTADO_ACEITA, TextosCandidaturas.ESTADO_RETIRADA, TextosCandidaturas.ESTADO_EXPIRADA),
            lista.anteriores.map { it.textoDoEstado },
        )
        val item = lista.pendentes.first()
        assertEquals("vaga-c2", item.vagaId)
        assertEquals("Garçom", item.funcao)
        assertEquals("CLS 405 Bloco C", item.local)
        assertEquals(Instant.parse("2026-12-01T21:00:00Z"), item.inicio)
        assertEquals(16_000L, item.valorCentavos)
    }

    @Test
    fun `a aceita leva ao turno que nasceu dela, sem turno_id leva a Meus turnos, e as outras levam a vaga`() {
        val vm = viewModel { listOf(candidatura("c1", "aceita", turnoId = "t1"), candidatura("c2", "aceita"), candidatura("c3", "pendente")) }

        vm.carregar()

        val itens = carregadas(vm).let { it.pendentes + it.anteriores }.associateBy { it.id }
        assertEquals(DestinoDaCandidatura.Turno("t1"), itens.getValue("c1").destino)
        assertEquals(DestinoDaCandidatura.MeusTurnos, itens.getValue("c2").destino)
        assertEquals(DestinoDaCandidatura.Vaga("vaga-c3"), itens.getValue("c3").destino)
        assertEquals(TextosCandidaturas.ABRE_O_TURNO, itens.getValue("c1").destino.dica)
        assertEquals(TextosCandidaturas.ABRE_MEUS_TURNOS, itens.getValue("c2").destino.dica)
        assertEquals(TextosCandidaturas.ABRE_A_VAGA, itens.getValue("c3").destino.dica)
    }

    @Test
    fun `estado que o app nao conhece fica fora da lista, e horario ilegivel nao derruba o item`() {
        val vm = viewModel { listOf(candidatura("c1", "em_analise"), candidatura("c2", "pendente", inicio = "amanhã")) }

        vm.carregar()

        val lista = carregadas(vm)
        assertEquals(listOf("c2"), lista.pendentes.map { it.id })
        assertTrue(lista.anteriores.isEmpty())
        assertNull(lista.pendentes.single().inicio)
    }

    @Test
    fun `sem candidaturas a lista e vazia, nao erro`() {
        val vm = viewModel { emptyList() }

        vm.carregar()

        assertEquals(ListaDeCandidaturas.Vazia, vm.estado.value.lista)
    }

    @Test
    fun `cada falha da primeira leitura vira texto do Frila, e so a passageira oferece tentar de novo`() {
        val casos = listOf(
            erro(CodigoErroAPI.SEM_REDE) to ListaDeCandidaturas.Erro(TextosCandidaturas.ERRO_SEM_REDE, podeTentarDeNovo = true),
            erro(CodigoErroAPI.NAO_AUTENTICADO) to ListaDeCandidaturas.Erro(TextosCandidaturas.SESSAO_EXPIRADA, podeTentarDeNovo = false),
            erro(CodigoErroAPI.PERFIL_INCOMPATIVEL) to ListaDeCandidaturas.Erro(TextosCandidaturas.CONTA_NAO_PODE, podeTentarDeNovo = false),
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to ListaDeCandidaturas.Erro(TextosCandidaturas.CONTA_NAO_PODE, podeTentarDeNovo = false),
            erro(CodigoErroAPI.DESCONHECIDO) to ListaDeCandidaturas.Erro(TextosCandidaturas.ERRO_GENERICO, podeTentarDeNovo = true),
            IllegalStateException("corpo que não é JSON") to ListaDeCandidaturas.Erro(TextosCandidaturas.ERRO_GENERICO, podeTentarDeNovo = true),
        )
        for ((falha, esperado) in casos) {
            val vm = viewModel { throw falha }

            vm.carregar()

            assertEquals(esperado, vm.estado.value.lista, falha.toString())
        }
    }

    @Test
    fun `falha ao atualizar nao apaga a lista - avisa que pode estar desatualizada, e a proxima leitura limpa o aviso`() {
        var resposta: () -> List<CandidaturaDto> = { listOf(candidatura("c1", "pendente")) }
        val vm = viewModel { resposta() }
        vm.carregar()

        resposta = { throw erro(CodigoErroAPI.SEM_REDE) }
        vm.atualizar()
        val depoisDaFalha = vm.estado.value
        resposta = { listOf(candidatura("c1", "retirada")) }
        vm.atualizar()

        assertEquals(listOf("c1"), (depoisDaFalha.lista as ListaDeCandidaturas.Carregadas).pendentes.map { it.id })
        assertTrue(depoisDaFalha.desatualizada)
        assertFalse(depoisDaFalha.atualizando)
        assertFalse(vm.estado.value.desatualizada)
        assertEquals(listOf("c1"), carregadas(vm).anteriores.map { it.id })
    }

    @Test
    fun `uma leitura em voo nao dispara outra, e atualizar mantem a lista na tela enquanto le`() {
        val segunda = CompletableDeferred<List<CandidaturaDto>>()
        val vm = viewModel { if (leituras == 1) listOf(candidatura("c1", "pendente")) else segunda.await() }
        vm.carregar()

        vm.atualizar()
        vm.atualizar()
        val lendo = vm.estado.value
        segunda.complete(emptyList())

        assertEquals(2, leituras)
        assertTrue(lendo.atualizando)
        assertTrue(lendo.lista is ListaDeCandidaturas.Carregadas)
        assertEquals(ListaDeCandidaturas.Vazia, vm.estado.value.lista)
        assertFalse(vm.estado.value.atualizando)
    }

    @Test
    fun `atualizarEmSilencio troca a lista sem indicador, e a falha a deixa como esta, sem marcar desatualizada (HaRJJ0L0)`() {
        var chamada = 0
        val vm = viewModel {
            when (++chamada) {
                1 -> listOf(candidatura("c1", "pendente"))
                2 -> listOf(candidatura("c2", "pendente"))
                else -> throw erro(CodigoErroAPI.SEM_REDE)
            }
        }
        vm.carregar()
        assertEquals(listOf("c1"), carregadas(vm).pendentes.map { it.id })

        vm.atualizarEmSilencio()
        assertEquals(listOf("c2"), carregadas(vm).pendentes.map { it.id })
        assertFalse(vm.estado.value.atualizando)

        vm.atualizarEmSilencio()
        assertEquals(listOf("c2"), carregadas(vm).pendentes.map { it.id }, "a falha deixa a lista")
        assertFalse(vm.estado.value.desatualizada, "a falha silenciosa não marca a lista como desatualizada")
        assertFalse(vm.estado.value.atualizando)
    }

    @Test
    fun `atualizarEmSilencio nao abre outra leitura com uma em voo`() {
        val trava = kotlinx.coroutines.CompletableDeferred<List<CandidaturaDto>>()
        val vm = viewModel { trava.await() }
        val primeira = vm.carregar()
        val silenciosa = vm.atualizarEmSilencio()
        assertEquals(primeira, silenciosa, "a silenciosa devolve a leitura em voo")
        assertEquals(1, leituras)
        trava.complete(emptyList())
    }
}
