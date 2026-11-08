package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

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
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaConsentimentoSelo(
    aoConfirmar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    versaoTermo: String = TermoBiometria.VERSAO,
    emailSuporte: String = EnderecosOficiais.padrao.emailSuporte,
) {
    var marcado by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        modifier = modifier,
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosConsentimentoSelo.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier
                            .sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo)
                            .testTag("consentimento-voltar"),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosConsentimentoSelo.ROTULO_VOLTAR,
                        )
                    }
                },
            )
        },
    ) { paddingInterno ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .verticalScroll(rememberScrollState())
                .padding(FrilaEspacamento.medio),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            Text(
                text = TextosConsentimentoSelo.CABECALHO,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
            Text(TextosConsentimentoSelo.FINALIDADE, style = MaterialTheme.typography.bodyMedium)
            Text(TextosConsentimentoSelo.USO, style = MaterialTheme.typography.bodyMedium)
            Text(TextosConsentimentoSelo.ARMAZENAMENTO, style = MaterialTheme.typography.bodyMedium)
            Text(TextosConsentimentoSelo.VOLUNTARIO, style = MaterialTheme.typography.bodyMedium)
            Text(
                text = TextosConsentimentoSelo.REVOGACAO,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.testTag("consentimento-revogacao"),
            )
            Text(
                text = "${TextosConsentimentoSelo.CONTATO_ROTULO}: $emailSuporte",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.testTag("consentimento-contato-suporte"),
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = FrilaMetricas.alvoMinimo)
                    .toggleable(
                        value = marcado,
                        role = Role.Checkbox,
                        onValueChange = { marcado = it },
                    )
                    .testTag("consentimento-checkbox"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
            ) {
                // A linha inteira é o controle; o Checkbox é só o desenho (evita foco duplicado).
                Checkbox(
                    checked = marcado,
                    onCheckedChange = null,
                    modifier = Modifier.clearAndSetSemantics { },
                )
                Text(
                    text = TextosConsentimentoSelo.CHECKBOX,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f),
                )
            }

            BotaoPrimario(
                texto = TextosConsentimentoSelo.BOTAO,
                aoClicar = aoConfirmar,
                habilitado = marcado,
                modifier = Modifier
                    .fillMaxWidth()
                    .testTag("consentimento-confirmar"),
            )
            Text(
                text = "${TextosConsentimentoSelo.RODAPE_VERSAO}: $versaoTermo",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 8.dp),
            )
        }
    }
}
