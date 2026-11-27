package br.com.frila.feature.turnos.contratante

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.LinkFrila
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.dominio.modelo.MotivoDeCancelamentoDaCasa
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.LinhaDeEtapas
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.delay

/** Tudo o que a tela pode pedir ao [AcompanhamentoContratanteViewModel] e a quem a abriu. */
data class AcoesTurnoDoContratante(
    val aoConfirmarPresenca: () -> Unit = {},
    val aoPedirCancelamento: () -> Unit = {},
    val aoDesistir: () -> Unit = {},
    /** Confirma o cancelamento com o motivo da folha (o ViewModel sabe qual é); sem motivo, ou "Outro motivo" sem detalhe, não envia. */
    val aoConfirmarCancelamento: () -> Unit = {},
    val aoEscolherMotivoDoCancelamento: (MotivoDeCancelamentoDaCasa) -> Unit = {},
    val aoMudarDetalhesDoCancelamento: (String) -> Unit = {},
    val aoVoltar: () -> Unit = {},
    /** L2-2: abrir a pergunta "Reabrir a vaga?", confirmá-la e desistir dela. */
    val aoPedirReabertura: () -> Unit = {},
    val aoConfirmarReabertura: () -> Unit = {},
    val aoDesistirDaReabertura: () -> Unit = {},
    /**
     * C0-9: denunciar o profissional deste turno (id do perfil público, id do turno), como o iOS
     * (`TelaTurnoDoContratante.swift:360`). Nulo esconde o botão.
     */
    val aoDenunciarProfissional: ((profissionalId: String, turnoId: String) -> Unit)? = null,
    /** Pedir ajuda com este turno (relato de ocorrência, RF12/RN15), como a folha de suporte do iOS. Nulo esconde o botão. */
    val aoPedirSuporte: ((turnoId: String) -> Unit)? = null,
    /** Item #27 da Paridade: avaliar o profissional pela casa. Nulo esconde o cartão. */
    val aoAvaliarTurno: ((turnoId: String) -> Unit)? = null,
)

