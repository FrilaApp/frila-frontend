package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import java.time.Instant

/**
 * Enviada a chamada, a folha mostra o que foi combinado, até quando o profissional responde e o caminho para
 * acompanhar (desenho do iOS `ResumoDaChamadaEnviada`, V11). Sem [aoAcompanhar] o botão não aparece.
 */
@Composable
internal fun ResumoDaChamadaEnviada(
    tela: EstadoChamadaDireta,
    aoAcompanhar: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val chamada = tela.resultado ?: return
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio)) {
        AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = TextosChamadaCasa.SUCESSO)
        runCatching { Instant.parse(chamada.expiraEm) }.getOrNull()?.let { expira ->
            Text(
                text = TextosChamadaCasa.prazoDeResposta(dataEHora(expira)),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
            )
        }
        Text(
            text = TextosChamadaCasa.RESUMO_DA_CHAMADA,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() }.padding(top = FrilaEspacamento.pequeno),
        )
        Linha(TextosChamadaCasa.VALOR_TOTAL, dinheiro(tela.valorCentavos), destaque = true)
        Linha(TextosChamadaCasa.HORARIO, TextosChamadaCasa.intervalo(dataEHora(tela.inicio), hora(tela.fim)))
        Linha(TextosChamadaCasa.RESPONSAVEL, tela.responsavel.trim())
        if (aoAcompanhar != null) {
            BotaoSecundario(
                texto = TextosChamadaCasa.ACOMPANHAR_TITULO,
                aoClicar = aoAcompanhar,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun Linha(rotulo: String, valor: String, destaque: Boolean = false) {
    Column(modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) { }) {
        Text(rotulo, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(valor, style = if (destaque) MaterialTheme.typography.titleLarge else MaterialTheme.typography.bodyLarge)
    }
}
