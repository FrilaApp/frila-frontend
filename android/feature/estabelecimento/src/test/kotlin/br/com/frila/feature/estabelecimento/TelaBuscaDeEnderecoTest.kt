package br.com.frila.feature.estabelecimento

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaBuscaDeEnderecoTest {

    @get:Rule
    val rule = createComposeRule()

    private val asaSul = EnderecoEncontrado("CLS 408, Asa Sul, Brasília", -15.815, -47.915, "Plano Piloto")
    private val taguatinga = EnderecoEncontrado("QSA 1, Taguatinga, Brasília", -15.83, -48.05, "Taguatinga")

    private class Chamadas {
        var buscas = 0
        val escolhidos = mutableListOf<EnderecoEncontrado>()
    }

    private fun montar(estado: EstadoCadastroEstabelecimento): Chamadas {
        val chamadas = Chamadas()
        rule.setContent {
            FrilaTheme {
                ConteudoCadastroEstabelecimento(
                    estado = estado,
                    aoEditarNome = {}, aoEditarDocumento = {}, aoEscolherTipo = {}, aoEditarEndereco = {},
                    aoEscolherRegiao = {}, aoEditarLatitude = {}, aoEditarLongitude = {}, aoCadastrar = {}, aoVoltar = {},
                    aoBuscarEndereco = { chamadas.buscas++ },
                    aoEscolherEndereco = { chamadas.escolhidos += it },
                )
            }
        }
        return chamadas
    }

    private fun comBusca(bloco: EstadoCadastroEstabelecimento.() -> EstadoCadastroEstabelecimento = { this }) =
        EstadoCadastroEstabelecimento(endereco = "CLS 408", buscaDisponivel = true).bloco()

    @Test
    fun botaoBuscarTemAlvoMinimoEChamaABusca() {
        val c = montar(comBusca())

        rule.onNodeWithText(TextosCadastroEstabelecimento.BUSCAR_ENDERECO).performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, c.buscas)
    }

    @Test
    fun semTextoNoEnderecoOBotaoFicaDesligado() {
        montar(comBusca { copy(endereco = "  ") })

        rule.onNodeWithText(TextosCadastroEstabelecimento.BUSCAR_ENDERECO).performScrollTo().assertIsNotEnabled()
    }

    @Test
    fun comOTextoOBotaoFicaLigado() {
        montar(comBusca())

        rule.onNodeWithText(TextosCadastroEstabelecimento.BUSCAR_ENDERECO).performScrollTo().assertIsEnabled()
    }

    @Test
    fun buscandoOBotaoMostraOAndamentoEFicaDesligado() {
        montar(comBusca { copy(buscando = true) })

        rule.onNodeWithText(TextosCadastroEstabelecimento.BUSCANDO_ENDERECO).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithText(TextosCadastroEstabelecimento.BUSCAR_ENDERECO).assertDoesNotExist()
    }

    @Test
    fun enviandoOCadastroOBotaoFicaDesligado() {
        montar(comBusca { copy(enviando = true) })

        rule.onNodeWithText(TextosCadastroEstabelecimento.BUSCAR_ENDERECO).performScrollTo().assertIsNotEnabled()
    }

    @Test
    fun resultadosAparecemEEscolherChamaOCallbackComOEnderecoCerto() {
        val c = montar(comBusca { copy(resultadosDaBusca = listOf(asaSul, taguatinga)) })

        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECOS_ENCONTRADOS).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(asaSul.texto).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(taguatinga.texto).performScrollTo().performClick()

        assertEquals(listOf(taguatinga), c.escolhidos)
    }

    @Test
    fun semResultadosNaoHaListaNemAvisoDeErro() {
        montar(comBusca())

        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECOS_ENCONTRADOS).assertDoesNotExist()
        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECO_SEM_RESULTADO).assertDoesNotExist()
        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECO_ERRO_DA_BUSCA).assertDoesNotExist()
    }

    @Test
    fun nadaAchadoMostraSoOAvisoDeNadaAchado() {
        montar(comBusca { copy(buscaSemResultado = true) })

        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECO_SEM_RESULTADO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECO_ERRO_DA_BUSCA).assertDoesNotExist()
    }

    @Test
    fun falhaDoServicoMostraSoOAvisoDeErro() {
        montar(comBusca { copy(erroDaBusca = true) })

        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECO_ERRO_DA_BUSCA).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECO_SEM_RESULTADO).assertDoesNotExist()
    }

    @Test
    fun semServicoDeGeocodificacaoNaoHaBotaoSoOAvisoEOsCamposManuaisSeguem() {
        montar(EstadoCadastroEstabelecimento(endereco = "CLS 408", buscaDisponivel = false))

        rule.onNodeWithText(TextosCadastroEstabelecimento.BUSCAR_ENDERECO).assertDoesNotExist()
        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECO_BUSCA_INDISPONIVEL).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.LATITUDE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.LONGITUDE).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun comServicoOsCamposManuaisContinuamNaTela() {
        montar(comBusca())

        rule.onNodeWithText(TextosCadastroEstabelecimento.LATITUDE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.LONGITUDE).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun telaLigadaAoViewModelBuscaEPreencheLatitudeELongitude() {
        val buscador = object : BuscadorDeEndereco {
            override val disponivel = true
            override suspend fun buscar(consulta: String) = listOf(asaSul)
        }
        val vm = CadastroEstabelecimentoViewModel(
            cadastrar = { error("a busca não cadastra") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
            buscador = buscador,
        )
        vm.editarEndereco("CLS 408")
        rule.setContent { FrilaTheme { TelaCadastroEstabelecimento(viewModel = vm, aoConcluir = {}, aoVoltar = {}) } }

        rule.onNodeWithText(TextosCadastroEstabelecimento.BUSCAR_ENDERECO).performScrollTo().performClick()
        rule.onNodeWithText(asaSul.texto).performScrollTo().performClick()

        assertEquals("-15.815", vm.estado.value.latitude)
        assertEquals("-47.915", vm.estado.value.longitude)
        assertEquals("Plano Piloto", vm.estado.value.regiaoAdministrativa)
        rule.onNodeWithText(TextosCadastroEstabelecimento.ENDERECOS_ENCONTRADOS).assertDoesNotExist()
    }
}
