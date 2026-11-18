package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Textos do consentimento. Mudou o conteúdo aqui? Mude [TermoBiometria.VERSAO]. */
internal object TextosConsentimentoSelo {
    const val TITULO = "Consentimento para o selo"
    const val ROTULO_VOLTAR = "Voltar"
    const val CABECALHO = "Antes de enviar seus documentos"
    const val FINALIDADE =
        "Para ganhar o selo \"Identidade Verificada\", você envia a foto do seu documento (RG ou CNH) e uma selfie. " +
            "A selfie é um dado biométrico facial, considerado dado pessoal sensível pela LGPD."
    const val USO =
        "As imagens são usadas só para conferir que você é a pessoa do documento. A análise é feita pela " +
            "moderação do Frila, por pessoas. Não há decisão automática sobre a sua conta."
    const val ARMAZENAMENTO =
        "As imagens vão para um armazenamento privado. O aplicativo só envia, e apenas a moderação consegue ler."
    const val VOLUNTARIO =
        "O selo é voluntário. Você pode usar o Frila sem ele e pode desistir antes de enviar."
    const val REVOGACAO =
        "Você pode revogar este consentimento a qualquer momento, de forma gratuita e facilitada " +
            "(LGPD, art. 8º, § 5º). Para revogar, escreva para o suporte oficial do Frila."
    const val CONTATO_ROTULO = "Contato do suporte"
    const val CHECKBOX =
        "Li e concordo em fornecer minha selfie e meu documento para verificar minha identidade, " +
            "para esta finalidade."
    const val BOTAO = "Concordar e continuar"
    const val RODAPE_VERSAO = "Versão do termo"
}

/**
 * Consentimento específico e destacado para tratar biometria facial (LGPD art. 11, I; RN15). É a
 * porta do envio: sem marcar a caixa e confirmar, nada da verificação segue. O checkbox nasce
 * desmarcado e o botão só habilita depois dele.
 *
 * No desenho do Fabrício: leitura em texto corrido sobre o fundo, o aceite num cartão que é um alvo só e o
 * "Concordar e continuar" (único primário) no rodapé ancorado.
 */
@Composable
fun TelaConsentimentoSelo(
    aoConfirmar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    versaoTermo: String = TermoBiometria.VERSAO,
    emailSuporte: String = EnderecosOficiais.padrao.emailSuporte,
) {
    var marcado by rememberSaveable { mutableStateOf(false) }
    val cores = FrilaTema.cores

    Scaffold(
        modifier = modifier,
        containerColor = cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar, modifier = Modifier.testTag("consentimento-voltar")) },
        bottomBar = {
            RodapeAncorado {
                BotaoPrimario(
                    texto = TextosConsentimentoSelo.BOTAO,
                    aoClicar = aoConfirmar,
                    habilitado = marcado,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("consentimento-confirmar"),
                )
            }
        },
    ) { paddingInterno ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            TituloDaTela(TextosConsentimentoSelo.TITULO)
            Text(
                text = TextosConsentimentoSelo.CABECALHO,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
            Text(TextosConsentimentoSelo.FINALIDADE, style = FrilaTipo.corpo, color = cores.tinta)
            Text(TextosConsentimentoSelo.USO, style = FrilaTipo.corpo, color = cores.tinta)
            Text(TextosConsentimentoSelo.ARMAZENAMENTO, style = FrilaTipo.corpo, color = cores.tinta)
            Text(TextosConsentimentoSelo.VOLUNTARIO, style = FrilaTipo.corpo, color = cores.tinta)
            Text(
                text = TextosConsentimentoSelo.REVOGACAO,
                style = FrilaTipo.corpo,
                color = cores.tinta,
                modifier = Modifier.testTag("consentimento-revogacao"),
            )
            Text(
                text = "${TextosConsentimentoSelo.CONTATO_ROTULO}: $emailSuporte",
                style = FrilaTipo.corpo,
                color = cores.tinta,
                modifier = Modifier.testTag("consentimento-contato-suporte"),
            )

            // O cartão inteiro é o controle; o Checkbox é só o desenho (evita foco duplicado).
            CartaoFrila(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(FrilaRaios.cartao))
                    .toggleable(
                        value = marcado,
                        role = Role.Checkbox,
                        onValueChange = { marcado = it },
                    )
                    .testTag("consentimento-checkbox"),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = FrilaMetricas.alvoMinimo),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                ) {
                    Checkbox(
                        checked = marcado,
                        onCheckedChange = null,
                        modifier = Modifier.clearAndSetSemantics { },
                    )
                    Text(
                        text = TextosConsentimentoSelo.CHECKBOX,
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                        modifier = Modifier.weight(1f),
                    )
                }
            }

            Text(
                text = "${TextosConsentimentoSelo.RODAPE_VERSAO}: $versaoTermo",
                style = FrilaTipo.legenda,
                color = cores.tintaSuave,
            )
        }
    }
}
