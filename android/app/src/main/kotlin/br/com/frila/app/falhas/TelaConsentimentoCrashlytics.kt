// TELA PROVISÓRIA (sistema do Fabrício): ele revê depois
package br.com.frila.app.falhas

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

object TextosConsentimentoCrashlytics {
    const val TITULO = "Ajudar a corrigir falhas do app?"
    const val PARAGRAFO_1 = "Se o app travar, podemos enviar um relatório técnico ao Google (Firebase Crashlytics) para o Frila achar e consertar o erro. O relatório mostra o que o app estava fazendo na hora do travamento, o modelo e a versão do Android do seu aparelho e um código da instalação do app."
    const val ROTULO_NAO_LEVA = "Não leva "
    const val CORPO_NAO_LEVA = "seu nome, e-mail, telefone, documento, localização nem o que você escreveu no app."
    const val ROTULO_EXTERIOR = "Envio para fora do Brasil: "
    const val CORPO_EXTERIOR = "o Google guarda o relatório por 90 dias e pode processá-lo nos Estados Unidos e em outros países, onde a proteção de dados pode não ser igual à do Brasil."
    const val PARAGRAFO_OPCIONAL = "É opcional: se você disser não, o app funciona do mesmo jeito. Você pode mudar de ideia quando quiser, em Configurações. Ao tocar em \"Permitir envio\", você concorda especificamente com esse envio ao exterior."
    const val BOTAO_PERMITIR = "Permitir envio"
    const val BOTAO_RECUSAR = "Agora não"
}

/**
 * Tela de consentimento específico e em destaque para coleta e envio de relatórios de falha ao exterior (LGPD art. 33, VIII).
 * Parecer P-059 / Pedido 19-05. Sistema visual do Fabrício com componentes e tokens nativos do design system Frila.
 */
@Composable
fun TelaConsentimentoCrashlytics(
    aoPermitir: () -> Unit,
    aoRecusar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val estadoRolagem = rememberScrollState()

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.superficie,
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(estadoRolagem)
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            TituloDaTela(
                texto = TextosConsentimentoCrashlytics.TITULO,
                modifier = Modifier.semantics { heading() },
            )

            Text(
                text = TextosConsentimentoCrashlytics.PARAGRAFO_1,
                style = FrilaTipo.corpo,
                color = cores.tinta,
            )

            val textoNaoLeva = buildAnnotatedString {
                withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
                    append(TextosConsentimentoCrashlytics.ROTULO_NAO_LEVA)
                }
                append(TextosConsentimentoCrashlytics.CORPO_NAO_LEVA)
            }
            Text(
                text = textoNaoLeva,
                style = FrilaTipo.corpo,
                color = cores.tinta,
            )

            val textoExterior = buildAnnotatedString {
                withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
                    append(TextosConsentimentoCrashlytics.ROTULO_EXTERIOR)
                }
                append(TextosConsentimentoCrashlytics.CORPO_EXTERIOR)
            }
            Text(
                text = textoExterior,
                style = FrilaTipo.corpo,
                color = cores.tinta,
            )

            Text(
                text = TextosConsentimentoCrashlytics.PARAGRAFO_OPCIONAL,
                style = FrilaTipo.corpo,
                color = cores.tintaSuave,
            )

            Spacer(modifier = Modifier.height(FrilaEspacamento.item))

            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                // Dois botões de peso IGUAL (BotaoSecundario com fillMaxWidth) para garantir escolha livre e sem indução (Parecer P-059 §3.2)
                BotaoSecundario(
                    texto = TextosConsentimentoCrashlytics.BOTAO_PERMITIR,
                    aoClicar = aoPermitir,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("botao-permitir-envio"),
                )
                BotaoSecundario(
                    texto = TextosConsentimentoCrashlytics.BOTAO_RECUSAR,
                    aoClicar = aoRecusar,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("botao-recusar-envio"),
                )
            }
        }
    }
}