/** Liga o [AcompanhamentoContratanteViewModel] ao [ConteudoTurnoDoContratante]. */
@Composable
fun TelaTurnoDoContratante(
    viewModel: AcompanhamentoContratanteViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoDenunciarProfissional: ((profissionalId: String, turnoId: String) -> Unit)? = null,
    aoPedirSuporte: ((turnoId: String) -> Unit)? = null,
    /** L1-5: nulo (chave `checkin_por_codigo` desligada, ou ainda sem fiação) esconde o código de chegada. */
    codigoDaCasa: CodigoDaCasaViewModel? = null,
    /** O que o app põe depois da chegada e antes das ações de risco (incluir na equipe de confiança). Nulo não põe nada. */
    depoisDaChegada: (@Composable () -> Unit)? = null,
    aoAvaliarTurno: ((turnoId: String) -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsState()
    ConteudoTurnoDoContratante(
        estado = estado,
        acoes = AcoesTurnoDoContratante(
            aoConfirmarPresenca = { viewModel.confirmarPresenca() },
            aoVoltar = aoVoltar,
            aoPedirCancelamento = viewModel::pedirCancelamento,
            aoDesistir = viewModel::desistir,
            aoConfirmarCancelamento = { viewModel.confirmarCancelamento() },
            aoEscolherMotivoDoCancelamento = viewModel::escolherMotivoDoCancelamento,
            aoMudarDetalhesDoCancelamento = viewModel::mudarDetalhesDoCancelamento,
            aoPedirReabertura = viewModel::pedirReabertura,
            aoConfirmarReabertura = { viewModel.confirmarReabertura() },
            aoDesistirDaReabertura = viewModel::desistirDaReabertura,
            aoDenunciarProfissional = aoDenunciarProfissional,
            aoPedirSuporte = aoPedirSuporte,
            aoAvaliarTurno = aoAvaliarTurno,
        ),
        modifier = modifier,
        cartaoDoCodigo = codigoDaCasa?.let { codigo -> { CartaoDoCodigoDaCasa(codigo) } },
        depoisDaChegada = depoisDaChegada,
    )
}

/**
 * Turno visto pela casa (UC05, UC07; paridade com `TelaTurnoDoContratante.swift`): tela em andamento, espelho da
 * do profissional. O cartão de status diz a etapa (selo e linha de etapas), a função, o horário e o local; o
 * profissional confirmado vem logo depois; e a chegada muda com o que o painel sabe: a caminho, atraso de 15
 * minutos, check-in manual esperando confirmação (o único primário da tela, no rodapé) ou presença verificada.
 * Ações de risco (reabrir a vaga, denunciar) ficam no fim, como ação discreta.
 */
@Composable
fun ConteudoTurnoDoContratante(
    estado: EstadoTurnoDoContratante,
    acoes: AcoesTurnoDoContratante,
    modifier: Modifier = Modifier,
    cartaoDoCodigo: (@Composable () -> Unit)? = null,
    depoisDaChegada: (@Composable () -> Unit)? = null,
) {
    // A folha de motivos substitui o corpo (como a tela de cancelar a vaga) em vez de abrir uma janela: assim a tela de baixo não fica
    // focável por baixo da folha, e o campo do detalhe vive na mesma composição.
    if (estado.pedindoCancelamento) {
        FolhaDeMotivosDoCancelamento(estado, acoes, modifier)
    } else {
        CorpoDoTurnoDoContratante(estado, acoes, modifier, cartaoDoCodigo, depoisDaChegada)
    }
}

@Composable
private fun CorpoDoTurnoDoContratante(
    estado: EstadoTurnoDoContratante,
    acoes: AcoesTurnoDoContratante,
    modifier: Modifier = Modifier,
    cartaoDoCodigo: (@Composable () -> Unit)? = null,
    depoisDaChegada: (@Composable () -> Unit)? = null,
) {
    val contexto = estado.contexto
    val pendente = estado.presenca == PresencaDoTurno.CHECKIN_MANUAL_PENDENTE && contexto.estadoDaPosicao != "cancelada"
    // Erro da confirmação fica junto ao botão que o disparou; o resto (resultado, ou erro sem botão) vai no conteúdo.
    val avisoNoRodape = estado.aviso?.takeIf { it.erro && pendente }
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = acoes.aoVoltar) },
        bottomBar = {
            if (pendente) {
                RodapeAncorado {
                    avisoNoRodape?.let { MensagemJuntoAoBotao(it.mensagem) }
                    BotaoPrimario(
                        texto = if (estado.enviando) TextosTurnoDoContratante.CONFIRMANDO else TextosTurnoDoContratante.CONFIRMAR_PRESENCA,
                        aoClicar = acoes.aoConfirmarPresenca,
                        habilitado = estado.podeConfirmar,
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
            TituloDaTela(TextosTurnoDoContratante.TITULO)
            CartaoDeStatus(estado)

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosTurnoDoContratante.PROFISSIONAL)
                CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                    val profissional = contexto.profissional
                    if (profissional == null) {
                        Text(text = TextosTurnoDoContratante.SEM_PROFISSIONAL, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                            Text(text = profissional.nome, style = FrilaTipo.nome, color = FrilaTema.cores.tinta)
                            profissional.funcoes?.takeIf { it.isNotEmpty() }?.let {
                                Text(
                                    text = TextosTurnoDoContratante.FUNCOES.format(it.joinToString(", ")),
                                    style = FrilaTipo.apoio,
                                    color = FrilaTema.cores.tintaSuave,
                                )
                            }
                        }
                    }
                }
            }

            Chegada(estado, cartaoDoCodigo)

            estado.aviso?.takeIf { it != avisoNoRodape }?.let { aviso ->
                AvisoFrila(tom = if (aviso.erro) TomAviso.ERRO else TomAviso.INFORMATIVO, mensagem = aviso.mensagem)
            }
            estado.avisoDaReabertura?.let { aviso ->
                AvisoFrila(tom = if (aviso.erro) TomAviso.ERRO else TomAviso.INFORMATIVO, mensagem = aviso.mensagem)
            }

            depoisDaChegada?.invoke()

            // Com a tela aberta, espera o fim previsto e recompõe, para o aviso dar lugar ao botão sem reabrir o turno (como o iOS).
            // O tique só força a releitura: quem decide é sempre `agora()`; se a espera acordar cedo, espera de novo.
            val liberaEm = estado.liberacaoDaAvaliacao
            var tique by remember { mutableIntStateOf(0) }
            LaunchedEffect(liberaEm, tique) {
                if (liberaEm != null) {
                    delay(Duration.between(estado.agora(), liberaEm).toMillis().coerceAtLeast(0) + 1)
                    tique++
                }
            }
            if (acoes.aoAvaliarTurno != null && liberaEm != null) {
                AvisoFrila(
                    tom = TomAviso.INFORMATIVO,
                    mensagem = TextosTurnoDoContratante.AVALIACAO_LIBERA_AS.format(hora(liberaEm)),
                    modifier = Modifier.testTag("aviso-avaliacao-libera"),
                )
            }
            if (acoes.aoAvaliarTurno != null && estado.presenca == PresencaDoTurno.VERIFICADA &&
                (estado.jaAvaliado || estado.podeAvaliar)
            ) {
                CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                        if (estado.jaAvaliado) {
                            // A casa já avaliou (o servidor, ou a fila offline): sem a pergunta, só o que ela respondeu e o caminho para rever.
                            Text(
                                text = TextosDaAvaliacaoDaCasa.status(estado.respostaDaAvaliacao),
                                style = FrilaTipo.corpo,
                                color = FrilaTema.cores.tinta,
                                modifier = Modifier.testTag("texto-status-avaliacao"),
                            )
                            BotaoSecundario(
                                texto = TextosDaAvaliacaoDaCasa.VER_AVALIACAO,
                                aoClicar = { acoes.aoAvaliarTurno.invoke(contexto.turnoId) },
                                modifier = Modifier.fillMaxWidth().testTag("botao-ver-avaliacao"),
                            )
                        } else {
                            Text(
                                text = "Como foi sua experiência no turno?",
                                style = FrilaTipo.corpo,
                                color = FrilaTema.cores.tinta,
                            )
                            BotaoSecundario(
                                texto = "Avaliar turno",
                                aoClicar = { acoes.aoAvaliarTurno.invoke(contexto.turnoId) },
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                }
            }

            // TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
            if (estado.podeCancelar || estado.cancelando) {
                TextButton(onClick = acoes.aoPedirCancelamento, enabled = estado.podeCancelar,
                    modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo)) {
                    Text(if (estado.cancelando) "Cancelando…" else "Cancelar posição")
                }
            }
            if (!estado.pedindoCancelamento) estado.avisoDoCancelamento?.let { Text(it) }

            // Ações de risco no fim da tela, uma por linha.
            val reabrirVisivel = estado.presenca == PresencaDoTurno.EM_ATRASO &&
                (estado.podeReabrir || (estado.reaberturaDisponivel && estado.reabrindo))
            val denunciar = acoes.aoDenunciarProfissional
            val profissional = contexto.profissional
            val pedirSuporte = acoes.aoPedirSuporte
            if (reabrirVisivel || pedirSuporte != null || (denunciar != null && profissional != null)) {
                Spacer(Modifier.height(FrilaEspacamento.item))
                if (reabrirVisivel) {
                    AcaoDiscreta(
                        texto = if (estado.reabrindo) TextosTurnoDoContratante.REABRINDO else TextosTurnoDoContratante.REABRIR_VAGA,
                        aoClicar = acoes.aoPedirReabertura,
                        habilitado = estado.podeReabrir,
                    )
                }
                if (pedirSuporte != null) {
                    AcaoDiscreta(
                        texto = TextosTurnoDoContratante.PEDIR_AJUDA,
                        aoClicar = { pedirSuporte(contexto.turnoId) },
                    )
                }
                if (denunciar != null && profissional != null) {
                    AcaoDiscreta(
                        texto = TextosTurnoDoContratante.DENUNCIAR,
                        aoClicar = { denunciar(profissional.id, contexto.turnoId) },
                        modifier = Modifier.semantics {
                            contentDescription = TextosTurnoDoContratante.DENUNCIAR_ROTULO.format(profissional.nome)
                        },
                    )
                }
            }
        }
    }

    if (estado.pedindoReabertura) {
        AlertDialog(
            onDismissRequest = acoes.aoDesistirDaReabertura,
            containerColor = FrilaTema.cores.superficie,
            title = {
                Text(
                    text = TextosTurnoDoContratante.REABRIR_PERGUNTA,
                    style = FrilaTipo.nome,
                    color = FrilaTema.cores.tinta,
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = {
                Text(
                    text = TextosTurnoDoContratante.REABRIR_AVISO.format(contexto.profissional?.nome ?: "o profissional"),
                    style = FrilaTipo.corpo,
                    color = FrilaTema.cores.tinta,
                )
            },
            confirmButton = {
                TextButton(onClick = acoes.aoConfirmarReabertura, modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo)) {
                    Text(TextosTurnoDoContratante.REABRIR_CONFIRMAR, style = FrilaTipo.rotuloSecundario, color = FrilaTema.cores.tinta)
                }
            },
            dismissButton = {
                TextButton(onClick = acoes.aoDesistirDaReabertura, modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo)) {
                    Text(TextosTurnoDoContratante.ESPERAR, style = FrilaTipo.rotuloSecundario, color = FrilaTema.cores.tintaSuave)
                }
            },
        )
    }
}

