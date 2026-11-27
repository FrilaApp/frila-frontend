package br.com.frila.feature.entrada.cadastro

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.unit.dp
import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoConta
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class TelaCadastroTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun tituloPossuiSemanticaDeCabecalho() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        rule.onNodeWithText("Complete seu cadastro")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
    }

    @Test
    fun escolhaDoPerfilMostraAsDuasOpcoesEOAvisoDePerfilFixo() {
        rule.setContent { FrilaTheme { TelaCadastro(viewModel = CadastroViewModel(), aoConcluir = {}) } }

        rule.onNodeWithText(TextosEscolhaDoPerfil.PERGUNTA).assertIsDisplayed()
        rule.onNodeWithText(TextosEscolhaDoPerfil.PROFISSIONAL_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosEscolhaDoPerfil.CONTRATANTE_TITULO).assertIsDisplayed()
        rule.onNodeWithTag("cadastro-aviso-fixo").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosEscolhaDoPerfil.AVISO_FIXO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosEscolhaDoPerfil.AVISO_FIXO).assertIsDisplayed()
    }

    @Test
    fun tocarEmPublicarVagasEscolheContratante() {
        val viewModel = CadastroViewModel()
        rule.setContent { FrilaTheme { TelaCadastro(viewModel = viewModel, aoConcluir = {}) } }

        rule.onNodeWithText(TextosEscolhaDoPerfil.CONTRATANTE_TITULO).performClick()
        rule.runOnIdle { assertEquals(PerfilDaConta.CONTRATANTE, viewModel.estado.value.perfil) }

        rule.onNodeWithText(TextosEscolhaDoPerfil.PROFISSIONAL_TITULO).performClick()
        rule.runOnIdle { assertEquals(PerfilDaConta.PROFISSIONAL, viewModel.estado.value.perfil) }
    }

    @Test
    fun concluirAvisaQuemChamouComOPerfilDaContaCriada() {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    """{"id":"u1","perfil":"contratante","nome":"Casa de Teste","telefone":"+5511987654321","email":"c@exemplo.com","nascimento":"2000-06-15","estado":"ativa"}""",
                    HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val viewModel = CadastroViewModel(
            servicoConta = ServicoConta(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
            hoje = { DataCivil.de(2026, 11, 16) },
        )
        val concluidos = mutableListOf<PerfilDaConta>()
        rule.setContent { FrilaTheme { TelaCadastro(viewModel = viewModel, aoConcluir = { concluidos += it }) } }

        rule.runOnIdle {
            viewModel.aoEscolherPerfil(PerfilDaConta.CONTRATANTE)
            viewModel.aoMudarNome("Casa de Teste")
            viewModel.aoMudarCpf("52998224725")
            viewModel.aoMudarTelefone("11987654321")
            viewModel.aoMudarNascimento(DataCivil.de(2000, 6, 15))
            viewModel.aoMudarAceiteDeTermos(true)
            viewModel.concluirCadastro()
        }
        rule.waitUntil(5_000) { concluidos.isNotEmpty() || viewModel.estado.value.erro != null }

        assertEquals(null, viewModel.estado.value.erro)

        assertEquals(listOf(PerfilDaConta.CONTRATANTE), concluidos)
    }

    @Test
    fun checkboxTermosPossuiAlvoMinimoEStateDescription() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        val checkboxNode = rule.onNodeWithText("Li e aceito os termos de uso e a política de privacidade.")
        checkboxNode.performScrollTo().assertIsDisplayed()

        // WCAG / Android touch target >= 48dp
        checkboxNode.assertWidthIsAtLeast(48.dp)
        checkboxNode.assertHeightIsAtLeast(48.dp)

        // Estado inicial não selecionado
        checkboxNode.assert(
            SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "não selecionado")
        )

        // Ao clicar, transiciona para selecionado
        checkboxNode.performClick()
        checkboxNode.assert(
            SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionado")
        )
    }

    @Test
    fun erroNomeExibeTextoDedicadoComLiveRegionAssertive() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        // Preenche nascimento para avançar até validação de nome ao submeter
        rule.onNodeWithText("Data de nascimento (dd/mm/aaaa)")
            .performScrollTo()
            .performTextInput("10/05/1990")

        // Submete sem preencher o nome
        viewModel.concluirCadastro()

        // Mensagem de erro dedicada do nome é exibida com LiveRegionMode.Assertive
        rule.onNodeWithText("Informe seu nome.")
            .performScrollTo()
            .assertIsDisplayed()
            .assert(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.LiveRegion,
                    LiveRegionMode.Assertive,
                )
            )
    }

    @Test
    fun erroCpfExibeTextoDedicadoComLiveRegionAssertive() {
        val viewModel = CadastroViewModel()
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        // Digita CPF inválido com 11 dígitos repetidos
        rule.onNodeWithText("CPF")
            .performScrollTo()
            .performTextInput("11111111111")

        rule.onNodeWithText(MENSAGEM_CPF_INVALIDO)
            .performScrollTo()
            .assertIsDisplayed()
            .assert(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.LiveRegion,
                    LiveRegionMode.Assertive,
                )
            )
    }

    @Test
    fun erroNascimentoExibeTextoDedicadoComLiveRegionAssertive() {
        val viewModel = CadastroViewModel(hoje = { DataCivil.de(2026, 11, 16) })
        rule.setContent {
            FrilaTheme {
                TelaCadastro(
                    viewModel = viewModel,
                    aoConcluir = {},
                )
            }
        }

        // Digita nascimento de menor de idade
        rule.onNodeWithText("Data de nascimento (dd/mm/aaaa)")
            .performScrollTo()
            .performTextInput("01/01/2015")

        rule.onNodeWithText(MENSAGEM_MENOR_DE_IDADE)
            .performScrollTo()
            .assertIsDisplayed()
            .assert(
                SemanticsMatcher.expectValue(
                    SemanticsProperties.LiveRegion,
                    LiveRegionMode.Assertive,
                )
            )
    }
}
