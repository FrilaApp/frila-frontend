package br.com.frila.feature.entrada.cadastro

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.dominio.modelo.DataCivil

@Composable
fun TelaCadastro(
    viewModel: CadastroViewModel,
    aoConcluir: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    LaunchedEffect(estado.concluido) {
        if (estado.concluido) {
            aoConcluir()
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(FrilaEspacamento.grande),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(text = "Complete seu cadastro", style = MaterialTheme.typography.titleLarge)

        OutlinedTextField(
            value = estado.nome,
            onValueChange = viewModel::aoMudarNome,
            label = { Text("Nome completo") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )

        OutlinedTextField(
            value = estado.telefone,
            onValueChange = viewModel::aoMudarTelefone,
            label = { Text("Telefone") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )

        CampoDeNascimento(
            nascimento = estado.nascimento,
            aoMudar = viewModel::aoMudarNascimento,
        )

        if (estado.nascimento != null && !estado.nascimentoValido) {
            Text(
                text = MENSAGEM_MENOR_DE_IDADE,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
            )
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(
                checked = estado.aceitouTermos,
                onCheckedChange = viewModel::aoMudarAceiteDeTermos,
            )
            Text(text = "Li e aceito os termos de uso e a política de privacidade.")
        }

        estado.erro?.let { mensagem ->
            Text(
                text = mensagem,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
            )
        }

        BotaoPrimario(
            texto = "Concluir cadastro",
            aoClicar = viewModel::concluirCadastro,
            // RN20 bloqueia visualmente antes mesmo do clique: menor de idade nunca vê o botão habilitado.
            habilitado = estado.nascimentoValido,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun CampoDeNascimento(
    nascimento: DataCivil?,
    aoMudar: (DataCivil) -> Unit,
) {
    var texto by remember {
        mutableStateOf(
            nascimento?.let { "%02d/%02d/%04d".format(it.data.dayOfMonth, it.data.monthValue, it.data.year) } ?: "",
        )
    }

    OutlinedTextField(
        value = texto,
        onValueChange = { novoTexto ->
            texto = novoTexto
            parseDataBr(novoTexto)?.let(aoMudar)
        },
        label = { Text("Data de nascimento (dd/mm/aaaa)") },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
}

private fun parseDataBr(texto: String): DataCivil? {
    val partes = texto.split("/")
    if (partes.size != 3) return null
    val dia = partes[0].toIntOrNull() ?: return null
    val mes = partes[1].toIntOrNull() ?: return null
    val ano = partes[2].toIntOrNull() ?: return null
    return runCatching { DataCivil.de(ano, mes, dia) }.getOrNull()
}
