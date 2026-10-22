package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

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

    Scaffold(
        modifier = modifier,
        topBar = { CenterAlignedTopAppBar(title = { Text("Meus Turnos") }) },
    ) { paddingInterno ->
        Column(modifier = Modifier.fillMaxSize().padding(paddingInterno)) {
            TabRow(selectedTabIndex = estado.abaSelecionada.ordinal) {
                Tab(
                    selected = estado.abaSelecionada == AbaDeTurnos.AGENDADOS,
                    onClick = { viewModel.aoSelecionarAba(AbaDeTurnos.AGENDADOS) },
                    text = { Text("Agendados") },
                )
                Tab(
                    selected = estado.abaSelecionada == AbaDeTurnos.HISTORICO,
                    onClick = { viewModel.aoSelecionarAba(AbaDeTurnos.HISTORICO) },
                    text = { Text("Histórico") },
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
                )
            }
        }
    }
}

@Composable
private fun ListaDeTurnos(
    itens: List<ItemTurno>,
    criarCheckinViewModel: @Composable (turnoId: String) -> CheckinViewModel,
    aoAbrirAvaliacao: (turnoId: String) -> Unit,
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
                Text(text = turno.funcaoNome, style = MaterialTheme.typography.titleSmall)
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
                }
                SecaoDeAvaliacao(turno = turno, aoAbrirAvaliacao = aoAbrirAvaliacao)
            }
        }
    }
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
                )
                BotaoSecundario(texto = "Tentar novamente", aoClicar = { viewModel.fazerCheckin() })
            }
        }
    }
}

@Composable
private fun BadgeDeStatus(estado: String) {
    SuggestionChip(
        onClick = {},
        label = { Text(rotuloDeEstado(estado), style = MaterialTheme.typography.bodySmall) },
    )
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
        )
        BotaoSecundario(texto = "Tentar novamente", aoClicar = aoTentarNovamente)
    }
}
