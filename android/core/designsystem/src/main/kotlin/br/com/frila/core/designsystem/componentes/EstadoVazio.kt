package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Estado vazio do Frila (RNF10), no desenho do Fabrício: coluna centralizada no lugar da lista, sem
 * cartão e sem laranja (o vazio não decide nada). Nesta ordem: o FATO em corpo e tinta, a DICA em
 * apoio e tinta suave, e a AÇÃO, opcional, em botão secundário da largura do rótulo.
 *
 * Só há ação quando existe um próximo passo que o campo da tela não é (o limpar de uma busca já é a
 * ação dela). Sem ícone por padrão; `icone` fica para quem ainda precisa de um.
 */
@Composable
fun EstadoVazio(
    titulo: String,
    modifier: Modifier = Modifier,
    mensagem: String? = null,
    icone: ImageVector? = null,
    rotuloIcone: String? = null,
    textoAcao: String? = null,
    aoClicarAcao: (() -> Unit)? = null,
) {
    val cores = FrilaTema.cores

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = FrilaEspacamento.grupo,
                end = FrilaEspacamento.grupo,
                top = FrilaEspacamento.respiro,
                bottom = FrilaEspacamento.grupo,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item, Alignment.CenterVertically),
    ) {
        if (icone != null) {
            Icon(
                imageVector = icone,
                contentDescription = rotuloIcone,
                tint = cores.tintaSuave,
                modifier = Modifier.size(24.dp),
            )
        }
        Text(
            text = titulo,
            style = FrilaTipo.corpo,
            color = cores.tinta,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        if (!mensagem.isNullOrBlank()) {
            Text(
                text = mensagem,
                style = FrilaTipo.apoio,
                color = cores.tintaSuave,
                textAlign = TextAlign.Center,
            )
        }
        if (!textoAcao.isNullOrBlank() && aoClicarAcao != null) {
            BotaoSecundario(
                texto = textoAcao,
                aoClicar = aoClicarAcao,
                modifier = Modifier.padding(top = FrilaEspacamento.item),
            )
        }
    }
}
