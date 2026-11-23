package br.com.frila.feature.turnos

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaSkeleton
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.MotivoCancelamento
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.localizacao.abrirConfiguracoesComFallback
import br.com.frila.core.localizacao.criarIntentConfiguracoesApp
import br.com.frila.core.localizacao.criarIntentConfiguracoesGps
import java.time.Instant
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive

/** Estados do turno em que o check-in ainda pode ser feito (RF13). */
private const val ESTADO_CHECKIN_DISPONIVEL = "confirmada"

/**
 * Meus Turnos (T7 do desenho): cada turno é um cartão de status com selo, casa, dia e horário, a linha de etapas e o
 * que a pessoa faz agora (avisar que está a caminho, fazer o check-in, digitar o código da casa, fazer o check-out,
 * avaliar). Cancelar e denunciar ficam no fim do cartão, em ação discreta. Só um botão laranja por cartão.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaMeusTurnos(
    viewModel: MeusTurnosViewModel,
    criarCheckinViewModel: @Composable (turno: ItemTurno) -> CheckinViewModel,
    modifier: Modifier = Modifier,
    aoAbrirAvaliacao: (turnoId: String) -> Unit = {},
    relogio: () -> Instant = { Instant.now() },
    /** C0-9: denunciar a casa do turno (id do perfil público, id do turno), como o iOS. Nulo esconde o botão. */
    aoDenunciarEstabelecimento: ((estabelecimentoId: String, turnoId: String) -> Unit)? = null,
    /** Pedir ajuda com o turno (relato de ocorrência, RF12/RN15), como a folha de suporte do iOS. Nulo esconde o botão. */
    aoPedirSuporte: ((turnoId: String) -> Unit)? = null,
    /** L2-1: "Estou a caminho" no turno confirmado. Nulo esconde o botão (a fiação é o L2-8); a regra da janela é do [podeAvisarACaminho]. */
    aoAvisarACaminho: ((turno: ItemTurno) -> Unit)? = null,
    /** Falso na tela raiz (aba "Meus turnos"): a aba já diz onde a pessoa está, e a lista é o primeiro elemento. */
    comTitulo: Boolean = true,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    var comprovanteParaExibir by remember { mutableStateOf<ComprovanteCheckin?>(null) }

    LaunchedEffect(estado.mensagemFeedback) {
        estado.mensagemFeedback?.let {
            snackbar.showSnackbar(it)
            viewModel.consumirFeedback()
        }
    }

    Scaffold(
        modifier = modifier,
        containerColor = FrilaTema.cores.fundo,
        snackbarHost = { SnackbarHost(snackbar) },
    ) { paddingInterno ->
        PullToRefreshBox(
            isRefreshing = estado.atualizando,
            onRefresh = viewModel::atualizar,
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .semantics {
                    contentDescription = if (estado.atualizando) "Atualizando turnos" else "Meus turnos"
                },
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                if (comTitulo) {
                    TituloDaTela(
                        texto = "Meus Turnos",
                        modifier = Modifier.padding(
                            start = FrilaEspacamento.grupo,
                            end = FrilaEspacamento.grupo,
                            top = FrilaEspacamento.bloco,
                        ),
                    )
                }
                // Agendados e Histórico: as duas faixas são um filtro da mesma lista, uma marcada por vez.
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item)
                        .selectableGroup(),
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                ) {
                    ChipFrila(
                        texto = "Agendados",
                        selecionado = estado.abaSelecionada == AbaDeTurnos.AGENDADOS,
                        aoClicar = { viewModel.aoSelecionarAba(AbaDeTurnos.AGENDADOS) },
                        escolhaUnica = true,
                    )
                    ChipFrila(
                        texto = "Histórico",
                        selecionado = estado.abaSelecionada == AbaDeTurnos.HISTORICO,
                        aoClicar = { viewModel.aoSelecionarAba(AbaDeTurnos.HISTORICO) },
                        escolhaUnica = true,
                    )
                }

                when (estado.status) {
                    StatusMeusTurnos.CARREGANDO -> SkeletonMeusTurnos()
                    StatusMeusTurnos.ERRO -> Erro(mensagem = estado.mensagemErro, aoTentarNovamente = viewModel::tentarNovamente)
                    StatusMeusTurnos.VAZIO -> Vazio()
                    StatusMeusTurnos.SUCESSO -> ListaDeTurnos(
                        itens = estado.itensDaAbaAtual,
                        criarCheckinViewModel = criarCheckinViewModel,
                        aoAbrirAvaliacao = aoAbrirAvaliacao,
                        aoCancelar = viewModel::abrirCancelamento,
                        aoExibirComprovante = { comprovanteParaExibir = it },
                        relogio = relogio,
                        abaHistorico = estado.abaSelecionada == AbaDeTurnos.HISTORICO,
                        carregandoMaisHistorico = estado.carregandoMaisHistorico,
                        aoCarregarMaisHistorico = { viewModel.carregarMaisHistorico() },
                        aoDenunciarEstabelecimento = aoDenunciarEstabelecimento,
                        aoPedirSuporte = aoPedirSuporte,
                        aoAvisarACaminho = aoAvisarACaminho,
                        avisandoACaminho = estado.avisandoACaminho,
                        erroACaminho = estado.erroACaminho,
                    )
                }
            }
        }
    }

    estado.cancelamento?.let { cancelamento ->
        DialogoCancelamentoTurno(
            estado = cancelamento,
            aoSelecionarMotivo = viewModel::selecionarMotivo,
            aoAtualizarDetalhes = viewModel::atualizarDetalhes,
            aoConfirmar = { viewModel.confirmarCancelamento() },
            aoVoltar = viewModel::fecharCancelamento,
        )
    }

    comprovanteParaExibir?.let { comprovante ->
        DialogoComprovanteCheckin(
            comprovante = comprovante,
            aoFechar = { comprovanteParaExibir = null },
        )
    }
}

