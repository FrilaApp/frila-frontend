package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Linha de etapas do turno (Confirmado, A caminho, Presença, Concluído): um marcador de 12dp por
 * etapa, ligado ao seguinte por um traço de 2dp. Feitas e a atual: marcador cheio em tinta; o traço
 * é tinta só entre etapas que já passaram. Futuras: marcador em contorno. O rótulo da atual vai em
 * tinta e 600; os outros, em tinta suave. Não depende só de cor, e o leitor de tela ouve a etapa atual.
 *
 * Com a fonte do sistema grande (acima de 1,3×) quatro rótulos lado a lado não cabem e quebrariam no meio da
 * palavra: aí os marcadores ficam sem rótulo e a etapa atual vem escrita embaixo, numa linha só ("Etapa 2 de 4: A caminho").
 */
@Composable
fun LinhaDeEtapas(
    etapas: List<String>,
    atual: Int,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val descricao = "Etapa ${atual + 1} de ${etapas.size}: ${etapas.getOrNull(atual).orEmpty()}"

    val rotulosCabem = LocalDensity.current.fontScale <= 1.3f

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clearAndSetSemantics { contentDescription = descricao },
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            etapas.forEachIndexed { indice, nome ->
                val feita = indice <= atual
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
                ) {
                    Canvas(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(12.dp),
                    ) {
                        val meio = Offset(size.width / 2, size.height / 2)
                        val raio = size.height / 2
                        val traco = 2.dp.toPx()
                        if (indice > 0) {
                            drawLine(
                                color = if (feita) cores.tinta else cores.borda,
                                start = Offset(0f, meio.y),
                                end = Offset(meio.x - raio, meio.y),
                                strokeWidth = traco,
                            )
                        }
                        if (indice < etapas.lastIndex) {
                            drawLine(
                                color = if (indice < atual) cores.tinta else cores.borda,
                                start = Offset(meio.x + raio, meio.y),
                                end = Offset(size.width, meio.y),
                                strokeWidth = traco,
                            )
                        }
                        if (feita) {
                            drawCircle(color = cores.tinta, radius = raio, center = meio)
                        } else {
                            val fio = 1.5.dp.toPx()
                            drawCircle(color = cores.bordaControle, radius = raio - fio / 2, center = meio, style = Stroke(fio))
                        }
                    }
                    if (rotulosCabem) {
                        Text(
                            text = nome,
                            style = FrilaTipo.legenda.copy(fontWeight = if (indice == atual) FontWeight.SemiBold else FontWeight.Normal),
                            color = if (indice == atual) cores.tinta else cores.tintaSuave,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
            }
        }
        if (!rotulosCabem) {
            Text(
                text = descricao,
                style = FrilaTipo.legenda.copy(fontWeight = FontWeight.SemiBold),
                color = cores.tinta,
            )
        }
    }
}
