package br.com.frila.core.designsystem.componentes

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaCores
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaRaios

/**
 * Componente base de esqueleto (skeleton loading) para feedback de carregamento suave (RNF10/RNF04).
 */
@Composable
fun FrilaSkeleton(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(FrilaRaios.pequeno),
) {
    val escuro = isSystemInDarkTheme()
    val corBase = if (escuro) Color(0xFF2C2C2A) else Color(0xFFE2E2DE)

    val transicao = rememberInfiniteTransition(label = "FrilaSkeletonPulse")
    val alphaAnimado by transicao.animateFloat(
        initialValue = 0.4f,
        targetValue = 0.9f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 900, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "FrilaSkeletonAlpha",
    )

    Box(
        modifier = modifier
            .background(color = corBase.copy(alpha = alphaAnimado), shape = shape)
            .semantics { contentDescription = "Carregando conteúdo" },
    )
}

/**
 * Esqueleto simulando um cartão de conteúdo (vaga ou turno) durante carregamento de lista.
 */
@Composable
fun FrilaCartaoSkeleton(
    modifier: Modifier = Modifier,
    altura: Dp = 120.dp,
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .height(altura),
        shape = RoundedCornerShape(FrilaRaios.medio),
        color = if (isSystemInDarkTheme()) FrilaCores.surfaceElevatedDark else FrilaCores.surfaceElevatedLight,
    ) {
        Column(
            modifier = Modifier.padding(FrilaEspacamento.medio),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
        ) {
            FrilaSkeleton(
                modifier = Modifier
                    .fillMaxWidth(0.6f)
                    .height(20.dp),
            )
            FrilaSkeleton(
                modifier = Modifier
                    .fillMaxWidth(0.85f)
                    .height(16.dp),
            )
            FrilaSkeleton(
                modifier = Modifier
                    .fillMaxWidth(0.4f)
                    .height(16.dp),
            )
        }
    }
}
