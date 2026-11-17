package br.com.frila.feature.vagas.candidaturas

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CandidaturaDto
import br.com.frila.core.rede.ErroDaApi
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class RetirarCandidaturaViewModelTest {

    private val pedidos = mutableListOf<String>()
    private var leiturasDaLista = 0
    private var avisos = 0

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) = ErroDaApi(codigo, codigo.name.lowercase(), detalhes, "x")

    private fun viewModel(
        lista: suspend () -> List<CandidaturaDto> = { emptyList() },
        retirar: suspend () -> CandidaturaDto = { candidatura("c1", "retirada") },
    ) = RetirarCandidaturaViewModel(
        candidaturaId = "c1",
        retirar = { id -> pedidos += id; retirar() },
        minhasCandidaturas = { leiturasDaLista++; lista() },
        aoRetirar = { avisos++ },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun aoRetirar(lista: suspend () -> List<CandidaturaDto> = { emptyList() }, retirar: suspend () -> CandidaturaDto): EstadoRetirarCandidatura =
        viewModel(lista, retirar).also { it.retirar() }.estado.value

    @Test
    fun `retirar manda a candidatura, fica retirada e avisa quem abriu, e nao envia de novo`() {
        val vm = viewModel()

        vm.retirar()

        assertEquals(listOf("c1"), pedidos)
        assertEquals(EstadoRetirarCandidatura(SituacaoDaRetirada.RETIRADA), vm.estado.value)
        assertEquals(1, avisos)
        assertNull(vm.retirar())
        assertEquals(1, pedidos.size)
    }

    @Test
    fun `dois toques seguidos mandam uma retirada so`() {
        val resposta = CompletableDeferred<CandidaturaDto>()
        val vm = viewModel(retirar = { resposta.await() })

        vm.retirar()
        assertEquals(SituacaoDaRetirada.RETIRANDO, vm.estado.value.situacao)
        assertNull(vm.retirar())
        resposta.complete(candidatura("c1", "retirada"))

        assertEquals(1, pedidos.size)
        assertEquals(SituacaoDaRetirada.RETIRADA, vm.estado.value.situacao)
    }

    @Test
    fun `sem rede nada e guardado para depois - a tela diz que nao retirou e da para tentar de novo`() {
        var falhas = 0
        val vm = viewModel(retirar = { if (falhas++ == 0) throw erro(CodigoErroAPI.SEM_REDE) else candidatura("c1", "retirada") })

        vm.retirar()
        val semRede = vm.estado.value
        vm.retirar()

        assertEquals(EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.RETIRADA_SEM_CONEXAO), semRede)
        assertEquals(SituacaoDaRetirada.RETIRADA, vm.estado.value.situacao)
        assertNull(vm.estado.value.falha)
        assertEquals(0, leiturasDaLista)
    }

    @Test
    fun `candidatura_indisponivel pergunta a lista da conta o que a casa respondeu e diz isso em texto`() {
        val casos = mapOf(
            "aceita" to TextosCandidaturas.JA_ESCOLHIDA,
            "recusada" to TextosCandidaturas.JA_RECUSADA,
            "expirada" to TextosCandidaturas.JA_EXPIRADA,
            "pendente" to TextosCandidaturas.JA_RESPONDIDA,
        )
        for ((estadoNaLista, texto) in casos) {
            val estado = aoRetirar(lista = { listOf(candidatura("c9", "pendente"), candidatura("c1", estadoNaLista)) }) {
                throw erro(CodigoErroAPI.CANDIDATURA_INDISPONIVEL)
            }

            assertEquals(EstadoRetirarCandidatura(SituacaoDaRetirada.INDISPONIVEL, texto), estado, estadoNaLista)
        }
        val foraDaLista = aoRetirar(lista = { emptyList() }) { throw erro(CodigoErroAPI.CANDIDATURA_INDISPONIVEL) }
        val listaFalhou = aoRetirar(lista = { throw erro(CodigoErroAPI.SEM_REDE) }) { throw erro(CodigoErroAPI.CANDIDATURA_INDISPONIVEL) }

        assertEquals(TextosCandidaturas.JA_RESPONDIDA, foraDaLista.falha)
        assertEquals(EstadoRetirarCandidatura(SituacaoDaRetirada.INDISPONIVEL, TextosCandidaturas.JA_RESPONDIDA), listaFalhou)
        assertEquals(0, avisos)
    }

    @Test
    fun `resposta que nao e a retirada e a resposta que a casa ja deu`() {
        val estado = aoRetirar { candidatura("c1", "aceita", turnoId = "t1") }

        assertEquals(EstadoRetirarCandidatura(SituacaoDaRetirada.INDISPONIVEL, TextosCandidaturas.JA_ESCOLHIDA), estado)
        assertEquals(0, avisos)
    }

    @Test
    fun `as outras recusas viram texto do Frila - nao encontrada encerra, as demais deixam tentar de novo`() {
        val casos = listOf(
            erro(CodigoErroAPI.NAO_ENCONTRADO) to EstadoRetirarCandidatura(SituacaoDaRetirada.INDISPONIVEL, TextosCandidaturas.RETIRADA_NAO_ENCONTRADA),
            erro(CodigoErroAPI.NAO_AUTENTICADO) to EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.SESSAO_EXPIRADA),
            erro(CodigoErroAPI.PERFIL_INCOMPATIVEL) to EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.RETIRADA_FALHA),
            erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa") to EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.RETIRADA_FALHA),
            erro(CodigoErroAPI.CAMPO_OBRIGATORIO, "candidatura_id") to EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.RETIRADA_FALHA),
            IllegalStateException("corpo que não é JSON") to EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.RETIRADA_FALHA),
        )
        for ((falha, esperado) in casos) {
            assertEquals(esperado, aoRetirar { throw falha }, falha.toString())
        }
    }
}