/** O selo e a etapa do cartão de status, pelo que o painel sabe da chegada. */
private data class EtapaDoTurno(val selo: String, val estilo: EstiloDoSelo, val atual: Int)

private fun etapaDe(presenca: PresencaDoTurno): EtapaDoTurno = when (presenca) {
    PresencaDoTurno.AGUARDANDO, PresencaDoTurno.EM_ATRASO ->
        EtapaDoTurno(TextosTurnoDoContratante.ETAPA_CONFIRMADO, EstiloDoSelo.CONFIRMADO, 0)
    PresencaDoTurno.A_CAMINHO -> EtapaDoTurno(TextosTurnoDoContratante.ETAPA_A_CAMINHO, EstiloDoSelo.ANDAMENTO, 1)
    PresencaDoTurno.CHECKIN_MANUAL_PENDENTE ->
        EtapaDoTurno(TextosTurnoDoContratante.SELO_PRESENCA_MARCADA, EstiloDoSelo.ANDAMENTO, 2)
    PresencaDoTurno.VERIFICADA -> EtapaDoTurno(TextosTurnoDoContratante.VERIFICADA, EstiloDoSelo.ANDAMENTO, 2)
    PresencaDoTurno.NAO_VERIFICADA -> EtapaDoTurno(TextosTurnoDoContratante.NAO_VERIFICADA, EstiloDoSelo.CONTORNO, 2)
}

