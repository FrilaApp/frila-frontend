package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.time.Instant
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AuditoriaSemanticaMeusTurnosTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `percorre cartoes de turno e valida 100 por cento dos criterios semanticos`() {
        val agora = Instant.parse("2026-11-01T20:00:00Z")
        val itens = listOf(
            ItemTurno(
                turnoId = "t1",
                posicaoId = "p1",
                inicio = agora.plusSeconds(3600),
                fim = agora.plusSeconds(21600),
                funcaoNome = "Barman",
                estabelecimentoNome = "Pizzaria Bela Vista",
                dataHorarioFormatado = "Hoje · 21:00 às 02:00",
                valorFormatado = "R$ 180,00",
                estado = "confirmada",
            ),
            ItemTurno(
                turnoId = "t2",
                posicaoId = "p2",
                inicio = agora.minusSeconds(86400),
                fim = agora.minusSeconds(64800),
                funcaoNome = "Copeiro",
                estabelecimentoNome = "Café do Lago",
                dataHorarioFormatado = "Ontem · 08:00 às 14:00",
                valorFormatado = "R$ 130,00",
                estado = "cumprida",
                podeAvaliar = true,
            ),
        )

        compose.setContent {
            FrilaTheme {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
                ) {
                    items(itens, key = { it.turnoId }) { turno ->
                        CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                text = turno.funcaoNome,
                                style = MaterialTheme.typography.titleSmall,
                                modifier = Modifier.semantics { heading() },
                            )
                            Text(text = turno.estabelecimentoNome, style = MaterialTheme.typography.bodyMedium)
                            Text(text = turno.dataHorarioFormatado, style = MaterialTheme.typography.bodySmall)
                            Column(
                                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
                            ) {
                                Text(text = turno.valorFormatado, style = MaterialTheme.typography.bodySmall)
                                Text(
                                    text = "Confirmado",
                                    modifier = Modifier.semantics { contentDescription = "Status: Confirmado" },
                                )
                            }
                            BotaoSecundario(
                                texto = "Cancelar turno",
                                aoClicar = {},
                                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                            )
                        }
                    }
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }

    @Test
    fun `cartao de turno com icone acionavel sem descricao falha na auditoria semantica`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                    Text(text = "Barman", modifier = Modifier.semantics { heading() })
                    // Botão de ajuda sem contentDescription
                    IconButton(onClick = {}) {
                        Icon(imageVector = Icons.Default.Info, contentDescription = null)
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
    fun `cartao de turno com icone decorativo com null passa na auditoria`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                    Text(text = "Barman", modifier = Modifier.semantics { heading() })
                    // Ícone decorativo de relógio/info
                    Icon(imageVector = Icons.Default.Info, contentDescription = null)
                    Text(text = "Hoje · 21:00 às 02:00")
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }

    @Test
    fun `cartao de turno com icone acionavel com descricao valida passa na auditoria`() {
        compose.setContent {
            FrilaTheme {
                CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                    Text(text = "Barman", modifier = Modifier.semantics { heading() })
                    IconButton(
                        onClick = {},
                        modifier = Modifier.semantics { contentDescription = "Mais informações sobre o turno" },
                    ) {
                        Icon(imageVector = Icons.Default.Info, contentDescription = null)
                    }
                }
            }
        }

        val noRaiz = compose.onRoot().fetchSemanticsNode()
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
    }
}
