package br.com.frila.feature.vagas.candidatos

import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * A miniatura precisa de um `Bitmap` de verdade, que o modo de gráficos padrão do Robolectric não cria
 * (`Bitmap.createBitmap` devolve nulo). Fica numa classe própria com `GraphicsMode.NATIVE` para não
 * mexer no ambiente dos outros testes de tela.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class FotoDoCandidatoTest {

    @get:Rule
    val rule = createComposeRule()

    private val candidato = CandidatoDto(
        candidaturaId = "c1",
        profissional = PerfilPublicoDto(
            id = "p1", tipo = "profissional", nome = "Ana",
            reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
            fotoUrl = "https://frila.supabase.co/foto.jpg",
        ),
        criadaEm = "2026-11-10T12:00:00Z",
    )

    @Test
    fun `com a foto baixada o cartao mostra a imagem do candidato no lugar da inicial`() {
        var pedida: String? = null
        rule.setContent {
            FrilaTheme {
                ConteudoCandidatosDaVaga(
                    estado = EstadoCandidatosDaVaga(
                        lista = EstadoDosCandidatos.Carregados(listOf(candidato)),
                        agora = Instant.parse("2026-11-10T15:00:00Z"),
                    ),
                    acoes = AcoesCandidatosDaVaga(),
                    carregarFoto = { url -> pedida = url; ImageBitmap(4, 4) },
                )
            }
        }

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("foto-do-candidato", useUnmergedTree = true).fetchSemanticsNodes().size == 1 }

        assertEquals("https://frila.supabase.co/foto.jpg", pedida)
        rule.onNodeWithTag("foto-do-candidato", useUnmergedTree = true).assert(hasContentDescription("Foto de Ana"))
        assertEquals(0, rule.onAllNodesWithTag("inicial-do-candidato", useUnmergedTree = true).fetchSemanticsNodes().size)
    }
}
