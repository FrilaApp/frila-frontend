package br.com.frila.feature.chamadas.casa

import android.app.DatePickerDialog
import android.app.TimePickerDialog
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.semantics.Role as PapelDeAcessibilidade
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import java.time.Instant
import java.time.ZonedDateTime

/** Liga o [ChamadaDiretaViewModel] ao [ConteudoChamadaDireta]. [aoAcompanhar] recebe o id da vaga da chamada enviada. */
@Composable
fun TelaChamadaDireta(
    viewModel: ChamadaDiretaViewModel,
    aoFechar: () -> Unit,
    modifier: Modifier = Modifier,
    aoAcompanhar: ((vagaId: String) -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoChamadaDireta(
        tela = estado,
        acoes = AcoesChamadaDireta(
            aoFechar = aoFechar,
            aoTentarNovamente = { viewModel.carregar() },
            aoEnviar = { viewModel.enviar() },
            aoConfirmarJ7 = { viewModel.enviar(confirmoRecorrencia = true) },
            aoDispensarJ7 = viewModel::dispensarJ7,
            aoEscolherFuncao = viewModel::definirFuncao,
            aoMudarInicio = viewModel::definirInicio,
            aoMudarFim = viewModel::definirFim,
            aoMudarResponsavel = viewModel::definirResponsavel,
            aoMudarValor = viewModel::definirValor,
            aoConfirmarTotal = viewModel::confirmarTotal,
            aoMudarRefeicao = viewModel::definirRefeicao,
            aoMudarTransporte = viewModel::definirTransporte,
            aoMudarMaterialProprio = viewModel::definirMaterialProprio,
            aoMudarRecado = viewModel::definirRecado,
            aoAcompanhar = aoAcompanhar,
        ),
        inicioMinimo = viewModel::inicioMinimo,
        faixaDoTermino = viewModel::faixaDoTermino,
        modifier = modifier,
    )
}

/** Tudo o que a folha pode pedir ao ViewModel; o teste de tela entrega os seus. */
class AcoesChamadaDireta(
    val aoFechar: () -> Unit = {},
    val aoTentarNovamente: () -> Unit = {},
    val aoEnviar: () -> Unit = {},
    val aoConfirmarJ7: () -> Unit = {},
    val aoDispensarJ7: () -> Unit = {},
    val aoEscolherFuncao: (String) -> Unit = {},
    val aoMudarInicio: (Instant) -> Unit = {},
    val aoMudarFim: (Instant) -> Unit = {},
    val aoMudarResponsavel: (String) -> Unit = {},
    val aoMudarValor: (String) -> Unit = {},
    val aoConfirmarTotal: (Boolean) -> Unit = {},
    val aoMudarRefeicao: (Boolean) -> Unit = {},
    val aoMudarTransporte: (Boolean) -> Unit = {},
    val aoMudarMaterialProprio: (Boolean) -> Unit = {},
    val aoMudarRecado: (String) -> Unit = {},
    val aoAcompanhar: ((vagaId: String) -> Unit)? = null,
)

/**
 * A folha "Chamar profissional" (desenho do iOS `TelaChamadaDireta`): função, local da casa, início e término,
 * responsável, valor total e a confirmação dele, inclusos e recado; o botão desligado diz o que falta, e o aviso J7
 * (3ª chamada em 7 dias) vem num diálogo. Enviada a chamada, a folha mostra o resumo e o caminho para acompanhar.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoChamadaDireta(
    tela: EstadoChamadaDireta,
    acoes: AcoesChamadaDireta,
    inicioMinimo: () -> Instant,
    faixaDoTermino: () -> ClosedRange<Instant>,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosChamadaCasa.TITULO_DA_FOLHA,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    TextButton(
                        onClick = acoes.aoFechar,
                        enabled = !tela.enviando,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) { Text(TextosChamadaCasa.FECHAR) }
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
            if (tela.carregando) IndicadorCarregando()
            tela.erro?.let { erro ->
                AvisoFrila(tom = TomAviso.ERRO, mensagem = erro)
                if (!tela.recursoHabilitado && !tela.carregando) {
                    BotaoSecundario(texto = TextosChamadaCasa.TENTAR_NOVAMENTE, aoClicar = acoes.aoTentarNovamente)
                }
            }
            val resultado = tela.resultado
            if (resultado != null) {
                ResumoDaChamadaEnviada(tela = tela, aoAcompanhar = acoes.aoAcompanhar?.let { acompanhar -> { acompanhar(resultado.vagaId) } })
            } else if (tela.recursoHabilitado) {
                Campos(tela, acoes, inicioMinimo, faixaDoTermino)
                BotaoPrimario(
                    texto = if (tela.enviando) TextosChamadaCasa.CARREGANDO else TextosChamadaCasa.ENVIAR,
                    aoClicar = acoes.aoEnviar,
                    habilitado = tela.podeEnviar,
                    modifier = Modifier.fillMaxWidth(),
                )
                tela.oQueFalta?.let { falta ->
                    Text(
                        text = falta,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }

    if (tela.mostrarJ7) {
        AlertDialog(
            onDismissRequest = acoes.aoDispensarJ7,
            title = { Text(TextosChamadaCasa.J7_TITULO, modifier = Modifier.semantics { heading() }) },
            text = { Text(TextosChamadaCasa.J7_MENSAGEM) },
            confirmButton = {
                TextButton(
                    onClick = acoes.aoConfirmarJ7,
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosChamadaCasa.J7_CONFIRMAR) }
            },
            dismissButton = {
                TextButton(
                    onClick = acoes.aoDispensarJ7,
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosChamadaCasa.CANCELAR) }
            },
        )
    }
}

@Composable
private fun Campos(
    tela: EstadoChamadaDireta,
    acoes: AcoesChamadaDireta,
    inicioMinimo: () -> Instant,
    faixaDoTermino: () -> ClosedRange<Instant>,
) {
    val editavel = tela.podeEditar
    SeletorDeFuncao(tela, acoes.aoEscolherFuncao, editavel)
    LinhaDeLeitura(TextosChamadaCasa.LOCAL, tela.local)
    CampoDeHorario(TextosChamadaCasa.INICIO, tela.inicio, editavel, minimo = inicioMinimo, maximo = null, aoEscolher = acoes.aoMudarInicio)
    CampoDeHorario(
        TextosChamadaCasa.TERMINO, tela.fim, editavel,
        minimo = { faixaDoTermino().start }, maximo = { faixaDoTermino().endInclusive }, aoEscolher = acoes.aoMudarFim,
    )
    OutlinedTextField(
        value = tela.responsavel,
        onValueChange = acoes.aoMudarResponsavel,
        label = { Text(TextosChamadaCasa.RESPONSAVEL) },
        enabled = editavel,
        singleLine = true,
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
        modifier = Modifier.fillMaxWidth(),
    )
    OutlinedTextField(
        value = tela.valorTexto,
        onValueChange = acoes.aoMudarValor,
        label = { Text(TextosChamadaCasa.VALOR_TOTAL) },
        placeholder = { Text(TextosChamadaCasa.VALOR_EXEMPLO) },
        prefix = { Text(TextosChamadaCasa.MOEDA) },
        enabled = editavel,
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        modifier = Modifier.fillMaxWidth(),
    )
    LinhaDeInterruptor(TextosChamadaCasa.CONFIRMAR_TOTAL, tela.totalConfirmado, editavel, acoes.aoConfirmarTotal)
    LinhaDeInterruptor(TextosChamadaCasa.INCLUI_REFEICAO, tela.refeicao, editavel, acoes.aoMudarRefeicao)
    LinhaDeInterruptor(TextosChamadaCasa.INCLUI_TRANSPORTE, tela.transporte, editavel, acoes.aoMudarTransporte)
    LinhaDeInterruptor(TextosChamadaCasa.EXIGE_MATERIAL_PROPRIO, tela.materialProprio, editavel, acoes.aoMudarMaterialProprio)
    OutlinedTextField(
        value = tela.recado,
        onValueChange = acoes.aoMudarRecado,
        label = { Text(TextosChamadaCasa.RECADO) },
        enabled = editavel,
        minLines = 3,
        maxLines = 6,
        isError = tela.recadoLongo,
        supportingText = if (tela.recadoLongo) {
            { Text(TextosChamadaCasa.RECADO_LONGO, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }) }
        } else {
            null
        },
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun LinhaDeLeitura(rotulo: String, valor: String) {
    Column(modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) { }) {
        Text(rotulo, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(valor, style = MaterialTheme.typography.bodyLarge)
    }
}

@Composable
private fun SeletorDeFuncao(tela: EstadoChamadaDireta, aoEscolher: (String) -> Unit, editavel: Boolean) {
    var aberto by remember { mutableStateOf(false) }
    val atual = tela.funcoes.firstOrNull { it.id == tela.funcaoId }
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(TextosChamadaCasa.FUNCAO, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        BotaoSecundario(
            texto = atual?.nome ?: "—",
            aoClicar = { aberto = true },
            habilitado = editavel,
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = "${TextosChamadaCasa.FUNCAO}: ${atual?.nome.orEmpty()}" },
        )
        DropdownMenu(expanded = aberto, onDismissRequest = { aberto = false }) {
            tela.funcoes.forEach { funcao ->
                DropdownMenuItem(
                    text = { Text(funcao.nome) },
                    onClick = {
                        aberto = false
                        aoEscolher(funcao.id)
                    },
                )
            }
        }
    }
}

/** Data e hora pelos seletores do sistema, no horário de Brasília; o ViewModel segura a faixa de 2 h a 16 h. */
@Composable
private fun CampoDeHorario(
    rotulo: String,
    valor: Instant,
    editavel: Boolean,
    minimo: () -> Instant,
    maximo: (() -> Instant)?,
    aoEscolher: (Instant) -> Unit,
) {
    val contexto = LocalContext.current
    val atual = ZonedDateTime.ofInstant(valor, FusoDoFrila)
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(rotulo, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        BotaoSecundario(
            texto = dataEHora(valor),
            habilitado = editavel,
            modifier = Modifier.fillMaxWidth().semantics { contentDescription = "$rotulo: ${dataEHora(valor)}" },
            aoClicar = {
                DatePickerDialog(
                    contexto,
                    { _, ano, mes, dia ->
                        TimePickerDialog(
                            contexto,
                            { _, h, min ->
                                val escolhido = ZonedDateTime.of(ano, mes + 1, dia, h, min, 0, 0, FusoDoFrila).toInstant()
                                val limiteBaixo = minimo()
                                val limiteAlto = maximo?.invoke()
                                aoEscolher(escolhido.coerceIn(limiteBaixo, limiteAlto))
                            },
                            atual.hour, atual.minute, true,
                        ).show()
                    },
                    atual.year, atual.monthValue - 1, atual.dayOfMonth,
                ).apply { datePicker.minDate = minimo().toEpochMilli() - UM_DIA_EM_MS }.show()
            },
        )
    }
}

private const val UM_DIA_EM_MS = 24L * 60 * 60 * 1000

private fun Instant.coerceIn(minimo: Instant, maximo: Instant?): Instant = when {
    isBefore(minimo) -> minimo
    maximo != null && isAfter(maximo) -> maximo
    else -> this
}

@Composable
private fun LinhaDeInterruptor(rotulo: String, ligado: Boolean, editavel: Boolean, aoMudar: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
            .toggleable(value = ligado, enabled = editavel, role = PapelDeAcessibilidade.Switch, onValueChange = aoMudar),
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        Text(rotulo, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        Switch(checked = ligado, onCheckedChange = null, enabled = editavel)
    }
}
