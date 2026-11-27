package br.com.frila.feature.perfil

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CriteriosDeNotificacaoDto
import br.com.frila.core.rede.EquipeDeConfiancaCriterioDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class TelaPorQueReceboVagasTest {

    @get:Rule
    val rule = createComposeRule()

    private val garcom = FuncaoDto(id = "f-garcom", nome = "Garçom", categoria = "Salão")
    private val cozinheiro = FuncaoDto(id = "f-cozinheiro", nome = "Cozinheiro", categoria = "Cozinha")
    private val janelaSegunda = JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00")
    private val equipeBar = EquipeDeConfiancaCriterioDto(estabelecimentoId = "est-1", nome = "Bar do Zé")

    private val criteriosPadrao = CriteriosDeNotificacaoDto(
        funcoes = listOf(garcom, cozinheiro),
        disponibilidades = listOf(janelaSegunda),
        distanciaMaximaKm = 15.0,
        equipesDeConfianca = listOf(equipeBar),
        notificacoesNoMaximoACadaMin = 30,
    )

    private class Eventos {
        var recarregou = 0
        var contestou = 0
        var voltou = 0
    }

    private fun montar(
        estado: EstadoPorQueReceboVagas = EstadoPorQueReceboVagas.Conteudo(criterios = criteriosPadrao),
        eventos: Eventos = Eventos(),
    ): Eventos {
        rule.setContent {
            FrilaTheme {
                ConteudoPorQueReceboVagas(
                    estado = estado,
                    aoTentarRecarregar = { eventos.recarregou++ },
                    aoContestar = { eventos.contestou++ },
                    aoVoltar = { eventos.voltou++ },
                )
            }
        }
        return eventos
    }

    @Test
    fun `renderiza titulo explicacao e criterios completos`() {
        montar()

        rule.onNodeWithText("Por que recebo vagas").assertIsDisplayed()
        rule.onNodeWithTag("perfil-explicacao-vagas").assertIsDisplayed()
        rule.onNodeWithTag("criterios-funcoes").assertIsDisplayed()
        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText("Cozinheiro").assertIsDisplayed()

        rule.onNodeWithTag("criterios-horarios").assertIsDisplayed()
        rule.onNodeWithText("Segunda-feira: 08:00 às 16:00").assertIsDisplayed()

        rule.onNodeWithTag("criterios-distancia").assertIsDisplayed()
        rule.onNodeWithText("Até 15 km do seu ponto base.").assertIsDisplayed()

        rule.onNodeWithTag("criterios-equipes").assertIsDisplayed()
        rule.onNodeWithText("Bar do Zé").assertIsDisplayed()

        rule.onNodeWithTag("criterios-frequencia").assertIsDisplayed()
        rule.onNodeWithText("No máximo uma notificação a cada 30 minutos.").assertIsDisplayed()
    }

    @Test
    fun `clicar em contestar aciona callback`() {
        val eventos = montar()

        rule.onNodeWithTag("botao-contestar-despacho").performScrollTo().performClick()
        assertEquals(1, eventos.contestou)
    }

    @Test
    fun `clicar em voltar aciona callback`() {
        val eventos = montar()

        rule.onNodeWithTag("botao-voltar-por-que-recebo").performClick()
        assertEquals(1, eventos.voltou)
    }

    @Test
    fun `renderiza indicador carregando quando estado eh Carregando`() {
        montar(estado = EstadoPorQueReceboVagas.Carregando)

        rule.onNodeWithTag("criterios-carregando").assertIsDisplayed()
    }

    @Test
    fun `renderiza estado vazio com mensagem e botao contestar`() {
        val eventos = montar(estado = EstadoPorQueReceboVagas.Vazio)

        rule.onNodeWithTag("criterios-vazio").assertIsDisplayed()
        rule.onNodeWithText("Nenhum critério cadastrado").assertIsDisplayed()
        rule.onNodeWithTag("botao-contestar-despacho").performScrollTo().performClick()
        assertEquals(1, eventos.contestou)
    }

    @Test
    fun `renderiza estado sem rede e tentar novamente chama recarregar`() {
        val eventos = montar(estado = EstadoPorQueReceboVagas.SemRede)

        rule.onNodeWithTag("criterios-sem-rede").assertIsDisplayed()
        rule.onNodeWithText("Sem conexão. Verifique sua internet e tente novamente.").assertIsDisplayed()
        rule.onNodeWithText("Tentar novamente").performClick()
        assertEquals(1, eventos.recarregou)
    }

    @Test
    fun `renderiza estado erro e tentar novamente chama recarregar`() {
        val eventos = montar(estado = EstadoPorQueReceboVagas.Erro("Erro no servidor"))

        rule.onNodeWithTag("criterios-erro").assertIsDisplayed()
        rule.onNodeWithText("Não foi possível carregar seus critérios. Tente novamente.").assertIsDisplayed()
        rule.onNodeWithText("Tentar novamente").performClick()
        assertEquals(1, eventos.recarregou)
    }

    @Test
    fun `renderiza protocolo quando contestacao foi enviada`() {
        val protocolo = ProtocoloExibido(
            numero = "ABCD1234",
            enviadoEm = "20/11/2026",
            prazoRespostaAte = "27/11/2026",
        )
        montar(
            estado = EstadoPorQueReceboVagas.Conteudo(
                criterios = criteriosPadrao,
                protocolo = protocolo,
                contestacaoJaAberta = true,
            ),
        )

        rule.onNodeWithTag("status-revisao-enviada").performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("protocolo-revisao-despacho").assertIsDisplayed()
        rule.onNodeWithText("#ABCD1234").assertIsDisplayed()
        rule.onNodeWithText("20/11/2026").assertIsDisplayed()
        rule.onNodeWithTag("prazo-resposta-revisao").assertIsDisplayed()
        rule.onNodeWithText("27/11/2026").assertIsDisplayed()
    }

    @Test
    fun `renderiza aviso quando contestacao ja esta aberta sem protocolo direto`() {
        montar(
            estado = EstadoPorQueReceboVagas.Conteudo(
                criterios = criteriosPadrao,
                protocolo = null,
                contestacaoJaAberta = true,
            ),
        )

        rule.onNodeWithTag("status-revisao-ja-aberta").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `403 com details conta_suspensa nao deixa nada cru do servidor na tela`() {
        val vm = PorQueReceboVagasViewModel(
            carregarCriterios = {
                throw br.com.frila.core.rede.ErroDaApi(
                    br.com.frila.core.dominio.modelo.CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "conta_suspensa", "permission denied",
                )
            },
            escopo = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined),
        )
        vm.carregar()

        montar(estado = vm.estado.value)

        rule.onNodeWithTag("criterios-erro").assertIsDisplayed()
        rule.onNodeWithText("Não foi possível carregar seus critérios. Tente novamente.").assertIsDisplayed()
        for (cru in listOf("conta_suspensa", "sem_permissao", "permission denied")) {
            assertEquals(cru, 0, rule.onAllNodesWithText(cru, substring = true).fetchSemanticsNodes().size)
        }
    }
}
