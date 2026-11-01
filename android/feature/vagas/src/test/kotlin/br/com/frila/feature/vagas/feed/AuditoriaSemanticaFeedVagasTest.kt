package br.com.frila.feature.vagas.feed

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AuditoriaSemanticaFeedVagasTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `percorre cartoes de vaga do feed e valida 100 por cento dos criterios semanticos`() {
        val vagas = listOf(
            ItemVaga(
                id = "1",
                funcaoNome = "Garçom",
                estabelecimentoNome = "Bar do Zé",
                horarioFormatado = "Hoje · 18:00 às 00:00",
                valorFormatado = "R$ 150,00",
                distanciaKm = 3.5,
                modo = "urgencia",
            ),
            ItemVaga(
                id = "2",
                funcaoNome = "Cozinheiro",
                estabelecimentoNome = "Restaurante Central",
                horarioFormatado = "Amanhã · 10:00 às 16:00",
                valorFormatado = "R$ 200,00",
                distanciaKm = 5.2,
                modo = "normal",
            ),
        )

        compose.setContent {
            FrilaTheme {
                androidx.compose.foundation.lazy.LazyColumn {
                    items(vagas.size) { i ->
                        val vaga = vagas[i]
                        CartaoVaga(
                            aoClicar = {},
                            rotuloDaAcao = "Abrir detalhes da vaga de ${vaga.funcaoNome}",
                        ) {
                            Text(
                                text = vaga.funcaoNome,
                                modifier = Modifier.semantics { heading() },
                            )
                            Text(text = vaga.estabelecimentoNome)
                            Text(text = vaga.horarioFormatado)
                            Text(text = "${vaga.valorFormatado} · ${"%.1f".format(vaga.distanciaKm)} km")
                        }
                    }
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }

    @Test
    fun `cartao de vaga com icone acionavel sem descricao falha na auditoria semantica`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga(aoClicar = {}, rotuloDaAcao = "Abrir vaga") {
                    Text(text = "Garçom", modifier = Modifier.semantics { heading() })
                    // Botão de compartilhar vaga sem contentDescription
                    IconButton(onClick = {}) {
                        Icon(imageVector = Icons.Default.Share, contentDescription = null)
                    }
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        val erro = assertThrows(AssertionError::class.java) {
            AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
        }

        assertTrue(
            "Deve falhar com violação de ícone acionável sem descrição: ${erro.message}",
            erro.message?.contains("ICONE_ACIONAVEL_SEM_DESCRICAO") == true,
        )
    }

    @Test
    fun `cartao de vaga com icone decorativo com contentDescription null passa na auditoria`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga(aoClicar = {}, rotuloDaAcao = "Abrir vaga") {
                    Text(text = "Garçom", modifier = Modifier.semantics { heading() })
                    // Ícone decorativo de local com null
                    Icon(imageVector = Icons.Default.Place, contentDescription = null)
                    Text(text = "Asa Sul · 2.1 km")
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }

    @Test
    fun `cartao de vaga com icone acionavel com descricao valida passa na auditoria`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga(aoClicar = {}, rotuloDaAcao = "Abrir vaga") {
                    Text(text = "Garçom", modifier = Modifier.semantics { heading() })
                    IconButton(
                        onClick = {},
                        modifier = Modifier.semantics { contentDescription = "Compartilhar vaga" },
                    ) {
                        Icon(imageVector = Icons.Default.Share, contentDescription = null)
                    }
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }
}
