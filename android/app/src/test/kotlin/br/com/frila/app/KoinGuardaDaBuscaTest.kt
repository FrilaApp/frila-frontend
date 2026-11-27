package br.com.frila.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.rede.ServicoChamadaDireta
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.feature.chamadas.casa.BuscaDeProfissionaisViewModel
import br.com.frila.feature.chamadas.casa.GuardaDaBusca
import br.com.frila.feature.chamadas.casa.ResultadoDaChamadaDaBusca
import br.com.frila.feature.chamadas.casa.ServicoDeRegioes
import br.com.frila.feature.chamadas.casa.TrabalhoDaChamada
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.io.IOException
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.koin.core.Koin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.koinApplication
import org.koin.dsl.module

/**
 * Cartão q5hioFIW (mesmo furo do JJnNU9Vc, agora na busca de profissionais): chamar com resultado incerto (sem rede, resposta perdida), sair
 * da busca e voltar não pode gerar uma chave de idempotência nova, nem outro trabalho completo, ou o servidor poderia abrir uma 2ª vaga.
 *
 * `koinViewModel` cria um view model por visita e o descarta quando a entrada da pilha sai. Cada visita aqui é um view model da fábrica REAL
 * do `moduloFeatures`, guardado num `ViewModelStore` (sair é `clear()`, o mesmo que a pilha faz), falando com um backend de mentira pelos
 * serviços de verdade.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGuardaDaBuscaTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val outraCasa = "22222222-2222-2222-2222-222222222222"
    private val garcom = "33333333-3333-3333-3333-333333333333"
    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private val trabalho = TrabalhoDaChamada(
        funcaoId = garcom,
        inicio = Instant.parse("2026-11-28T22:00:00Z"),
        fim = Instant.parse("2026-11-29T02:00:00Z"),
        local = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto",
        ponto = CoordenadaDto(-15.79, -47.88),
        valorCentavos = 18000,
        responsavelLocal = "Bistrô Ipê",
    )

    /** O servidor de mentira. [aoChamar] decide cada `chamar_profissional` (1º, 2º...): resposta ou falha. */
    private class Servidor(val garcom: String, val aoChamar: suspend (Int) -> Unit) {
        val corpos = mutableListOf<JsonObject>()
    }

    private fun cartao(id: String, garcom: String) =
        """{"id":"$id","nome":"Pessoa $id","servico":{"funcao":{"id":"$garcom","nome":"Garçom","categoria":"salao"},"unidade":"diaria","valor_centavos":15000,"horas_incluidas":8},"regioes":[],"atende_todo_df":false,"distancia_faixa":"ate_5km","reputacao":{"positivas":7,"total":7,"turnos_considerados":7,"turnos_realizados":7},"disponivel_no_horario":true}"""

    private fun clienteDe(servidor: Servidor) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { pedido ->
            val caminho = pedido.url.encodedPath
            when {
                caminho.endsWith("/configuracao_do_app") ->
                    respond("""{"plataforma":"android","versao_minima":"","recursos":{"busca_profissionais":true,"chamada_direta":true}}""", HttpStatusCode.OK, json)
                caminho.endsWith("/rest/v1/funcao") ->
                    respond("""[{"id":"${servidor.garcom}","nome":"Garçom","categoria":"salao"}]""", HttpStatusCode.OK, json)
                caminho.endsWith("/meu_estabelecimento") ->
                    respond(
                        """{"id":"$casa","nome":"Casa","tipo":"restaurante","endereco":"SCS Quadra 2","regiao_administrativa":"Plano Piloto","ponto":{"latitude":-15.79,"longitude":-47.88},"papel":"administrador"}""",
                        HttpStatusCode.OK, json,
                    )
                caminho.endsWith("/buscar_profissionais") ->
                    respond("""{"itens":[${cartao("p1", servidor.garcom)},${cartao("p2", servidor.garcom)}],"proximo_cursor":null}""", HttpStatusCode.OK, json)
                caminho.endsWith("/chamar_profissional") -> {
                    val corpo = Json.parseToJsonElement((pedido.body as TextContent).text).jsonObject
                    servidor.corpos += corpo
                    servidor.aoChamar(servidor.corpos.size)
                    val prof = corpo["profissional_id"]!!.jsonPrimitive.content
                    respond(
                        """{"id":"c-$prof","vaga_id":"vaga-1","profissional_id":"$prof","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-29T00:00:00Z","criada_em":"2026-11-28T12:00:00Z"}""",
                        HttpStatusCode.OK, json,
                    )
                }
                else -> respond("[]", HttpStatusCode.OK, json)
            }
        },
    )

    private fun comAplicacao(servidor: Servidor, comSeguranca: Boolean = false, bloco: suspend (Koin) -> Unit) = runBlocking {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val gestor = GestorClienteKtor { clienteDe(servidor) }
        val rede = module {
            single { gestor }
            single { ServicoChamadaDireta { gestor.clienteAtual } }
            single { ServicoVagas { gestor.clienteAtual } }
            single { ServicoMembros { gestor.clienteAtual } }
            single { ServicoDeRegioes { gestor.clienteAtual } }
        }
        val app = koinApplication { modules(*(if (comSeguranca) listOf(moduloSeguranca) else emptyList()).toTypedArray(), moduloFeatures, rede) }
        try { bloco(app.koin) } finally { app.close(); Dispatchers.resetMain() }
    }

    /** A pilha de navegação: cada [visita] é um view model da fábrica real; [sair] é o `clear()` da entrada que saiu. */
    private class Pilha(private val koin: Koin) {
        private var armazem = ViewModelStore()
        fun visita(casaId: String): BuscaDeProfissionaisViewModel {
            armazem = ViewModelStore()
            val fabrica = object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T =
                    koin.get<BuscaDeProfissionaisViewModel> { parametersOf(casaId) } as T
            }
            return ViewModelProvider(armazem, fabrica)[BuscaDeProfissionaisViewModel::class.java]
        }
        fun sair() = armazem.clear()
    }

    private val semRede: suspend (Int) -> Unit = { n -> if (n == 1) throw IOException("sem rede") }

    /** A pessoa busca, marca o p1 e chama: com [semRede], o 1º pedido termina incerto. */
    private suspend fun buscarEChamar(vm: BuscaDeProfissionaisViewModel) {
        vm.carregarCatalogos().join()
        vm.definirFuncao(garcom)
        vm.buscar().join()
        vm.alternarSelecao("p1")
        vm.chamar(trabalho).join()
    }

    /** O que a pessoa faria na visita seguinte: se a tela não voltou com o pedido pendente, busca e marca de novo; depois chama. */
    private suspend fun voltarEChamar(vm: BuscaDeProfissionaisViewModel) {
        vm.carregarCatalogos().join()
        if (!vm.estado.value.temEnvioPendente) {
            vm.definirFuncao(garcom)
            vm.buscar().join()
            vm.alternarSelecao("p1")
        }
        vm.chamar(trabalho).join()
    }

    @Test
    fun `chamada incerta, sair e voltar reenvia com a mesma chave e o mesmo trabalho`() {
        val servidor = Servidor(garcom, semRede)
        comAplicacao(servidor) { koin ->
            val pilha = Pilha(koin)
            val primeira = pilha.visita(casa)
            buscarEChamar(primeira)
            assertTrue(primeira.estado.value.temEnvioPendente, "o resultado incerto deixa o envio pendente")
            pilha.sair()

            val segunda = pilha.visita(casa)
            voltarEChamar(segunda)

            assertEquals(2, servidor.corpos.size)
            assertEquals(
                servidor.corpos[0]["chave"]!!.jsonPrimitive.content, servidor.corpos[1]["chave"]!!.jsonPrimitive.content,
                "a chave do pedido não pode mudar entre as visitas",
            )
            assertEquals(servidor.corpos[0], servidor.corpos[1], "o reenvio é o mesmo pedido, com o trabalho completo")
        }
    }

    @Test
    fun `na visita seguinte o reenvio leva o trabalho guardado, mesmo que a folha entregue outro`() {
        val servidor = Servidor(garcom, semRede)
        comAplicacao(servidor) { koin ->
            val pilha = Pilha(koin)
            buscarEChamar(pilha.visita(casa))
            pilha.sair()

            val segunda = pilha.visita(casa)
            segunda.carregarCatalogos().join()
            segunda.chamar(trabalho.copy(valorCentavos = 99_900, local = "Outro endereço")).join()

            assertEquals(2, servidor.corpos.size)
            assertEquals(servidor.corpos[0], servidor.corpos[1], "o trabalho do 1º envio da busca vale; outro valor abriria outra vaga")
        }
    }

    @Test
    fun `a segunda visita volta com a busca, a selecao e o resultado incerto, sem envio em curso`() {
        val servidor = Servidor(garcom, semRede)
        comAplicacao(servidor) { koin ->
            val pilha = Pilha(koin)
            val primeira = pilha.visita(casa)
            buscarEChamar(primeira)
            pilha.sair()

            val estado = pilha.visita(casa).estado.value

            assertEquals(listOf("p1", "p2"), estado.resultados.map { it.id })
            assertEquals(listOf("p1"), estado.selecionados)
            assertEquals(true, estado.resultadosDaChamada["p1"].let { it is ResultadoDaChamadaDaBusca.Erro && it.incerto })
            assertFalse(estado.enviando)
            assertTrue(estado.temEnvioPendente)
            assertFalse(estado.podeBuscar, "com envio pendente a busca fica travada, como antes de sair")
            assertEquals(trabalho, estado.trabalhoEnviadoDaBusca)
        }
    }

    @Test
    fun `sair com o envio em voo volta como incerto sem envio em curso e reenvia a mesma chave`() {
        val chegou = CompletableDeferred<Unit>()
        val servidor = Servidor(garcom) { n -> if (n == 1) { chegou.complete(Unit); awaitCancellation() } }
        comAplicacao(servidor) { koin ->
            val pilha = Pilha(koin)
            val primeira = pilha.visita(casa)
            primeira.carregarCatalogos().join()
            primeira.definirFuncao(garcom)
            primeira.buscar().join()
            primeira.alternarSelecao("p1")
            primeira.chamar(trabalho) // não termina: o servidor não responde
            assertTrue(primeira.estado.value.enviando)
            withTimeout(5_000) { chegou.await() } // só sai depois de o pedido chegar ao servidor: o incerto é "chegou e não voltou"
            pilha.sair()

            val segunda = pilha.visita(casa)

            assertFalse(segunda.estado.value.enviando, "o envio interrompido não volta como 'enviando'")
            assertTrue(segunda.estado.value.temEnvioPendente)
            segunda.reenviar().join()
            assertEquals(2, servidor.corpos.size)
            assertEquals(servidor.corpos[0], servidor.corpos[1])
            assertTrue(segunda.estado.value.resultadosDaChamada["p1"] is ResultadoDaChamadaDaBusca.Enviada)
        }
    }

    @Test
    fun `depois do envio resolvido a guarda esvazia e a visita seguinte comeca limpa, com chave nova`() {
        val servidor = Servidor(garcom, semRede)
        comAplicacao(servidor) { koin ->
            val pilha = Pilha(koin)
            buscarEChamar(pilha.visita(casa))
            pilha.sair()
            val segunda = pilha.visita(casa)
            segunda.reenviar().join() // o reenvio dá certo
            assertTrue(segunda.estado.value.resultadosDaChamada["p1"] is ResultadoDaChamadaDaBusca.Enviada)
            pilha.sair()

            val terceira = pilha.visita(casa)

            assertTrue(terceira.estado.value.resultados.isEmpty(), "sem pendência a busca recomeça limpa")
            assertTrue(terceira.estado.value.resultadosDaChamada.isEmpty())
            assertFalse(terceira.estado.value.temEnvioPendente)
            terceira.carregarCatalogos().join()
            terceira.definirFuncao(garcom)
            terceira.buscar().join()
            terceira.alternarSelecao("p2")
            terceira.chamar(trabalho).join()
            assertEquals(3, servidor.corpos.size)
            assertTrue(
                servidor.corpos[2]["chave"]!!.jsonPrimitive.content != servidor.corpos[0]["chave"]!!.jsonPrimitive.content,
                "uma chamada nova nasce com chave nova",
            )
        }
    }

    @Test
    fun `a guarda e por casa, o envio pendente de uma nao aparece na outra`() {
        val servidor = Servidor(garcom, semRede)
        comAplicacao(servidor) { koin ->
            val pilha = Pilha(koin)
            buscarEChamar(pilha.visita(casa))
            pilha.sair()

            val daOutraCasa = pilha.visita(outraCasa)

            assertTrue(daOutraCasa.estado.value.resultados.isEmpty())
            assertFalse(daOutraCasa.estado.value.temEnvioPendente)
            pilha.sair()
            assertTrue(pilha.visita(casa).estado.value.temEnvioPendente, "a da primeira casa continua guardada")
        }
    }

    @Test
    fun `a recorrencia pendente tambem volta e o J7 confirma com a mesma chave`() {
        val recorrencia: suspend (Int) -> Unit = { n ->
            if (n == 1) throw br.com.frila.core.rede.ErroDaApi(
                br.com.frila.core.dominio.modelo.CodigoErroAPI.RECORRENCIA_NAO_CONFIRMADA, "recorrencia_nao_confirmada", null, "x",
            )
        }
        val servidor = Servidor(garcom, recorrencia)
        comAplicacao(servidor) { koin ->
            val pilha = Pilha(koin)
            val primeira = pilha.visita(casa)
            buscarEChamar(primeira)
            assertTrue(primeira.estado.value.mostrarJ7)
            pilha.sair()

            val segunda = pilha.visita(casa)

            assertTrue(segunda.estado.value.mostrarJ7, "o aviso J7 volta")
            segunda.confirmarJ7().join()
            assertEquals(2, servidor.corpos.size)
            assertEquals(
                servidor.corpos[0]["chave"]!!.jsonPrimitive.content, servidor.corpos[1]["chave"]!!.jsonPrimitive.content,
            )
            assertTrue(servidor.corpos[1]["confirmo_recorrencia"]!!.jsonPrimitive.boolean)
        }
    }

    @Test
    fun `o logout esvazia a guarda pelo ponto unico de limpeza da sessao`() {
        val servidor = Servidor(garcom, semRede)
        comAplicacao(servidor, comSeguranca = true) { koin ->
            val pilha = Pilha(koin)
            buscarEChamar(pilha.visita(casa))
            pilha.sair()
            assertTrue(pilha.visita(casa).estado.value.temEnvioPendente, "a pendência foi guardada")
            pilha.sair()

            koin.get<ArmazenamentoDeSessao>().limparSessao()

            val depois = pilha.visita(casa)
            assertTrue(depois.estado.value.resultados.isEmpty(), "a conta seguinte não herda a busca da que saiu")
            assertFalse(depois.estado.value.temEnvioPendente)
        }
    }

    @Test
    fun `logout com a tela aberta e sair depois nao devolve a pendencia da conta que saiu`() {
        val servidor = Servidor(garcom, semRede)
        comAplicacao(servidor, comSeguranca = true) { koin ->
            val pilha = Pilha(koin)
            val primeira = pilha.visita(casa)
            buscarEChamar(primeira)

            koin.get<ArmazenamentoDeSessao>().limparSessao() // sai da conta com a tela ainda aberta
            pilha.sair() // a tela fecha depois: o view model não pode recolocar o que o logout apagou

            val depois = pilha.visita(casa)
            assertTrue(depois.estado.value.resultados.isEmpty(), "a pendência da conta que saiu não volta")
            assertFalse(depois.estado.value.temEnvioPendente)
        }
    }

    @Test
    fun `a guarda e unica no grafo e a fabrica entrega a mesma aos view models`() {
        val servidor = Servidor(garcom, semRede)
        comAplicacao(servidor) { koin ->
            assertNotNull(koin.get<GuardaDaBusca>())
            assertTrue(koin.get<GuardaDaBusca>() === koin.get<GuardaDaBusca>())
        }
    }
}
