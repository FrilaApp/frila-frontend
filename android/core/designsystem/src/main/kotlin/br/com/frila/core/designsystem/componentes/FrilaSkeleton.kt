package br.com.frila.core.designsystem.componentes

import android.provider.Settings
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaCores
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaRaios

/**
 * `true` quando o sistema permite animação (padrão), `false` quando o usuário desligou
 * animações em Opções do desenvolvedor/Acessibilidade (`Settings.Global.ANIMATOR_DURATION_SCALE
 * == 0`). RNF10: nesse caso o skeleton fica estático em vez de forçar o shimmer — "Reduzir
 * movimento" é uma preferência de acessibilidade, não só uma opção de performance.
 */
@Composable
private fun animacoesAtivadas(): Boolean {
    val contexto = LocalContext.current
    return remember {
        val escala = Settings.Global.getFloat(contexto.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
        escala != 0f
    }
}

/**
 * Componente base de esqueleto (skeleton loading) para feedback de carregamento suave
 * (RNF10/RNF04). Shimmer leve: gradiente linear de 3 cores animado por `rememberInfiniteTransition`
 * (1500ms, [LinearEasing]) — mais barato que recompor `Brush` a cada frame porque o gradiente é
 * `remember`ado e só a posição (`Float`) muda; o desenho usa `drawWithCache` para não precisar de
 * `onGloballyPositioned` (que forçaria recomposição extra a cada mudança de tamanho).
 */
@Composable
fun FrilaSkeleton(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(FrilaRaios.pequeno),
) {
    val escuro = isSystemInDarkTheme()
    val cores = remember(escuro) {
        val base = if (escuro) Color(0xFF2C2C2A) else Color(0xFFE2E2DE)
        // Destaque especular (paridade com iOS FrilaSkeleton.swift:154): claro = branco 42%,
        // escuro/OLED = branco 9% (evita glare num fundo quase preto) — DEDUZIDO do swift.
        val destaque = lerp(base, Color.White, if (escuro) 0.09f else 0.42f)
        listOf(base, destaque, base)
    }
    val ativo = animacoesAtivadas()

    if (!ativo) {
        Box(
            modifier = modifier
                .clip(shape)
                .drawWithCache { onDrawBehind { drawRect(cores.first(), size = size) } }
                .clearAndSetSemantics {},
        )
        return
    }

    val transicao = rememberInfiniteTransition(label = "FrilaSkeletonShimmer")
    val deslocamento by transicao.animateFloat(
        initialValue = -1f,
        targetValue = 2f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1500, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "FrilaSkeletonOffset",
    )

    Box(
        modifier = modifier
            .clip(shape)
            .drawWithCache {
                // MEDIDO (Shisui, PR #594, bloqueante 2): ler `deslocamento` (o Float animado)
                // aqui dentro invalidava o cache a cada frame — 53 recriações de Brush em 3s
                // por osso. O bloco de `drawWithCache` só lê `size`/`cores`, então o Brush é
                // montado uma vez por mudança de tamanho; o frame a frame só desloca o canvas
                // (`translate`) antes de pintar o mesmo Brush já pronto — sem alocar nada novo.
                val largura = size.width
                val corBase = cores.first()
                val pincel = Brush.linearGradient(
                    colors = cores,
                    start = Offset(-largura, 0f),
                    end = Offset(largura, 0f),
                )
                onDrawBehind {
                    // MEDIDO (Shisui, PR #594, regressão visual): transladar só o retângulo
                    // deixava parte do osso sem cobertura em 26/26 frames medidos (chegando a
                    // 100% transparente). Correção: 1) pinta o fundo sólido sempre, cobrindo
                    // 100% do osso em qualquer frame; 2) desenha o gradiente com
                    // contra-translação (`topLeft = -x` dentro de `translate(left = x)`) — o
                    // retângulo do gradiente volta a cobrir exatamente (0,0,size), e só o shader
                    // do Brush (que carrega a transformação do canvas) deslisa visualmente.
                    drawRect(color = corBase, size = size)
                    val x = deslocamento * largura
                    translate(left = x) {
                        drawRect(brush = pincel, topLeft = Offset(-x, 0f), size = size)
                    }
                }
            }
            .clearAndSetSemantics {},
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
