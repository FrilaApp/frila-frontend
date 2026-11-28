package br.com.frila.feature.perfil

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import kotlinx.coroutines.delay

object TextosContatoDoPerfil {
    const val TELEFONE = "Telefone"
    const val EMAIL = "E-mail"
    const val COPIAR = "Copiar"
    const val COPIADO = "Copiado"
    const val NAO_INFORMADO = "—"
}

/** Quanto tempo o "Copiado" fica no lugar do valor (o iOS usa `FrilaMotion.copyTipHold`). */
private const val TEMPO_DO_COPIADO_MS = 1_500L

/**
 * Telefone e e-mail da conta, cada um com "copiar" (`ContatoCopiavel` do iOS): rótulo acima do valor, um toque copia o valor como está
 * na tela e "Copiado" aparece no lugar dele. O telefone vai formatado ([FormatoDeTelefone.paraExibir]); contato vazio mostra "—".
 * Editar o contato fica de fora.
 */
@Composable
internal fun BlocoDeContato(
    telefone: String?,
    email: String?,
    aoCopiar: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    CartaoFrila(modifier = modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            ContatoCopiavel(
                rotulo = TextosContatoDoPerfil.TELEFONE,
                valor = FormatoDeTelefone.paraExibir(telefone.orEmpty()),
                aoCopiar = aoCopiar,
                tag = "perfil-telefone",
            )
            ContatoCopiavel(
                rotulo = TextosContatoDoPerfil.EMAIL,
                valor = email.orEmpty(),
                aoCopiar = aoCopiar,
                tag = "perfil-email",
            )
        }
    }
}

@Composable
private fun ContatoCopiavel(rotulo: String, valor: String, aoCopiar: (String) -> Unit, tag: String) {
    val cores = FrilaTema.cores
    var copiado by remember { mutableStateOf(false) }
    LaunchedEffect(copiado) {
        if (copiado) {
            delay(TEMPO_DO_COPIADO_MS)
            copiado = false
        }
    }
    val vazio = valor.isBlank()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .testTag(tag)
            .clickable(enabled = !vazio, onClickLabel = TextosContatoDoPerfil.COPIAR, role = Role.Button) {
                aoCopiar(valor)
                copiado = true
            },
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
    ) {
        Text(text = rotulo, style = FrilaTipo.apoio, color = cores.tintaSuave)
        Text(
            text = when {
                copiado -> TextosContatoDoPerfil.COPIADO
                vazio -> TextosContatoDoPerfil.NAO_INFORMADO
                else -> valor
            },
            style = FrilaTipo.corpo,
            color = cores.tinta,
            modifier = Modifier.semantics { if (copiado) liveRegion = LiveRegionMode.Polite },
        )
    }
}
