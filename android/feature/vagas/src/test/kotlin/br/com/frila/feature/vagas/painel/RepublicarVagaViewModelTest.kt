package br.com.frila.feature.vagas.painel

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.VagaPublicadaDto
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class RepublicarVagaViewModelTest {

    private val agora: Instant = Instant.parse("2026-11-10T15:00:30Z")

    private class Pedido(val vagaId: String, val inicio: Instant, val fim: Instant, val chave: String)

    private val pedidos = mutableListOf<Pedido>()
    private var chaves = 0

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun viewModel(
        selecao: Boolean = false,
        duracao: Duration = Duration.ofHours(6),
        republicar: suspend () -> VagaPublicadaDto = { VagaPublicadaDto("nova", listOf("p1")) },
    ) = RepublicarVagaViewModel(
        vagaId = "v1",
        selecao = selecao,
        duracaoOriginal = duracao,
        republicar = { vaga, inicio, fim, chave -> pedidos += Pedido(vaga, inicio, fim, chave); republicar() },
        relogio = { agora },
        novaChave = { "chave-${++chaves}" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `sugere o inicio em 3 horas na urgencia e em 25 na selecao, no minuto cheio, com a duracao da vaga de origem`() {
        val urgencia = viewModel().estado.value
        val selecao = viewModel(selecao = true, duracao = Duration.ofHours(4)).estado.value

        assertEquals(Instant.parse("2026-11-10T18:00:00Z"), urgencia.inicio)
        assertEquals(Instant.parse("2026-11-11T00:00:00Z"), urgencia.fim)
        assertEquals(Instant.parse("2026-11-11T16:00:00Z"), selecao.inicio)
        assertEquals(Instant.parse("2026-11-11T20:00:00Z"), selecao.fim)
    }

    @Test
    fun `mudar o inicio leva o termino junto e republicar manda a origem, o horario e a chave`() {
        val vm = viewModel()
        vm.mudarInicio(Instant.parse("2026-11-12T21:00:00Z"))

        vm.republicar()

        val pedido = pedidos.single()
        assertEquals("v1", pedido.vagaId)
        assertEquals(Instant.parse("2026-11-12T21:00:00Z"), pedido.inicio)
        assertEquals(Instant.parse("2026-11-13T03:00:00Z"), pedido.fim)
        assertEquals("chave-1", pedido.chave)
        assertEquals("nova", vm.estado.value.vagaPublicadaId)
        assertFalse(vm.estado.value.podeConfirmar)
        assertNull(vm.republicar(), "depois de republicada não envia de novo")
    }

    @Test
    fun `horario invalido nao vai ao servidor e mostra o motivo no campo`() {
        val noPassado = viewModel().apply { mudarInicio(agora.minusSeconds(60)); republicar() }.estado.value
        val fimAntes = viewModel().apply { mudarFim(agora.plusSeconds(3600)); republicar() }.estado.value
        val curto = viewModel().apply { mudarFim(estado.value.inicio.plusSeconds(3600)); republicar() }.estado.value
        val longo = viewModel().apply { mudarFim(estado.value.inicio.plusSeconds(17 * 3600)); republicar() }.estado.value
        val semAntecedencia = viewModel(selecao = true).apply { mudarInicio(agora.plusSeconds(24 * 3600)); republicar() }.estado.value

        assertEquals(TextosRepublicarVaga.INICIO_NO_PASSADO, noPassado.erroInicio)
        assertEquals(TextosRepublicarVaga.FIM_ANTES_DO_INICIO, fimAntes.erroFim)
        assertEquals(TextosRepublicarVaga.TURNO_CURTO, curto.erroFim)
        assertEquals(TextosRepublicarVaga.TURNO_LONGO, longo.erroFim)
        assertEquals(TextosRepublicarVaga.SELECAO_SEM_ANTECEDENCIA, semAntecedencia.erroInicio)
        assertTrue(pedidos.isEmpty())
    }

    @Test
    fun `falha passageira trava o horario e o reenvio sai com a mesma chave e o mesmo horario`() {
        var falhas = 0
        val vm = viewModel(republicar = { if (falhas++ == 0) throw erro(CodigoErroAPI.SEM_REDE) else VagaPublicadaDto("nova", emptyList()) })

        vm.republicar()
        val depoisDaFalha = vm.estado.value
        vm.mudarInicio(Instant.parse("2026-12-01T21:00:00Z"))
        vm.republicar()

        assertEquals(TextosRepublicarVaga.SEM_REDE, depoisDaFalha.mensagemErro)
        assertTrue(depoisDaFalha.camposBloqueados)
        assertTrue(depoisDaFalha.podeConfirmar)
        assertEquals(listOf("chave-1", "chave-1"), pedidos.map { it.chave })
        assertEquals(pedidos[0].inicio, pedidos[1].inicio)
        assertEquals("nova", vm.estado.value.vagaPublicadaId)
        assertFalse(vm.estado.value.camposBloqueados)
    }

    @Test
    fun `sessao expirada e erro sem codigo tambem travam para o reenvio, com o texto certo`() {
        val sessao = viewModel(republicar = { throw erro(CodigoErroAPI.NAO_AUTENTICADO) }).apply { republicar() }.estado.value
        val estranho = viewModel(republicar = { throw IllegalStateException("corpo que não é JSON") }).apply { republicar() }.estado.value

        assertEquals(TextosRepublicarVaga.SESSAO_EXPIRADA, sessao.mensagemErro)
        assertEquals(TextosRepublicarVaga.ERRO_GENERICO, estranho.mensagemErro)
        assertTrue(sessao.camposBloqueados && estranho.camposBloqueados)
    }

    @Test
    fun `recusa definitiva vira texto do Frila, destrava o horario e a proxima tentativa leva chave nova`() {
        val casos = listOf(
            erro(CodigoErroAPI.NAO_ENCONTRADO) to TextosRepublicarVaga.NAO_ENCONTRADO,
            erro(CodigoErroAPI.SEM_PERMISSAO) to TextosRepublicarVaga.SEM_PERMISSAO,
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to TextosRepublicarVaga.SEM_PERMISSAO,
            erro(CodigoErroAPI.VAGA_OCULTA) to TextosRepublicarVaga.VAGA_OCULTA,
            erro(CodigoErroAPI.PERFIL_INCOMPATIVEL) to TextosRepublicarVaga.PERFIL_INCOMPATIVEL,
            erro(CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA) to TextosRepublicarVaga.SELECAO_SEM_ANTECEDENCIA,
            erro(CodigoErroAPI.HORARIO_INVALIDO) to TextosRepublicarVaga.HORARIO_INVALIDO,
            erro(CodigoErroAPI.CAMPO_INVALIDO, "inicio_em") to TextosRepublicarVaga.HORARIO_INVALIDO,
        )
        for ((falha, texto) in casos) {
            pedidos.clear()
            val vm = viewModel(republicar = { throw falha })

            vm.republicar()
            val estado = vm.estado.value
            vm.republicar()

            assertEquals(texto, estado.mensagemErro, falha.codigo.name)
            assertFalse(estado.camposBloqueados, falha.codigo.name)
            assertTrue(estado.podeMudarHorario)
            assertEquals(2, pedidos.map { it.chave }.distinct().size, "chave nova depois de ${falha.codigo}")
        }
    }

    @Test
    fun `selecao sem antecedencia e horario invalido do servidor marcam os campos`() {
        val selecao = viewModel(republicar = { throw erro(CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA) }).apply { republicar() }.estado.value
        val horario = viewModel(republicar = { throw erro(CodigoErroAPI.HORARIO_INVALIDO) }).apply { republicar() }.estado.value

        assertEquals(TextosRepublicarVaga.SELECAO_SEM_ANTECEDENCIA, selecao.erroInicio)
        assertNull(selecao.erroFim)
        assertEquals(TextosRepublicarVaga.HORARIO_INVALIDO, horario.erroInicio)
        assertEquals(TextosRepublicarVaga.HORARIO_INVALIDO, horario.erroFim)
    }

    @Test
    fun `dois toques seguidos mandam uma republicacao so`() {
        val resposta = CompletableDeferred<VagaPublicadaDto>()
        val vm = viewModel(republicar = { resposta.await() })

        vm.republicar()
        assertTrue(vm.estado.value.enviando)
        assertNull(vm.republicar())
        resposta.complete(VagaPublicadaDto("nova", emptyList()))

        assertEquals(1, pedidos.size)
        assertEquals("nova", vm.estado.value.vagaPublicadaId)
    }
}
