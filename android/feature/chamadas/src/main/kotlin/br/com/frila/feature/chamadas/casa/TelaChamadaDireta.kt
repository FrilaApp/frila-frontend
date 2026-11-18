package br.com.frila.feature.chamadas.casa

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role as PapelDeAcessibilidade
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
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
 * A tela "Chamar profissional" (desenho do iOS `TelaChamadaDireta`): formulário curto com UM primário no rodapé.
 * Função, local da casa, início e término, responsável, valor total e a confirmação dele, inclusos e recado; o botão
 * desligado diz o que falta, e o aviso J7 (3ª chamada em 7 dias) vem num diálogo. Enviada a chamada, mostra o resumo
 * e o caminho para acompanhar.
 */
@Composable
fun ConteudoChamadaDireta(
    tela: EstadoChamadaDireta,
    acoes: AcoesChamadaDireta,
    inicioMinimo: () -> Instant,
    faixaDoTermino: () -> ClosedRange<Instant>,
    modifier: Modifier = Modifier,
) {
    val resultado = tela.resultado
    val comFormulario = resultado == null && tela.recursoHabilitado
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = {
            FrilaBarraDeTopo(
                acoes = {
                    LinkFrila(
                        texto = TextosChamadaCasa.FECHAR,
                        aoClicar = acoes.aoFechar,
                        habilitado = !tela.enviando,
                        modifier = Modifier.padding(end = FrilaEspacamento.compacto),
                    )
                },
            )
        },
        bottomBar = {
            if (comFormulario) {
                RodapeAncorado {
                    tela.oQueFalta?.let { MensagemJuntoAoBotao(it) }
                    BotaoPrimario(
                        texto = if (tela.enviando) TextosChamadaCasa.CARREGANDO else TextosChamadaCasa.ENVIAR,
                        aoClicar = acoes.aoEnviar,
                        habilitado = tela.podeEnviar,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo)
                .padding(bottom = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            TituloDaTela(TextosChamadaCasa.TITULO_DA_FOLHA)
            if (tela.carregando) EstadoCarregando()
            tela.erro?.let { erro ->
                AvisoFrila(tom = TomAviso.ERRO, mensagem = erro)
                if (!tela.recursoHabilitado && !tela.carregando) {
                    BotaoSecundario(texto = TextosChamadaCasa.TENTAR_NOVAMENTE, aoClicar = acoes.aoTentarNovamente)
                }
            }
            if (resultado != null) {
                ResumoDaChamadaEnviada(tela = tela, aoAcompanhar = acoes.aoAcompanhar?.let { acompanhar -> { acompanhar(resultado.vagaId) } })
            } else if (tela.recursoHabilitado) {
                Campos(tela, acoes, inicioMinimo, faixaDoTermino)
            }
        }
    }

    if (tela.mostrarJ7) {
        AlertDialog(
            onDismissRequest = acoes.aoDispensarJ7,
            containerColor = FrilaTema.cores.superficie,
            title = {
                Text(
                    TextosChamadaCasa.J7_TITULO,
                    style = FrilaTipo.nome,
                    color = FrilaTema.cores.tinta,
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = { Text(TextosChamadaCasa.J7_MENSAGEM, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta) },
            confirmButton = {
                TextButton(onClick = acoes.aoConfirmarJ7, modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo)) {
                    Text(TextosChamadaCasa.J7_CONFIRMAR, style = FrilaTipo.rotuloSecundario, color = FrilaTema.cores.tinta)
                }
            },
            dismissButton = {
                TextButton(onClick = acoes.aoDispensarJ7, modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo)) {
                    Text(TextosChamadaCasa.CANCELAR, style = FrilaTipo.rotuloSecundario, color = FrilaTema.cores.tintaSuave)
                }
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
    CampoDeTexto(
        valor = tela.responsavel,
        aoMudar = acoes.aoMudarResponsavel,
        rotulo = TextosChamadaCasa.RESPONSAVEL,
        habilitado = editavel,
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
    )
    CampoDeTexto(
        valor = tela.valorTexto,
        aoMudar = acoes.aoMudarValor,
        rotulo = TextosChamadaCasa.VALOR_TOTAL,
        dica = TextosChamadaCasa.VALOR_EXEMPLO,
        habilitado = editavel,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
        acessorio = { Text(TextosChamadaCasa.MOEDA, style = FrilaTipo.corpo, color = FrilaTema.cores.tintaSuave) },
    )
    FrilaGrupoDeLinhas {
        linha { LinhaDeInterruptor(TextosChamadaCasa.CONFIRMAR_TOTAL, tela.totalConfirmado, editavel, acoes.aoConfirmarTotal) }
        linha { LinhaDeInterruptor(TextosChamadaCasa.INCLUI_REFEICAO, tela.refeicao, editavel, acoes.aoMudarRefeicao) }
        linha { LinhaDeInterruptor(TextosChamadaCasa.INCLUI_TRANSPORTE, tela.transporte, editavel, acoes.aoMudarTransporte) }
        linha { LinhaDeInterruptor(TextosChamadaCasa.EXIGE_MATERIAL_PROPRIO, tela.materialProprio, editavel, acoes.aoMudarMaterialProprio) }
    }
    CampoDeTexto(
        valor = tela.recado,
        aoMudar = acoes.aoMudarRecado,
        rotulo = TextosChamadaCasa.RECADO,
        habilitado = editavel,
        umaLinha = false,
        linhasMinimas = 3,
        erro = if (tela.recadoLongo) TextosChamadaCasa.RECADO_LONGO else null,
    )
}

@Composable
private fun LinhaDeLeitura(rotulo: String, valor: String) {
    Column(
        modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) { },
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        Text(rotulo, style = FrilaTipo.rotuloDeGrupo, color = FrilaTema.cores.tintaSuave)
        Text(valor, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
    }
}

@Composable
private fun SeletorDeFuncao(tela: EstadoChamadaDireta, aoEscolher: (String) -> Unit, editavel: Boolean) {
    var aberto by remember { mutableStateOf(false) }
    val atual = tela.funcoes.firstOrNull { it.id == tela.funcaoId }
    CampoDeEscolha(
        rotulo = TextosChamadaCasa.FUNCAO,
        valor = atual?.nome ?: "—",
        dica = "—",
        aberto = aberto && editavel,
        aoMudarAberto = { aberto = it },
        opcoes = tela.funcoes.map { funcao -> OpcaoDeEscolha(funcao.nome) { aoEscolher(funcao.id) } },
        modifier = Modifier.semantics { contentDescription = "${TextosChamadaCasa.FUNCAO}: ${atual?.nome.orEmpty()}" },
    )
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
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        Text(rotulo, style = FrilaTipo.rotuloDeGrupo, color = FrilaTema.cores.tintaSuave)
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
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .toggleable(value = ligado, enabled = editavel, role = PapelDeAcessibilidade.Switch, onValueChange = aoMudar)
            .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(rotulo, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta, modifier = Modifier.weight(1f))
        Switch(checked = ligado, onCheckedChange = null, enabled = editavel)
    }
}
