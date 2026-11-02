package br.com.frila.feature.perfil

import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Auditoria semântica e de acessibilidade das telas do módulo de Perfil (RNF10 / Cartão 68).
 *
 * Valida recursivamente:
 * 1. Todos os elementos acionáveis possuem rótulo TalkBack acessível (contentDescription ou texto).
 * 2. Nenhum ícone decorativo possui descrição redundante ou genérica ("ícone", "imagem").
 * 3. Cabeçalhos estruturais (heading) nas seções para permitir navegação rápida pelo rotor do TalkBack.
 * 4. Alvos mínimos de toque em controles e botões de navegação.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class AuditoriaSemanticaPerfilTest {

    @get:Rule
    val compose = createComposeRule()

    private val perfilJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "usuario_id": "22222222-2222-2222-2222-222222222222",
          "funcoes": [{"id": "f1", "nome": "Garçom", "categoria": "Salão"}],
          "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
          "disponibilidades": [],
          "reputacao": {
            "positivas": 7, "total": 7, "taxa_comparecimento": 0.95,
            "turnos_considerados": 8, "turnos_realizados": 8
          }
        }
    """.trimIndent()

    private fun criarViewModel(
        respostaJson: String = perfilJson,
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
        armazenamento: ArmazenamentoDeSessao = mockk(relaxed = true),
        respostaTurnosJson: String = "[]",
    ): PerfilViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = statusHttp,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val clienteTurnos = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaTurnosJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return PerfilViewModel(
            servicoPerfil = ServicoPerfil(cliente),
            servicoTurnos = ServicoTurnos(clienteTurnos),
            armazenamentoDeSessao = armazenamento,
            escopo = CoroutineScope(Dispatchers.Default),
            preferenciasNotificacao = br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoEmMemoria(),
        )
    }

    private fun coletarHeadings(no: SemanticsNode): List<SemanticsNode> {
        val resultado = mutableListOf<SemanticsNode>()
        fun buscar(atual: SemanticsNode) {
            if (atual.config.contains(SemanticsProperties.Heading)) {
                resultado.add(atual)
            }
            for (filho in atual.children) {
                buscar(filho)
            }
        }
        buscar(no)
        return resultado
    }

    @Test
    fun `audita semantica da TelaPerfil real com perfil carregado e reputacao`() {
        runBlocking {
            val viewModel = criarViewModel()
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        aoAbrirAjuda = {},
                        verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.SEM_HARDWARE },
                    )
                }
            }
            compose.waitForIdle()

            // 1. Auditoria semântica completa na árvore real
            val noRaiz = compose.onRoot().fetchSemanticsNode()
            AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)

            // 2. Valida cabeçalhos estruturais presentes para navegação pelo TalkBack
            val headings = coletarHeadings(noRaiz)
            assertTrue("TelaPerfil deve conter múltiplos cabeçalhos estruturais", headings.size >= 2)

            val textosHeadings = headings.mapNotNull {
                it.config.getOrNull(SemanticsProperties.Text)?.firstOrNull()?.text
            }
            assertTrue("Deve conter cabeçalho Meu Perfil", textosHeadings.contains("Meu Perfil"))
            assertTrue("Deve conter cabeçalho Reputação", textosHeadings.contains("Reputação"))

            // 3. Valida conteúdo semântico do profissional
            compose.onNodeWithText("Meu Perfil").assertIsDisplayed()
            compose.onNodeWithText("Garçom").assertExists()
        }
    }

    @Test
    fun `audita semantica da TelaPerfil real no estado de erro de rede`() {
        runBlocking {
            val viewModel = criarViewModel(
                statusHttp = HttpStatusCode.InternalServerError,
                respostaJson = """{"erro": "servico_indisponivel"}""",
            )
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaPerfil(
                        viewModel = viewModel,
                        aoDeslogar = {},
                        aoAbrirAjuda = {},
                        verificarDisponibilidadeBiometrica = { DisponibilidadeBiometrica.SEM_HARDWARE },
                    )
                }
            }
            compose.waitForIdle()

            // Auditoria semântica na tela de erro
            val noRaiz = compose.onRoot().fetchSemanticsNode()
            AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)

            // Botão de tentar novamente deve ser acionável e visível
            compose.onNodeWithText("Tentar novamente").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `audita semantica da TelaAjudaPerfil com canais de suporte e navegacao`() {
        var voltou = false
        var termosAbertos = false

        compose.setContent {
            FrilaTheme {
                TelaAjudaPerfil(
                    aoVoltar = { voltou = true },
                    aoNavegarParaTermos = { termosAbertos = true },
                )
            }
        }
        compose.waitForIdle()

        // 1. Auditoria semântica completa na árvore da tela de ajuda
        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)

        // 2. Cabeçalho semântico estrutural "Ajuda"
        val headings = coletarHeadings(noRaiz)
        val textosHeadings = headings.mapNotNull {
            it.config.getOrNull(SemanticsProperties.Text)?.firstOrNull()?.text
        }
        assertTrue("Deve conter cabeçalho semântico 'Ajuda'", textosHeadings.contains("Ajuda"))

        // 3. Botão voltar com descrição acessível e clique
        val botaoVoltar = compose.onNodeWithContentDescription("Voltar")
        botaoVoltar.assertIsDisplayed().assertHasClickAction()
        botaoVoltar.performClick()
        assertTrue("Ação de voltar deve ser executada", voltou)
    }

    @Test
    fun `audita semantica da TelaLicencas no catalogo e na visualizacao de detalhes`() {
        var voltou = false

        compose.setContent {
            FrilaTheme {
                TelaLicencas(
                    aoVoltar = { voltou = true },
                )
            }
        }
        compose.waitForIdle()

        // 1. Auditoria semântica da lista de licenças
        val noRaizCatalogo = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaizCatalogo)

        val headingsCatalogo = coletarHeadings(noRaizCatalogo)
        val textosHeadings = headingsCatalogo.mapNotNull {
            it.config.getOrNull(SemanticsProperties.Text)?.firstOrNull()?.text
        }
        assertTrue(
            "Deve conter cabeçalho 'Licenças de código aberto'",
            textosHeadings.contains("Licenças de código aberto"),
        )

        // 2. Clica em um item de licença para abrir o detalhe
        compose.onNodeWithText("Kotlin Coroutines").performClick()
        compose.waitForIdle()

        // 3. Auditoria semântica da tela de detalhe da licença
        val noRaizDetalhe = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaizDetalhe)

        // Botão voltar do detalhe deve ter rótulo acessível
        compose.onNodeWithContentDescription("Voltar para a lista de licenças")
            .assertIsDisplayed()
            .assertHasClickAction()
    }
}
