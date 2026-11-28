package br.com.frila.feature.vagas.feed

import br.com.frila.core.dominio.modelo.AlvoBloqueado
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/** I1PonzKJ, fatia 3: o feed do profissional não mostra vaga de estabelecimento que ele bloqueou nesta sessão (iOS: `FeedVagasViewModel.bloqueios`). */
class FeedVagasBloqueadosTest {

    private val casaA = "aaaaaaaa-0000-0000-0000-00000000000a"
    private val casaB = "bbbbbbbb-0000-0000-0000-00000000000b"

    private fun vagaJson(id: String, casaId: String, funcao: String = "garçom") = """
        {"id": "$id",
         "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "$funcao", "categoria": "Salão"},
         "estabelecimento": {"id": "$casaId", "tipo": "estabelecimento", "nome": "Casa $casaId",
           "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}},
         "inicio_em": "2099-11-01T21:00:00Z", "fim_em": "2099-11-02T03:00:00Z", "local": "SQN 108", "regiao_administrativa": "Asa Norte",
         "distancia_km": 4.2, "valor_centavos": 16000, "posicoes_abertas": 2,
         "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false}, "modo": "selecao"}
    """.trimIndent()

    private val vagaDaA = vagaJson("11111111-1111-1111-1111-111111111111", casaA, funcao = "garçom")
    private val vagaDaB = vagaJson("22222222-2222-2222-2222-222222222222", casaB, funcao = "cozinheiro")

    private fun viewModel(bloqueios: BloqueiosDaSessao?): FeedVagasViewModel {
        val engine = MockEngine {
            respond("[$vagaDaA,$vagaDaB]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return FeedVagasViewModel(
            servicoVagas = ServicoVagas(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)),
            escopo = CoroutineScope(Dispatchers.Default),
            bloqueios = bloqueios,
        )
    }

    private fun ids(vm: FeedVagasViewModel) = vm.estado.value.vagas.map { it.id }

    private suspend fun esperar(descricao: String, condicao: () -> Boolean) {
        try { withTimeout(5_000) { while (!condicao()) delay(10) } } catch (_: Exception) { throw AssertionError("não chegou a: $descricao") }
    }

    private val casaBloqueada = AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "aaaaaaaa-0000-0000-0000-00000000000a")

    @Test
    fun `estabelecimento ja bloqueado nao aparece no feed`() = runBlocking {
        val sessao = BloqueiosDaSessao().apply { registrar(casaBloqueada) }
        val vm = viewModel(sessao)

        vm.carregar().join()

        assertEquals(listOf("22222222-2222-2222-2222-222222222222"), ids(vm))
    }

    @Test
    fun `bloquear com o feed carregado tira a vaga na hora e desbloquear a devolve`() = runBlocking {
        val sessao = BloqueiosDaSessao()
        val vm = viewModel(sessao)
        vm.carregar().join()
        assertEquals(2, ids(vm).size)

        sessao.registrar(casaBloqueada)
        esperar("sumir a vaga da casa bloqueada") { ids(vm).size == 1 }
        sessao.remover(casaBloqueada)
        esperar("a vaga voltar") { ids(vm).size == 2 }
    }

    @Test
    fun `todas bloqueadas, o feed fica vazio e nao em erro`() = runBlocking {
        val sessao = BloqueiosDaSessao().apply {
            registrar(casaBloqueada)
            registrar(AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, casaB))
        }
        val vm = viewModel(sessao)

        vm.carregar().join()

        assertEquals(StatusFeed.VAZIO, vm.estado.value.status)
    }

    @Test
    fun `o mesmo id com outro tipo nao esconde a vaga`() = runBlocking {
        val sessao = BloqueiosDaSessao().apply { registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, casaA)) }
        val vm = viewModel(sessao)

        vm.carregar().join()

        assertEquals(2, ids(vm).size)
    }

    @Test
    fun `a vaga do bloqueado nao e achada pelo id e a funcao dela some do filtro`() = runBlocking {
        val sessao = BloqueiosDaSessao().apply { registrar(casaBloqueada) }
        val vm = viewModel(sessao)
        vm.carregar().join()

        assertNull(vm.encontrarVagaPorId("11111111-1111-1111-1111-111111111111"))
        assertNotNull(vm.encontrarVagaPorId("22222222-2222-2222-2222-222222222222"))
        assertEquals(listOf("cozinheiro"), vm.estado.value.funcoesDisponiveis)
    }

    @Test
    fun `bloquear antes de a lista chegar nao estraga o carregamento`() = runBlocking {
        val sessao = BloqueiosDaSessao()
        val vm = viewModel(sessao)

        sessao.registrar(casaBloqueada)
        vm.carregar().join()

        assertEquals(listOf("22222222-2222-2222-2222-222222222222"), ids(vm))
        assertEquals(StatusFeed.SUCESSO, vm.estado.value.status)
    }

    @Test
    fun `sem o conjunto, o feed mostra tudo`() = runBlocking {
        val vm = viewModel(null)

        vm.carregar().join()

        assertEquals(2, ids(vm).size)
    }
}
