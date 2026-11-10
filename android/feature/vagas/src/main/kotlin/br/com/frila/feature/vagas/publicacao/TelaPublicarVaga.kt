package br.com.frila.feature.vagas.publicacao

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.rede.VagaPublicadaDto
import java.time.Instant

/** Tudo o que a tela pode pedir ao [PublicarVagaViewModel]; o padrão `{}` mantém o teste de tela curto. */
data class AcoesPublicarVaga(
    val aoCarregarFuncoes: () -> Unit = {},
    val aoEscolherFuncao: (String) -> Unit = {},
    val aoEditarInicio: (Instant) -> Unit = {},
    val aoEditarFim: (Instant) -> Unit = {},
    val aoEscolherModo: (ModoDaVaga) -> Unit = {},
    val aoEditarLocal: (String) -> Unit = {},
    val aoEditarValor: (String) -> Unit = {},
    val aoEditarPosicoes: (String) -> Unit = {},
    val aoMaisUmaPosicao: () -> Unit = {},
    val aoMenosUmaPosicao: () -> Unit = {},
    val aoAlternarRefeicao: (Boolean) -> Unit = {},
    val aoAlternarTransporte: (Boolean) -> Unit = {},
    val aoAlternarMaterial: (Boolean) -> Unit = {},
    val aoEditarResponsavel: (String) -> Unit = {},
    val aoEditarTraje: (String) -> Unit = {},
    val aoEditarObservacoes: (String) -> Unit = {},
    val aoAlternarRateio: (Boolean) -> Unit = {},
    val aoPublicar: () -> Unit = {},
    val aoVoltar: () -> Unit = {},
)

/** Liga o [PublicarVagaViewModel] ao [ConteudoPublicarVaga]. */
@Composable
fun TelaPublicarVaga(
    viewModel: PublicarVagaViewModel,
    aoPublicar: (VagaPublicadaDto) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(Unit) { viewModel.carregarFuncoes() }
    LaunchedEffect(estado.publicada) {
        estado.publicada?.let(aoPublicar)
    }
    ConteudoPublicarVaga(
        estado = estado,
        acoes = AcoesPublicarVaga(
            aoCarregarFuncoes = { viewModel.carregarFuncoes() },
            aoEscolherFuncao = viewModel::escolherFuncao,
            aoEditarInicio = viewModel::editarInicio,
            aoEditarFim = viewModel::editarFim,
            aoEscolherModo = viewModel::escolherModo,
            aoEditarLocal = viewModel::editarLocal,
            aoEditarValor = viewModel::editarValor,
            aoEditarPosicoes = viewModel::editarPosicoes,
            aoMaisUmaPosicao = viewModel::maisUmaPosicao,
            aoMenosUmaPosicao = viewModel::menosUmaPosicao,
            aoAlternarRefeicao = viewModel::alternarRefeicao,
            aoAlternarTransporte = viewModel::alternarTransporte,
            aoAlternarMaterial = viewModel::alternarMaterialProprio,
            aoEditarResponsavel = viewModel::editarResponsavel,
            aoEditarTraje = viewModel::editarTraje,
            aoEditarObservacoes = viewModel::editarObservacoes,
            aoAlternarRateio = viewModel::alternarRateio,
            aoPublicar = { viewModel.publicar() },
            aoVoltar = aoVoltar,
        ),
        modifier = modifier,
    )
}