/** Cartão de status do turno: selo, função, horário, local e a linha de etapas (como T4 e T8 do profissional). */
@Composable
private fun CartaoDeStatus(estado: EstadoTurnoDoContratante) {
    val contexto = estado.contexto
    val etapa = etapaDe(estado.presenca)
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            SeloDeStatus(texto = etapa.selo, estilo = etapa.estilo)
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                Text(text = contexto.funcao, style = FrilaTipo.nome, color = FrilaTema.cores.tinta)
                horario(contexto.inicio, contexto.fim)?.let { Text(text = it, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta) }
                Text(text = contexto.local, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            }
            Spacer(Modifier.height(FrilaEspacamento.item))
            LinhaDeEtapas(
                etapas = listOf(
                    TextosTurnoDoContratante.ETAPA_CONFIRMADO,
                    TextosTurnoDoContratante.ETAPA_A_CAMINHO,
                    TextosTurnoDoContratante.ETAPA_PRESENCA,
                    TextosTurnoDoContratante.ETAPA_CONCLUIDO,
                ),
                atual = etapa.atual,
            )
        }
    }
}

/** O bloco "Chegada". Presença verificada ou não verificada já está dita no selo do cartão de status. */
@Composable
private fun Chegada(estado: EstadoTurnoDoContratante, cartaoDoCodigo: (@Composable () -> Unit)?) {
    val contexto = estado.contexto
    val nome = contexto.profissional?.nome ?: ""
    if (estado.presenca == PresencaDoTurno.VERIFICADA || estado.presenca == PresencaDoTurno.NAO_VERIFICADA) return
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        RotuloDeGrupo(TextosTurnoDoContratante.CHEGADA)
        when (estado.presenca) {
            PresencaDoTurno.AGUARDANDO -> CorpoDaChegada(TextosTurnoDoContratante.AGUARDANDO)
            PresencaDoTurno.A_CAMINHO ->
                CorpoDaChegada(TextosTurnoDoContratante.A_CAMINHO.format(nome, contexto.aCaminhoEm?.let(::hora).orEmpty()))
            PresencaDoTurno.EM_ATRASO -> AvisoFrila(tom = TomAviso.ALERTA, mensagem = TextosTurnoDoContratante.EM_ATRASO)
            PresencaDoTurno.CHECKIN_MANUAL_PENDENTE -> {
                CorpoDaChegada(
                    contexto.checkinEm
                        ?.let { TextosTurnoDoContratante.CHECKIN_PENDENTE_COM_HORA.format(nome, hora(it)) }
                        ?: TextosTurnoDoContratante.CHECKIN_PENDENTE.format(nome),
                )
                cartaoDoCodigo?.invoke()
            }
            PresencaDoTurno.VERIFICADA, PresencaDoTurno.NAO_VERIFICADA -> Unit
        }
    }
}

