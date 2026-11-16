package br.com.frila.feature.chamadas.profissional

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** Liga o [PreferenciasChamadaViewModel] ao [ConteudoPreferenciasDeChamada]. */
@Composable
fun TelaPreferenciasDeChamada(
    viewModel: PreferenciasChamadaViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    /** Abre "Editar serviços"; nulo esconde o atalho. */
    aoEditarServicos: (() -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoPreferenciasDeChamada(
        tela = estado,
        aoTentarNovamente = { viewModel.carregar() },
        aoAlternarAceitaChamadas = viewModel::alternarAceitaChamadas,
        aoAlternarAceitaDeQuemJaTrabalhou = viewModel::alternarAceitaDeQuemJaTrabalhou,
        aoAlternarPausa = viewModel::alternarPausa,
        aoEscolherDataDaPausa = viewModel::escolherDataDaPausa,
        aoEscolherAntecedencia = viewModel::escolherAntecedencia,
        aoEscolherQuemPodeChamar = viewModel::escolherQuemPodeChamar,
        aoSalvar = { viewModel.salvar() },
        aoVoltar = aoVoltar,
        aoEditarServicos = aoEditarServicos,
        modifier = modifier,
    )
}

/**
 * Preferências de chamada (CD-I5d; paridade com `TelaPreferenciasDeChamada.swift`, mais o "Aceito chamadas
 * diretas" e as pendências da busca, CD-P10 a CD-P12): mesma ordem de campos do iOS, com o pedido do titular
 * no topo. Pausa por data (diálogo de data), antecedência e "quem pode me chamar" em escolhas de uma opção.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoPreferenciasDeChamada(
    tela: EstadoPreferenciasChamada,
    aoTentarNovamente: () -> Unit,
    aoAlternarAceitaChamadas: (Boolean) -> Unit,
    aoAlternarAceitaDeQuemJaTrabalhou: (Boolean) -> Unit,
    aoAlternarPausa: (Boolean) -> Unit,
    aoEscolherDataDaPausa: (LocalDate) -> Unit,
    aoEscolherAntecedencia: (Int) -> Unit,
    aoEscolherQuemPodeChamar: (String) -> Unit,
    aoSalvar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoEditarServicos: (() -> Unit)? = null,
    hoje: LocalDate = LocalDate.now(FormatoChamada.fuso),
) {
    var escolhendoData by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = { BarraDoTopoChamada(TextosChamadaProfissional.PREFERENCIAS_TITULO, aoVoltar) },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            when {
                tela.carregando -> Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = FrilaEspacamento.grande),
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    Text(text = TextosChamadaProfissional.CARREGANDO, style = MaterialTheme.typography.bodyMedium)
                }
                !tela.carregou -> Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio)) {
                    tela.erro?.let { AvisoFrila(tom = TomAviso.ERRO, mensagem = it) }
                    BotaoPrimario(texto = TextosChamadaProfissional.TENTAR_NOVAMENTE, aoClicar = aoTentarNovamente)
                }
                else -> Formulario(
                    tela = tela,
                    aoAlternarAceitaChamadas = aoAlternarAceitaChamadas,
                    aoAlternarAceitaDeQuemJaTrabalhou = aoAlternarAceitaDeQuemJaTrabalhou,
                    aoAlternarPausa = aoAlternarPausa,
                    aoAbrirData = { escolhendoData = true },
                    aoEscolherAntecedencia = aoEscolherAntecedencia,
                    aoEscolherQuemPodeChamar = aoEscolherQuemPodeChamar,
                    aoSalvar = aoSalvar,
                    aoEditarServicos = aoEditarServicos,
                )
            }
        }
    }

    if (escolhendoData) {
        val estadoDaData = rememberDatePickerState(
            initialSelectedDateMillis = tela.pausadoAte.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                    Instant.ofEpochMilli(utcTimeMillis).atZone(ZoneOffset.UTC).toLocalDate().isAfter(hoje)
            },
        )
        DatePickerDialog(
            onDismissRequest = { escolhendoData = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        estadoDaData.selectedDateMillis?.let { millis ->
                            aoEscolherDataDaPausa(Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate())
                        }
                        escolhendoData = false
                    },
                ) { Text(TextosChamadaProfissional.CONFIRMAR) }
            },
            dismissButton = {
                TextButton(onClick = { escolhendoData = false }) { Text(TextosChamadaProfissional.CANCELAR) }
            },
        ) { DatePicker(state = estadoDaData) }
    }
}

@Composable
private fun Formulario(
    tela: EstadoPreferenciasChamada,
    aoAlternarAceitaChamadas: (Boolean) -> Unit,
    aoAlternarAceitaDeQuemJaTrabalhou: (Boolean) -> Unit,
    aoAlternarPausa: (Boolean) -> Unit,
    aoAbrirData: () -> Unit,
    aoEscolherAntecedencia: (Int) -> Unit,
    aoEscolherQuemPodeChamar: (String) -> Unit,
    aoSalvar: () -> Unit,
    aoEditarServicos: (() -> Unit)?,
) {
    val livre = !tela.salvando
    tela.erro?.let { erro ->
        AvisoFrila(tom = TomAviso.ERRO, mensagem = erro, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive })
    }
    if (tela.sucesso) {
        AvisoFrila(
            tom = TomAviso.INFORMATIVO,
            mensagem = TextosChamadaProfissional.PREFERENCIAS_SALVAS,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }.testTag("preferencias-sucesso"),
        )
    }

    // "Aceito chamadas diretas" (CD-P10 a CD-P12): o pedido do titular, sem "autorizo" nem "consinto" (J1).
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        Text(
            text = TextosChamadaProfissional.ACEITO_TITULO,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() },
        )
        LinhaComChave(
            titulo = TextosChamadaProfissional.ACEITO_TEXTO,
            ligado = tela.aceitaChamadas,
            aoMudar = aoAlternarAceitaChamadas,
            habilitado = livre,
            modifier = Modifier.testTag("chave-aceita-chamadas"),
        )
        Text(
            text = TextosChamadaProfissional.ACEITO_O_QUE_APARECE,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Text(
            text = TextosChamadaProfissional.ACEITO_DESLIGAR,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        val pendencias = tela.pendencias.mapNotNull(TextosChamadaProfissional::pendencia)
        if (tela.aceitaChamadas && pendencias.isNotEmpty()) {
            Column(
                modifier = Modifier.testTag("pendencias-busca"),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
            ) {
                Text(
                    text = TextosChamadaProfissional.PENDENCIAS_TITULO,
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.semantics { heading() },
                )
                pendencias.forEach { Text(text = "• $it", style = MaterialTheme.typography.bodyMedium) }
            }
        }
        if (aoEditarServicos != null) {
            BotaoSecundario(
                texto = TextosChamadaProfissional.EDITAR_SERVICOS,
                aoClicar = aoEditarServicos,
                modifier = Modifier.fillMaxWidth().testTag("editar-servicos"),
            )
        }
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
        LinhaComChave(
            titulo = TextosChamadaProfissional.RECEBER_DE_QUEM_JA_TRABALHOU,
            ligado = tela.aceitaDeQuemJaTrabalhou,
            aoMudar = aoAlternarAceitaDeQuemJaTrabalhou,
            habilitado = livre,
            modifier = Modifier.testTag("toggle-receber-chamadas"),
        )
        Text(
            text = TextosChamadaProfissional.RECEBER_DE_QUEM_JA_TRABALHOU_SUBTITULO,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
        LinhaComChave(
            titulo = TextosChamadaProfissional.PAUSAR_CHAMADAS,
            ligado = tela.pausar,
            aoMudar = aoAlternarPausa,
            habilitado = livre,
            modifier = Modifier.testTag("toggle-pausa-chamadas"),
        )
        if (tela.pausar) {
            BotaoSecundario(
                texto = "${TextosChamadaProfissional.PAUSAR_ATE_DATA}: ${FormatoChamada.data(tela.pausadoAte)}",
                aoClicar = aoAbrirData,
                habilitado = livre,
                modifier = Modifier.fillMaxWidth().testTag("data-pausa-chamadas"),
            )
            Text(
                text = TextosChamadaProfissional.retomadaDaPausa(FormatoChamada.data(tela.diaDaRetomada)),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

    EscolhaUnica(
        titulo = TextosChamadaProfissional.ANTECEDENCIA_MINIMA,
        opcoes = listOf(
            2 to TextosChamadaProfissional.ANTECEDENCIA_2H,
            6 to TextosChamadaProfissional.ANTECEDENCIA_6H,
            24 to TextosChamadaProfissional.ANTECEDENCIA_24H,
            48 to TextosChamadaProfissional.ANTECEDENCIA_48H,
        ),
        selecionada = tela.antecedenciaMinimaH,
        aoEscolher = aoEscolherAntecedencia,
        habilitado = livre,
        modifier = Modifier.testTag("picker-antecedencia-chamada"),
    )
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

    EscolhaUnica(
        titulo = TextosChamadaProfissional.QUEM_PODE_CHAMAR,
        opcoes = listOf(
            "todos" to TextosChamadaProfissional.QUEM_TODOS,
            "so_cnpj" to TextosChamadaProfissional.QUEM_SO_CNPJ,
        ),
        selecionada = tela.aceitaDe,
        aoEscolher = aoEscolherQuemPodeChamar,
        habilitado = livre,
        modifier = Modifier.testTag("picker-quem-pode-chamar"),
    )
    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)

    Text(
        text = TextosChamadaProfissional.AVISO_CHAMADAS_EXISTENTES,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    BotaoPrimario(
        texto = TextosChamadaProfissional.PREFERENCIAS_SALVAR,
        aoClicar = aoSalvar,
        habilitado = livre,
        modifier = Modifier.fillMaxWidth().testTag("salvar-preferencias-chamada"),
    )
}
