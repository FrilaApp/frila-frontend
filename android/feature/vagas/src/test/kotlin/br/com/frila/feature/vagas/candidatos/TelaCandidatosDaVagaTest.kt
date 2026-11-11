package br.com.frila.feature.vagas.candidatos

import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class TelaCandidatosDaVagaTest {

    @get:Rule
    val rule = createComposeRule()

    private val agora: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private fun candidato(
        id: String,
        nome: String,
        daEquipe: Boolean = false,
        funcoes: List<String>? = listOf("garçom", "barman"),
        total: Int = 5,
        fotoUrl: String? = null,
    ) = CandidatoDto(
        candidaturaId = id,
        profissional = PerfilPublicoDto(
            id = "p-$id", tipo = "profissional", nome = nome, funcoes = funcoes,
            reputacao = ReputacaoDto(positivas = 4, total = total, taxaComparecimento = if (total == 0) null else 0.9, turnosConsiderados = total, turnosRealizados = total),
            fotoUrl = fotoUrl,
        ),
        criadaEm = "2026-11-10T12:00:00Z",
        daEquipe = daEquipe,
    )

    private val ana = candidato("c1", "Ana", daEquipe = true)
    private val beto = candidato("c2", "Beto", total = 0, funcoes = null)

    private fun estado(
        lista: EstadoDosCandidatos = EstadoDosCandidatos.Carregados(listOf(ana, beto)),
        mudar: EstadoCandidatosDaVaga.() -> EstadoCandidatosDaVaga = { this },
    ) = EstadoCandidatosDaVaga(lista = lista, agora = agora).mudar()

    private class Chamadas {
        val escolhas = mutableListOf<String>()
        var carregou = 0
        var atualizou = 0
        var desistiu = 0
        var confirmou = 0
        var voltou = 0
    }

    private fun montar(
        estado: EstadoCandidatosDaVaga = estado(),
        chamadas: Chamadas = Chamadas(),
        carregarFoto: suspend (String) -> ImageBitmap? = { null },
    ): Chamadas {
        rule.setContent {
            FrilaTheme {
                ConteudoCandidatosDaVaga(
                    estado = estado,
                    acoes = AcoesCandidatosDaVaga(
                        aoCarregar = { chamadas.carregou++ },
                        aoAtualizar = { chamadas.atualizou++ },
                        aoPedirEscolha = { chamadas.escolhas += it.candidaturaId },
                        aoDesistirDaEscolha = { chamadas.desistiu++ },
                        aoConfirmarEscolha = { chamadas.confirmou++ },
                        aoVoltar = { chamadas.voltou++ },
                    ),
                    carregarFoto = carregarFoto,
                )
            }
        }
        return chamadas
    }

    @Test
    fun `mostra o titulo em cabecalho, a explicacao e um cartao por candidato na ordem recebida`() {
        montar()

        rule.onNodeWithText(TextosCandidatosDaVaga.TITULO)
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosCandidatosDaVaga.EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithText("Ana").assertIsDisplayed()
        rule.onNodeWithText("Beto").assertIsDisplayed()
        val topoAna = rule.onNodeWithText("Ana").getUnclippedBoundsInRoot().top
        val topoBeto = rule.onNodeWithText("Beto").getUnclippedBoundsInRoot().top
        assertTrue("a ordem de chegada se mantém (RN06)", topoAna < topoBeto)
    }

    @Test
    fun `o selo da equipe aparece so para quem e da equipe, em texto`() {
        montar()

        rule.onNodeWithText(TextosCandidatosDaVaga.DA_EQUIPE).assertIsDisplayed()
        rule.onAllNodesWithTextCount(TextosCandidatosDaVaga.DA_EQUIPE).let { assertEquals(1, it) }
    }

    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithTextCount(texto: String) =
        onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `mostra funcoes e reputacao, e sem avaliacoes quando nao ha`() {
        montar()

        rule.onNodeWithText("Funções: garçom, barman").assertIsDisplayed()
        rule.onNodeWithText("4 de 5 avaliações positivas · 90% de comparecimento").assertIsDisplayed()
        rule.onNodeWithText(TextosCandidatosDaVaga.SEM_AVALIACOES).assertIsDisplayed()
        rule.onAllNodesWithTextCount("Funções: ").let { assertEquals(0, it) }
    }

    @Test
    fun `tocar em escolher pede a escolha do candidato do cartao`() {
        val chamadas = montar()

        rule.onNodeWithContentDescription("Escolher Beto").performClick()

        assertEquals(listOf("c2"), chamadas.escolhas)
    }

    @Test
    fun `o botao de escolher tem alvo de toque minimo`() {
        montar()

        rule.onNodeWithContentDescription("Escolher Ana").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun `com uma escolha em voo os botoes ficam desabilitados e o do escolhido mostra confirmando`() {
        montar(estado { copy(escolhendo = "c1") })

        rule.onNodeWithContentDescription("Escolher Ana").assertIsNotEnabled()
        rule.onNodeWithContentDescription("Escolher Beto").assertIsNotEnabled()
        rule.onNodeWithText(TextosCandidatosDaVaga.ESCOLHENDO).assertIsDisplayed()
    }

    @Test
    fun `sem escolha em voo os botoes ficam habilitados`() {
        montar()

        rule.onNodeWithContentDescription("Escolher Ana").assertIsEnabled()
    }

    @Test
    fun `o dialogo pergunta antes de confirmar e confirmar chama o ViewModel`() {
        val chamadas = montar(estado { copy(emConfirmacao = ana) })

        rule.onNodeWithText(TextosCandidatosDaVaga.PERGUNTA_DA_ESCOLHA).assertIsDisplayed()
        rule.onNodeWithText("Você vai confirmar Ana nesta vaga.").assertIsDisplayed()
        rule.onNodeWithText(TextosCandidatosDaVaga.CONFIRMAR).performClick()

        assertEquals(1, chamadas.confirmou)
        assertEquals(0, chamadas.desistiu)
    }

    @Test
    fun `cancelar o dialogo desiste da escolha`() {
        val chamadas = montar(estado { copy(emConfirmacao = ana) })

        rule.onNodeWithText(TextosCandidatosDaVaga.CANCELAR).performClick()

        assertEquals(1, chamadas.desistiu)
        assertEquals(0, chamadas.confirmou)
    }

    @Test
    fun `na ultima posicao o dialogo avisa que os outros candidatos serao avisados`() {
        montar(estado { copy(emConfirmacao = ana, posicoesAbertas = 1) })

        rule.onNodeWithText(
            "Você vai confirmar Ana nesta vaga. É a última posição: os outros candidatos serão avisados de que não foram escolhidos.",
        ).assertIsDisplayed()
    }

    @Test
    fun `lista vazia mostra ninguem se candidatou ainda`() {
        montar(estado(lista = EstadoDosCandidatos.Vazio))

        rule.onNodeWithText(TextosCandidatosDaVaga.VAZIO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidatosDaVaga.VAZIO_MENSAGEM).assertIsDisplayed()
    }

    @Test
    fun `carregando mostra o indicador e nenhum cartao`() {
        montar(estado(lista = EstadoDosCandidatos.Carregando))

        assertTrue(rule.onAllNodes(SemanticsMatcher.keyIsDefined(SemanticsProperties.ProgressBarRangeInfo)).fetchSemanticsNodes().isNotEmpty())
        assertEquals(0, rule.onAllNodesWithTextCount("Ana"))
        assertEquals(0, rule.onAllNodesWithTextCount(TextosCandidatosDaVaga.VAZIO_TITULO))
    }

    @Test
    fun `falha mostra a mensagem e tentar novamente chama o carregar`() {
        val chamadas = montar(estado(lista = EstadoDosCandidatos.Falha))

        rule.onNodeWithText(TextosCandidatosDaVaga.FALHA).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidatosDaVaga.TENTAR_NOVAMENTE).performClick()

        assertEquals(1, chamadas.carregou)
    }

    @Test
    fun `sem conexao mostra a mensagem propria e tentar novamente chama o carregar`() {
        val chamadas = montar(estado(lista = EstadoDosCandidatos.SemConexao))

        rule.onNodeWithText(TextosCandidatosDaVaga.SEM_CONEXAO).assertIsDisplayed()
        rule.onNodeWithText(TextosCandidatosDaVaga.TENTAR_NOVAMENTE).performClick()

        assertEquals(1, chamadas.carregou)
    }

    @Test
    fun `o banner mostra o prazo de escolha em horario de Brasilia`() {
        montar(estado { copy(prazoDeEscolha = Instant.parse("2026-11-11T18:00:00Z")) })

        rule.onNodeWithText("Escolha até 11/11/2026 às 15:00, quando a vaga fecha.").assertIsDisplayed()
    }

    @Test
    fun `prazo que ja passou troca o banner`() {
        montar(estado { copy(prazoDeEscolha = Instant.parse("2026-11-10T15:00:00Z")) })

        rule.onNodeWithText(TextosCandidatosDaVaga.PRAZO_PASSOU).assertIsDisplayed()
        assertEquals(0, rule.onAllNodesWithTextCount("Escolha até 10/11/2026 às 12:00, quando a vaga fecha."))
    }

    @Test
    fun `sem prazo conhecido nao ha banner de prazo`() {
        montar()

        assertEquals(0, rule.onAllNodesWithTextCount(TextosCandidatosDaVaga.PRAZO_PASSOU))
    }

    @Test
    fun `lista possivelmente velha avisa`() {
        montar(estado { copy(desatualizada = true) })

        rule.onNodeWithText(TextosCandidatosDaVaga.DESATUALIZADA).assertIsDisplayed()
    }

    @Test
    fun `resultado da escolha e anunciado, com e sem vaga preenchida`() {
        montar(estado { copy(resultado = ResultadoDaEscolha("Ana", vagaPreenchida = false)) })
        rule.onNodeWithText("Você confirmou Ana.").assertIsDisplayed()
    }

    @Test
    fun `quando a vaga enche o resultado diz que os outros foram avisados`() {
        montar(estado(lista = EstadoDosCandidatos.Vazio) { copy(resultado = ResultadoDaEscolha("Ana", vagaPreenchida = true)) })

        rule.onNodeWithText("Você confirmou Ana. Os outros candidatos foram avisados.").assertIsDisplayed()
    }

    @Test
    fun `falha da escolha e mostrada`() {
        montar(estado { copy(falha = FalhaDaEscolha.TurnoSobreposto("Ana")) })

        rule.onNodeWithText("Ana já tem outro turno confirmado no mesmo horário. Escolha outro candidato.").assertIsDisplayed()
    }

    @Test
    fun `cada falha da escolha tem mensagem propria e as que citam o candidato levam o nome`() {
        val falhas = listOf(
            FalhaDaEscolha.PosicaoJaPreenchida,
            FalhaDaEscolha.CandidaturaIndisponivel("Ana"),
            FalhaDaEscolha.SelecaoEncerrada,
            FalhaDaEscolha.TurnoSobreposto("Ana"),
            FalhaDaEscolha.Inelegivel("Ana"),
            FalhaDaEscolha.VagaOculta,
            FalhaDaEscolha.SemPermissao,
            FalhaDaEscolha.PerfilIncompativel,
            FalhaDaEscolha.ContaSuspensa,
            FalhaDaEscolha.SessaoExpirada,
            FalhaDaEscolha.SemRede,
            FalhaDaEscolha.ResultadoIncerto("Ana"),
            FalhaDaEscolha.Generica,
        )

        val mensagens = falhas.map(::mensagemDaFalha)

        assertEquals(falhas.size, mensagens.toSet().size)
        mensagens.forEach { assertTrue(it.isNotBlank()) }
        listOf(1, 3, 4, 11).forEach { assertTrue(mensagens[it], "Ana" in mensagens[it]) }
    }

    @Test
    fun `sem foto o cartao mostra a inicial do nome`() {
        montar()

        assertEquals(2, rule.onAllNodesWithTag("inicial-do-candidato", useUnmergedTree = true).fetchSemanticsNodes().size)
        assertEquals(0, rule.onAllNodesWithTag("foto-do-candidato", useUnmergedTree = true).fetchSemanticsNodes().size)
    }

    private fun androidx.compose.ui.test.junit4.ComposeContentTestRule.onAllNodesWithContentDescriptionCount(texto: String) =
        onAllNodes(hasContentDescription(texto)).fetchSemanticsNodes().size

    @Test
    fun `falha ao baixar a foto cai na inicial sem derrubar a tela`() {
        montar(
            estado(lista = EstadoDosCandidatos.Carregados(listOf(candidato("c1", "Ana", fotoUrl = "https://frila.supabase.co/foto.jpg")))),
            carregarFoto = { error("sem rede") },
        )
        rule.waitForIdle()

        rule.onNodeWithTag("inicial-do-candidato", useUnmergedTree = true).assertExists()
        assertEquals(0, rule.onAllNodesWithTag("foto-do-candidato", useUnmergedTree = true).fetchSemanticsNodes().size)
    }

    @Test
    fun `candidato sem foto_url nao pede foto`() {
        var pedidas = 0
        montar(carregarFoto = { pedidas++; null })
        rule.waitForIdle()

        assertEquals(0, pedidas)
    }

    @Test
    fun `puxar a lista chama o atualizar`() {
        val chamadas = montar()

        rule.onNodeWithContentDescription(TextosCandidatosDaVaga.LISTA).performTouchInput { swipeDown() }
        rule.waitForIdle()

        assertTrue("atualizou ${chamadas.atualizou}x", chamadas.atualizou >= 1)
    }

    @Test
    fun `atualizando o container anuncia a atualizacao`() {
        montar(estado { copy(atualizando = true) })

        rule.onNodeWithContentDescription(TextosCandidatosDaVaga.ATUALIZANDO).assertExists()
    }

    @Test
    fun `voltar chama o ViewModel`() {
        val chamadas = montar()

        rule.onNodeWithContentDescription(TextosCandidatosDaVaga.ROTULO_VOLTAR).performClick()

        assertEquals(1, chamadas.voltou)
    }
}
