package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.Column
import androidx.compose.material.icons.Icons
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
import br.com.frila.core.designsystem.tema.FrilaCores
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
class AuditoriaSemanticaCartoesTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `cartao de vaga valido passa com sucesso na auditoria semantica`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga(
                    aoClicar = {},
                    rotuloDaAcao = "Abrir detalhes da vaga de Garçom",
                ) {
                    Text(text = "Garçom", modifier = Modifier.semantics { heading() })
                    Text(text = "Bar do Zé")
                    Text(text = "Hoje · 18:00 às 00:00")
                    Text(text = "R$ 150,00 · 3.5 km")
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }

    @Test
    fun `cartao com icone acionavel sem descricao falha na auditoria semantica com mensagem explicativa`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga {
                    Text(text = "Garçom", modifier = Modifier.semantics { heading() })
                    // Botão de ícone sem contentDescription e sem texto visível
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
            "Mensagem deve apontar ícone acionável sem descrição: ${erro.message}",
            erro.message?.contains("ICONE_ACIONAVEL_SEM_DESCRICAO") == true,
        )
    }

    @Test
    fun `cartao com icone acionavel com descricao acessivel valida passa na auditoria`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga {
                    Text(text = "Garçom", modifier = Modifier.semantics { heading() })
                    IconButton(
                        onClick = {},
                        modifier = Modifier.semantics { contentDescription = "Compartilhar oportunidade" },
                    ) {
                        Icon(imageVector = Icons.Default.Share, contentDescription = null)
                    }
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }

    @Test
    fun `cartao com icone decorativo com contentDescription null passa na auditoria`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga {
                    Text(text = "Garçom", modifier = Modifier.semantics { heading() })
                    Column {
                        Icon(
                            imageVector = Icons.Default.Place,
                            contentDescription = null,
                        )
                        Text(text = "Asa Norte · 4.2 km")
                    }
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }

    @Test
    fun `cartao com icone decorativo com descricao generica ou redundante falha na auditoria`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga {
                    Text(text = "Garçom", modifier = Modifier.semantics { heading() })
                    Icon(
                        imageVector = Icons.Default.Place,
                        contentDescription = "ícone", // Redundância que polui o TalkBack
                    )
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        val erro = assertThrows(AssertionError::class.java) {
            AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
        }

        assertTrue(
            "Mensagem deve apontar ícone decorativo com descrição redundante: ${erro.message}",
            erro.message?.contains("ICONE_DECORATIVO_COM_DESCRICAO_REDUNDANTE") == true,
        )
    }

    @Test
    fun `contraste de texto sobre superficies de cartao atinge WCAG AA no tema claro e escuro`() {
        // Tema claro: texto sobre cartão (SurfaceElevatedLight)
        AuditoriaSemanticaAcessibilidade.assertContrasteAA(
            corTexto = FrilaCores.textPrimaryLight,
            corFundo = FrilaCores.surfaceElevatedLight,
            descricaoCores = "textPrimaryLight sobre surfaceElevatedLight",
        )
        AuditoriaSemanticaAcessibilidade.assertContrasteAA(
            corTexto = FrilaCores.textSecondaryLight,
            corFundo = FrilaCores.surfaceElevatedLight,
            descricaoCores = "textSecondaryLight sobre surfaceElevatedLight",
        )

        // Tema escuro: texto sobre cartão (SurfaceElevatedDark)
        AuditoriaSemanticaAcessibilidade.assertContrasteAA(
            corTexto = FrilaCores.textPrimaryDark,
            corFundo = FrilaCores.surfaceElevatedDark,
            descricaoCores = "textPrimaryDark sobre surfaceElevatedDark",
        )
        AuditoriaSemanticaAcessibilidade.assertContrasteAA(
            corTexto = FrilaCores.textSecondaryDark,
            corFundo = FrilaCores.surfaceElevatedDark,
            descricaoCores = "textSecondaryDark sobre surfaceElevatedDark",
        )
    }
}
