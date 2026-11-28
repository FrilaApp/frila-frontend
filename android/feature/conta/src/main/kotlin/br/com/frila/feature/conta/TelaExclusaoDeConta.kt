package br.com.frila.feature.conta

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** Liga o [ExclusaoDeContaViewModel] ao [ConteudoExclusaoDeConta]. */
@Composable
fun TelaExclusaoDeConta(
    viewModel: ExclusaoDeContaViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    // Só lê e mostra os turnos futuros; a exclusão não depende dessa leitura.
    LaunchedEffect(viewModel) { viewModel.carregarTurnos() }
    ConteudoExclusaoDeConta(
        estado = estado,
        aoAlterarConfirmacao = viewModel::alterarConfirmacao,
        aoExcluir = { viewModel.confirmarExclusao() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

/**
 * Exclusão de conta em tela cheia (RF25/UC16, paridade com `TelaExclusaoDeConta.swift`): o que
 * acontece, a caixa de confirmação e um diálogo final antes do pedido. O botão só habilita depois
 * da caixa marcada. Prazo de até 15 dias para as cópias de backup (contrato `ExclusaoDeConta`).
 *
 * Tela de leitura com uma ação de risco: sem laranja. "Excluir minha conta definitivamente" é uma ação
 * discreta no fim da tela, e o diálogo nativo escreve a consequência antes de qualquer pedido. Sem desenho
 * do Fabrício (extrapolada do mesmo sistema).
 */
@Composable
fun ConteudoExclusaoDeConta(
    estado: EstadoExclusaoDeConta,
    aoAlterarConfirmacao: (Boolean) -> Unit,
    aoExcluir: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    var dialogoAberto by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { BarraDeVoltar(aoVoltar = aoVoltar, habilitado = !estado.excluindo) },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    top = FrilaEspacamento.item,
                    bottom = FrilaEspacamento.grupo,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            val resultado = estado.resultado
            if (resultado != null) {
                TituloDaTela(
                    texto = TextosExclusaoDeConta.CONCLUIDA_TITULO,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
                Text(
                    text = TextosExclusaoDeConta.concluidaResumo(
                        turnosCancelados = resultado.turnosCancelados,
                        dadosApagadosAte = resultado.dadosApagadosAte,
                    ),
                    style = FrilaTipo.corpo,
                    color = cores.tinta,
                )
                return@Column
            }

            TituloDaTela(TextosExclusaoDeConta.TITULO)
            AvisoFrila(tom = TomAviso.ALERTA, mensagem = TextosExclusaoDeConta.AVISO)

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosExclusaoDeConta.SECAO_O_QUE_ACONTECE)
                Consequencia(TextosExclusaoDeConta.CONSEQUENCIA_ANONIMIZACAO)
                Consequencia(TextosExclusaoDeConta.CONSEQUENCIA_TURNOS)
                Consequencia(TextosExclusaoDeConta.CONSEQUENCIA_PRAZO)
            }

            SecaoTurnosFuturos(estado.turnosFuturos)

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
                    .toggleable(
                        value = estado.confirmouConsequencias,
                        enabled = !estado.excluindo,
                        role = Role.Checkbox,
                        onValueChange = aoAlterarConfirmacao,
                    ),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                // O clique é do Row (toggleable): a caixa só reflete o estado.
                Checkbox(checked = estado.confirmouConsequencias, onCheckedChange = null)
                Text(
                    text = TextosExclusaoDeConta.CONFIRMACAO_CHECK,
                    style = FrilaTipo.corpo,
                    color = cores.tinta,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                estado.mensagemErro?.let { mensagem ->
                    MensagemJuntoAoBotao(
                        texto = mensagem,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
                AcaoDiscreta(
                    texto = if (estado.excluindo) TextosExclusaoDeConta.EXCLUINDO else TextosExclusaoDeConta.BOTAO_EXCLUIR,
                    aoClicar = { dialogoAberto = true },
                    habilitado = estado.podeExcluir,
                )
            }
        }
    }

    if (dialogoAberto && estado.podeExcluir) {
        AlertDialog(
            onDismissRequest = { dialogoAberto = false },
            containerColor = cores.superficie,
            title = {
                Text(
                    text = TextosExclusaoDeConta.DIALOGO_TITULO,
                    style = FrilaTipo.nome,
                    color = cores.tinta,
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = {
                Text(text = TextosExclusaoDeConta.DIALOGO_MENSAGEM, style = FrilaTipo.corpo, color = cores.tintaSuave)
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        dialogoAberto = false
                        aoExcluir()
                    },
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) {
                    Text(TextosExclusaoDeConta.DIALOGO_CONFIRMAR, style = FrilaTipo.rotuloSecundario, color = cores.tinta)
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { dialogoAberto = false },
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) { Text(TextosExclusaoDeConta.CANCELAR, style = FrilaTipo.rotuloSecundario, color = cores.tinta) }
            },
        )
    }
}

/**
 * A barra de topo da tela (só o voltar, sem título), igual à `FrilaBarraDeTopo`, mas com o voltar que
 * desliga enquanto a exclusão roda. Para subir ao sistema: `FrilaBarraDeTopo` ganhar `voltarHabilitado`.
 */
@Composable
private fun BarraDeVoltar(aoVoltar: () -> Unit, habilitado: Boolean) {
    val cores = FrilaTema.cores
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(cores.fundo)
            // O app desenha de borda a borda: a barra recua para baixo da barra de status, como a `FrilaBarraDeTopo`.
            .windowInsetsPadding(WindowInsets.statusBars)
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .padding(horizontal = FrilaEspacamento.compacto),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = aoVoltar, enabled = habilitado, modifier = Modifier.size(FrilaMetricas.alvoMinimo)) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                contentDescription = TextosExclusaoDeConta.ROTULO_VOLTAR,
                tint = if (habilitado) cores.tinta else cores.tintaSuave,
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

@Composable
private fun Consequencia(texto: String) {
    Text(
        text = "• $texto",
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
    )
}

private val FORMATO_DATA_HORA: DateTimeFormatter =
    DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm").withZone(ZoneId.of("America/Sao_Paulo"))
private val FORMATO_HORA: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.of("America/Sao_Paulo"))

/** "20/11/2026 18:00 – 23:00": o dia e a hora de início, e a hora do fim (se o fim cair em outro dia, com a data também). */
internal fun intervaloDoTurno(inicio: Instant, fim: Instant): String {
    val zona = ZoneId.of("America/Sao_Paulo")
    val mesmoDia = inicio.atZone(zona).toLocalDate() == fim.atZone(zona).toLocalDate()
    return FORMATO_DATA_HORA.format(inicio) + " – " + (if (mesmoDia) FORMATO_HORA else FORMATO_DATA_HORA).format(fim)
}

/**
 * Os turnos futuros que a exclusão cancelaria (contrato: cancela e avisa as contrapartes; do profissional e, para contratante, das casas). Só lista; nunca bloqueia nada:
 * lista indisponível vira um aviso e a exclusão segue liberada. Sem consulta ([TurnosFuturosDaExclusao.NaoConsultados]), nada.
 */
@Composable
private fun SecaoTurnosFuturos(turnos: TurnosFuturosDaExclusao) {
    val cores = FrilaTema.cores
    if (turnos == TurnosFuturosDaExclusao.NaoConsultados) return
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        RotuloDeGrupo(TextosExclusaoDeConta.TITULO_TURNOS_FUTUROS)
        when (turnos) {
            TurnosFuturosDaExclusao.NaoConsultados -> Unit
            TurnosFuturosDaExclusao.Carregando ->
                Text(TextosExclusaoDeConta.CARREGANDO_TURNOS, style = FrilaTipo.apoio, color = cores.tintaSuave)
            TurnosFuturosDaExclusao.Indisponivel ->
                AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = TextosExclusaoDeConta.LISTA_TURNOS_INDISPONIVEL)
            is TurnosFuturosDaExclusao.Lista -> {
                if (turnos.limitada) {
                    AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = TextosExclusaoDeConta.LISTA_LIMITADA)
                }
                if (turnos.turnos.isEmpty()) {
                    Text(TextosExclusaoDeConta.SEM_TURNOS_FUTUROS, style = FrilaTipo.apoio, color = cores.tintaSuave)
                } else {
                    turnos.turnos.forEach { turno ->
                        Column(
                            modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) { },
                            verticalArrangement = Arrangement.spacedBy(2.dp),
                        ) {
                            Text(turno.funcao, style = FrilaTipo.nome, color = cores.tinta)
                            Text(turno.contraparte, style = FrilaTipo.apoio, color = cores.tintaSuave)
                            Text(intervaloDoTurno(turno.inicio, turno.fim), style = FrilaTipo.apoio, color = cores.tintaSuave)
                            Text(turno.local, style = FrilaTipo.apoio, color = cores.tintaSuave)
                        }
                    }
                }
            }
        }
    }
}

