package br.com.frila.feature.entrada.cadastro

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.mascara.CpfVisualTransformation
import br.com.frila.core.designsystem.mascara.TelefoneVisualTransformation
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.dominio.modelo.DataCivil

@Composable
fun TelaCadastro(
    viewModel: CadastroViewModel,
    aoConcluir: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val erroNome = estado.erro?.takeIf { it == "Informe seu nome." }
    val erroCpf = estado.erro?.takeIf { it == "Informe seu CPF." || it == MENSAGEM_CPF_INVALIDO }
    val erroTelefone = estado.erro?.takeIf { it == "Informe seu telefone." || it == MENSAGEM_TELEFONE_INVALIDO }
    val erroNascimento = estado.erro?.takeIf {
        it == "Informe sua data de nascimento." || it == MENSAGEM_MENOR_DE_IDADE
    }
    val erroTermos = estado.erro?.takeIf { it == "Você precisa aceitar os termos para continuar." }

    LaunchedEffect(estado.concluido) {
        if (estado.concluido) {
            aoConcluir()
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(FrilaEspacamento.grande),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(
            text = "Complete seu cadastro",
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.semantics { heading() },
        )

        OutlinedTextField(
            value = estado.nome,
            onValueChange = viewModel::aoMudarNome,
            label = { Text("Nome completo") },
            singleLine = true,
            isError = erroNome != null,
            modifier = Modifier
                .fillMaxWidth()
                .semantics { erroNome?.let { error(it) } },
        )

        OutlinedTextField(
            value = estado.cpf,
            onValueChange = viewModel::aoMudarCpf,
            label = { Text("CPF") },
            placeholder = { Text("000.000.000-00") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            visualTransformation = remember { CpfVisualTransformation() },
            isError = erroCpf != null,
            modifier = Modifier
                .fillMaxWidth()
                .semantics { erroCpf?.let { error(it) } },
        )

        if (erroCpf != null) {
            Text(
                text = erroCpf,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }

        OutlinedTextField(
            value = estado.telefone,
            onValueChange = viewModel::aoMudarTelefone,
            label = { Text("Telefone com DDD") },
            placeholder = { Text("(00) 00000-0000") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            visualTransformation = remember { TelefoneVisualTransformation() },
            isError = erroTelefone != null,
            modifier = Modifier
                .fillMaxWidth()
                .semantics { erroTelefone?.let { error(it) } },
        )

        if (erroTelefone != null) {
            Text(
                text = erroTelefone,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }

        CampoDeNascimento(
            nascimento = estado.nascimento,
            aoMudar = viewModel::aoMudarNascimento,
            mensagemErro = erroNascimento,
        )

        if (estado.nascimento != null && !estado.nascimentoValido) {
            Text(
                text = MENSAGEM_MENOR_DE_IDADE,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .sizeIn(
                    minWidth = FrilaMetricas.alvoMinimo,
                    minHeight = FrilaMetricas.alvoMinimo,
                )
                .toggleable(
                    value = estado.aceitouTermos,
                    role = Role.Checkbox,
                    onValueChange = viewModel::aoMudarAceiteDeTermos,
                )
                .semantics {
                    stateDescription = if (estado.aceitouTermos) "selecionado" else "não selecionado"
                    erroTermos?.let { error(it) }
                },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Checkbox(
                checked = estado.aceitouTermos,
                onCheckedChange = null,
                modifier = Modifier.clearAndSetSemantics { },
            )
            Text(text = "Li e aceito os termos de uso e a política de privacidade.")
        }

        val erroGenerico = estado.erro?.takeUnless {
            it == MENSAGEM_MENOR_DE_IDADE || it == erroCpf || it == erroTelefone
        }
        if (erroGenerico != null) {
            Text(
                text = erroGenerico,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }

        val podeSubmeter = estado.nascimentoValido && estado.cpfValido && estado.telefoneValido
        BotaoPrimario(
            texto = "Concluir cadastro",
            aoClicar = viewModel::concluirCadastro,
            habilitado = podeSubmeter,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun CampoDeNascimento(
    nascimento: DataCivil?,
    aoMudar: (DataCivil) -> Unit,
    mensagemErro: String?,
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
        placeholder = { Text("dd/mm/aaaa") },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        isError = mensagemErro != null,
        modifier = Modifier
            .fillMaxWidth()
            .semantics { mensagemErro?.let { error(it) } },
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
