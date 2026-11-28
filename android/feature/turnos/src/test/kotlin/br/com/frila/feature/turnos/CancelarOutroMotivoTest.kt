package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.MotivoCancelamento
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão irPIMqTk (item 238): cancelar o turno com "Outro motivo" exige 3 caracteres depois de aparar as pontas
 * (`EstadoCancelamentoTurno.motivoCompleto`), e `confirmarCancelamento` sai sem enviar abaixo disso. Os testes antigos só digitam texto
 * longo; `>= 3` virar `> 3` ou `>= 2` e tirar o `trim()` passavam. Aqui: 2 e 3 caracteres, com e sem espaços nas pontas.
 */
class CancelarOutroMotivoTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val turnoJson = """
        {"id":"a","posicao_id":"posicao-a","vaga":{"id":"vaga-a","funcao":"garçom","local":"CLS 405 Bloco C","regiao_administrativa":"Plano Piloto",
        "inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z","valor_centavos":16000},
        "contraparte":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé","reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},
        "contato_visivel_ate":"2026-11-09T03:00:00Z","a_caminho_em":null,"checkin_em":null,"checkin_tipo":null,"checkin_distancia_m":null,
        "checkin_confirmado_em":null,"checkout_em":null,"checkout_distancia_m":null,"verificacao":"pendente","valor_acordado_centavos":16000,
        "pode_avaliar":false,"estado":"confirmada","avaliacao":null,"cancelamento":null}
    """.trimIndent()

    private val corposDoCancelamento = mutableListOf<String>()

    private fun viewModelComTurno(segurarEnvio: CompletableDeferred<Unit>? = null): MeusTurnosViewModel {
        corposDoCancelamento.clear()
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("meus_turnos")) {
                respond("[$turnoJson]", HttpStatusCode.OK, json)
            } else {
                corposDoCancelamento += (request.body as TextContent).text
                segurarEnvio?.await()
                respond("""{"posicao_id":"posicao-a","falta":false,"reaberta":true,"nova_posicao_id":"nova-a"}""", HttpStatusCode.OK, json)
            }
        }
        val vm = MeusTurnosViewModel(
            ServicoTurnos(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine)),
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        runBlocking { vm.carregar().join() }
        vm.abrirCancelamento(vm.estado.value.agendados.first())
        return vm
    }

    private fun MeusTurnosViewModel.comOutroMotivo(detalhes: String): MeusTurnosViewModel {
        selecionarMotivo(MotivoCancelamento.OUTRO)
        atualizarDetalhes(detalhes)
        return this
    }

    /** Confirma e espera o envio terminar; `null` se a confirmação saiu sem enviar. */
    private fun enviar(vm: MeusTurnosViewModel) = vm.confirmarCancelamento()?.also { runBlocking { it.join() } }

    private val MeusTurnosViewModel.cancelamento get() = estado.value.cancelamento!!

    @Test
    fun `abaixo de 3 caracteres nao confirma, nao tem motivo completo e o envio sai sem mandar nada`() {
        for (detalhes in listOf("", " ", "a", "ab", "  ab  ", "\n ab\t", "   a   ", "ab   ")) {
            val vm = viewModelComTurno().comOutroMotivo(detalhes)

            assertNull(vm.cancelamento.motivoCompleto, "'$detalhes'")
            assertFalse(vm.cancelamento.podeConfirmar, "'$detalhes'")
            assertNull(vm.confirmarCancelamento(), "'$detalhes'")
            assertTrue(corposDoCancelamento.isEmpty(), "'$detalhes' não pode chegar ao servidor")
            assertNotNull(vm.estado.value.cancelamento, "'$detalhes': o diálogo segue aberto")
        }
    }

    @Test
    fun `exatamente 3 caracteres confirmam, com ou sem espacos nas pontas, e o motivo vai aparado`() {
        for ((digitado, enviado) in listOf("abc" to "abc", "  abc  " to "abc", "\n abc\t" to "abc", "a b" to "a b", " a b " to "a b")) {
            val vm = viewModelComTurno().comOutroMotivo(digitado)

            assertEquals(enviado, vm.cancelamento.motivoCompleto, "'$digitado'")
            assertTrue(vm.cancelamento.podeConfirmar, "'$digitado'")
            assertNotNull(enviar(vm), "'$digitado'")
            assertEquals(1, corposDoCancelamento.size, "'$digitado'")
            assertTrue(corposDoCancelamento.single().contains("\"motivo\":\"$enviado\""), "'$digitado' → ${corposDoCancelamento.single()}")
        }
    }

    @Test
    fun `de 2 para 3 caracteres o botao passa de desligado a ligado, digitando uma letra por vez`() {
        val vm = viewModelComTurno()
        vm.selecionarMotivo(MotivoCancelamento.OUTRO)

        vm.atualizarDetalhes("a"); assertFalse(vm.cancelamento.podeConfirmar)
        vm.atualizarDetalhes("ab"); assertFalse(vm.cancelamento.podeConfirmar)
        vm.atualizarDetalhes("abc"); assertTrue(vm.cancelamento.podeConfirmar)
        vm.atualizarDetalhes("abcd"); assertTrue(vm.cancelamento.podeConfirmar)
        vm.atualizarDetalhes("ab "); assertFalse(vm.cancelamento.podeConfirmar, "o espaço no fim não conta")
    }

    @Test
    fun `os outros motivos nao pedem detalhes e mandam a propria descricao`() {
        for (motivo in MotivoCancelamento.entries.filter { it != MotivoCancelamento.OUTRO }) {
            val vm = viewModelComTurno()
            vm.selecionarMotivo(motivo)

            assertEquals(motivo.descricao, vm.cancelamento.motivoCompleto, "$motivo")
            assertTrue(vm.cancelamento.podeConfirmar, "$motivo")
            assertNotNull(enviar(vm), "$motivo")
            assertTrue(corposDoCancelamento.single().contains("\"motivo\":\"${motivo.descricao}\""), "$motivo")
        }
    }

    @Test
    fun `trocar de outro motivo para um com descricao apaga o texto digitado, e voltar a outro comeca vazio`() {
        val vm = viewModelComTurno().comOutroMotivo("preciso sair")
        vm.selecionarMotivo(MotivoCancelamento.SAUDE)
        assertEquals("", vm.cancelamento.detalhes)

        vm.selecionarMotivo(MotivoCancelamento.OUTRO)

        assertFalse(vm.cancelamento.podeConfirmar, "o texto antigo não volta")
        assertNull(vm.confirmarCancelamento())
        assertTrue(corposDoCancelamento.isEmpty())
    }

    @Test
    fun `com o envio em andamento um segundo toque nao envia de novo`() {
        val liberar = CompletableDeferred<Unit>()
        val vm = viewModelComTurno(segurarEnvio = liberar).comOutroMotivo("abc")

        val primeiro = vm.confirmarCancelamento()
        assertNotNull(primeiro)
        assertTrue(vm.cancelamento.enviando)
        assertFalse(vm.cancelamento.podeConfirmar, "enviando: o botão desliga")
        assertNull(vm.confirmarCancelamento(), "o segundo toque sai sem enviar")
        liberar.complete(Unit)
        runBlocking { primeiro!!.join() }

        assertEquals(1, corposDoCancelamento.size)
    }

    @Test
    fun `sem escolher motivo nenhum o cancelamento direto segue valendo, com o motivo padrao`() {
        val vm = viewModelComTurno()

        assertNull(vm.cancelamento.motivoCompleto)
        assertTrue(vm.cancelamento.podeConfirmar)
        assertNotNull(enviar(vm))
        assertTrue(corposDoCancelamento.single().contains("\"motivo\":\"Cancelamento pelo profissional\""))
    }
}
