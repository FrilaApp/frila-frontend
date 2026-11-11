package br.com.frila.feature.vagas.painel

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.time.Duration
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TelaMinhasVagasTest {

    @get:Rule
    val rule = createComposeRule()

    private fun item(
        id: String,
        funcao: String = "Garçom",
        secao: SecaoMinhasVagas = SecaoMinhasVagas.PROXIMAS,
        inicio: String? = "2026-11-12T21:00:00Z",
        fim: String? = "2026-11-13T03:00:00Z",
        total: Int = 3,
        confirmadas: Int = 1,
        abertas: Int = 2,
        pendentes: Int = 0,
        selecao: Boolean = false,
        oculta: Boolean = false,
        emAtraso: Int = 0,
        podeVerCandidatos: Boolean = false,
        recemPublicada: Boolean = false,
        comecaEm: Duration? = null,
    ) = ItemMinhaVaga(
        id = id, funcao = funcao, local = "SQN 108", inicio = inicio?.let(Instant::parse), fim = fim?.let(Instant::parse),
        valorCentavos = 16_000, selecao = selecao, oculta = oculta, alertaVagaVazia = secao == SecaoMinhasVagas.EM_ALERTA,
        candidatosPendentes = pendentes, totalPosicoes = total, confirmadas = confirmadas, posicoesAbertas = abertas,
        emAtraso = emAtraso, secao = secao, recemPublicada = recemPublicada, podeVerCandidatos = podeVerCandidatos,
        comecaEm = comecaEm,
    )

    private fun sucesso(vararg itens: ItemMinhaVaga) = EstadoMinhasVagas(lista = ListaMinhasVagas.Sucesso(itens.toList()))

    private class Chamadas {
        var carregou = 0
        var atualizou = 0
        var publicou = 0
        var voltou = 0
        val candidatos = mutableListOf<ItemMinhaVaga>()
    }

    private fun montar(
        estado: EstadoMinhasVagas,
        nome: String? = "Bar da Lia",
        chamadas: Chamadas = Chamadas(),
    ): Chamadas {
        rule.setContent {
            FrilaTheme {
                ConteudoMinhasVagas(
                    estado = estado,
                    nomeEstabelecimento = nome,
                    acoes = AcoesMinhasVagas(
                        aoCarregar = { chamadas.carregou++ },
                        aoAtualizar = { chamadas.atualizou++ },
                        aoVerCandidatos = { chamadas.candidatos += it },
                        aoPublicarVaga = { chamadas.publicou++ },
                        aoVoltar = { chamadas.voltou++ },
                    ),
                )
            }
        }
        return chamadas
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `mostra o titulo em cabecalho e o nome do estabelecimento`() {
        montar(sucesso(item("v1")))

        rule.onNodeWithText(TextosMinhasVagas.TITULO).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText("Bar da Lia").assertIsDisplayed()
    }

    @Test
    fun `as secoes aparecem na ordem atencao, hoje, proximas, encerradas, cada uma como cabecalho, e so as que tem vagas`() {
        montar(
            sucesso(
                item("a", funcao = "Cozinheiro", secao = SecaoMinhasVagas.ENCERRADAS),
                item("b", funcao = "Barman", secao = SecaoMinhasVagas.PROXIMAS),
                item("c", funcao = "Garçom", secao = SecaoMinhasVagas.EM_ALERTA),
            ),
        )

        val alerta = rule.onNodeWithText(TextosMinhasVagas.EM_ALERTA).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        val proximas = rule.onNodeWithText(TextosMinhasVagas.PROXIMAS)
        val encerradas = rule.onNodeWithText(TextosMinhasVagas.ENCERRADAS)
        assertTrue(alerta.getUnclippedBoundsInRoot().top < proximas.getUnclippedBoundsInRoot().top)
        assertTrue(proximas.getUnclippedBoundsInRoot().top < encerradas.getUnclippedBoundsInRoot().top)
        assertEquals(0, contar(TextosMinhasVagas.HOJE))
    }

    @Test
    fun `cada cartao mostra funcao, periodo, local, valor, posicoes e confirmadas`() {
        montar(sucesso(item("v1")))

        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText("12/11/2026 18:00 – 13/11/2026 00:00").assertIsDisplayed()
        rule.onNodeWithText("SQN 108").assertIsDisplayed()
        rule.onNodeWithText("R$ 160,00 por pessoa").assertIsDisplayed()
        rule.onNodeWithText("3 posições · 1 de 3 confirmadas").assertIsDisplayed()
    }

    @Test
    fun `vaga de um dia mostra o periodo numa linha e vaga de uma posicao fala no singular`() {
        montar(sucesso(item("v1", inicio = "2026-11-12T21:00:00Z", fim = "2026-11-13T00:00:00Z", total = 1, confirmadas = 0, abertas = 1)))

        rule.onNodeWithText("12/11/2026, 18:00 – 21:00").assertIsDisplayed()
        rule.onNodeWithText("1 posição · 0 de 1 confirmada").assertIsDisplayed()
    }

    @Test
    fun `instante ilegivel nao quebra o cartao`() {
        montar(sucesso(item("v1", inicio = null, fim = null, secao = SecaoMinhasVagas.ENCERRADAS)))

        rule.onNodeWithText("Garçom").assertIsDisplayed()
    }

    @Test
    fun `marcas da vaga aparecem so quando valem`() {
        montar(
            sucesso(
                item("v1", funcao = "Barman", recemPublicada = true, oculta = true, selecao = true, pendentes = 2, emAtraso = 1),
                item("v2", funcao = "Cozinheiro"),
            ),
        )

        assertEquals(1, contar(TextosMinhasVagas.RECEM_PUBLICADA))
        assertEquals(1, contar(TextosMinhasVagas.OCULTA))
        assertEquals(1, contar(TextosMinhasVagas.MODO_SELECAO))
        rule.onNodeWithText("2 candidatos aguardando sua escolha").assertIsDisplayed()
        rule.onNodeWithText(TextosMinhasVagas.EM_ATRASO_UM).assertIsDisplayed()
    }

    @Test
    fun `um candidato fala no singular e varios atrasos no plural`() {
        montar(sucesso(item("v1", pendentes = 1, emAtraso = 2)))

        rule.onNodeWithText(TextosMinhasVagas.CANDIDATO_UM).assertIsDisplayed()
        rule.onNodeWithText("2 profissionais sem check-in há mais de 15 minutos").assertIsDisplayed()
    }

    @Test
    fun `vaga que precisa de atencao diz quanto falta para comecar`() {
        montar(sucesso(item("v1", secao = SecaoMinhasVagas.EM_ALERTA, comecaEm = Duration.ofMinutes(135))))

        rule.onNodeWithText("Começa em 2 h 15 min").assertIsDisplayed()
    }

    @Test
    fun `textoDoInicio arredonda os minutos para cima e trata o tempo esgotado`() {
        assertEquals("Começa em 40 min", textoDoInicio(Duration.ofMinutes(40)))
        assertEquals("Começa em 1 min", textoDoInicio(Duration.ofSeconds(1)))
        assertEquals("Começa em 3 h 0 min", textoDoInicio(Duration.ofHours(3)))
        assertEquals("Começa em 1 h 1 min", textoDoInicio(Duration.ofSeconds(3601)))
        assertEquals(TextosMinhasVagas.MENOS_DE_UM_MINUTO, textoDoInicio(Duration.ZERO))
        assertEquals(TextosMinhasVagas.MENOS_DE_UM_MINUTO, textoDoInicio(Duration.ofMinutes(-5)))
    }

    @Test
    fun `periodo trata mesmo dia, dias diferentes e instante ausente`() {
        assertEquals(
            "10/11/2026, 18:00 – 21:00",
            periodo(Instant.parse("2026-11-10T21:00:00Z"), Instant.parse("2026-11-11T00:00:00Z")),
        )
        assertEquals("", periodo(null, Instant.parse("2026-11-11T00:00:00Z")))
        assertEquals("", periodo(Instant.parse("2026-11-11T00:00:00Z"), null))
    }

    @Test
    fun `ver candidatos so existe nas vagas que podem e entrega id, posicoes abertas e inicio`() {
        val chamadas = montar(
            sucesso(
                item("v1", funcao = "Garçom", podeVerCandidatos = true, abertas = 2, pendentes = 1),
                item("v2", funcao = "Barman", podeVerCandidatos = false),
            ),
        )

        assertEquals(1, rule.onAllNodesWithText(TextosMinhasVagas.VER_CANDIDATOS).fetchSemanticsNodes().size)
        rule.onNodeWithContentDescription("Ver candidatos da vaga de Garçom")
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        val chamada = chamadas.candidatos.single()
        assertEquals("v1", chamada.id)
        assertEquals(2, chamada.posicoesAbertas)
        assertEquals(Instant.parse("2026-11-12T21:00:00Z"), chamada.inicio)
        assertEquals(0, rule.onAllNodesWithContentDescription("Ver candidatos da vaga de Barman").fetchSemanticsNodes().size)
    }

    @Test
    fun `publicar vaga fica na barra quando ha vagas e chama o callback`() {
        val chamadas = montar(sucesso(item("v1")))

        rule.onNodeWithText(TextosMinhasVagas.PUBLICAR_VAGA).performClick()

        assertEquals(1, chamadas.publicou)
    }

    @Test
    fun `lista vazia mostra o estado vazio com publicar vaga como acao`() {
        val chamadas = montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Vazio))

        rule.onNodeWithText(TextosMinhasVagas.VAZIA_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosMinhasVagas.VAZIA_MENSAGEM).assertIsDisplayed()
        assertEquals(1, contar(TextosMinhasVagas.PUBLICAR_VAGA))
        rule.onNodeWithText(TextosMinhasVagas.PUBLICAR_VAGA).performClick()

        assertEquals(1, chamadas.publicou)
    }

    @Test
    fun `carregando mostra o indicador e nenhuma acao de publicar`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Carregando))

        rule.onNodeWithContentDescription(TextosMinhasVagas.CARREGANDO).assertIsDisplayed()
        assertEquals(0, contar(TextosMinhasVagas.PUBLICAR_VAGA))
    }

    @Test
    fun `erro que admite nova tentativa mostra a mensagem e tentar de novo chama o carregar`() {
        val chamadas = montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Erro(ErroMinhasVagas.GENERICO)))

        rule.onNodeWithText(TextosMinhasVagas.ERRO_GENERICO).assertIsDisplayed()
        rule.onNodeWithText(TextosMinhasVagas.TENTAR_DE_NOVO).performClick()

        assertEquals(1, chamadas.carregou)
    }

    @Test
    fun `erro de permissao mostra o motivo e nao oferece tentar de novo`() {
        montar(EstadoMinhasVagas(lista = ListaMinhasVagas.Erro(ErroMinhasVagas.SEM_PERMISSAO)))

        rule.onNodeWithText(TextosMinhasVagas.ERRO_SEM_PERMISSAO).assertIsDisplayed()
        assertEquals(0, contar(TextosMinhasVagas.TENTAR_DE_NOVO))
    }

    @Test
    fun `lista possivelmente velha avisa`() {
        montar(sucesso(item("v1")).copy(desatualizada = true))

        rule.onNodeWithText(TextosMinhasVagas.DESATUALIZADA).assertIsDisplayed()
    }

    @Test
    fun `sem aviso de lista velha quando a lista esta em dia`() {
        montar(sucesso(item("v1")))

        assertEquals(0, contar(TextosMinhasVagas.DESATUALIZADA))
    }

    @Test
    fun `puxar a lista chama o atualizar`() {
        val chamadas = montar(sucesso(item("v1")))

        rule.onNodeWithContentDescription(TextosMinhasVagas.LISTA).performTouchInput { swipeDown() }
        rule.waitForIdle()

        assertTrue("atualizou ${chamadas.atualizou}x", chamadas.atualizou >= 1)
    }

    @Test
    fun `atualizando o container anuncia a atualizacao`() {
        montar(sucesso(item("v1")).copy(atualizando = true))

        rule.onNodeWithContentDescription(TextosMinhasVagas.ATUALIZANDO).assertIsDisplayed()
    }

    @Test
    fun `voltar chama o callback`() {
        val chamadas = montar(sucesso(item("v1")))

        rule.onNodeWithContentDescription(TextosMinhasVagas.ROTULO_VOLTAR).performClick()

        assertEquals(1, chamadas.voltou)
        assertNull(chamadas.candidatos.firstOrNull())
    }
}