@Composable
private fun ListaDeTurnos(
    itens: List<ItemTurno>,
    criarCheckinViewModel: @Composable (turno: ItemTurno) -> CheckinViewModel,
    aoAbrirAvaliacao: (turnoId: String) -> Unit,
    aoCancelar: (ItemTurno) -> Unit,
    aoExibirComprovante: (ComprovanteCheckin) -> Unit,
    relogio: () -> Instant = { Instant.now() },
    abaHistorico: Boolean = false,
    carregandoMaisHistorico: Boolean = false,
    aoCarregarMaisHistorico: () -> Unit = {},
    aoDenunciarEstabelecimento: ((estabelecimentoId: String, turnoId: String) -> Unit)? = null,
    aoPedirSuporte: ((turnoId: String) -> Unit)? = null,
    aoAvisarACaminho: ((turno: ItemTurno) -> Unit)? = null,
    avisandoACaminho: String? = null,
    erroACaminho: ErroDoACaminho? = null,
) {
    if (itens.isEmpty()) {
        Vazio()
        return
    }

    val listState = rememberLazyListState()

    // RF16: gatilho de rolagem infinita — quando faltam 2 itens para o fim da lista do
    // histórico, pede a próxima fatia. derivedStateOf evita recompor a cada frame de scroll.
    val deveCarregarMais by remember {
        derivedStateOf {
            val total = listState.layoutInfo.totalItemsCount
            val ultimoVisivel = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            total > 0 && ultimoVisivel >= total - 2
        }
    }

    LaunchedEffect(deveCarregarMais, abaHistorico) {
        if (deveCarregarMais && abaHistorico) {
            aoCarregarMaisHistorico()
        }
    }

    LazyColumn(
        state = listState,
        contentPadding = PaddingValues(
            start = FrilaEspacamento.grupo,
            end = FrilaEspacamento.grupo,
            top = FrilaEspacamento.item,
            bottom = FrilaEspacamento.grupo,
        ),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        modifier = Modifier.testTag("lista-de-turnos"),
    ) {
        items(itens, key = { it.turnoId }) { turno ->
            CartaoDoTurno(
                turno = turno,
                criarCheckinViewModel = criarCheckinViewModel,
                aoAbrirAvaliacao = aoAbrirAvaliacao,
                aoCancelar = aoCancelar,
                aoExibirComprovante = aoExibirComprovante,
                relogio = relogio,
                aoDenunciarEstabelecimento = aoDenunciarEstabelecimento,
                aoPedirSuporte = aoPedirSuporte,
                aoAvisarACaminho = aoAvisarACaminho,
                avisandoACaminho = avisandoACaminho,
                erroACaminho = erroACaminho,
            )
        }
        if (abaHistorico && carregandoMaisHistorico) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(FrilaEspacamento.item),
                    contentAlignment = Alignment.Center,
                ) {
                    IndicadorCarregando(modifier = Modifier.padding(FrilaEspacamento.junto))
                }
            }
        }
    }
}

