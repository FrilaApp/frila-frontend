package br.com.frila.feature.chamadas.casa

import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class PerfilPublicoViewModelTest {

    private val profissional = "22222222-2222-2222-2222-222222222222"
    private val garcom = "33333333-3333-3333-3333-333333333333"

    private val perfilJson = """
        {"id":"$profissional","tipo":"profissional","nome":"Maria S.","funcoes":["Garçom"],
         "reputacao":{"positivas":7,"total":8,"taxa_comparecimento":1.0,"turnos_considerados":8,"turnos_realizados":8},
         "apresentacao":"Dez anos de salão","experiencia_faixa":"de_5_a_10_anos","cursos":["Boas práticas"],
         "idiomas":["portugues","ingles"],
         "servicos":[{"funcao":{"id":"$garcom","nome":"Garçom","categoria":"salao"},"unidade":"diaria","valor_centavos":15000,"horas_incluidas":8}],
         "regioes":[{"id":1,"numero":"I","nome":"Plano Piloto"}],"atende_todo_df":false}
    """.trimIndent()

    private fun viewModelCom(rede: RedeDeTeste, prazoMs: Long = 5_000) = PerfilPublicoViewModel(
        id = profissional,
        buscar = rede.chamadas::perfilPublico,
        prazoMs = prazoMs,
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `comeca carregando e carregar mostra o perfil, com o nome do jeito que o servidor mandou`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("perfil_publico", perfilJson) }
        val vm = viewModelCom(rede)
        assertEquals(EstadoPerfilPublico.Carregando, vm.estado.value)

        vm.carregar().join()

        val perfil = (vm.estado.value as EstadoPerfilPublico.Carregado).perfil
        assertEquals("Maria S.", perfil.nome)
        assertEquals(15000L, perfil.servicos!!.single().valorCentavos)
        assertEquals(profissional, rede.doNome("perfil_publico").single().corpo["id"]!!.jsonPrimitive.content)
    }

    @Test
    fun `404 vira perfil indisponivel, que e o caso do bloqueio`() = runBlocking {
        val rede = RedeDeTeste().apply { recusa("perfil_publico", HttpStatusCode.NotFound, "nao_encontrado") }
        val vm = viewModelCom(rede)

        vm.carregar().join()

        assertEquals(EstadoPerfilPublico.Indisponivel, vm.estado.value)
    }

    @Test
    fun `sem rede, erro do servidor e corpo ilegivel viram falha com texto proprio, e tentar novamente recupera`() = runBlocking {
        var situacao = "offline"
        val rede = RedeDeTeste().apply {
            rota("perfil_publico") {
                when (situacao) {
                    "offline" -> throw ConnectTimeoutException("sem rota", null)
                    "500" -> respond("""{"code":"erro_interno","message":"x"}""", HttpStatusCode.InternalServerError, headersOf(HttpHeaders.ContentType, "application/json"))
                    "html" -> respond("<html>bad gateway</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html"))
                    else -> respond(perfilJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                }
            }
        }
        val vm = viewModelCom(rede)

        vm.carregar().join()
        assertEquals(EstadoPerfilPublico.Falha(TextosChamadaCasa.SEM_REDE), vm.estado.value)
        situacao = "500"
        vm.carregar().join()
        assertEquals(EstadoPerfilPublico.Falha(TextosChamadaCasa.ERRO_GENERICO), vm.estado.value)
        situacao = "html"
        vm.carregar().join()
        assertEquals(EstadoPerfilPublico.Falha(TextosChamadaCasa.ERRO_GENERICO), vm.estado.value)
        situacao = "ok"
        vm.carregar().join()
        assertTrue(vm.estado.value is EstadoPerfilPublico.Carregado)
    }

    @Test
    fun `prazo estourado vira falha e nao deixa a tela carregando`() = runBlocking {
        val rede = RedeDeTeste().apply {
            rota("perfil_publico") { delay(10_000); respond(perfilJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) }
        }
        val vm = viewModelCom(rede, prazoMs = 100)

        vm.carregar().join()

        assertEquals(EstadoPerfilPublico.Falha(TextosChamadaCasa.ERRO_GENERICO), vm.estado.value)
    }

    @Test
    fun `os textos do perfil seguem o iOS`() {
        assertEquals("7 de 8 chamariam de novo", TextosChamadaCasa.reputacao(7, 8))
        assertEquals("Sem histórico", TextosChamadaCasa.reputacao(0, 0))
        assertEquals("Compareceu a 8 de 8 turnos", TextosChamadaCasa.comparecimento(8, 8))
        assertEquals("Compareceu a 1 de 1 turno", TextosChamadaCasa.comparecimento(1, 1))
        assertEquals("5 a 10 anos", TextosChamadaCasa.experiencia("de_5_a_10_anos"))
        assertEquals("Inglês", TextosChamadaCasa.idioma("ingles"))
        assertEquals("Diária", TextosChamadaCasa.unidadeDoServico("diaria"))
    }
}
