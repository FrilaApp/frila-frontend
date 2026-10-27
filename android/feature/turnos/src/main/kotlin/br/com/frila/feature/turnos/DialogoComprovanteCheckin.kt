package br.com.frila.feature.turnos

import android.content.Intent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.dominio.modelo.ComprovanteCheckin

/**
 * Diálogo do comprovante de presença com carimbo temporal e hash verificador (RN06/RN22).
 * Exibe horário exato, coordenadas aproximadas e código verificador.
 * Permite compartilhamento acessível nativo do Android.
 */
@Composable
fun DialogoComprovanteCheckin(
    comprovante: ComprovanteCheckin,
    aoFechar: () -> Unit,
    modifier: Modifier = Modifier,
    aoCompartilharPersonalizado: ((String) -> Unit)? = null,
) {
    val contexto = LocalContext.current

    val aoCompartilhar: () -> Unit = {
        val texto = comprovante.textoCompartilhamento()
        if (aoCompartilharPersonalizado != null) {
            aoCompartilharPersonalizado(texto)
        } else {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, "Comprovante de Check-in · Frila")
                putExtra(Intent.EXTRA_TEXT, texto)
            }
            contexto.startActivity(Intent.createChooser(intent, "Compartilhar comprovante"))
        }
    }

    AlertDialog(
        onDismissRequest = aoFechar,
        modifier = modifier,
        title = {
            Text(
                text = "Comprovante de presença",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
            ) {
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(FrilaRaios.medio),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Column(
                        modifier = Modifier.padding(FrilaEspacamento.compacto),
                        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
                    ) {
                        Text(
                            text = "Código verificador",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text = comprovante.codigoAutenticacao,
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.semantics {
                                contentDescription = "Código verificador: ${comprovante.codigoAutenticacao}"
                            },
                        )
                    }
                }

                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "Horário do registro",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = comprovante.horarioFormatado(),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }

                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = "Tipo de verificação",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = comprovante.tipoVerificacao.descricao,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }

                comprovante.coordenadasAproximadas?.let { coords ->
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            text = "Coordenadas aproximadas (LGPD)",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text = coords,
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.semantics {
                                contentDescription = "Coordenadas aproximadas: $coords"
                            },
                        )
                    }
                }
            }
        },
        confirmButton = {
            BotaoPrimario(
                texto = "Compartilhar comprovante",
                aoClicar = aoCompartilhar,
            )
        },
        dismissButton = {
            BotaoSecundario(
                texto = "Fechar",
                aoClicar = aoFechar,
            )
        },
    )
}
