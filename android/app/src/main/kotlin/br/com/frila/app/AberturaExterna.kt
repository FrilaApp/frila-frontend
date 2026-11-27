package br.com.frila.app

import android.content.ClipData
import android.content.Context
import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.Saver
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ClipEntry
import androidx.compose.ui.platform.LocalClipboard
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import kotlinx.coroutines.launch

/**
 * Abre [intent] em outro app (e-mail, discador, navegador). Devolve `false` quando o aparelho não tem quem o trate
 * (`ActivityNotFoundException`) ou o sistema recusa: quem chama avisa a pessoa, nunca engole a falha em silêncio.
 */
fun abrirExterno(contexto: Context, intent: Intent): Boolean = try {
    contexto.startActivity(intent)
    true
} catch (_: Exception) {
    false
}

/** O que a pessoa lê quando nenhum app abriu, e o endereço ou número que ela pode copiar para seguir por outro caminho. */
data class AvisoDeAberturaExterna(val mensagem: String, val paraCopiar: String? = null) {
    companion object {
        fun semEmail(email: String) =
            AvisoDeAberturaExterna("Não encontramos um app de e-mail neste aparelho. Escreva para este endereço pelo app que você usa:", email)

        fun semTelefone(numero: String) =
            AvisoDeAberturaExterna("Não encontramos um app de telefone neste aparelho. Ligue para este número:", numero)

        fun semNavegador(url: String) =
            AvisoDeAberturaExterna("Não encontramos um navegador neste aparelho. Abra este endereço em outro navegador ou aparelho:", url)

        /** O endereço do login social é de uso único (PKCE): copiá-lo não ajuda, então o aviso só explica. */
        val semNavegadorParaEntrar = AvisoDeAberturaExterna(
            "Não encontramos um navegador neste aparelho para entrar com o Google ou a Apple. " +
                "Ative ou instale um navegador e tente de novo, ou entre com e-mail e senha.",
        )

        /** Sobrevive à rotação e à morte do processo com o diálogo aberto. */
        val Salvador: Saver<AvisoDeAberturaExterna?, Any> = Saver(
            save = { aviso -> aviso?.let { arrayListOf(it.mensagem, it.paraCopiar) } },
            restore = { salvo ->
                @Suppress("UNCHECKED_CAST")
                val campos = salvo as List<String?>
                AvisoDeAberturaExterna(campos[0].orEmpty(), campos[1])
            },
        )
    }
}

internal object TextosAberturaExterna {
    const val TITULO = "Não deu para abrir"
    const val COPIAR = "Copiar"
    const val FECHAR = "Fechar"
    const val ENTENDI = "Entendi"
}

/** Diálogo do aviso, no mesmo desenho do `DialogoDeConfirmacao` do suporte: superfície com raio de cartão, sem cor de erro. */
@Composable
fun DialogoDeAberturaExterna(aviso: AvisoDeAberturaExterna, aoFechar: () -> Unit) {
    val cores = FrilaTema.cores
    val areaDeTransferencia = LocalClipboard.current
    val escopo = rememberCoroutineScope()
    AlertDialog(
        onDismissRequest = aoFechar,
        modifier = Modifier.testTag("aviso-abertura-externa"),
        containerColor = cores.superficie,
        shape = RoundedCornerShape(FrilaRaios.cartao),
        title = {
            Text(
                text = TextosAberturaExterna.TITULO,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                Text(text = aviso.mensagem, style = FrilaTipo.corpo, color = cores.tinta)
                aviso.paraCopiar?.let { endereco ->
                    SelectionContainer {
                        Text(
                            text = endereco,
                            style = FrilaTipo.corpo,
                            color = cores.tinta,
                            modifier = Modifier.testTag("aviso-abertura-externa-endereco"),
                        )
                    }
                }
            }
        },
        confirmButton = {
            val endereco = aviso.paraCopiar
            if (endereco == null) {
                BotaoSecundario(texto = TextosAberturaExterna.ENTENDI, aoClicar = aoFechar)
            } else {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
                ) {
                    AcaoDiscreta(texto = TextosAberturaExterna.FECHAR, aoClicar = aoFechar)
                    BotaoSecundario(
                        texto = TextosAberturaExterna.COPIAR,
                        aoClicar = {
                            escopo.launch {
                                areaDeTransferencia.setClipEntry(ClipEntry(ClipData.newPlainText(endereco, endereco)))
                                aoFechar()
                            }
                        },
                    )
                }
            }
        },
    )
}
