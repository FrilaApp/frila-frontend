package br.com.frila.feature.vagas.escala.capturas

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.EscalaPublicadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.VagaPublicadaDto
import br.com.frila.feature.vagas.escala.EscalaDeEventoViewModel
import br.com.frila.feature.vagas.escala.TelaEscalaDeEvento
import br.com.frila.feature.vagas.escala.TextosEscala
import br.com.frila.feature.vagas.painel.AcoesMinhasVagas
import br.com.frila.feature.vagas.painel.ConteudoMinhasVagas
import br.com.frila.feature.vagas.painel.EstadoMinhasVagas
import br.com.frila.feature.vagas.painel.ListaMinhasVagas
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.TextosPublicarVaga
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints da escala de evento (pedido 18-02) num Pixel de 411 × 914 dp, no claro, no tamanho padrão e com a fonte do
 * sistema em 200%. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasEscalaTest {

    @get:Rule
    val compose = createComposeRule()

    private val base: Instant = Instant.parse("2026-11-10T15:00:00Z")
    private val funcoes = listOf(FuncaoDto("f1", "Garçom", "Salão"), FuncaoDto("f2", "Cozinheiro", "Cozinha"), FuncaoDto("f3", "Barman", "Bar"))

    private fun viewModel(falhar: Boolean = false) = EscalaDeEventoViewModel(
        estabelecimento = EstabelecimentoDaVaga("e1", "CLS 408, Bloco B, Loja 12", "Plano Piloto", CoordenadaDto(-15.7942, -47.8822)),
        buscarFuncoes = { funcoes },
        enviarEscala = { corpo ->
            if (falhar) error("sem rede")
            EscalaPublicadaDto("ev1", corpo.vagas.map { VagaPublicadaDto("v", listOf("p")) })
        },
        relogio = { base },
        novaChave = { "chave-1" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun montar(vm: EscalaDeEventoViewModel) {
        compose.setContent { FrilaTheme(temaEscuro = false) { TelaEscalaDeEvento(vm, aoConcluir = {}, aoVoltar = {}) } }
    }

    private fun preencherDuasVagas() {
        compose.onNodeWithText(TextosEscala.NOME).performTextInput("Formatura de Direito")
        compose.onAllNodesWithText(TextosEscala.FUNCAO_SELECIONAR)[0].performScrollTo().performClick()
        compose.onNodeWithText("Garçom").performClick()
        compose.onAllNodesWithText(TextosPublicarVaga.VALOR)[0].performScrollTo().performTextInput("180")
        compose.onAllNodesWithText(TextosPublicarVaga.RESPONSAVEL)[0].performScrollTo().performTextInput("Lia")
        compose.onNodeWithText(TextosEscala.ADICIONAR).performScrollTo().performClick()
        compose.onAllNodesWithText(TextosEscala.FUNCAO_SELECIONAR)[0].performScrollTo().performClick()
        compose.onNodeWithText("Cozinheiro").performClick()
        compose.onAllNodesWithText(TextosPublicarVaga.VALOR)[1].performScrollTo().performTextInput("220")
    }

    @Test
    fun `escala vazia - claro`() {
        montar(viewModel())
        compose.capturar("escala-01-vazia-claro")
    }

    @Test
    fun `escala com duas vagas, inicio da segunda - claro`() {
        montar(viewModel())
        preencherDuasVagas()
        compose.onNodeWithText(TextosEscala.VAGA.format(2, 2)).performScrollTo()
        compose.capturar("escala-02-duas-vagas-claro")
    }

    @Test
    fun `escala com a folha de funcao aberta - claro`() {
        montar(viewModel())
        compose.onAllNodesWithText(TextosEscala.FUNCAO_SELECIONAR)[0].performScrollTo().performClick()
        compose.capturarJanela("escala-03-funcao-aberta-claro", janela = 1)
    }

    @Test
    fun `escala com erros por campo e erro geral - claro`() {
        montar(viewModel())
        compose.onNodeWithText(TextosEscala.PUBLICAR).performClick()
        compose.capturar("escala-04-erros-nome-claro")
        compose.onAllNodesWithText(TextosEscala.FUNCAO_CAMPO)[0].performScrollTo()
        compose.capturar("escala-05-erros-vaga-claro")
    }

    @Test
    fun `escala pendente depois de falha de rede - claro`() {
        montar(viewModel(falhar = true))
        preencherDuasVagas()
        compose.onNodeWithText(TextosEscala.PUBLICAR).performClick()
        compose.capturar("escala-06-pendente-claro")
    }

    @Test
    fun `escala publicada - claro`() {
        montar(viewModel())
        preencherDuasVagas()
        compose.onNodeWithText(TextosEscala.PUBLICAR).performClick()
        compose.capturar("escala-07-publicada-claro")
    }

    @Test
    fun `minhas vagas com a entrada da escala - claro`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoMinhasVagas(
                    estado = EstadoMinhasVagas(lista = ListaMinhasVagas.Vazio),
                    nomeEstabelecimento = "Bar da Lia",
                    acoes = AcoesMinhasVagas(aoVoltar = null, aoPublicarEscala = {}),
                )
            }
        }
        compose.capturar("escala-08-minhas-vagas-entrada-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `escala vazia com fonte em 200 por cento`() {
        montar(viewModel())
        compose.capturar("escala-09-vazia-fonte-200")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `escala com duas vagas e erros com fonte em 200 por cento`() {
        montar(viewModel())
        compose.onNodeWithText(TextosEscala.PUBLICAR).performClick()
        compose.onAllNodesWithText(TextosEscala.FUNCAO_CAMPO)[0].performScrollTo()
        compose.capturar("escala-10-vaga-erros-fonte-200")
        compose.onNodeWithText(TextosEscala.ADICIONAR).performScrollTo()
        compose.capturar("escala-11-fim-fonte-200")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `escala publicada com fonte em 200 por cento`() {
        montar(viewModel())
        preencherDuasVagas()
        compose.onNodeWithText(TextosEscala.PUBLICAR).performClick()
        compose.capturar("escala-12-publicada-fonte-200")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `minhas vagas com a entrada da escala com fonte em 200 por cento`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoMinhasVagas(
                    estado = EstadoMinhasVagas(lista = ListaMinhasVagas.Vazio),
                    nomeEstabelecimento = "Bar da Lia",
                    acoes = AcoesMinhasVagas(aoVoltar = null, aoPublicarEscala = {}),
                )
            }
        }
        compose.capturar("escala-13-minhas-vagas-fonte-200")
    }
}
