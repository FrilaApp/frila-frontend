package br.com.frila.feature.vagas.publicacao

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão 0Nm8bS1q: a ligação inteira, tela real e `PublicarVagaViewModel` real, até o corpo que sai para `publicar_vaga`. O teste de tela
 * prova as opções e o do view model prova o corpo; só este prova que a tela está ligada ao view model.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AlertaDeAntecedenciaLigadoTest {

    @get:Rule
    val rule = createComposeRule()

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val agora: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private fun viewModel(corposDePublicar: MutableList<JsonObject>): PublicarVagaViewModel {
        val engine = MockEngine { request ->
            if (request.url.encodedPath.endsWith("/funcao")) {
                respond("""[{"id":"f1","nome":"Garçom","categoria":"Salão"}]""", HttpStatusCode.OK, json)
            } else {
                val corpo = (request.body as TextContent).text
                corposDePublicar += ClienteSupabase.jsonFrila.parseToJsonElement(corpo).jsonObject
                respond("""{"vaga_id":"v1","posicoes":["p1","p2"]}""", HttpStatusCode.OK, json)
            }
        }
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return PublicarVagaViewModel(
            estabelecimento = EstabelecimentoDaVaga("e1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822)),
            buscarFuncoes = servico::listarFuncoes,
            enviarVaga = servico::publicarVaga,
            relogio = { agora },
            novaChave = { "chave-1" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private fun publicarEscolhendo(rotulo: String?): String {
        val corpos = java.util.Collections.synchronizedList(mutableListOf<JsonObject>())
        val vm = viewModel(corpos)
        runBlocking { vm.carregarFuncoes().join() }
        vm.escolherFuncao("f1")
        vm.editarValor("140")
        vm.editarPosicoes("2")
        vm.editarResponsavel("Lia")
        rule.setContent { FrilaTheme { TelaPublicarVaga(viewModel = vm, aoPublicar = {}, aoVoltar = {}) } }

        if (rotulo != null) {
            rule.onNodeWithText(TextosPublicarVaga.MAIS_OPCOES).performScrollTo().performClick()
            rule.onNodeWithText(rotulo).performScrollTo().performClick()
        }
        rule.onNodeWithText(TextosPublicarVaga.PUBLICAR).performClick() // fica no rodapé, fora da área rolável
        rule.waitUntil(5_000) { corpos.isNotEmpty() }

        return corpos.single()["alerta_antecedencia_min"]!!.jsonPrimitive.content
    }

    @Test
    fun escolherSeisHorasNaTelaManda360ParaOServidor() {
        assertEquals("360", publicarEscolhendo("6 horas antes"))
    }

    @Test
    fun escolherDuasHorasNaTelaManda120ParaOServidor() {
        assertEquals("120", publicarEscolhendo("2 horas antes"))
    }

    @Test
    fun semMexerEmMaisOpcoesOServidorRecebeOPadraoDeTresHoras() {
        assertEquals("180", publicarEscolhendo(null))
    }
}
