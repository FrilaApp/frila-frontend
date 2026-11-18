package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema

/**
 * Cartão do Frila: superfície, fio de 1dp em `borda`, raio 24, padding 16, SEM sombra. Todo conteúdo
 * agrupado sobre o fundo da tela fica num destes. Com `aoClicar`, o cartão inteiro é um alvo só.
 */
@Composable
fun CartaoFrila(
    modifier: Modifier = Modifier,
    forma: Shape = RoundedCornerShape(FrilaRaios.cartao),
    aoClicar: (() -> Unit)? = null,
    rotuloDaAcao: String? = null,
    conteudo: @Composable () -> Unit,
) {
    val cores = FrilaTema.cores
    val modifierDoCartao = if (aoClicar == null) {
        modifier
    } else {
        modifier
            .sizeIn(
                minWidth = FrilaMetricas.alvoMinimo,
                minHeight = FrilaMetricas.alvoMinimo,
            )
            .focoAcessivelFrila(forma = forma)
            .clip(forma)
            .clickable(
                onClickLabel = rotuloDaAcao,
                role = Role.Button,
                onClick = aoClicar,
            )
    }

    Column(
        modifier = modifierDoCartao
            .background(cores.superficie, shape = forma)
            .border(BorderStroke(1.dp, cores.borda), shape = forma)
            .padding(FrilaEspacamento.bloco),
    ) {
        conteudo()
    }
}

/** O cartão de vaga de antes do redesign: hoje é o [CartaoFrila]. Mantido para as telas que já o usam. */
@Composable
fun CartaoVaga(
    modifier: Modifier = Modifier,
    forma: Shape = RoundedCornerShape(FrilaRaios.cartao),
    aoClicar: (() -> Unit)? = null,
    rotuloDaAcao: String? = null,
    conteudo: @Composable () -> Unit,
) {
    CartaoFrila(modifier, forma, aoClicar, rotuloDaAcao, conteudo)
}