/**
 * O estado da contagem até a janela de check-in do turno confirmado. Recalcula a cada segundo enquanto a janela não
 * abriu, e para quando ela abre ou o turno acaba.
 */
@Composable
private fun lembrarContagem(turno: ItemTurno, relogio: () -> Instant): EstadoContagemRegressiva {
    var estadoContagem by remember(turno.inicio, turno.fim) {
        mutableStateOf(CalculadorContagemRegressiva.calcular(turno.inicio, turno.fim, relogio()))
    }

    LaunchedEffect(turno.inicio, turno.fim) {
        while (isActive) {
            val novoEstado = CalculadorContagemRegressiva.calcular(turno.inicio, turno.fim, relogio())
            estadoContagem = novoEstado
            if (novoEstado !is EstadoContagemRegressiva.AguardandoJanela) break
            delay(1000L)
        }
    }
    return estadoContagem
}

/**
 * Um turno da lista: o cartão de status e, dentro dele, na ordem em que a pessoa precisa: avisar que está a caminho,
 * a presença (contagem, check-in, código da casa, check-out), a avaliação e as ações discretas (cancelar, denunciar).
 *
 * Laranja: um só botão por cartão. "Estou a caminho" vence enquanto é oferecido (e o check-in vira secundário, como
 * o "Marcar presença" da T4); depois, o check-in (64dp) ou o código da casa; o check-out só é primário quando nada
 * disso está em jogo.
 */
