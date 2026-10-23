package br.com.frila.feature.turnos

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.dominio.modelo.MotivoCancelamento

/** Estados do turno em que o check-in ainda pode ser feito (RF13). */
private const val ESTADO_CHECKIN_DISPONIVEL = "confirmada"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaMeusTurnos(
    viewModel: MeusTurnosViewModel,
    criarCheckinViewModel: @Composable (turnoId: String) -> CheckinViewModel,
    modifier: Modifier = Modifier,
    aoAbrirAvaliacao: (turnoId: String) -> Unit = {},
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(estado.mensagemFeedback) {
        estado.mensagemFeedback?.let {
            snackbar.showSnackbar(it)
            viewModel.consumirFeedback()
        }
    }

    Scaffold(
        modifier = modifier,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Meus Turnos", modifier = Modifier.semantics { heading() }) },
            )
        },
    ) { paddingInterno ->
        Column(modifier = Modifier.fillMaxSize().padding(paddingInterno)) {
            TabRow(selectedTabIndex = estado.abaSelecionada.ordinal) {
                Tab(
                    selected = estado.abaSelecionada == AbaDeTurnos.AGENDADOS,
                    onClick = { viewModel.aoSelecionarAba(AbaDeTurnos.AGENDADOS) },
                    text = { Text("Agendados") },
                    modifier = Modifier
                        .sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        )
                        .semantics {
                            stateDescription = if (estado.abaSelecionada == AbaDeTurnos.AGENDADOS) {
                                "selecionado"
                            } else {
                                "não selecionado"
                            }
                        },
                )
                Tab(
                    selected = estado.abaSelecionada == AbaDeTurnos.HISTORICO,
                    onClick = { viewModel.aoSelecionarAba(AbaDeTurnos.HISTORICO) },
                    text = { Text("Histórico") },
                    modifier = Modifier
                        .sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        )
                        .semantics {
                            stateDescription = if (estado.abaSelecionada == AbaDeTurnos.HISTORICO) {
                                "selecionado"
                            } else {
                                "não selecionado"
                            }
                        },
                )
            }

            when (estado.status) {
                StatusMeusTurnos.CARREGANDO -> Carregando()
                StatusMeusTurnos.ERRO -> Erro(mensagem = estado.mensagemErro, aoTentarNovamente = viewModel::tentarNovamente)
                StatusMeusTurnos.VAZIO -> Vazio()
                StatusMeusTurnos.SUCESSO -> ListaDeTurnos(
                    itens = estado.itensDaAbaAtual,
                    criarCheckinViewModel = criarCheckinViewModel,
                    aoAbrirAvaliacao = aoAbrirAvaliacao,
                    aoCancelar = viewModel::abrirCancelamento,
                )
            }
        }
    }

    estado.cancelamento?.let { cancelamento ->
        DialogoCancelamentoTurno(
            estado = cancelamento,
            aoSelecionarMotivo = viewModel::selecionarMotivo,
            aoAtualizarDetalhes = viewModel::atualizarDetalhes,
            aoConfirmar = { viewModel.confirmarCancelamento() },
            aoVoltar = viewModel::fecharCancelamento,
        )
    }
}

@Composable
private fun ListaDeTurnos(
    itens: List<ItemTurno>,
    criarCheckinViewModel: @Composable (turnoId: String) -> CheckinViewModel,
    aoAbrirAvaliacao: (turnoId: String) -> Unit,
    aoCancelar: (ItemTurno) -> Unit,
) {
    if (itens.isEmpty()) {
        Vazio()
        return
    }

    LazyColumn(
        contentPadding = PaddingValues(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
    ) {
        items(itens, key = { it.turnoId }) { turno ->
            CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = turno.funcaoNome,
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.semantics { heading() },
                )
                Text(text = turno.estabelecimentoNome, style = MaterialTheme.typography.bodyMedium)
                Text(text = turno.dataHorarioFormatado, style = MaterialTheme.typography.bodySmall)
                Column(
                    modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
                ) {
                    Text(text = turno.valorFormatado, style = MaterialTheme.typography.bodySmall)
                    BadgeDeStatus(estado = turno.estado)
                }
                if (turno.estado == ESTADO_CHECKIN_DISPONIVEL) {
                    SecaoDeCheckin(turnoId = turno.turnoId, criarCheckinViewModel = criarCheckinViewModel)
                    BotaoSecundario(
                        texto = "Cancelar turno",
                        aoClicar = { aoCancelar(turno) },
                        modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                    )
                }
                SecaoDeAvaliacao(turno = turno, aoAbrirAvaliacao = aoAbrirAvaliacao)
            }
        }
    }
}

