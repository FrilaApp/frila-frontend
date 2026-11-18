package br.com.frila.feature.estabelecimento.capturas.r5

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.feature.estabelecimento.CampoCadastro
import br.com.frila.feature.estabelecimento.ConteudoCadastroEstabelecimento
import br.com.frila.feature.estabelecimento.EstadoCadastroEstabelecimento
import br.com.frila.feature.estabelecimento.ErroGlobalCadastro
import br.com.frila.feature.estabelecimento.TextosCadastroEstabelecimento
import br.com.frila.feature.estabelecimento.TipoEstabelecimento
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do cadastro do estabelecimento (R5) num Pixel de 411 × 914 dp, no claro. Sem `FRILA_CAPTURAS_DIR`
 * (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR5Test {

    @get:Rule
    val compose = createComposeRule()

    private val preenchido = EstadoCadastroEstabelecimento(
        nome = "Bar da Lia",
        documento = "12345678000199",
        tipo = TipoEstabelecimento.EVENTO,
        endereco = "CLS 408, Bloco B, loja 12",
        regiaoAdministrativa = "Plano Piloto",
        latitude = "-15,7801",
        longitude = "-47,9292",
    )

    private fun montar(estado: EstadoCadastroEstabelecimento) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoCadastroEstabelecimento(
                    estado = estado,
                    aoEditarNome = {}, aoEditarDocumento = {}, aoEscolherTipo = {}, aoEditarEndereco = {},
                    aoEscolherRegiao = {}, aoEditarLatitude = {}, aoEditarLongitude = {}, aoCadastrar = {}, aoVoltar = {},
                )
            }
        }
    }

    @Test
    fun `cadastro vazio - claro`() {
        montar(EstadoCadastroEstabelecimento())
        compose.capturar("cadastro-01-vazio-claro")
    }

    @Test
    fun `cadastro preenchido, fim do formulario - claro`() {
        montar(preenchido)
        compose.onNodeWithText(TextosCadastroEstabelecimento.LONGITUDE).performScrollTo()
        compose.capturar("cadastro-02-preenchido-fim-claro")
    }

    @Test
    fun `cadastro com erros de campo e erro global - claro`() {
        montar(
            EstadoCadastroEstabelecimento(
                nome = "",
                documento = "123",
                errosDeCampo = mapOf(
                    CampoCadastro.NOME to TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO,
                    CampoCadastro.DOCUMENTO to TextosCadastroEstabelecimento.DOCUMENTO_INVALIDO,
                ),
                erro = ErroGlobalCadastro.CONFIRA_CAMPOS,
            ),
        )
        compose.capturar("cadastro-03-erros-claro")
    }

    @Test
    fun `cadastro com erro de regiao e de ponto - claro`() {
        montar(
            preenchido.copy(
                regiaoAdministrativa = "",
                errosDeCampo = mapOf(
                    CampoCadastro.REGIAO_ADMINISTRATIVA to TextosCadastroEstabelecimento.REGIAO_INVALIDA,
                    CampoCadastro.LATITUDE to TextosCadastroEstabelecimento.COORDENADA_INVALIDA,
                ),
                erro = ErroGlobalCadastro.DOCUMENTO_DUPLICADO,
            ),
        )
        compose.onNodeWithText(TextosCadastroEstabelecimento.LONGITUDE).performScrollTo()
        compose.capturar("cadastro-04-erros-do-fim-claro")
    }

    @Test
    fun `cadastro enviando - claro`() {
        montar(preenchido.copy(enviando = true))
        compose.capturar("cadastro-05-enviando-claro")
    }

    @Test
    fun `cadastro com a folha de regiao aberta - claro`() {
        montar(preenchido.copy(regiaoAdministrativa = ""))
        compose.onNodeWithText(TextosCadastroEstabelecimento.REGIAO_SELECIONAR).performScrollTo().performClick()
        compose.capturarJanela("cadastro-06-regiao-aberta-claro", janela = 1)
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `cadastro com fonte do sistema em 200 por cento`() {
        montar(preenchido)
        compose.capturar("cadastro-07-fonte-200-claro")
    }
}