@Composable
private fun CartaoDoTurno(
    turno: ItemTurno,
    criarCheckinViewModel: @Composable (turno: ItemTurno) -> CheckinViewModel,
    aoAbrirAvaliacao: (turnoId: String) -> Unit,
    aoCancelar: (ItemTurno) -> Unit,
    aoExibirComprovante: (ComprovanteCheckin) -> Unit,
    relogio: () -> Instant,
    aoDenunciarEstabelecimento: ((estabelecimentoId: String, turnoId: String) -> Unit)?,
    aoPedirSuporte: ((turnoId: String) -> Unit)?,
    aoAvisarACaminho: ((turno: ItemTurno) -> Unit)?,
    avisandoACaminho: String?,
    erroACaminho: ErroDoACaminho?,
) {
    val confirmado = turno.estado == ESTADO_CHECKIN_DISPONIVEL
    val contagem = if (confirmado) lembrarContagem(turno, relogio) else null
    // O check-in só nasce quando a janela abre (como antes): a contagem não cria o ViewModel do turno.
    val viewModel = if (contagem != null && contagem !is EstadoContagemRegressiva.AguardandoJanela) {
        criarCheckinViewModel(turno)
    } else {
        null
    }
    val estadoCheckin = viewModel?.estado?.collectAsStateWithLifecycle()?.value
    val comprovante = estadoCheckin?.comprovante ?: turno.comprovante
    val aCaminhoOferecido = confirmado && aoAvisarACaminho != null && podeAvisarACaminho(turno, relogio())
    val presencaPendente = comprovante?.tipoVerificacao == TipoVerificacaoCheckin.MANUAL_PENDENTE ||
        estadoCheckin?.status == StatusCheckin.MANUAL_PENDENTE

    CartaoDeStatusDoTurno(turno = turno, selo = seloDoTurno(turno, comprovante)) {
        if (confirmado && aoAvisarACaminho != null) {
            SecaoACaminho(
                turno = turno,
                avisando = avisandoACaminho == turno.turnoId,
                mensagemErro = erroACaminho?.takeIf { it.turnoId == turno.turnoId }?.mensagem,
                aoAvisar = { aoAvisarACaminho(turno) },
                agora = relogio(),
            )
        }
        when (contagem) {
            is EstadoContagemRegressiva.AguardandoJanela -> BlocoContagemRegressiva(texto = contagem.textoFormatado)
            is EstadoContagemRegressiva.JanelaAberta -> if (viewModel != null) {
                SecaoDeCheckin(
                    turno = turno,
                    viewModel = viewModel,
                    aoExibirComprovante = aoExibirComprovante,
                    destaque = !aCaminhoOferecido,
                )
                SecaoDeCheckout(turno = turno, viewModel = viewModel, agora = relogio(), destaque = !aCaminhoOferecido && !presencaPendente)
            }
            // Turno finalizado não exibe check-in nem cancelamento. L1-4: o check-out ainda vale até 60 min depois do fim.
            is EstadoContagemRegressiva.TurnoFinalizado -> if (viewModel != null) {
                SecaoDeCheckout(turno = turno, viewModel = viewModel, agora = relogio(), destaque = !presencaPendente)
            }
            null -> Unit
        }
        SecaoDeAvaliacao(turno = turno, aoAbrirAvaliacao = aoAbrirAvaliacao)

        val podeCancelar = contagem is EstadoContagemRegressiva.AguardandoJanela || contagem is EstadoContagemRegressiva.JanelaAberta
        val casaId = turno.contraparteId
        val podeDenunciar = aoDenunciarEstabelecimento != null && casaId != null
        if (podeCancelar || podeDenunciar || aoPedirSuporte != null) {
            Spacer(modifier = Modifier.height(FrilaEspacamento.item))
            Column {
                if (podeCancelar) {
                    AcaoDiscreta(texto = "Cancelar turno", aoClicar = { aoCancelar(turno) })
                }
                if (aoPedirSuporte != null) {
                    AcaoDiscreta(
                        texto = "Pedir ajuda com o turno",
                        aoClicar = { aoPedirSuporte(turno.turnoId) },
                        modifier = Modifier.semantics { contentDescription = "Pedir ajuda com o turno em ${turno.estabelecimentoNome}" },
                    )
                }
                if (podeDenunciar && casaId != null && aoDenunciarEstabelecimento != null) {
                    AcaoDiscreta(
                        texto = "Denunciar",
                        aoClicar = { aoDenunciarEstabelecimento(casaId, turno.turnoId) },
                        modifier = Modifier.semantics { contentDescription = "Denunciar ${turno.estabelecimentoNome}" },
                    )
                }
            }
        }
    }
}

/** Aviso de que o check-in ainda não abriu: quanto falta, em apoio, num bloco neutro (sem laranja nem alerta). */
@Composable
fun BlocoContagemRegressiva(
    texto: String,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    Column(
        modifier = modifier
            .fillMaxWidth()
            .semantics {
                contentDescription = "Check-in abre em: $texto"
            }
            .background(cores.superficiePressionada, RoundedCornerShape(FrilaRaios.interno))
            .padding(FrilaEspacamento.bloco),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
    ) {
        Text(
            text = "Janela de check-in (RN06)",
            style = FrilaTipo.apoio,
            color = cores.tintaSuave,
        )
        Text(
            text = "Check-in abre em $texto",
            style = FrilaTipo.corpo,
            color = cores.tinta,
        )
    }
}

