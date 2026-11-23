package br.com.frila.feature.perfil

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import java.io.File
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

@OptIn(ExperimentalCoroutinesApi::class)
class ExportarDadosViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    @TempDir lateinit var cache: File
    @BeforeEach fun preparar() { Dispatchers.setMain(dispatcher) }
    @AfterEach fun encerrar() { Dispatchers.resetMain() }

    @Test
    fun `sucesso grava bytes sem alterar e limpa somente JSONs da exportacao anterior`() = runTest(dispatcher) {
        val pasta = File(cache, "meus-dados").apply { mkdirs() }
        val antigo = File(pasta, "frila-meus-dados-antigo.json").apply { writeText("{}") }
        val outro = File(pasta, "outro.json").apply { writeText("{}") }
        val dados = """{ "nome": "Ação" }""".toByteArray()
        val vm = ExportarDadosViewModel({ dados }, dispatcher)
        vm.exportar(cache)
        assertTrue(vm.estado.value.carregando)
        advanceUntilIdle()
        val arquivo = requireNotNull(vm.estado.value.arquivo)
        assertEquals("json", arquivo.extension)
        assertArrayEquals(dados, arquivo.readBytes())
        assertFalse(antigo.exists())
        assertTrue(outro.exists())
        assertFalse(vm.estado.value.carregando)
        vm.compartilhamentoAberto()
        assertNull(vm.estado.value.arquivo)
        assertTrue(arquivo.exists()) // Destinatário ainda pode ler depois de ACTION_SEND.
    }

    @Test
    fun `erro libera nova tentativa e preserva codigo sem mensagem crua`() = runTest(dispatcher) {
        var falhar = true
        val vm = ExportarDadosViewModel({
            if (falhar) throw ErroDaApi(CodigoErroAPI.NAO_ENCONTRADO, "nao_encontrado", null, "mensagem interna")
            "{}".toByteArray()
        }, dispatcher)
        vm.exportar(cache)
        advanceUntilIdle()
        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, vm.estado.value.erro)
        assertNull(vm.estado.value.arquivo)
        falhar = false
        vm.exportar(cache)
        advanceUntilIdle()
        assertNull(vm.estado.value.erro)
        assertNotNull(vm.estado.value.arquivo)
    }

    @Test
    fun `dois cliques antes do launch e durante a requisicao exportam uma vez`() = runTest(dispatcher) {
        val resposta = CompletableDeferred<ByteArray>()
        var chamadas = 0
        val vm = ExportarDadosViewModel({ chamadas++; resposta.await() }, dispatcher)
        vm.exportar(cache)
        vm.exportar(cache)
        advanceUntilIdle()
        vm.exportar(cache)
        resposta.complete("{}".toByteArray())
        advanceUntilIdle()
        assertEquals(1, chamadas)
        assertNotNull(vm.estado.value.arquivo)
    }

    @Test
    fun `falha de escrita permite tentar novamente sem arquivo parcial`() = runTest(dispatcher) {
        val vm = ExportarDadosViewModel({ "{}".toByteArray() }, dispatcher)
        val arquivoComoPasta = File(cache, "arquivo").apply { writeText("x") }
        vm.exportar(arquivoComoPasta)
        advanceUntilIdle()
        assertEquals(CodigoErroAPI.DESCONHECIDO, vm.estado.value.erro)
        assertFalse(vm.estado.value.carregando)
        assertNull(vm.estado.value.arquivo)
    }
}
