package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** O que o leitor de tela diz do botão enquanto a ação roda: o mesmo texto do iOS (`Componentes.swift:166`), sem reticências. */
private const val DESCRICAO_CARREGANDO = "Carregando"

/**
 * Botão primário do Frila: o único laranja da tela, e só onde a pessoa avança ou se compromete.
 * Cápsula de 48dp (64 em "MARCAR PRESENÇA", por `alturaMinima`), rótulo BRANCO em negrito de 20sp:
 * branco sobre o laranja só passa no contraste assim, então nunca texto menor, mais leve ou escuro aqui.
 *
 * Desligado, é o "botão em conferência" do desenho: fica no lugar, com o mesmo rótulo, em `borda` e
 * tinta suave. É o único estado desligado do produto; quem roda uma ação passa `carregando = true`
 * enquanto ela roda (desliga o botão e o leitor de tela diz "Carregando"), sem indicador girando.
 */
@Composable
fun BotaoPrimario(
    texto: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
    alturaMinima: Dp = FrilaMetricas.alturaBotao,
    /** A ação roda: o botão fica desligado, no lugar e com o mesmo rótulo, e o leitor de tela diz "Carregando" (iOS: `BotaoPrimario(carregando:)`, `Componentes.swift:161-167`). */
    carregando: Boolean = false,
) {
    val cores = FrilaTema.cores
    val interacao = remember { MutableInteractionSource() }
    val pressionado by interacao.collectIsPressedAsState()

    Button(
        onClick = aoClicar,
        enabled = habilitado && !carregando,
        modifier = modifier
            .sizeIn(
                minWidth = FrilaMetricas.alvoMinimo,
                minHeight = FrilaMetricas.alvoMinimo,
            )
            .heightIn(min = alturaMinima)
            .widthIn(min = FrilaMetricas.alvoMinimo)
            .focoAcessivelFrila(forma = CircleShape)
            // O leitor de tela diz o porquê de o botão estar desligado, e não só "desativado" (iOS: `.accessibilityValue("Carregando")`).
            .then(if (carregando) Modifier.semantics { stateDescription = DESCRICAO_CARREGANDO } else Modifier),
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (pressionado) cores.acaoPressionada else cores.acao,
            contentColor = cores.sobreAcao,
            disabledContainerColor = cores.borda,
            disabledContentColor = cores.tintaSuave,
        ),
        elevation = null,
        contentPadding = PaddingValues(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        interactionSource = interacao,
    ) {
        Text(text = texto, style = FrilaTipo.rotuloDoPrimario, textAlign = TextAlign.Center)
    }
}