/**
 * Diálogo RN12: modal de confirmação de cancelamento com a regra de antecedência.
 *
 * Apresenta o efeito do cancelamento segundo a regra RN12 (se antecedência < 24h,
 * conta como falta e alerta sobre impacto na reputação; se >= 24h, sem falta).
 *
 * O campo de motivo NÃO entra na interface, conforme contrato do Android (decisão
 * de produto de 02/10/2026, com contradição registrada como decisão pendente do Cauê).
 *
 * Desenho: a consequência vem escrita em tinta (problema não tem cor) e o botão de confirmar é secundário, não
 * laranja: cancelar um turno não é o caminho que o produto quer incentivar.
 */
@Composable
fun DialogoCancelamentoTurno(
    estado: EstadoCancelamentoTurno,
    aoConfirmar: () -> Unit,
    aoVoltar: () -> Unit,
    aoSelecionarMotivo: ((MotivoCancelamento) -> Unit)? = null,
    aoAtualizarDetalhes: ((String) -> Unit)? = null,
) {
    val emitirFeedback = lembrarFeedbackAcaoCritica()
    val cores = FrilaTema.cores
    AlertDialog(
        onDismissRequest = { if (!estado.enviando) aoVoltar() },
        title = {
            Text("Cancelar turno", modifier = Modifier.semantics { heading() })
        },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                Text(
                    text = if (estado.contaComoFalta) {
                        "Faltam menos de 24 horas. Este cancelamento conta como falta e pode afetar sua reputação."
                    } else {
                        "Este cancelamento não conta como falta nem afeta sua reputação."
                    },
                    style = if (estado.contaComoFalta) FrilaTipo.rotuloSecundario else FrilaTipo.corpo,
                    color = cores.tinta,
                )
                estado.mensagemErro?.let { mensagem ->
                    Text(
                        text = mensagem,
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                        modifier = Modifier.semantics { error(mensagem) },
                    )
                }
            }
        },
        confirmButton = {
            BotaoSecundario(
                texto = if (estado.enviando) "Cancelando…" else "Confirmar cancelamento",
                aoClicar = { emitirFeedback(); aoConfirmar() },
                habilitado = estado.podeConfirmar,
            )
        },
        dismissButton = {
            LinkFrila(
                texto = "Voltar",
                aoClicar = aoVoltar,
                habilitado = !estado.enviando,
            )
        },
    )
}

/**
 * Diálogo defensivo (RN06/RN22): antes de tentar o check-in geolocalizado, explica a pendência
 * (permissão ou GPS) e deixa claro que o check-in manual segue disponível, sem bloquear o toque.
 */
@Composable
private fun DialogoDefensivoLocalizacao(
    dialogo: DialogoDefensivoLocalizacao,
    /** Abrir as Configurações (permissão, GPS) ou, na leitura imprecisa, tentar o GPS de novo. */
    aoAcaoPrincipal: () -> Unit,
    aoContinuarManual: () -> Unit,
    aoDispensar: () -> Unit,
) {
    val (titulo, texto, textoBotaoPrimario) = when (dialogo) {
        DialogoDefensivoLocalizacao.PERMISSAO_NEGADA -> Triple(
            "Permissão de localização",
            "Para confirmar sua presença automaticamente, o Frila precisa da sua localização no " +
                "momento do check-in. Sem ela, você ainda pode registrar o check-in manual, que fica " +
                "pendente até o contratante confirmar.",
            "Abrir configurações",
        )
        DialogoDefensivoLocalizacao.GPS_DESLIGADO -> Triple(
            "GPS desativado",
            "A localização do seu aparelho está desativada. Ative-a para confirmar sua presença " +
                "automaticamente, ou continue com o check-in manual, que fica pendente até o " +
                "contratante confirmar.",
            "Ativar GPS",
        )
        // Como o `.semGPS(.imprecisa)` do iOS (TextosDaPresenca.motivoImprecisa e manualExplicacao).
        DialogoDefensivoLocalizacao.LEITURA_IMPRECISA -> Triple(
            "Localização não confirmada",
            "O sinal do GPS está fraco demais para confirmar que você está no endereço. Você pode tentar " +
                "de novo ou fazer o check-in manual, que fica pendente até o contratante confirmar.",
            "Tentar de novo",
        )
    }

    AlertDialog(
        onDismissRequest = aoDispensar,
        title = { Text(titulo, modifier = Modifier.semantics { heading() }) },
        text = { Text(texto, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta) },
        confirmButton = {
            BotaoPrimario(texto = textoBotaoPrimario, aoClicar = aoAcaoPrincipal)
        },
        dismissButton = {
            BotaoSecundario(texto = "Continuar manual", aoClicar = aoContinuarManual)
        },
    )
}