@Composable
private fun CorpoDaChegada(texto: String) {
    Text(text = texto, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
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

/** Os textos da folha de cancelamento da posição (os de `TextosCancelarVaga`, no mesmo tom; o efeito do cancelamento vem no PR seguinte). */
internal object TextosCancelarPosicao {
    const val TITULO = "Cancelar posição"
    const val MOTIVO_TITULO = "Qual é o motivo?"
    const val DETALHES_OPCIONAIS = "Quer explicar melhor? (opcional)"
    const val DETALHES_OBRIGATORIOS = "Descreva o motivo (pelo menos 3 caracteres)"
    const val CONFIRMAR = "Confirmar cancelamento"
    const val VOLTAR = "Voltar"
}

/** A folha de motivos da casa ao cancelar a posição (paridade com `CancelamentoViewModel` do iOS): os motivos da casa e o detalhe. */
@Composable
private fun FolhaDeMotivosDoCancelamento(estado: EstadoTurnoDoContratante, acoes: AcoesTurnoDoContratante, modifier: Modifier = Modifier) {
    BackHandler(onBack = acoes.aoDesistir)
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(FrilaTema.cores.fundo)
            .verticalScroll(rememberScrollState())
            .padding(FrilaEspacamento.grupo),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
    ) {
        TituloDaTela(TextosCancelarPosicao.TITULO)
        FrilaGrupoDeLinhas(titulo = TextosCancelarPosicao.MOTIVO_TITULO) {
            MotivoDeCancelamentoDaCasa.entries.forEach { motivo ->
                linha {
                    FrilaLinhaDeOpcao(
                        titulo = motivo.texto,
                        marcada = estado.motivoDoCancelamento == motivo,
                        aoClicar = { acoes.aoEscolherMotivoDoCancelamento(motivo) },
                    )
                }
            }
        }
        CampoDeTexto(
            valor = estado.detalhesDoCancelamento,
            aoMudar = acoes.aoMudarDetalhesDoCancelamento,
            rotulo = if (estado.motivoDoCancelamento?.exigeDetalhes == true) {
                TextosCancelarPosicao.DETALHES_OBRIGATORIOS
            } else {
                TextosCancelarPosicao.DETALHES_OPCIONAIS
            },
            umaLinha = false,
            linhasMinimas = 3,
        )
        estado.avisoDoCancelamento?.let { Text(it, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta) }
        BotaoPrimario(
            texto = TextosCancelarPosicao.CONFIRMAR,
            aoClicar = acoes.aoConfirmarCancelamento,
            habilitado = estado.motivoCompletoDoCancelamento != null,
            modifier = Modifier.fillMaxWidth(),
        )
        LinkFrila(texto = TextosCancelarPosicao.VOLTAR, aoClicar = acoes.aoDesistir)
    }
}

/** Os textos do cartão de avaliação da casa quando o turno já foi avaliado (paridade com `TextosDoProfissional.Avaliacao` do iOS). */
internal object TextosDaAvaliacaoDaCasa {
    const val VER_AVALIACAO = "Ver avaliação"

    fun status(resposta: Boolean?): String = when (resposta) {
        true -> "Turno avaliado · Resposta: Sim"
        false -> "Turno avaliado · Resposta: Não"
        null -> "Turno avaliado"
    }
}
