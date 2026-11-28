package br.com.frila.feature.estabelecimento

import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class BuscaDeEnderecoViewModelTest {

    private class BuscadorFalso(
        override val disponivel: Boolean = true,
        var resposta: suspend (String) -> List<EnderecoEncontrado> = { emptyList() },
    ) : BuscadorDeEndereco {
        val consultas = mutableListOf<String>()
        override suspend fun buscar(consulta: String): List<EnderecoEncontrado> {
            consultas += consulta
            return resposta(consulta)
        }
    }

    private val asaSul = EnderecoEncontrado("CLS 408, Asa Sul, Brasília", -15.8150, -47.9150, "Plano Piloto")
    private val semRegiao = EnderecoEncontrado("Rua 1, Cidade Tal", -15.9, -47.9, null)

    private fun viewModel(buscador: BuscadorDeEndereco?) = CadastroEstabelecimentoViewModel(
        cadastrar = { error("a busca não cadastra") },
        escopo = CoroutineScope(Dispatchers.Unconfined),
        buscador = buscador,
    )

    @Test
    fun `buscar chama o buscador com o texto aparado e mostra os resultados`() = runBlocking {
        val buscador = BuscadorFalso(resposta = { listOf(asaSul, semRegiao) })
        val vm = viewModel(buscador)
        vm.editarEndereco("  CLS 408  ")

        vm.buscarEndereco().join()

        assertEquals(listOf("CLS 408"), buscador.consultas)
        assertEquals(listOf(asaSul, semRegiao), vm.estado.value.resultadosDaBusca)
        assertFalse(vm.estado.value.buscando)
        assertFalse(vm.estado.value.buscaSemResultado)
    }

    @Test
    fun `escolher preenche endereco, latitude, longitude e a regiao do casamento`() = runBlocking {
        val vm = viewModel(BuscadorFalso(resposta = { listOf(asaSul) }))
        vm.editarEndereco("CLS 408")
        vm.buscarEndereco().join()

        vm.escolherEndereco(asaSul)

        val e = vm.estado.value
        assertEquals("CLS 408, Asa Sul, Brasília", e.endereco)
        assertEquals("-15.815", e.latitude)
        assertEquals("-47.915", e.longitude)
        assertEquals("Plano Piloto", e.regiaoAdministrativa)
        assertTrue(e.resultadosDaBusca.isEmpty())
        // O ponto escolhido é lido como o digitado: o plano B e a busca chegam ao mesmo lugar.
        assertEquals(-15.815, lerGrau(e.latitude))
    }

    @Test
    fun `sem regiao no casamento o campo fica vazio para a pessoa escolher`() = runBlocking {
        val vm = viewModel(BuscadorFalso())
        vm.escolherRegiao("Taguatinga")

        vm.escolherEndereco(semRegiao)

        assertEquals("", vm.estado.value.regiaoAdministrativa)
        assertEquals("-15.9", vm.estado.value.latitude)
    }

    @Test
    fun `regiao fora da lista das 35 nao entra no campo`() = runBlocking {
        val vm = viewModel(BuscadorFalso())
        vm.escolherEndereco(semRegiao.copy(regiaoAdministrativa = "Atlantida"))
        assertEquals("", vm.estado.value.regiaoAdministrativa)
    }

    @Test
    fun `escolher limpa os erros dos campos que preencheu`() = runBlocking {
        val vm = viewModel(BuscadorFalso())
        vm.cadastrar().join() // tudo vazio: erros de campo
        assertTrue(vm.estado.value.errosDeCampo.keys.containsAll(listOf(CampoCadastro.ENDERECO, CampoCadastro.LATITUDE, CampoCadastro.LONGITUDE)))

        vm.escolherEndereco(asaSul)

        val erros = vm.estado.value.errosDeCampo.keys
        assertFalse(CampoCadastro.ENDERECO in erros || CampoCadastro.LATITUDE in erros || CampoCadastro.LONGITUDE in erros || CampoCadastro.REGIAO_ADMINISTRATIVA in erros)
        assertTrue(CampoCadastro.NOME in erros)
    }

    @Test
    fun `nada achado e erro do servico sao estados diferentes`() = runBlocking {
        val buscador = BuscadorFalso(resposta = { emptyList() })
        val vm = viewModel(buscador)
        vm.editarEndereco("xyz")
        vm.buscarEndereco().join()
        assertTrue(vm.estado.value.buscaSemResultado)
        assertFalse(vm.estado.value.erroDaBusca)

        buscador.resposta = { throw IOException("sem serviço") }
        vm.buscarEndereco().join()
        assertTrue(vm.estado.value.erroDaBusca)
        assertFalse(vm.estado.value.buscaSemResultado)
        assertFalse(vm.estado.value.buscando)
    }

    @Test
    fun `sem servico de geocodificacao ou sem buscador a busca nao faz nada`() = runBlocking {
        val indisponivel = BuscadorFalso(disponivel = false)
        listOf(viewModel(indisponivel), viewModel(null)).forEach { vm ->
            vm.editarEndereco("CLS 408")
            assertFalse(vm.estado.value.buscaDisponivel)
            vm.buscarEndereco().join()
            assertFalse(vm.estado.value.buscando)
            assertTrue(vm.estado.value.resultadosDaBusca.isEmpty())
        }
        assertTrue(indisponivel.consultas.isEmpty())
        assertTrue(viewModel(BuscadorFalso()).estado.value.buscaDisponivel)
    }

    @Test
    fun `endereco em branco nao busca`() = runBlocking {
        val buscador = BuscadorFalso()
        val vm = viewModel(buscador)
        vm.editarEndereco("   ")
        vm.buscarEndereco().join()
        assertTrue(buscador.consultas.isEmpty())
    }

    @Test
    fun `editar o texto no meio da busca joga o resultado fora`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        // Como a chamada bloqueante do Geocoder abaixo da API 33, esta busca não obedece ao cancelamento: só a guarda do estado a segura.
        val buscador = BuscadorFalso(resposta = { withContext(NonCancellable) { liberar.await() }; listOf(asaSul) })
        val vm = viewModel(buscador)
        vm.editarEndereco("CLS 408")
        val busca = vm.buscarEndereco()
        assertTrue(vm.estado.value.buscando)

        vm.editarEndereco("CLN 100")
        liberar.complete(Unit)
        busca.join()

        assertFalse(vm.estado.value.buscando)
        assertTrue(vm.estado.value.resultadosDaBusca.isEmpty())
        assertEquals("CLN 100", vm.estado.value.endereco)
    }

    @Test
    fun `editar o texto depois dos resultados limpa a lista e os avisos`() = runBlocking {
        val vm = viewModel(BuscadorFalso(resposta = { listOf(asaSul) }))
        vm.editarEndereco("CLS 408")
        vm.buscarEndereco().join()
        assertEquals(listOf(asaSul), vm.estado.value.resultadosDaBusca)

        vm.editarEndereco("CLS 409")

        assertTrue(vm.estado.value.resultadosDaBusca.isEmpty())
        assertFalse(vm.estado.value.buscaSemResultado)
        assertFalse(vm.estado.value.erroDaBusca)
    }

    @Test
    fun `so os 5 primeiros resultados ficam`() = runBlocking {
        val vm = viewModel(BuscadorFalso(resposta = { List(9) { asaSul.copy(texto = "Rua $it") } }))
        vm.editarEndereco("Rua")
        vm.buscarEndereco().join()
        assertEquals(5, vm.estado.value.resultadosDaBusca.size)
    }

    @Test
    fun `durante uma busca um segundo toque nao dispara outra`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val buscador = BuscadorFalso(resposta = { liberar.await(); listOf(asaSul) })
        val vm = viewModel(buscador)
        vm.editarEndereco("CLS 408")
        val primeira = vm.buscarEndereco()
        val segunda = vm.buscarEndereco()
        liberar.complete(Unit)
        primeira.join()
        segunda.join()
        assertEquals(1, buscador.consultas.size)
    }
}
