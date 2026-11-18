package br.com.frila.feature.suporte

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Confirmação de uma só etapa, com a consequência escrita (bloquear e desbloquear), no sistema do Frila: `AlertDialog`
 * nativo em superfície com raio de cartão, texto em tinta e SEM laranja nem vermelho (o laranja é do botão que avança
 * na tela por baixo). Confirmar é [BotaoSecundario]; voltar atrás é [AcaoDiscreta]. Componente do módulo: se outras
 * telas precisarem, sobe para o design system.
 */
@Composable
internal fun DialogoDeConfirmacao(
    titulo: String,
    mensagem: String,
    textoConfirmar: String,
    aoConfirmar: () -> Unit,
    textoCancelar: String,
    aoCancelar: () -> Unit,
) {
    val cores = FrilaTema.cores
    AlertDialog(
        onDismissRequest = aoCancelar,
        containerColor = cores.superficie,
        shape = RoundedCornerShape(FrilaRaios.cartao),
        title = {
            Text(
                text = titulo,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = { Text(text = mensagem, style = FrilaTipo.corpo, color = cores.tinta) },
        confirmButton = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
            ) {
                AcaoDiscreta(texto = textoCancelar, aoClicar = aoCancelar)
                BotaoSecundario(texto = textoConfirmar, aoClicar = aoConfirmar)
            }
        },
    )
}
