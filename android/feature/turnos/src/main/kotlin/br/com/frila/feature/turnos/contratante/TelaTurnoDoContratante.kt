package br.com.frila.feature.turnos.contratante

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** Tudo o que a tela pode pedir ao [AcompanhamentoContratanteViewModel] e a quem a abriu. */
data class AcoesTurnoDoContratante(
    val aoConfirmarPresenca: () -> Unit = {},
    val aoVoltar: () -> Unit = {},
)

/** Liga o [AcompanhamentoContratanteViewModel] ao [ConteudoTurnoDoContratante]. */
@Composable
fun TelaTurnoDoContratante(
    viewModel: AcompanhamentoContratanteViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    ConteudoTurnoDoContratante(
        estado = estado,
        acoes = AcoesTurnoDoContratante(aoConfirmarPresenca = { viewModel.confirmarPresenca() }, aoVoltar = aoVoltar),
        modifier = modifier,
    )
}

/**
 * Turno visto pela casa (UC05, UC07; paridade com `TelaTurnoDoContratante.swift`): função, horário e
 * local; o profissional confirmado; e a chegada, que muda com o que o painel sabe: a caminho, atraso de
 * 15 minutos, check-in manual esperando confirmação (botão em destaque) ou presença verificada.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoTurnoDoContratante(
    estado: EstadoTurnoDoContratante,
    acoes: AcoesTurnoDoContratante,
    modifier: Modifier = Modifier,
) {
    val contexto = estado.contexto
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosTurnoDoContratante.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = acoes.aoVoltar,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosTurnoDoContratante.ROTULO_VOLTAR,
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
                .padding(FrilaEspacamento.medio),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
                Text(text = contexto.funcao, style = MaterialTheme.typography.headlineSmall)
                horario(contexto.inicio, contexto.fim)?.let { Text(text = it, style = MaterialTheme.typography.bodyLarge) }
                Text(text = contexto.local, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            Text(
                text = TextosTurnoDoContratante.PROFISSIONAL,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
            CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                val profissional = contexto.profissional
                if (profissional == null) {
                    Text(text = TextosTurnoDoContratante.SEM_PROFISSIONAL, style = MaterialTheme.typography.bodyMedium)
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
                        Text(text = profissional.nome, style = MaterialTheme.typography.titleMedium)
                        profissional.funcoes?.takeIf { it.isNotEmpty() }?.let {
                            Text(text = TextosTurnoDoContratante.FUNCOES.format(it.joinToString(", ")), style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }

            Text(
                text = TextosTurnoDoContratante.CHEGADA,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.semantics { heading() },
            )
            Chegada(estado, acoes)

            estado.aviso?.let { aviso ->
                Text(
                    text = aviso.mensagem,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (aviso.erro) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.semantics {
                        liveRegion = if (aviso.erro) LiveRegionMode.Assertive else LiveRegionMode.Polite
                    },
                )
            }
        }
    }
}

@Composable
private fun Chegada(estado: EstadoTurnoDoContratante, acoes: AcoesTurnoDoContratante) {
    val contexto = estado.contexto
    val nome = contexto.profissional?.nome ?: ""
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        when (estado.presenca) {
            PresencaDoTurno.AGUARDANDO ->
                Text(text = TextosTurnoDoContratante.AGUARDANDO, style = MaterialTheme.typography.bodyLarge)
            PresencaDoTurno.A_CAMINHO ->
                Text(
                    text = TextosTurnoDoContratante.A_CAMINHO.format(nome, contexto.aCaminhoEm?.let(::hora).orEmpty()),
                    style = MaterialTheme.typography.bodyLarge,
                )
            PresencaDoTurno.EM_ATRASO -> Row(
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                verticalAlignment = Alignment.Top,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            ) {
                Icon(Icons.Filled.Warning, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(24.dp))
                Text(text = TextosTurnoDoContratante.EM_ATRASO, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.error)
            }
            PresencaDoTurno.CHECKIN_MANUAL_PENDENTE -> {
                Text(
                    text = contexto.checkinEm
                        ?.let { TextosTurnoDoContratante.CHECKIN_PENDENTE_COM_HORA.format(nome, hora(it)) }
                        ?: TextosTurnoDoContratante.CHECKIN_PENDENTE.format(nome),
                    style = MaterialTheme.typography.bodyLarge,
                )
                BotaoPrimario(
                    texto = if (estado.enviando) TextosTurnoDoContratante.CONFIRMANDO else TextosTurnoDoContratante.CONFIRMAR_PRESENCA,
                    aoClicar = acoes.aoConfirmarPresenca,
                    habilitado = estado.podeConfirmar,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            // Texto e ícone, nunca só cor.
            PresencaDoTurno.VERIFICADA -> Row(
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(24.dp))
                Text(text = TextosTurnoDoContratante.VERIFICADA, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
            }
            PresencaDoTurno.NAO_VERIFICADA ->
                Text(text = TextosTurnoDoContratante.NAO_VERIFICADA, style = MaterialTheme.typography.bodyLarge)
        }
    }
}

private val FUSO = ZoneId.of("America/Sao_Paulo")
private val FORMATO_HORA = DateTimeFormatter.ofPattern("HH:mm")
private val FORMATO_DATA = DateTimeFormatter.ofPattern("dd/MM/yyyy")

private fun hora(instante: Instant): String = instante.atZone(FUSO).format(FORMATO_HORA)

/** "12/11/2026, 18:00 – 21:00" no mesmo dia; "12/11/2026 18:00 – 13/11/2026 02:00" em dias diferentes. */
internal fun horario(inicio: Instant?, fim: Instant?): String? {
    if (inicio == null || fim == null) return null
    val dataDoInicio = inicio.atZone(FUSO).format(FORMATO_DATA)
    val dataDoFim = fim.atZone(FUSO).format(FORMATO_DATA)
    return if (dataDoInicio == dataDoFim) {
        "$dataDoInicio, ${hora(inicio)} – ${hora(fim)}"
    } else {
        "$dataDoInicio ${hora(inicio)} – $dataDoFim ${hora(fim)}"
    }
}
