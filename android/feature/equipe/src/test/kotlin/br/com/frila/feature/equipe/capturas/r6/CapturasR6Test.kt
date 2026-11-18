package br.com.frila.feature.equipe.capturas.r6

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.feature.equipe.ConteudoEquipeDeConfianca
import br.com.frila.feature.equipe.ConteudoIncluirNaEquipe
import br.com.frila.feature.equipe.EstadoEquipe
import br.com.frila.feature.equipe.EstadoIncluirNaEquipe
import br.com.frila.feature.equipe.EstadoTelaEquipe
import br.com.frila.feature.equipe.SituacaoNaEquipe
import br.com.frila.feature.equipe.TextosEquipe
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Prints do lote R6 no módulo da equipe. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR6Test {

    @get:Rule
    val compose = createComposeRule()

    private val ana = PerfilPublicoDto("a1", "profissional", "Ana Souza", listOf("garçom", "barman"), ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8))
    private val beto = PerfilPublicoDto("b1", "profissional", "Beto Lima", null, ReputacaoDto(positivas = 0, total = 0, turnosConsiderados = 0, turnosRealizados = 0))

    private fun tela(tela: EstadoTelaEquipe, comChamarDeNovo: Boolean = true) {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                ConteudoEquipeDeConfianca(
                    tela = tela,
                    aoTentarNovamente = {},
                    aoRemover = {},
                    aoVoltar = {},
                    aoChamarDeNovo = if (comChamarDeNovo) ({ }) else null,
                )
            }
        }
    }

    @Test
    fun `equipe com dados - claro`() {
        tela(EstadoTelaEquipe(estado = EstadoEquipe.Conteudo(listOf(ana, beto))))
        compose.capturar("r6-10-equipe-com-dados-claro")
    }

    @Test
    fun `equipe com aviso de remocao e erro - claro`() {
        tela(
            EstadoTelaEquipe(
                estado = EstadoEquipe.Conteudo(listOf(ana)),
                aviso = TextosEquipe.REMOVIDO,
                mensagemErro = TextosEquipe.SO_ADMINISTRADOR,
                removendo = "a1",
            ),
            comChamarDeNovo = false,
        )
        compose.capturar("r6-11-equipe-aviso-e-erro-claro")
    }

    @Test
    fun `equipe carregando - claro`() {
        tela(EstadoTelaEquipe(estado = EstadoEquipe.Carregando))
        compose.capturar("r6-12-equipe-carregando-claro")
    }

    @Test
    fun `equipe vazia - claro`() {
        tela(EstadoTelaEquipe(estado = EstadoEquipe.Vazio))
        compose.capturar("r6-13-equipe-vazia-claro")
    }

    @Test
    fun `equipe com erro - claro`() {
        tela(EstadoTelaEquipe(estado = EstadoEquipe.SemRede))
        compose.capturar("r6-14-equipe-sem-rede-claro")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 2f)
    fun `equipe com dados - fonte do sistema em 200 por cento`() {
        tela(EstadoTelaEquipe(estado = EstadoEquipe.Conteudo(listOf(ana, beto))))
        compose.capturar("r6-15-equipe-fonte-200")
    }

    @Test
    fun `incluir na equipe - os tres estados - claro`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(FrilaTema.cores.fundo)
                        .padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(32.dp),
                ) {
                    ConteudoIncluirNaEquipe(EstadoIncluirNaEquipe(SituacaoNaEquipe.FORA_DA_EQUIPE), "Ana Souza", {})
                    ConteudoIncluirNaEquipe(
                        EstadoIncluirNaEquipe(SituacaoNaEquipe.FORA_DA_EQUIPE, mensagemErro = TextosEquipe.SEM_TURNO_CUMPRIDO),
                        "Ana Souza",
                        {},
                    )
                    ConteudoIncluirNaEquipe(EstadoIncluirNaEquipe(SituacaoNaEquipe.FORA_DA_EQUIPE, incluindo = true), "Ana Souza", {})
                    ConteudoIncluirNaEquipe(EstadoIncluirNaEquipe(SituacaoNaEquipe.NA_EQUIPE), "Ana Souza", {})
                }
            }
        }
        compose.capturar("r6-16-incluir-na-equipe-claro")
    }
}