/**
 * RF15/RN11: avaliação binária de turno cumprido. Um voto por lado, sem nota, sem repetição. A resposta já dada é
 * só um fato em apoio; "Avaliar turno" é botão secundário (o laranja do cartão é de quem avança no turno).
 */
@Composable
private fun SecaoDeAvaliacao(turno: ItemTurno, aoAbrirAvaliacao: (turnoId: String) -> Unit) {
    val resposta = turno.avaliacaoResposta
    when {
        resposta != null -> Text(
            text = if (resposta) "Você recomendou este local" else "Você não recomendou este local",
            style = FrilaTipo.apoio,
            color = FrilaTema.cores.tintaSuave,
        )
        turno.podeAvaliar -> BotaoSecundario(
            texto = "Avaliar turno",
            aoClicar = { aoAbrirAvaliacao(turno.turnoId) },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

/**
 * Textos normativos do check-in presencial (RF13/RN06/RN22, paridade iOS TextosDaPresenca.swift:42-51).
 */
object TextosCheckin {
    const val REGISTRANDO = "Registrando check-in…"
    const val CHECKIN_VERIFICADO = "Check-in verificado"
    const val CHECKIN_MANUAL_CONFIRMADO = "Check-in manual confirmado"
    const val CHECKIN_MANUAL_CONFIRMADO_DESCRICAO = "Check-in manual confirmado pelo contratante"
    const val CHECKIN_MANUAL_PENDENTE = "Check-in manual, aguardando confirmação do contratante"
    const val CHECKIN_SEM_VERIFICACAO = "Check-in sem verificação"
    const val BOTAO_VER_COMPROVANTE = "Ver comprovante"
    const val BOTAO_FAZER_CHECKIN = "Fazer check-in"
    const val BOTAO_TENTAR_NOVAMENTE = "Tentar novamente"
    const val ERRO_PADRAO = "Não foi possível registrar o check-in."
}

/** Fina ou aproximada: o Android deixa a pessoa escolher, e a aproximada cai na regra dos 100 m. */
private val PERMISSOES_DE_LOCALIZACAO = arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)

/**
 * Troca o pedido de permissão do sistema num teste (o Robolectric não responde ao diálogo do sistema): recebe quem
 * trata a resposta (`true` = concedida). `null` em produção, e o pedido vai ao sistema.
 */
val LocalPedidoDePermissaoDeLocalizacao = staticCompositionLocalOf<((aoResponder: (Boolean) -> Unit) -> Unit)?> { null }

/**
 * A presença do turno (T4/T8 e o check-in por código da casa). O toque nunca confirma a presença sozinho: o botão faz
 * o check-in (GPS ou manual) e, com ele manual e pendente, a pessoa digita o código da casa ou espera a casa
 * confirmar. Mensagem de erro fica logo acima do botão, que continua ativo para tentar de novo; enquanto o check-in
 * é registrado, o botão fica no lugar, desligado, sem indicador girando.
 */
@Composable
private fun SecaoDeCheckin(
    turno: ItemTurno,
    viewModel: CheckinViewModel,
    aoExibirComprovante: (ComprovanteCheckin) -> Unit,
    destaque: Boolean,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val contexto = LocalContext.current
    val emitirFeedback = lembrarFeedbackAcaoCritica()

    LaunchedEffect(estado.comprovante) {
        estado.comprovante?.let { aoExibirComprovante(it) }
    }

    val comprovanteAtivo = estado.comprovante ?: turno.comprovante

    // C0-7: sem permissão, o 1º toque pede ao sistema; a resposta volta à VM (recusa = diálogo das Configurações).
    val pedidoDeTeste = LocalPedidoDePermissaoDeLocalizacao.current
    val lancadorDePermissao = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { respostas ->
        viewModel.respostaDaPermissao(concedida = respostas.values.any { it })
    }
    LaunchedEffect(estado.pedirPermissao) {
        if (estado.pedirPermissao) {
            viewModel.pedidoDePermissaoAberto()
            if (pedidoDeTeste != null) {
                pedidoDeTeste { concedida -> viewModel.respostaDaPermissao(concedida) }
            } else {
                lancadorDePermissao.launch(PERMISSOES_DE_LOCALIZACAO)
            }
        }
    }

    estado.dialogoDefensivo?.let { dialogo ->
        DialogoDefensivoLocalizacao(
            dialogo = dialogo,
            aoAcaoPrincipal = {
                when (dialogo) {
                    DialogoDefensivoLocalizacao.PERMISSAO_NEGADA ->
                        abrirConfiguracoesComFallback(contexto, criarIntentConfiguracoesApp(contexto))
                    DialogoDefensivoLocalizacao.GPS_DESLIGADO ->
                        abrirConfiguracoesComFallback(contexto, criarIntentConfiguracoesGps())
                    DialogoDefensivoLocalizacao.LEITURA_IMPRECISA -> { emitirFeedback(); viewModel.fazerCheckin() }
                }
            },
            aoContinuarManual = { viewModel.prosseguirCheckinManual() },
            aoDispensar = { viewModel.dispensarDialogoDefensivo() },
        )
    }

    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        val comprovante = comprovanteAtivo
        when {
            estado.status == StatusCheckin.REGISTRANDO -> {
                BotaoDeAcaoDoTurno(
                    texto = TextosCheckin.REGISTRANDO,
                    aoClicar = {},
                    destaque = destaque,
                    habilitado = false,
                    presenca = true,
                )
            }
            estado.status == StatusCheckin.VERIFICADO || (estado.status == StatusCheckin.OCIOSO && comprovante?.tipoVerificacao == TipoVerificacaoCheckin.GEOLOCALIZADO) -> {
                FatoDoCheckin(texto = TextosCheckin.CHECKIN_VERIFICADO, descricao = TextosCheckin.CHECKIN_VERIFICADO)
                if (comprovante != null) {
                    BotaoVerComprovante { aoExibirComprovante(comprovante) }
                }
            }
            estado.status == StatusCheckin.OCIOSO && comprovante?.tipoVerificacao == TipoVerificacaoCheckin.MANUAL_CONFIRMADO -> {
                FatoDoCheckin(
                    texto = TextosCheckin.CHECKIN_MANUAL_CONFIRMADO,
                    descricao = TextosCheckin.CHECKIN_MANUAL_CONFIRMADO_DESCRICAO,
                )
                BotaoVerComprovante { aoExibirComprovante(comprovante) }
            }
            estado.status == StatusCheckin.MANUAL_PENDENTE || (estado.status == StatusCheckin.OCIOSO && comprovante?.tipoVerificacao == TipoVerificacaoCheckin.MANUAL_PENDENTE) -> {
                FatoDoCheckin(texto = TextosCheckin.CHECKIN_MANUAL_PENDENTE, descricao = TextosCheckin.CHECKIN_MANUAL_PENDENTE)
                if (comprovante != null) {
                    BotaoVerComprovante { aoExibirComprovante(comprovante) }
                }
                // L1-4: com a confirmação por código ligada (fiação no L1-7), o profissional digita o código da casa.
                CampoDoCodigo(turno)
            }
            estado.status == StatusCheckin.OCIOSO && comprovante?.tipoVerificacao == TipoVerificacaoCheckin.NAO_VERIFICADO -> {
                FatoDoCheckin(texto = TextosCheckin.CHECKIN_SEM_VERIFICACAO, descricao = TextosCheckin.CHECKIN_SEM_VERIFICACAO)
                BotaoVerComprovante { aoExibirComprovante(comprovante) }
            }
            estado.status == StatusCheckin.NA_FILA -> {
                val texto = estado.checkinNaFila?.let(TextosDaFilaDePresenca::checkinNaFila) ?: TextosCheckin.REGISTRANDO
                FatoDoCheckin(texto = texto, descricao = texto)
            }
            estado.status == StatusCheckin.ERRO -> {
                MensagemDeAcao(texto = estado.mensagemErro ?: TextosCheckin.ERRO_PADRAO)
                BotaoDeAcaoDoTurno(
                    texto = TextosCheckin.BOTAO_TENTAR_NOVAMENTE,
                    aoClicar = { emitirFeedback(); viewModel.fazerCheckin() },
                    destaque = destaque,
                    presenca = true,
                )
            }
            else -> {
                estado.avisoCheckin?.let { MensagemDeAcao(texto = it) }
                BotaoDeAcaoDoTurno(
                    texto = TextosCheckin.BOTAO_FAZER_CHECKIN,
                    aoClicar = { emitirFeedback(); viewModel.fazerCheckin() },
                    destaque = destaque,
                    presenca = true,
                )
            }
        }
    }
}

/** O fato do check-in já feito, em corpo e tinta, com o nome acessível que o leitor de tela já ouvia. */
@Composable
private fun FatoDoCheckin(texto: String, descricao: String) {
    Text(
        text = texto,
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
        modifier = Modifier.semantics { contentDescription = descricao },
    )
}

@Composable
private fun BotaoVerComprovante(aoClicar: () -> Unit) {
    BotaoSecundario(
        texto = TextosCheckin.BOTAO_VER_COMPROVANTE,
        aoClicar = aoClicar,
        modifier = Modifier.fillMaxWidth(),
    )
}

/**
 * RNF10/RNF04: skeleton da lista de turnos enquanto carrega. Replica os cartões de turno usados em
 * [ListaDeTurnos] (selo, função, casa, data/horário, valor). Container único com `liveRegion`: os ossos
 * individuais ([FrilaSkeleton]) são `clearAndSetSemantics {}`, então o TalkBack anuncia só isto, uma vez.
 */
@Composable
private fun SkeletonMeusTurnos(quantidade: Int = 3) {
    LazyColumn(
        contentPadding = PaddingValues(
            start = FrilaEspacamento.grupo,
            end = FrilaEspacamento.grupo,
            top = FrilaEspacamento.item,
            bottom = FrilaEspacamento.grupo,
        ),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        modifier = Modifier
            .fillMaxSize()
            .semantics {
                liveRegion = LiveRegionMode.Polite
                contentDescription = "Carregando turnos..."
            },
    ) {
        items(quantidade) {
            CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.3f).height(28.dp))
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.55f).height(20.dp))
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.8f).height(16.dp))
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.5f).height(16.dp))
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.35f).height(16.dp))
                }
            }
        }
    }
}

@Composable
private fun Vazio() {
    EstadoVazio(titulo = "Você ainda não tem turnos nesta aba.")
}

@Composable
private fun Erro(mensagem: String?, aoTentarNovamente: () -> Unit) {
    EstadoErro(
        titulo = mensagem ?: "Não foi possível carregar seus turnos.",
        mensagem = null,
        aoTentarNovamente = aoTentarNovamente,
    )
}
