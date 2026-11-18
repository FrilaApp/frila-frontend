package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextDecoration
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Link: texto sublinhado em tinta, no corpo, com alvo de 48dp. Para abrir outra tela ou folha
 * ("Ver todas as funções") ou refazer um envio ("Reenviar código"). Não é ação de risco.
 */
@Composable
fun LinkFrila(
    texto: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    TextoSublinhadoTocavel(texto, aoClicar, modifier, habilitado, cor = FrilaTema.cores.tinta)
}

/**
 * Ação discreta: texto sublinhado em tinta suave, com alvo de 48dp. Só para risco e suporte (desistir,
 * cancelar, sair, excluir, denunciar, pedir ajuda), no fim da tela, uma por linha, longe do primário.
 */
@Composable
fun AcaoDiscreta(
    texto: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
) {
    TextoSublinhadoTocavel(texto, aoClicar, modifier, habilitado, cor = FrilaTema.cores.tintaSuave)
}

@Composable
private fun TextoSublinhadoTocavel(
    texto: String,
    aoClicar: () -> Unit,
    modifier: Modifier,
    habilitado: Boolean,
    cor: Color,
) {
    Box(
        modifier = modifier
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .focoAcessivelFrila(forma = RoundedCornerShape(FrilaRaios.selo))
            .clickable(enabled = habilitado, role = Role.Button, onClick = aoClicar),
        contentAlignment = Alignment.CenterStart,
    ) {
        Text(
            text = texto,
            style = FrilaTipo.corpo.copy(textDecoration = TextDecoration.Underline),
            color = cor,
        )
    }
}
