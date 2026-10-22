package br.com.frila.feature.entrada.entrada

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.rede.DemonstracaoContas

@Composable
fun TelaEntrada(
    viewModel: EntradaViewModel,
    aoReceberCodigo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    LaunchedEffect(estado.otpSolicitado) {
        if (estado.otpSolicitado) {
            aoReceberCodigo()
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        LogoFrila()

        Text(
            text = "Bem-vindo ao Frila",
            style = MaterialTheme.typography.titleLarge,
        )
        Text(
            text = "Entre com seu e-mail para receber o código de acesso.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        OutlinedTextField(
            value = estado.email,
            onValueChange = viewModel::aoMudarEmail,
            label = { Text("E-mail") },
            singleLine = true,
            isError = estado.erro != null,
            modifier = Modifier.fillMaxWidth(),
        )

        estado.erro?.let { mensagem ->
            Text(
                text = mensagem,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
            )
        }

        BotaoPrimario(
            texto = if (estado.carregando) "Enviando…" else "Receber código",
            aoClicar = viewModel::solicitarCodigo,
            habilitado = !estado.carregando,
            modifier = Modifier.fillMaxWidth(),
        )

        BotaoSecundario(
            texto = "Entrar em modo demonstração",
            aoClicar = {
                viewModel.aoMudarEmail(DemonstracaoContas.EMAIL_PROFISSIONAL)
                viewModel.solicitarCodigo()
            },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun LogoFrila() {
    Column(
        modifier = Modifier
            .size(64.dp)
            .background(MaterialTheme.colorScheme.primary, shape = RoundedCornerShape(FrilaRaios.grande)),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "F",
            color = MaterialTheme.colorScheme.onPrimary,
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}
