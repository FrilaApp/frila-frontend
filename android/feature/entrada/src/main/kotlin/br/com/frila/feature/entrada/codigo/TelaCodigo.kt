package br.com.frila.feature.entrada.codigo

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento

@Composable
fun TelaCodigo(
    viewModel: CodigoViewModel,
    aoAutenticar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    LaunchedEffect(estado.autenticado) {
        if (estado.autenticado) {
            aoAutenticar()
        }
    }

    // O campo já abre com foco e teclado, como no iOS: quem chega aqui só tem de digitar o código.
    val focoDoCodigo = remember { FocusRequester() }
    LaunchedEffect(Unit) { focoDoCodigo.requestFocus() }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(
            text = "Confirme seu código",
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.semantics { heading() },
        )
        Text(
            text = "Enviamos um código de 6 dígitos para ${estado.email}.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        OutlinedTextField(
            value = estado.codigo,
            onValueChange = { viewModel.aoMudarCodigo(it) },
            label = { Text("Código de 6 dígitos") },
            singleLine = true,
            isError = estado.erro != null,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
            modifier = Modifier
                .fillMaxWidth()
                .focusRequester(focoDoCodigo)
                .semantics {
                    estado.erro?.let { error(it) }
                },
        )

        if (estado.reenviado) {
            Text(
                text = "Código reenviado.",
                color = MaterialTheme.colorScheme.tertiary,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }

        estado.erro?.let { mensagem ->
            Text(
                text = mensagem,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }

        BotaoPrimario(
            texto = if (estado.carregando) "Confirmando…" else "Confirmar código",
            aoClicar = viewModel::confirmarCodigo,
            habilitado = !estado.carregando,
            modifier = Modifier.fillMaxWidth(),
        )

        BotaoSecundario(
            texto = "Reenviar código",
            aoClicar = viewModel::reenviarCodigo,
            habilitado = !estado.carregando,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
