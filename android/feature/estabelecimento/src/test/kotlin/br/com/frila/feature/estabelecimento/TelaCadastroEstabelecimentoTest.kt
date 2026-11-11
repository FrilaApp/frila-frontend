package br.com.frila.feature.estabelecimento

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.EstabelecimentoDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaCadastroEstabelecimentoTest {

    @get:Rule
    val rule = createComposeRule()

    private class Chamadas {
        var cadastros = 0
        var voltou = 0
    }

    /** O estado vive no teste, como o `StateFlow` do ViewModel vive na tela; as edições o atualizam. */
    private fun montar(inicial: EstadoCadastroEstabelecimento = EstadoCadastroEstabelecimento(), chamadas: Chamadas = Chamadas()): Chamadas {
        rule.setContent {
            var estado by mutableStateOf(inicial)
            FrilaTheme {
                ConteudoCadastroEstabelecimento(
                    estado = estado,
                    aoEditarNome = { estado = estado.copy(nome = it) },
                    aoEditarDocumento = { estado = estado.copy(documento = it.filter(Char::isDigit).take(14)) },
                    aoEscolherTipo = { estado = estado.copy(tipo = it) },
                    aoEditarEndereco = { estado = estado.copy(endereco = it) },
                    aoEscolherRegiao = { estado = estado.copy(regiaoAdministrativa = it) },
                    aoEditarLatitude = { estado = estado.copy(latitude = it) },
                    aoEditarLongitude = { estado = estado.copy(longitude = it) },
                    aoCadastrar = { chamadas.cadastros++ },
                    aoVoltar = { chamadas.voltou++ },
                )
            }
        }
        return chamadas
    }

    @Test
    fun tituloEhCabecalhoEVoltarTemAlvoMinimoEChamaOCallback() {
        val c = montar()

        rule.onNodeWithText(TextosCadastroEstabelecimento.TITULO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithContentDescription(TextosCadastroEstabelecimento.ROTULO_VOLTAR)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, c.voltou)
    }

    @Test
    fun formularioMostraTodosOsCamposDoContrato() {
        montar()

        listOf(
            TextosCadastroEstabelecimento.NOME,
            TextosCadastroEstabelecimento.DOCUMENTO,
            TextosCadastroEstabelecimento.ENDERECO,
            TextosCadastroEstabelecimento.LATITUDE,
            TextosCadastroEstabelecimento.LONGITUDE,
        ).forEach { rule.onNodeWithText(it).performScrollTo().assertIsDisplayed() }
        rule.onNodeWithText(TextosCadastroEstabelecimento.REGIAO_SELECIONAR).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.CADASTRAR).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun tiposSaoUmGrupoDeRadioComAlimentacaoSelecionadaEAlvoMinimo() {
        montar()

        TipoEstabelecimento.entries.forEach { tipo ->
            rule.onNodeWithText(tipo.rotulo).performScrollTo()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
        }
        rule.onNodeWithText(TipoEstabelecimento.ALIMENTACAO.rotulo).assertIsSelected()

        rule.onNodeWithText(TipoEstabelecimento.SERVICO_DOMESTICO.rotulo).performScrollTo().performClick()

        rule.onNodeWithText(TipoEstabelecimento.SERVICO_DOMESTICO.rotulo).assertIsSelected()
    }

    @Test
    fun digitarNosCamposAtualizaOEstadoEODocumentoFicaSoComDigitos() {
        montar()

        rule.onNodeWithText(TextosCadastroEstabelecimento.NOME).performScrollTo().performTextInput("Bar da Lia")
        rule.onNodeWithText(TextosCadastroEstabelecimento.DOCUMENTO).performScrollTo().performTextInput("12.345.678/0001-99")

        rule.onNodeWithText("Bar da Lia").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("12345678000199").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun regiaoAbreOSeletorEEscolherFechaEMostraNoBotao() {
        montar()

        rule.onNodeWithText(TextosCadastroEstabelecimento.REGIAO_SELECIONAR).performScrollTo().performClick()
        rule.onNodeWithText("Águas Claras").assertIsDisplayed().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        rule.onNodeWithText("Águas Claras").performClick()

        rule.onNodeWithText("Águas Claras").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.REGIAO_SELECIONAR).assertDoesNotExist()
    }

    @Test
    fun errosDeCampoAparecemNoProprioCampoEMarcamErro() {
        montar(
            EstadoCadastroEstabelecimento(
                errosDeCampo = mapOf(
                    CampoCadastro.NOME to TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO,
                    CampoCadastro.DOCUMENTO to TextosCadastroEstabelecimento.DOCUMENTO_INVALIDO,
                    CampoCadastro.REGIAO_ADMINISTRATIVA to TextosCadastroEstabelecimento.REGIAO_INVALIDA,
                    CampoCadastro.LATITUDE to TextosCadastroEstabelecimento.COORDENADA_INVALIDA,
                ),
            ),
        )

        rule.onNodeWithText(TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.DOCUMENTO_INVALIDO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.REGIAO_INVALIDA).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.COORDENADA_INVALIDA).performScrollTo().assertIsDisplayed()
        // O texto de ajuda dá lugar ao erro.
        rule.onNodeWithText(TextosCadastroEstabelecimento.DOCUMENTO_AJUDA).assertDoesNotExist()
        rule.onNodeWithText(TextosCadastroEstabelecimento.REGIAO_AJUDA).assertDoesNotExist()
    }

    @Test
    fun erroGlobalAparecePertoDoBotaoEOBotaoContinuaDisponivel() {
        montar(EstadoCadastroEstabelecimento(erro = ErroGlobalCadastro.DOCUMENTO_DUPLICADO))

        rule.onNodeWithText(ErroGlobalCadastro.DOCUMENTO_DUPLICADO.mensagem).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.CADASTRAR).performScrollTo().assertIsEnabled()
    }

    @Test
    fun botaoCadastrarChamaOCallbackUmaVez() {
        val c = montar()

        rule.onNodeWithText(TextosCadastroEstabelecimento.CADASTRAR).performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, c.cadastros)
    }

    @Test
    fun enviandoMostraProgressoDesabilitaBotaoCamposEVoltar() {
        montar(EstadoCadastroEstabelecimento(enviando = true))

        rule.onNodeWithText(TextosCadastroEstabelecimento.CADASTRANDO).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithText(TextosCadastroEstabelecimento.NOME).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithContentDescription(TextosCadastroEstabelecimento.ROTULO_VOLTAR).assertIsNotEnabled()
    }

    @Test
    fun concluidoAvisaEBloqueiaNovoEnvio() {
        montar(
            EstadoCadastroEstabelecimento(
                estabelecimentoCriado = EstabelecimentoDto("e1", "Bar", "12345678901", "outro", "Rua 1", "Gama", CoordenadaDto(-16.0, -48.0), "administrador"),
            ),
        )

        rule.onNodeWithText(TextosCadastroEstabelecimento.CONCLUIDO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosCadastroEstabelecimento.CADASTRAR).performScrollTo().assertIsNotEnabled()
    }
}