/** Diálogo RN12: explica o efeito antes do envio e exige um motivo válido. */
@Composable
fun DialogoCancelamentoTurno(
    estado: EstadoCancelamentoTurno,
    aoSelecionarMotivo: (MotivoCancelamento) -> Unit,
    aoAtualizarDetalhes: (String) -> Unit,
    aoConfirmar: () -> Unit,
    aoVoltar: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = { if (!estado.enviando) aoVoltar() },
        title = {
            Text("Cancelar turno", modifier = Modifier.semantics { heading() })
        },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
            ) {
                Text(
                    text = if (estado.contaComoFalta) {
                        "Faltam menos de 24 horas. Este cancelamento conta como falta e pode afetar sua reputação."
                    } else {
                        "Este cancelamento não conta como falta nem afeta sua reputação."
                    },
                    color = if (estado.contaComoFalta) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = "Qual é o motivo?",
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.semantics { heading() },
                )
                Column(modifier = Modifier.selectableGroup()) {
                    MotivoCancelamento.entries.forEach { motivo ->
                        val selecionado = estado.motivoSelecionado == motivo
                        androidx.compose.foundation.layout.Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .sizeIn(minWidth = 48.dp, minHeight = 48.dp)
                                .selectable(
                                    selected = selecionado,
                                    role = Role.RadioButton,
                                    onClick = { aoSelecionarMotivo(motivo) },
                                )
                                .semantics {
                                    stateDescription = if (selecionado) "selecionado" else "não selecionado"
                                },
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RadioButton(selected = selecionado, onClick = null)
                            Text(text = motivo.descricao, modifier = Modifier.padding(start = FrilaEspacamento.pequeno))
                        }
                    }
                }
                if (estado.motivoSelecionado?.exigeDetalhes == true) {
                    OutlinedTextField(
                        value = estado.detalhes,
                        onValueChange = aoAtualizarDetalhes,
                        label = { Text("Descreva o motivo") },
                        supportingText = { Text("Pelo menos 3 caracteres") },
                        modifier = Modifier.fillMaxWidth().sizeIn(minHeight = FrilaMetricas.alvoMinimo),
                        minLines = 2,
                    )
                }
                estado.mensagemErro?.let { mensagem ->
                    Text(
                        text = mensagem,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.semantics { error(mensagem) },
                    )
                }
            }
        },
        confirmButton = {
            BotaoPrimario(
                texto = if (estado.enviando) "Cancelando…" else "Confirmar cancelamento",
                aoClicar = aoConfirmar,
                habilitado = estado.podeConfirmar,
            )
        },
        dismissButton = {
            BotaoSecundario(
                texto = "Voltar",
                aoClicar = aoVoltar,
                habilitado = !estado.enviando,
            )
        },
    )
}

/** RF15/RN11: avaliação binária de turno cumprido. Um voto por lado, sem nota, sem repetição. */
@Composable
private fun SecaoDeAvaliacao(turno: ItemTurno, aoAbrirAvaliacao: (turnoId: String) -> Unit) {
    val resposta = turno.avaliacaoResposta
    when {
        resposta != null -> Text(
            text = if (resposta) "Você recomendou este local" else "Você não recomendou este local",
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
        )
        turno.podeAvaliar -> BotaoSecundario(
            texto = "Avaliar turno",
            aoClicar = { aoAbrirAvaliacao(turno.turnoId) },
            modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
        )
    }
}

@Composable
private fun SecaoDeCheckin(turnoId: String, criarCheckinViewModel: @Composable (turnoId: String) -> CheckinViewModel) {
    val viewModel = criarCheckinViewModel(turnoId)
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    Column(
        modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
    ) {
        when (estado.status) {
            StatusCheckin.OCIOSO -> BotaoSecundario(texto = "Fazer check-in", aoClicar = { viewModel.fazerCheckin() })
            StatusCheckin.REGISTRANDO -> Text("Registrando check-in…", style = MaterialTheme.typography.bodySmall)
            StatusCheckin.VERIFICADO -> Text("Check-in verificado", style = MaterialTheme.typography.bodySmall)
            StatusCheckin.MANUAL_PENDENTE -> Text(
                "Check-in manual, aguardando confirmação do contratante",
                style = MaterialTheme.typography.bodySmall,
            )
            StatusCheckin.ERRO -> Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
                Text(
                    text = estado.mensagemErro ?: "Não foi possível registrar o check-in.",
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.semantics {
                        error(estado.mensagemErro ?: "Não foi possível registrar o check-in.")
                    },
                )
                BotaoSecundario(texto = "Tentar novamente", aoClicar = { viewModel.fazerCheckin() })
            }
        }
    }
}

@Composable
private fun BadgeDeStatus(estado: String) {
    val rotulo = rotuloDeEstado(estado)
    Surface(
        modifier = Modifier.semantics(mergeDescendants = true) {
            contentDescription = "Status: $rotulo"
        },
        shape = MaterialTheme.shapes.small,
        color = MaterialTheme.colorScheme.surfaceVariant,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Text(
            text = rotulo,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(
                horizontal = FrilaEspacamento.pequeno,
                vertical = FrilaEspacamento.minimo,
            ),
        )
    }
}

private fun rotuloDeEstado(estado: String): String = when (estado) {
    "confirmada" -> "Confirmado"
    "cumprida" -> "Cumprido"
    "cancelada" -> "Cancelado"
    else -> estado
}

@Composable
private fun Carregando() {
    Box(
        modifier = Modifier.fillMaxSize().heightIn(FrilaMetricas.alvoMinimo),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun Vazio() {
    Box(
        modifier = Modifier.fillMaxSize().padding(FrilaEspacamento.grande),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Você ainda não tem turnos nesta aba.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun Erro(mensagem: String?, aoTentarNovamente: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        Text(
            text = mensagem ?: "Não foi possível carregar seus turnos.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { error(mensagem ?: "Não foi possível carregar seus turnos.") },
        )
        BotaoSecundario(texto = "Tentar novamente", aoClicar = aoTentarNovamente)
    }
}
