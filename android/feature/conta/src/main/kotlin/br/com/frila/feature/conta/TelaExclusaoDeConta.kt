package br.com.frila.feature.conta

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

/** Liga o [ExclusaoDeContaViewModel] ao [ConteudoExclusaoDeConta]. */
@Composable
fun TelaExclusaoDeConta(
    viewModel: ExclusaoDeContaViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    ConteudoExclusaoDeConta(
        estado = estado,
        aoAlterarConfirmacao = viewModel::alterarConfirmacao,
        aoExcluir = { viewModel.confirmarExclusao() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

/**
 * Exclusão de conta em tela cheia (RF25/UC16, paridade com `TelaExclusaoDeConta.swift`): o que
 * acontece, a caixa de confirmação e um diálogo final antes do pedido. O botão só habilita depois
 * da caixa marcada. Prazo de até 15 dias para as cópias de backup (contrato `ExclusaoDeConta`).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoExclusaoDeConta(
    estado: EstadoExclusaoDeConta,
    aoAlterarConfirmacao: (Boolean) -> Unit,
    aoExcluir: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var dialogoAberto by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosExclusaoDeConta.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        enabled = !estado.excluindo,
                        modifier = Modifier.sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosExclusaoDeConta.ROTULO_VOLTAR,
                        )
                    }
                },
            )
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            val resultado = estado.resultado
            if (resultado != null) {
                Text(
                    text = TextosExclusaoDeConta.CONCLUIDA_TITULO,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.semantics {
                        heading()
                        liveRegion = LiveRegionMode.Polite
                    },
                )
                Text(
                    text = TextosExclusaoDeConta.concluidaResumo(
                        turnosCancelados = resultado.turnosCancelados,
                        dadosApagadosAte = resultado.dadosApagadosAte,
                    ),
                    style = MaterialTheme.typography.bodyMedium,
                )
                return@Column
            }

            Text(
                text = TextosExclusaoDeConta.AVISO,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.error,
            )
            Text(
                text = TextosExclusaoDeConta.SECAO_O_QUE_ACONTECE,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                Consequencia(TextosExclusaoDeConta.CONSEQUENCIA_ANONIMIZACAO)
                Consequencia(TextosExclusaoDeConta.CONSEQUENCIA_TURNOS)
                Consequencia(TextosExclusaoDeConta.CONSEQUENCIA_PRAZO)
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                    .toggleable(
                        value = estado.confirmouConsequencias,
                        enabled = !estado.excluindo,
                        role = Role.Checkbox,
                        onValueChange = aoAlterarConfirmacao,
                    ),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
            ) {
                // O clique é do Row (toggleable): a caixa só reflete o estado.
                Checkbox(checked = estado.confirmouConsequencias, onCheckedChange = null)
                Text(
                    text = TextosExclusaoDeConta.CONFIRMACAO_CHECK,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            estado.mensagemErro?.let { mensagem ->
                Text(
                    text = mensagem,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                )
            }

            BotaoPrimario(
                texto = if (estado.excluindo) TextosExclusaoDeConta.EXCLUINDO else TextosExclusaoDeConta.BOTAO_EXCLUIR,
                aoClicar = { dialogoAberto = true },
                habilitado = estado.podeExcluir,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }

    if (dialogoAberto && estado.podeExcluir) {
        AlertDialog(
            onDismissRequest = { dialogoAberto = false },
            title = {
                Text(
                    text = TextosExclusaoDeConta.DIALOGO_TITULO,
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = { Text(text = TextosExclusaoDeConta.DIALOGO_MENSAGEM) },
            confirmButton = {
                TextButton(
                    onClick = {
                        dialogoAberto = false
                        aoExcluir()
                    },
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) {
                    Text(TextosExclusaoDeConta.DIALOGO_CONFIRMAR, color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { dialogoAberto = false },
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) { Text(TextosExclusaoDeConta.CANCELAR) }
            },
        )
    }
}

@Composable
private fun Consequencia(texto: String) {
    Text(
        text = "• $texto",
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurface,
    )
}
