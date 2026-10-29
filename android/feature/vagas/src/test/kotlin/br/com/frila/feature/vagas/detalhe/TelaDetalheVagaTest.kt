package br.com.frila.feature.vagas.detalhe

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaDetalheVagaTest {

    @get:Rule
    val compose = createComposeRule()

    private fun criarVaga(
        modo: String = "urgencia",
        funcaoNome: String = "Garçom",
        estabelecimentoNome: String = "Bar do Zé",
        incluiRefeicao: Boolean = true,
        incluiTransporte: Boolean = false,
        exigeMaterial: Boolean = false,
    ) = VagaAbertaDto(
        id = "11111111-1111-1111-1111-111111111111",
        funcao = FuncaoDto(id = "f1", nome = funcaoNome, categoria = "Salão"),
        estabelecimento = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = estabelecimentoNome,
            reputacao = ReputacaoDto(positivas = 7, total = 7, taxaComparecimento = 1.0, turnosConsiderados = 7, turnosRealizados = 7),
        ),
        inicioEm = "2026-11-01T21:00:00Z",
        fimEm = "2026-11-02T03:00:00Z",
        local = "SQN 108",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 4.2,
        valorCentavos = 16_000,
        posicoesAbertas = 2,
        inclusos = InclusosDto(
            incluiRefeicao = incluiRefeicao,
            incluiTransporte = incluiTransporte,
            exigeMaterialProprio = exigeMaterial,
        ),
        modo = modo,
    )

    private fun criarViewModel(
        vaga: VagaAbertaDto,
        respostaJson: String = "",
        status: HttpStatusCode = HttpStatusCode.OK,
    ): DetalheVagaViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = status,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return DetalheVagaViewModel(
            vaga = vaga,
            servicoVagas = ServicoVagas(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `exibe detalhes da vaga com modo urgencia e inclusos`() {
        val vaga = criarVaga(modo = "urgencia")
        val viewModel = criarViewModel(vaga)

        compose.setContent {
            FrilaTheme {
                TelaDetalheVaga(viewModel = viewModel)
            }
        }

        compose.onNodeWithText("Garçom").assertIsDisplayed()
        compose.onNodeWithText("Bar do Zé").assertIsDisplayed()
        compose.onNodeWithText("Modo urgência: confirmação na hora").assertIsDisplayed()
        compose.onNodeWithText("Local: SQN 108").assertIsDisplayed()
        compose.onNodeWithText("Região: Asa Norte").assertIsDisplayed()
        compose.onNode(hasText("Valor:", substring = true)).assertExists()
        compose.onNode(hasText("Distância:", substring = true)).assertExists()

        // Benefícios e acessibilidade
        compose.onNodeWithText("Inclui").assertExists()
        compose.onNodeWithContentDescription("Refeição: incluído").assertExists()
        compose.onNodeWithContentDescription("Transporte: não incluído").assertExists()

        // Botão de candidatura
        compose.onNodeWithText("Candidatar-se").assertExists().assertIsEnabled().assertHasClickAction()
    }

    @Test
    fun `exibe modo selecao quando vaga for do tipo selecao`() {
        val vaga = criarVaga(modo = "selecao")
        val viewModel = criarViewModel(vaga)

        compose.setContent {
            FrilaTheme {
                TelaDetalheVaga(viewModel = viewModel)
            }
        }

        compose.onNodeWithText("Modo seleção: contratante escolhe depois").assertIsDisplayed()
        compose.onNodeWithText("Candidatar-se").assertExists().assertIsEnabled()
    }

    @Test
    fun `ao candidatar-se em modo urgencia confirma e exibe cartao de contato`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "confirmada",
                  "candidatura_id": "c1",
                  "posicao_id": "p1",
                  "turno_id": "t1",
                  "contato": {
                    "nome": "Zé da Silva",
                    "telefone": "61988887777"
                  }
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(viewModel = viewModel)
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            // Mensagem de sucesso
            compose.onNodeWithText("Candidatura confirmada! Confira o contato abaixo.").assertExists()

            // Contato confirmado visível
            compose.onNodeWithText("Contato confirmado").assertExists()
            compose.onNodeWithText("Nome: Zé da Silva").assertExists()
            compose.onNodeWithText("Telefone: 61988887777").assertExists()

            // Botão atualiza texto e fica desabilitado
            compose.onNodeWithText("Candidatura confirmada").assertExists().assertIsNotEnabled()
        }
    }

    @Test
    fun `ao candidatar-se em modo selecao exibe candidatura enviada`() {
        runBlocking {
            val respostaJson = """
                {
                  "estado": "pendente",
                  "candidatura_id": "c2",
                  "posicao_id": null,
                  "turno_id": null,
                  "contato": null
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "selecao")
            val viewModel = criarViewModel(vaga, respostaJson = respostaJson)

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(viewModel = viewModel)
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            compose.onNodeWithText("Candidatura enviada. Aguarde a escolha do contratante.").assertExists()
            compose.onNodeWithText("Candidatura enviada").assertExists().assertIsNotEnabled()
        }
    }

    @Test
    fun `quando api retorna erro de conflito exibe mensagem de erro apropriada`() {
        runBlocking {
            val erroJson = """
                {
                  "code": "posicao_ja_preenchida",
                  "message": "alguém chegou antes"
                }
            """.trimIndent()
            val vaga = criarVaga(modo = "urgencia")
            val viewModel = criarViewModel(vaga, respostaJson = erroJson, status = HttpStatusCode.Conflict)

            compose.setContent {
                FrilaTheme {
                    TelaDetalheVaga(viewModel = viewModel)
                }
            }

            viewModel.candidatar().join()
            compose.waitForIdle()

            compose.onNodeWithText("Que pena, a vaga acabou de ser preenchida.").assertExists()
            compose.onNodeWithText("Candidatar-se").assertExists().assertIsEnabled()
        }
    }
}