/**
 * Publicação de vaga pelo contratante (RF04, RN02, RN24, UC01; paridade com `TelaPublicarVaga` de
 * `PublicarVaga.swift`). Cada campo mostra o próprio erro; o erro global e o botão ficam juntos no fim.
 * Com uma publicação pendente o formulário trava e o botão vira "Tentar novamente".
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoPublicarVaga(
    estado: EstadoPublicarVaga,
    acoes: AcoesPublicarVaga,
    modifier: Modifier = Modifier,
) {
    var seletorDeFuncaoAberto by rememberSaveable { mutableStateOf(false) }
    var maisOpcoesAberto by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosPublicarVaga.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = acoes.aoVoltar,
                        enabled = !estado.enviando,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosPublicarVaga.ROTULO_VOLTAR,
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
            // Função
            Titulo(TextosPublicarVaga.FUNCAO)
            when {
                estado.carregandoFuncoes -> Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    Text(TextosPublicarVaga.FUNCOES_CARREGANDO, style = MaterialTheme.typography.bodyMedium)
                }
                estado.falhaAoCarregarFuncoes -> Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                    Text(
                        text = TextosPublicarVaga.FUNCOES_FALHA,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                    BotaoSecundario(texto = TextosPublicarVaga.TENTAR_NOVAMENTE, aoClicar = acoes.aoCarregarFuncoes)
                }
                else -> Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
                    BotaoSecundario(
                        texto = estado.funcoes.firstOrNull { it.id == estado.funcaoId }?.nome ?: TextosPublicarVaga.FUNCAO_SELECIONAR,
                        aoClicar = { seletorDeFuncaoAberto = true },
                        habilitado = estado.podeEditar,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    estado.errosDeCampo[CampoPublicacao.FUNCAO]?.let { TextoDeErro(it) }
                }
            }

            // Quando
            Titulo(TextosPublicarVaga.QUANDO)
            SeletorDeInstante(
                titulo = TextosPublicarVaga.INICIO,
                rotuloData = TextosPublicarVaga.DATA_DO_INICIO,
                rotuloHora = TextosPublicarVaga.HORA_DO_INICIO,
                instante = estado.inicio,
                erro = estado.errosDeCampo[CampoPublicacao.INICIO],
                habilitado = estado.podeEditar,
                aoMudar = acoes.aoEditarInicio,
            )
            SeletorDeInstante(
                titulo = TextosPublicarVaga.FIM,
                rotuloData = TextosPublicarVaga.DATA_DO_FIM,
                rotuloHora = TextosPublicarVaga.HORA_DO_FIM,
                instante = estado.fim,
                erro = estado.errosDeCampo[CampoPublicacao.FIM],
                habilitado = estado.podeEditar,
                aoMudar = acoes.aoEditarFim,
            )
            if (estado.duracao.toMinutes() > 0) {
                Text(
                    text = TextosPublicarVaga.DURACAO.format(formatarDuracao(estado.duracao)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // Modo
            Titulo(TextosPublicarVaga.MODO)
            Column(modifier = Modifier.selectableGroup()) {
                OpcaoDeModo(
                    rotulo = TextosPublicarVaga.MODO_URGENCIA,
                    explicacao = TextosPublicarVaga.MODO_URGENCIA_EXPLICACAO,
                    selecionado = estado.modo == ModoDaVaga.URGENCIA,
                    habilitado = estado.podeEditar,
                    aoEscolher = { acoes.aoEscolherModo(ModoDaVaga.URGENCIA) },
                )
                OpcaoDeModo(
                    rotulo = TextosPublicarVaga.MODO_SELECAO,
                    explicacao = if (estado.selecaoDisponivel) {
                        TextosPublicarVaga.MODO_SELECAO_EXPLICACAO
                    } else {
                        TextosPublicarVaga.MODO_SELECAO_SO_COM_ANTECEDENCIA
                    },
                    selecionado = estado.modo == ModoDaVaga.SELECAO,
                    habilitado = estado.podeEditar && estado.selecaoDisponivel,
                    aoEscolher = { acoes.aoEscolherModo(ModoDaVaga.SELECAO) },
                )
            }
            estado.errosDeCampo[CampoPublicacao.MODO]?.let { TextoDeErro(it) }

            // Local, valor e posições
            Campo(
                rotulo = TextosPublicarVaga.LOCAL,
                valor = estado.local,
                aoMudar = acoes.aoEditarLocal,
                erro = estado.errosDeCampo[CampoPublicacao.LOCAL] ?: estado.errosDeCampo[CampoPublicacao.ESTABELECIMENTO],
                habilitado = estado.podeEditar,
                ajuda = TextosPublicarVaga.LOCAL_AJUDA,
            )
            Campo(
                rotulo = TextosPublicarVaga.VALOR,
                valor = estado.valor,
                aoMudar = acoes.aoEditarValor,
                erro = estado.errosDeCampo[CampoPublicacao.VALOR],
                habilitado = estado.podeEditar,
                ajuda = TextosPublicarVaga.VALOR_AJUDA,
                teclado = KeyboardType.Decimal,
            )
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
            ) {
                BotaoSecundario(
                    texto = "−",
                    aoClicar = acoes.aoMenosUmaPosicao,
                    habilitado = estado.podeEditar,
                    modifier = Modifier.semantics { contentDescription = TextosPublicarVaga.MENOS_UMA_POSICAO },
                )
                Campo(
                    rotulo = TextosPublicarVaga.POSICOES,
                    valor = estado.posicoes,
                    aoMudar = acoes.aoEditarPosicoes,
                    erro = estado.errosDeCampo[CampoPublicacao.POSICOES],
                    habilitado = estado.podeEditar,
                    ajuda = TextosPublicarVaga.POSICOES_AJUDA,
                    teclado = KeyboardType.Number,
                    modifier = Modifier.weight(1f),
                )
                BotaoSecundario(
                    texto = "+",
                    aoClicar = acoes.aoMaisUmaPosicao,
                    habilitado = estado.podeEditar,
                    modifier = Modifier.semantics { contentDescription = TextosPublicarVaga.MAIS_UMA_POSICAO },
                )
            }
            estado.valorTotalCentavos?.let { total ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio),
                    modifier = Modifier.semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
                ) {
                    Text(
                        text = TextosPublicarVaga.TOTAL_DA_VAGA.format(formatarReais(total)),
                        style = MaterialTheme.typography.titleMedium,
                    )
                    val posicoes = estado.posicoesNumero ?: 1
                    Text(
                        text = if (posicoes == 1) TextosPublicarVaga.TOTAL_SINGULAR else TextosPublicarVaga.TOTAL_PLURAL.format(posicoes),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    estado.valorPorHoraCentavos?.let {
                        Text(
                            text = TextosPublicarVaga.VALOR_POR_HORA.format(formatarReais(it)),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            // Inclusos
            Titulo(TextosPublicarVaga.INCLUSOS)
            LinhaComChave(TextosPublicarVaga.REFEICAO, estado.incluiRefeicao, estado.podeEditar, acoes.aoAlternarRefeicao)
            LinhaComChave(TextosPublicarVaga.TRANSPORTE, estado.incluiTransporte, estado.podeEditar, acoes.aoAlternarTransporte)
            LinhaComChave(TextosPublicarVaga.MATERIAL, estado.exigeMaterialProprio, estado.podeEditar, acoes.aoAlternarMaterial)
            Campo(
                rotulo = TextosPublicarVaga.RESPONSAVEL,
                valor = estado.responsavelLocal,
                aoMudar = acoes.aoEditarResponsavel,
                erro = estado.errosDeCampo[CampoPublicacao.RESPONSAVEL],
                habilitado = estado.podeEditar,
            )

            // Mais opções
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                    .toggleable(
                        value = maisOpcoesAberto,
                        role = Role.Switch,
                        onValueChange = { maisOpcoesAberto = it },
                    ),
            ) {
                Text(TextosPublicarVaga.MAIS_OPCOES, style = MaterialTheme.typography.titleMedium)
                Text(
                    TextosPublicarVaga.MAIS_OPCOES_AJUDA,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            if (maisOpcoesAberto) {
                Campo(
                    rotulo = TextosPublicarVaga.TRAJE,
                    valor = estado.traje,
                    aoMudar = acoes.aoEditarTraje,
                    erro = estado.errosDeCampo[CampoPublicacao.TRAJE],
                    habilitado = estado.podeEditar,
                )
                LinhaComChave(TextosPublicarVaga.RATEIO, estado.participaRateio, estado.podeEditar, acoes.aoAlternarRateio)
                Campo(
                    rotulo = TextosPublicarVaga.OBSERVACOES,
                    valor = estado.observacoes,
                    aoMudar = acoes.aoEditarObservacoes,
                    erro = estado.errosDeCampo[CampoPublicacao.OBSERVACOES],
                    habilitado = estado.podeEditar,
                    ajuda = TextosPublicarVaga.OBSERVACOES_AJUDA,
                    umaLinha = false,
                )
            }

            // Resultado
            estado.erro?.let { erro ->
                Text(
                    text = erro.mensagem,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                )
            }
            if (estado.pendente != null && !estado.enviando && !estado.concluida) {
                Text(
                    text = TextosPublicarVaga.PENDENTE,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
            }
            if (estado.concluida) {
                Text(
                    text = TextosPublicarVaga.CONCLUIDA,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
            }

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                BotaoPrimario(
                    texto = when {
                        estado.enviando -> TextosPublicarVaga.PUBLICANDO
                        estado.pendente != null -> TextosPublicarVaga.TENTAR_NOVAMENTE
                        else -> TextosPublicarVaga.PUBLICAR
                    },
                    aoClicar = acoes.aoPublicar,
                    habilitado = !estado.enviando && !estado.concluida,
                    modifier = Modifier.weight(1f),
                )
                if (estado.enviando) CircularProgressIndicator(modifier = Modifier.size(24.dp))
            }
        }
    }

    if (seletorDeFuncaoAberto) {
        AlertDialog(
            onDismissRequest = { seletorDeFuncaoAberto = false },
            title = { Text(text = TextosPublicarVaga.FUNCAO_ESCOLHA, modifier = Modifier.semantics { heading() }) },
            text = {
                LazyColumn(modifier = Modifier.selectableGroup()) {
                    items(estado.funcoes, key = { it.id }) { funcao ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                                .selectable(
                                    selected = estado.funcaoId == funcao.id,
                                    role = Role.RadioButton,
                                    onClick = {
                                        acoes.aoEscolherFuncao(funcao.id)
                                        seletorDeFuncaoAberto = false
                                    },
                                ),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                        ) {
                            RadioButton(selected = estado.funcaoId == funcao.id, onClick = null)
                            Column {
                                Text(text = funcao.nome, style = MaterialTheme.typography.bodyLarge)
                                Text(
                                    text = funcao.categoria,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(
                    onClick = { seletorDeFuncaoAberto = false },
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosPublicarVaga.CANCELAR) }
            },
        )
    }
}

@Composable
private fun Titulo(texto: String) {
    Text(text = texto, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
}

@Composable
private fun TextoDeErro(texto: String) {
    Text(text = texto, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
}

@Composable
private fun OpcaoDeModo(
    rotulo: String,
    explicacao: String,
    selecionado: Boolean,
    habilitado: Boolean,
    aoEscolher: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
            .selectable(selected = selecionado, enabled = habilitado, role = Role.RadioButton, onClick = aoEscolher),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
    ) {
        // O clique é do Row (selectable): o botão de rádio só reflete o estado.
        RadioButton(selected = selecionado, onClick = null, enabled = habilitado)
        Column {
            Text(text = rotulo, style = MaterialTheme.typography.bodyLarge)
            Text(text = explicacao, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun LinhaComChave(rotulo: String, ligada: Boolean, habilitada: Boolean, aoMudar: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
            .toggleable(value = ligada, enabled = habilitada, role = Role.Switch, onValueChange = aoMudar),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(text = rotulo, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        Switch(checked = ligada, onCheckedChange = null, enabled = habilitada)
    }
}

/** Data e hora de um instante, cada uma num botão que abre o seletor do Material 3. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SeletorDeInstante(
    titulo: String,
    rotuloData: String,
    rotuloHora: String,
    instante: Instant,
    erro: String?,
    habilitado: Boolean,
    aoMudar: (Instant) -> Unit,
) {
    var escolhendoData by rememberSaveable { mutableStateOf(false) }
    var escolhendoHora by rememberSaveable { mutableStateOf(false) }
    val data = formatarData(instante)
    val hora = formatarHora(instante)

    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
        Text(text = titulo, style = MaterialTheme.typography.labelLarge)
        Row(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
            BotaoSecundario(
                texto = data,
                aoClicar = { escolhendoData = true },
                habilitado = habilitado,
                modifier = Modifier
                    .weight(1f)
                    .semantics { contentDescription = "$rotuloData: $data" },
            )
            BotaoSecundario(
                texto = hora,
                aoClicar = { escolhendoHora = true },
                habilitado = habilitado,
                modifier = Modifier
                    .weight(1f)
                    .semantics { contentDescription = "$rotuloHora: $hora" },
            )
        }
        erro?.let { TextoDeErro(it) }
    }

    if (escolhendoData) {
        val estadoDoSeletor = rememberDatePickerState(initialSelectedDateMillis = dataParaSeletorUtcMs(instante))
        DatePickerDialog(
            onDismissRequest = { escolhendoData = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        estadoDoSeletor.selectedDateMillis?.let { aoMudar(trocarData(instante, it)) }
                        escolhendoData = false
                    },
                ) { Text(TextosPublicarVaga.CONFIRMAR) }
            },
            dismissButton = { TextButton(onClick = { escolhendoData = false }) { Text(TextosPublicarVaga.CANCELAR) } },
        ) {
            DatePicker(state = estadoDoSeletor, title = { Text(rotuloData, modifier = Modifier.padding(FrilaEspacamento.medio)) })
        }
    }

    if (escolhendoHora) {
        val local = instante.atZone(FUSO_DA_VAGA)
        val estadoDoSeletor = rememberTimePickerState(initialHour = local.hour, initialMinute = local.minute, is24Hour = true)
        AlertDialog(
            onDismissRequest = { escolhendoHora = false },
            title = { Text(rotuloHora, modifier = Modifier.semantics { heading() }) },
            text = { TimePicker(state = estadoDoSeletor) },
            confirmButton = {
                TextButton(
                    onClick = {
                        aoMudar(trocarHora(instante, estadoDoSeletor.hour, estadoDoSeletor.minute))
                        escolhendoHora = false
                    },
                ) { Text(TextosPublicarVaga.CONFIRMAR) }
            },
            dismissButton = { TextButton(onClick = { escolhendoHora = false }) { Text(TextosPublicarVaga.CANCELAR) } },
        )
    }
}

@Composable
private fun Campo(
    rotulo: String,
    valor: String,
    aoMudar: (String) -> Unit,
    erro: String?,
    habilitado: Boolean,
    modifier: Modifier = Modifier,
    ajuda: String? = null,
    teclado: KeyboardType = KeyboardType.Text,
    umaLinha: Boolean = true,
) {
    OutlinedTextField(
        value = valor,
        onValueChange = aoMudar,
        enabled = habilitado,
        label = { Text(rotulo) },
        isError = erro != null,
        supportingText = (erro ?: ajuda)?.let { texto -> { Text(texto) } },
        singleLine = umaLinha,
        keyboardOptions = KeyboardOptions(keyboardType = teclado),
        modifier = modifier.fillMaxWidth(),
    )
}
