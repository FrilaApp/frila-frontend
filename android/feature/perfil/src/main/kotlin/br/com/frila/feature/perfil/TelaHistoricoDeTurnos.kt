// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
package br.com.frila.feature.perfil

import android.content.Intent
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.core.content.FileProvider
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

@Composable
fun TelaHistoricoDeTurnos(
    viewModel: HistoricoDeTurnosViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    val contexto = LocalContext.current

    LaunchedEffect(estado.arquivoParaCompartilhar) {
        val arquivo = estado.arquivoParaCompartilhar ?: return@LaunchedEffect
        val uri = FileProvider.getUriForFile(contexto, "${contexto.packageName}.fileprovider", arquivo)
        val mimeType = if (estado.formato == FormatoExportacao.PDF) "application/pdf" else "text/csv"
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "Histórico de Turnos Frila")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        contexto.startActivity(Intent.createChooser(intent, "Compartilhar histórico de turnos"))
        viewModel.limparArquivoParaCompartilhar()
    }

    ConteudoHistoricoDeTurnos(
        estado = estado,
        aoEscolherAtalho = viewModel::escolher,
        aoEscolherFormato = viewModel::escolher,
        aoEscolherInicio = viewModel::escolherInicio,
        aoEscolherFim = viewModel::escolherFim,
        aoExportar = { viewModel.exportar(contexto.cacheDir) },
        aoVoltar = aoVoltar,
        modifier = modifier,
        formatosDisponiveis = viewModel.formatosDisponiveis,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoHistoricoDeTurnos(
    estado: EstadoTelaHistorico,
    aoEscolherAtalho: (AtalhoHistorico) -> Unit,
    aoEscolherFormato: (FormatoExportacao) -> Unit,
    aoEscolherInicio: (LocalDate) -> Unit,
    aoEscolherFim: (LocalDate) -> Unit,
    aoExportar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    /** A casa só exporta CSV (o PDF local é do profissional); o padrão são os dois, como sempre foi. */
    formatosDisponiveis: List<FormatoExportacao> = FormatoExportacao.entries,
) {
    val cores = FrilaTema.cores
    val formatoData = remember { DateTimeFormatter.ofPattern("dd/MM/yyyy") }
    var mostrarSeletorInicio by remember { mutableStateOf(false) }
    var mostrarSeletorFim by remember { mutableStateOf(false) }

    if (mostrarSeletorInicio) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = estado.inicioEscolhido.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean {
                    val data = Instant.ofEpochMilli(utcTimeMillis).atZone(ZoneOffset.UTC).toLocalDate()
                    return !data.isAfter(estado.fimEscolhido) && !data.isAfter(estado.hoje)
                }
            },
        )
        DatePickerDialog(
            onDismissRequest = { mostrarSeletorInicio = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        aoEscolherInicio(Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate())
                    }
                    mostrarSeletorInicio = false
                }) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { mostrarSeletorInicio = false }) {
                    Text("Cancelar")
                }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }

    if (mostrarSeletorFim) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = estado.fimEscolhido.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean {
                    val data = Instant.ofEpochMilli(utcTimeMillis).atZone(ZoneOffset.UTC).toLocalDate()
                    return !data.isAfter(estado.hoje)
                }
            },
        )
        DatePickerDialog(
            onDismissRequest = { mostrarSeletorFim = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { millis ->
                        aoEscolherFim(Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate())
                    }
                    mostrarSeletorFim = false
                }) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { mostrarSeletorFim = false }) {
                    Text("Cancelar")
                }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = FrilaEspacamento.item, vertical = FrilaEspacamento.junto),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = aoVoltar) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Fechar",
                        tint = cores.tinta,
                    )
                }
                TituloDaTela(stringResource(R.string.historico_turnos_titulo))
            }
        },
        bottomBar = {
            RodapeAncorado {
                when (val st = estado.estado) {
                    is EstadoHistorico.SemTurnos -> {
                        MensagemJuntoAoBotao(
                            texto = stringResource(R.string.historico_turnos_sem_turnos),
                            modifier = Modifier.testTag("historico-sem-turnos"),
                        )
                    }
                    is EstadoHistorico.Erro -> {
                        MensagemJuntoAoBotao(
                            texto = st.mensagem,
                            modifier = Modifier.testTag("historico-erro"),
                        )
                        if (st.repetivel) {
                            BotaoSecundario(
                                texto = stringResource(R.string.historico_turnos_tentar_novamente),
                                aoClicar = aoExportar,
                                modifier = Modifier.testTag("historico-tentar-novamente"),
                            )
                        }
                    }
                    else -> Unit
                }
                val carregando = estado.estado is EstadoHistorico.Carregando
                BotaoPrimario(
                    texto = if (carregando) {
                        stringResource(R.string.historico_turnos_gerando)
                    } else {
                        stringResource(R.string.historico_turnos_exportar)
                    },
                    habilitado = estado.periodoValido && !carregando,
                    aoClicar = aoExportar,
                    modifier = Modifier.testTag("historico-exportar"),
                )
            }
        },
    ) { enchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(enchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            Text(
                text = stringResource(R.string.historico_turnos_explicacao),
                style = FrilaTipo.apoio,
                color = cores.tintaSuave,
            )

            FrilaGrupoDeLinhas(titulo = stringResource(R.string.historico_turnos_periodo)) {
                linha {
                    FrilaLinhaDeOpcao(
                        titulo = stringResource(R.string.historico_turnos_este_mes),
                        marcada = estado.atalho == AtalhoHistorico.ESTE_MES,
                        aoClicar = { aoEscolherAtalho(AtalhoHistorico.ESTE_MES) },
                        modifier = Modifier.testTag("historico-este-mes"),
                    )
                }
                linha {
                    FrilaLinhaDeOpcao(
                        titulo = stringResource(R.string.historico_turnos_mes_passado),
                        marcada = estado.atalho == AtalhoHistorico.MES_PASSADO,
                        aoClicar = { aoEscolherAtalho(AtalhoHistorico.MES_PASSADO) },
                        modifier = Modifier.testTag("historico-mes-passado"),
                    )
                }
                linha {
                    FrilaLinhaDeOpcao(
                        titulo = stringResource(R.string.historico_turnos_intervalo),
                        marcada = estado.atalho == AtalhoHistorico.INTERVALO,
                        aoClicar = { aoEscolherAtalho(AtalhoHistorico.INTERVALO) },
                        modifier = Modifier.testTag("historico-intervalo"),
                    )
                }
            }

            if (estado.atalho == AtalhoHistorico.INTERVALO) {
                CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                    ) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { mostrarSeletorInicio = true }
                                .testTag("historico-de")
                                .padding(vertical = FrilaEspacamento.junto),
                            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
                        ) {
                            Text(
                                text = stringResource(R.string.historico_turnos_de),
                                style = FrilaTipo.rotuloDeGrupo,
                                color = cores.tintaSuave,
                            )
                            Text(
                                text = estado.inicioEscolhido.format(formatoData),
                                style = FrilaTipo.corpo,
                                color = cores.tinta,
                            )
                        }

                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { mostrarSeletorFim = true }
                                .testTag("historico-ate")
                                .padding(vertical = FrilaEspacamento.junto),
                            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
                        ) {
                            Text(
                                text = stringResource(R.string.historico_turnos_ate),
                                style = FrilaTipo.rotuloDeGrupo,
                                color = cores.tintaSuave,
                            )
                            Text(
                                text = estado.fimEscolhido.format(formatoData),
                                style = FrilaTipo.corpo,
                                color = cores.tinta,
                            )
                        }
                    }
                }
            }

            if (estado.excedeLimite) {
                AvisoFrila(
                    tom = TomAviso.ALERTA,
                    mensagem = stringResource(R.string.historico_turnos_intervalo_maximo_excedido),
                    modifier = Modifier.testTag("historico-periodo-invalido"),
                )
            } else if (estado.periodoEscolhido != null) {
                val periodo = estado.periodoEscolhido!!
                val deStr = periodo.de.format(formatoData)
                val ateStr = periodo.ate.format(formatoData)
                Text(
                    text = TextosHistoricoDeTurnos.resumo(deStr, ateStr),
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                    modifier = Modifier.testTag("historico-resumo-periodo"),
                )
            } else {
                AvisoFrila(
                    tom = TomAviso.ALERTA,
                    mensagem = stringResource(R.string.historico_turnos_periodo_invalido),
                    modifier = Modifier.testTag("historico-periodo-invalido"),
                )
            }

            FrilaGrupoDeLinhas(titulo = stringResource(R.string.historico_turnos_formato)) {
                if (FormatoExportacao.CSV in formatosDisponiveis) linha {
                    FrilaLinhaDeOpcao(
                        titulo = "CSV",
                        marcada = estado.formato == FormatoExportacao.CSV,
                        aoClicar = { aoEscolherFormato(FormatoExportacao.CSV) },
                        modifier = Modifier.testTag("historico-formato-csv"),
                    )
                }
                if (FormatoExportacao.PDF in formatosDisponiveis) linha {
                    FrilaLinhaDeOpcao(
                        titulo = "PDF",
                        marcada = estado.formato == FormatoExportacao.PDF,
                        aoClicar = { aoEscolherFormato(FormatoExportacao.PDF) },
                        modifier = Modifier.testTag("historico-formato-pdf"),
                    )
                }
            }
        }
    }
}
