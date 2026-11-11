package br.com.frila.feature.suporte

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.dominio.modelo.MotivoDenuncia
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.rede.ProtocoloDto

/** Liga o [DenunciaViewModel] ao [ConteudoDenuncia]. */
@Composable
fun TelaDenuncia(
    viewModel: DenunciaViewModel,
    aoFechar: () -> Unit,
    aoLigar: (numero: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    ConteudoDenuncia(
        estado = estado,
        associadaAoTurno = viewModel.associadaAoTurno,
        associadaAChamada = viewModel.associadaAChamada,
        aoEscolherMotivo = viewModel::escolherMotivo,
        aoEditarRelato = viewModel::editarRelato,
        aoEnviar = { viewModel.enviarDenuncia() },
        aoAbrirBloqueio = viewModel::abrirDialogoBloqueio,
        aoCancelarBloqueio = viewModel::cancelarBloqueio,
        aoConfirmarBloqueio = { viewModel.confirmarBloqueio() },
        aoFechar = aoFechar,
        aoLigar = aoLigar,
        modifier = modifier,
    )
}

/**
 * Denúncia e bloqueio (RF26, UC17, paridade com `AcoesDeSeguranca.swift`). Os atalhos 190/180
 * ficam sempre à vista e não esperam a resposta da denúncia (diretriz 1.2 da App Store).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoDenuncia(
    estado: EstadoDenuncia,
    associadaAoTurno: Boolean,
    associadaAChamada: Boolean,
    aoEscolherMotivo: (MotivoDenuncia) -> Unit,
    aoEditarRelato: (String) -> Unit,
    aoEnviar: () -> Unit,
    aoAbrirBloqueio: () -> Unit,
    aoCancelarBloqueio: () -> Unit,
    aoConfirmarBloqueio: () -> Unit,
    aoFechar: () -> Unit,
    aoLigar: (numero: String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosSuporte.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoFechar,
                        modifier = Modifier.sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosSuporte.ROTULO_VOLTAR,
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
            Emergencia(aoLigar)
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

            val protocolo = estado.protocolo
            if (protocolo != null) {
                DenunciaEnviada(protocolo = protocolo, aoConcluir = aoFechar)
            } else {
                FormularioDenuncia(
                    estado = estado,
                    associadaAoTurno = associadaAoTurno,
                    associadaAChamada = associadaAChamada,
                    aoEscolherMotivo = aoEscolherMotivo,
                    aoEditarRelato = aoEditarRelato,
                    aoEnviar = aoEnviar,
                )
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            SecaoBloqueio(estado = estado, aoAbrir = aoAbrirBloqueio)
        }
    }

    if (estado.dialogoBloqueioAberto) {
        AlertDialog(
            onDismissRequest = aoCancelarBloqueio,
            title = {
                Text(text = TextosSuporte.BLOQUEIO_TITULO, modifier = Modifier.semantics { heading() })
            },
            text = { Text(text = TextosSuporte.BLOQUEIO_EFEITO) },
            confirmButton = {
                TextButton(
                    onClick = aoConfirmarBloqueio,
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) { Text(TextosSuporte.BLOQUEIO_CONFIRMAR, color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(
                    onClick = aoCancelarBloqueio,
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) { Text(TextosSuporte.CANCELAR) }
            },
        )
    }
}

@Composable
private fun Emergencia(aoLigar: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        Text(
            text = TextosSuporte.EMERGENCIA,
            style = MaterialTheme.typography.bodyMedium,
        )
        BotaoSecundario(
            texto = TextosSuporte.LIGAR_190,
            aoClicar = { aoLigar("190") },
            modifier = Modifier.fillMaxWidth(),
        )
        BotaoSecundario(
            texto = TextosSuporte.LIGAR_180,
            aoClicar = { aoLigar("180") },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun FormularioDenuncia(
    estado: EstadoDenuncia,
    associadaAoTurno: Boolean,
    associadaAChamada: Boolean,
    aoEscolherMotivo: (MotivoDenuncia) -> Unit,
    aoEditarRelato: (String) -> Unit,
    aoEnviar: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio)) {
        Text(
            text = TextosSuporte.SECAO_MOTIVO,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() },
        )
        Column(modifier = Modifier.selectableGroup()) {
            MotivoDenuncia.entries.forEach { motivo ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                        .selectable(
                            selected = estado.motivo == motivo,
                            enabled = !estado.enviando,
                            role = Role.RadioButton,
                            onClick = { aoEscolherMotivo(motivo) },
                        ),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                ) {
                    // O clique é do Row (selectable): o botão de rádio só reflete o estado.
                    RadioButton(selected = estado.motivo == motivo, onClick = null)
                    Text(text = TextosSuporte.nome(motivo), style = MaterialTheme.typography.bodyLarge)
                }
            }
        }

        Text(
            text = TextosSuporte.SECAO_RELATO,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() },
        )
        OutlinedTextField(
            value = estado.relato,
            onValueChange = aoEditarRelato,
            enabled = !estado.enviando,
            label = { Text(TextosSuporte.SECAO_RELATO) },
            supportingText = {
                Text(if (estado.relatoValido) TextosSuporte.RELATO_VALIDO else TextosSuporte.RELATO_DICA)
            },
            minLines = 4,
            modifier = Modifier.fillMaxWidth(),
        )

        if (associadaAoTurno) Text(TextosSuporte.ASSOCIADA_AO_TURNO, style = MaterialTheme.typography.bodySmall)
        if (associadaAChamada) Text(TextosSuporte.ASSOCIADA_A_CHAMADA, style = MaterialTheme.typography.bodySmall)

        estado.erroDenuncia?.let { mensagem ->
            Text(
                text = mensagem,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }

        BotaoPrimario(
            texto = if (estado.enviando) TextosSuporte.ENVIANDO else TextosSuporte.ENVIAR,
            aoClicar = aoEnviar,
            habilitado = estado.podeEnviar,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun DenunciaEnviada(protocolo: ProtocoloDto, aoConcluir: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        Text(
            text = TextosSuporte.ENVIADA,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics {
                heading()
                liveRegion = LiveRegionMode.Polite
            },
        )
        Text(text = "${TextosSuporte.PROTOCOLO}: #${protocolo.protocoloCurto}", style = MaterialTheme.typography.bodyLarge)
        Text(
            text = "${TextosSuporte.PRAZO} ${formatarPrazo(protocolo.prazoRespostaAte)}",
            style = MaterialTheme.typography.bodyMedium,
        )
        BotaoPrimario(
            texto = TextosSuporte.CONCLUIR,
            aoClicar = aoConcluir,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun SecaoBloqueio(estado: EstadoDenuncia, aoAbrir: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        if (estado.bloqueado) {
            Text(
                text = TextosSuporte.BLOQUEADO,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        } else {
            BotaoSecundario(
                texto = if (estado.bloqueando) TextosSuporte.BLOQUEANDO else TextosSuporte.BLOQUEAR,
                aoClicar = aoAbrir,
                habilitado = !estado.bloqueando,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        estado.erroBloqueio?.let { mensagem ->
            Text(
                text = mensagem,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }
    }
}
