package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.rede.ChamadaResumoDto

/** Liga o [AcompanharChamadasViewModel] ao [ConteudoAcompanharChamadas]. */
@Composable
fun TelaAcompanharChamadas(
    viewModel: AcompanharChamadasViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoVerVagaPublicada: ((vagaId: String) -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoAcompanharChamadas(
        tela = estado,
        aoCancelar = { viewModel.cancelar(it) },
        aoPublicarParaTodos = { viewModel.publicarParaTodos() },
        aoVoltar = aoVoltar,
        modifier = modifier,
        aoVerVagaPublicada = aoVerVagaPublicada,
    )
}

/**
 * Acompanhar as chamadas de uma vaga (desenho do iOS `TelaAcompanharChamadas`): um cartão por chamada com o
 * estado, o motivo da recusa e, na aberta, "Cancelar chamada" atrás de uma confirmação; "Publicar para todos"
 * quando nenhuma chamada foi aceita e todas terminaram.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoAcompanharChamadas(
    tela: EstadoAcompanharChamadas,
    aoCancelar: (chamadaId: String) -> Unit,
    aoPublicarParaTodos: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoVerVagaPublicada: ((vagaId: String) -> Unit)? = null,
) {
    var idParaCancelar by rememberSaveable { mutableStateOf<String?>(null) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosChamadaCasa.ACOMPANHAR_TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = TextosChamadaCasa.VOLTAR) }
                },
            )
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(FrilaEspacamento.medio),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            if (tela.carregando) {
                IndicadorCarregando()
            } else {
                tela.erro?.let { AvisoFrila(tom = TomAviso.ERRO, mensagem = it) }
                tela.sucesso?.let { AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = it) }

                Text(
                    text = TextosChamadaCasa.CHAMADAS_ENVIADAS,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.semantics { heading() },
                )
                if (tela.chamadas.isEmpty()) {
                    Text(
                        text = TextosChamadaCasa.NENHUMA_CHAMADA,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else {
                    tela.chamadas.forEach { chamada ->
                        CartaoDaChamada(chamada, tela, bloqueado = tela.acaoEmVoo, aoCancelar = { idParaCancelar = chamada.id })
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    }
                }

                if (tela.podePublicarParaTodos) {
                    Text(
                        text = TextosChamadaCasa.PUBLICAR_PARA_TODOS_EXPLICACAO,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    BotaoPrimario(
                        texto = TextosChamadaCasa.PUBLICAR_PARA_TODOS,
                        aoClicar = aoPublicarParaTodos,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                val nova = tela.vagaPublicadaId
                if (nova != null && aoVerVagaPublicada != null) {
                    BotaoSecundario(
                        texto = TextosChamadaCasa.VER_VAGA_ABERTA,
                        aoClicar = { aoVerVagaPublicada(nova) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }

    if (idParaCancelar != null) {
        AlertDialog(
            onDismissRequest = { idParaCancelar = null },
            title = { Text(TextosChamadaCasa.CONFIRMAR_CANCELAMENTO_TITULO, modifier = Modifier.semantics { heading() }) },
            text = { Text(TextosChamadaCasa.CONFIRMAR_CANCELAMENTO) },
            confirmButton = {
                TextButton(
                    onClick = {
                        val id = idParaCancelar
                        idParaCancelar = null
                        if (id != null) aoCancelar(id)
                    },
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosChamadaCasa.CONFIRMAR_CANCELAMENTO_BOTAO, color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(
                    onClick = { idParaCancelar = null },
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosChamadaCasa.VOLTAR) }
            },
        )
    }
}

@Composable
private fun CartaoDaChamada(
    chamada: ChamadaResumoDto,
    tela: EstadoAcompanharChamadas,
    bloqueado: Boolean,
    aoCancelar: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = FrilaEspacamento.minimo),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
    ) {
        Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = chamada.outraParte.nome,
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = tela.rotuloDoEstado(chamada.estado),
                style = MaterialTheme.typography.labelLarge,
                color = corDoEstado(chamada.estado),
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
        Text(text = chamada.funcao.nome, style = MaterialTheme.typography.bodyMedium)
        chamada.motivoRecusa?.let {
            Text(
                text = "${TextosChamadaCasa.MOTIVO_ROTULO}: ${textoDoMotivoDeRecusa(it)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (chamada.estado == EstadoAcompanharChamadas.ESTADO_ABERTA) {
            TextButton(
                onClick = aoCancelar,
                enabled = !bloqueado,
                modifier = Modifier
                    .sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo)
                    .semantics { contentDescription = "${TextosChamadaCasa.CANCELAR_CHAMADA}: ${chamada.outraParte.nome}" },
            ) { Text(TextosChamadaCasa.CANCELAR_CHAMADA, color = MaterialTheme.colorScheme.error) }
        }
    }
}

@Composable
private fun corDoEstado(estado: String): Color = when (estado) {
    EstadoAcompanharChamadas.ESTADO_ACEITA -> MaterialTheme.colorScheme.primary
    EstadoAcompanharChamadas.ESTADO_ABERTA -> MaterialTheme.colorScheme.onSurface
    else -> MaterialTheme.colorScheme.onSurfaceVariant
}
