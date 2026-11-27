package br.com.frila.feature.vagas.detalhe

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import br.com.frila.core.rede.ReputacaoDto
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.text
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoVerNoMapa
import br.com.frila.core.designsystem.componentes.linkDoMapa
import br.com.frila.core.rede.ContatoDto
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaDivisoria
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.feature.vagas.feed.IconeCamisa
import br.com.frila.feature.vagas.feed.IconeFuncao
import java.time.Duration
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
private val PT_BR: Locale = Locale("pt", "BR")
private val FORMATO_DATA_POR_EXTENSO: DateTimeFormatter = DateTimeFormatter.ofPattern("EEEE, d 'de' MMMM 'de' yyyy", PT_BR)
private val FORMATO_HORA: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm", PT_BR)

@Composable
fun TelaDetalheVaga(
    viewModel: DetalheVagaViewModel,
    modifier: Modifier = Modifier,
    verificarPermissaoNotificacao: (Context) -> Boolean = { ctx ->
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                ctx,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    },
    jaPediuNaSessao: () -> Boolean = { ControleSessaoNotificacao.jaPediuNaSessao },
    marcarPediuNaSessao: () -> Unit = { ControleSessaoNotificacao.marcarComoPedida() },
    aoResultadoPermissao: (Boolean) -> Unit = {},
    /** Nulo (o padrão) deixa a tela sem a barra de topo: quem a abre ainda volta pelo gesto do sistema. */
    aoVoltar: (() -> Unit)? = null,
    aoNavegarParaConfirmada: ((VagaAbertaDto, ContatoDto?) -> Unit)? = null,
    aoNavegarParaConflito: ((VagaAbertaDto) -> Unit)? = null,
    aoNavegarParaVagaPreenchida: ((VagaAbertaDto) -> Unit)? = null,
    aoNavegarParaVagaEncerrada: ((VagaAbertaDto) -> Unit)? = null,
    aoNavegarParaContaSuspensa: (() -> Unit)? = null,
    aoNavegarParaFuncaoIncompativel: ((VagaAbertaDto) -> Unit)? = null,
) {
    val contexto = LocalContext.current
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val vaga = estado.vaga

    var dialogoPermissaoVisivel by rememberSaveable { mutableStateOf(false) }

    val launcherPermissao = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { concedida ->
        aoResultadoPermissao(concedida)
    }

    LaunchedEffect(
        estado.navegarParaConfirmada,
        estado.ehConflitoHorario,
        estado.ehVagaPreenchida,
        estado.ehVagaEncerrada,
        estado.ehContaSuspensa,
        estado.ehFuncaoIncompativel,
    ) {
        if (estado.navegarParaConfirmada && viewModel.consumirNavegacaoParaConfirmada()) {
            aoNavegarParaConfirmada?.invoke(estado.vaga, estado.contato)
            if (!jaPediuNaSessao()) {
                if (!verificarPermissaoNotificacao(contexto)) {
                    marcarPediuNaSessao()
                    dialogoPermissaoVisivel = true
                }
            }
        }
        if (estado.ehConflitoHorario && viewModel.consumirNavegacaoParaConflitoHorario()) {
            aoNavegarParaConflito?.invoke(estado.vaga)
        }
        if (estado.ehVagaPreenchida && viewModel.consumirNavegacaoParaVagaPreenchida()) {
            aoNavegarParaVagaPreenchida?.invoke(estado.vaga)
        }
        if (estado.ehVagaEncerrada && viewModel.consumirNavegacaoParaVagaEncerrada()) {
            aoNavegarParaVagaEncerrada?.invoke(estado.vaga)
        }
        if (estado.ehContaSuspensa && viewModel.consumirNavegacaoParaContaSuspensa()) {
            aoNavegarParaContaSuspensa?.invoke()
        }
        if (estado.ehFuncaoIncompativel && viewModel.consumirNavegacaoParaFuncaoIncompativel()) {
            aoNavegarParaFuncaoIncompativel?.invoke(estado.vaga)
        }
    }

    if (dialogoPermissaoVisivel) {
        DialogoPermissaoNotificacao(
            aoConfirmar = {
                dialogoPermissaoVisivel = false
                marcarPediuNaSessao()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    launcherPermissao.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    aoResultadoPermissao(true)
                }
            },
            aoDispensar = {
                dialogoPermissaoVisivel = false
                marcarPediuNaSessao()
                aoResultadoPermissao(false)
            },
        )
    }

    val rolagem = rememberScrollState()
    // O cartão inteiro já apareceu: o rodapé vira barra, com o valor ao lado do botão.
    val noFim by remember { derivedStateOf { !rolagem.canScrollForward } }
    val candidaturaJaEnviada = estado.statusCandidatura == StatusCandidatura.CONFIRMADA ||
        estado.statusCandidatura == StatusCandidatura.PENDENTE
    val inicio = instanteDoServidor(vaga.inicioEm).atZone(FUSO_BRASILIA)
    val fim = instanteDoServidor(vaga.fimEm).atZone(FUSO_BRASILIA)
    val duracao = Duration.between(inicio, fim)

    Scaffold(
        modifier = modifier,
        containerColor = FrilaTema.cores.fundo,
        topBar = { if (aoVoltar != null) FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            RodapeDoDetalheDaVaga(
                valor = Dinheiro(vaga.valorCentavos).formatado(),
                periodo = periodoDoRodape(duracao, inicio.hour),
                noFim = noFim,
                textoDoBotao = when (estado.statusCandidatura) {
                    StatusCandidatura.ENVIANDO -> "Enviando…"
                    StatusCandidatura.CONFIRMADA -> "Candidatura confirmada"
                    StatusCandidatura.PENDENTE -> "Candidatura enviada"
                    else -> "Candidatar-se"
                },
                aoClicar = viewModel::candidatar,
                habilitado = estado.statusCandidatura != StatusCandidatura.ENVIANDO && !candidaturaJaEnviada,
                mensagem = estado.mensagem?.let { mensagem ->
                    {
                        MensagemJuntoAoBotao(
                            texto = mensagem,
                            modifier = Modifier.semantics {
                                when (estado.statusCandidatura) {
                                    StatusCandidatura.ERRO -> {
                                        liveRegion = LiveRegionMode.Assertive
                                        error(mensagem)
                                    }
                                    StatusCandidatura.CONFIRMADA, StatusCandidatura.PENDENTE -> {
                                        liveRegion = LiveRegionMode.Polite
                                    }
                                    else -> Unit
                                }
                            },
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
                .verticalScroll(rolagem)
                .padding(horizontal = FrilaEspacamento.grupo)
                .padding(top = FrilaEspacamento.item, bottom = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            // A casa em caixa alta; o leitor de tela lê o nome como ele é.
            TituloDaTela(
                texto = vaga.estabelecimento.nome.uppercase(PT_BR),
                modifier = Modifier.clearAndSetSemantics {
                    heading()
                    text = AnnotatedString(vaga.estabelecimento.nome)
                },
            )

            // A reputação da casa, logo abaixo do nome (iOS `reputacaoDaCasa`): quantas avaliações indicam que trabalhariam lá de novo.
            Text(
                text = textoDaReputacaoDaCasa(vaga.estabelecimento.reputacao),
                style = FrilaTipo.apoio,
                color = FrilaTema.cores.tintaSuave,
                modifier = Modifier.fillMaxWidth().testTag("detalhe-reputacao"),
            )

            // A faixa do modo, sobre o fundo, sem cartão: o que o toque no botão vai fazer.
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                if (estado.ehModoUrgencia) {
                    SeloDeStatus(texto = "Urgência", estilo = EstiloDoSelo.URGENCIA)
                } else {
                    SeloDeStatus(texto = "Por seleção", estilo = EstiloDoSelo.CONTORNO)
                }
                Text(
                    text = if (estado.ehModoUrgencia) "Modo urgência: confirmação na hora" else "Modo seleção: contratante escolhe depois",
                    style = FrilaTipo.fraseDoModo,
                    color = FrilaTema.cores.tinta,
                )
            }

            CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    // Dá para ir?
                    FrilaLinhaDeDado(icone = IconeFuncao, valor = vaga.funcao.nome)
                    FrilaLinhaDeDado(
                        icone = Icons.Default.DateRange,
                        valor = dataPorExtenso(inicio.toLocalDate()) + "\ndas ${FORMATO_HORA.format(inicio)} às ${FORMATO_HORA.format(fim)}",
                        qualificador = "(${duracaoCurta(duracao)} de turno)",
                    )
                    FrilaLinhaDeDado(
                        icone = Icons.Default.Place,
                        valor = if (estado.mostraDistancia) {
                            "${vaga.local}, ${vaga.regiaoAdministrativa}\n${"%.1f km".format(PT_BR, vaga.distanciaKm)}"
                        } else {
                            "${vaga.local}, ${vaga.regiaoAdministrativa}"
                        },
                        qualificador = if (estado.mostraDistancia) "de distância" else null,
                    )
                    BotaoVerNoMapa(link = linkDoMapa("${vaga.estabelecimento.nome}, ${vaga.local}"))
                    estado.detalhe?.traje?.takeIf { it.isNotBlank() }?.let { traje ->
                        FrilaLinhaDeDado(icone = IconeCamisa, valor = "${TextosAberturaDeVaga.TRAJE}: $traje")
                    }
                }

                FrilaDivisoria(modifier = Modifier.padding(vertical = FrilaEspacamento.bloco))

                // Compensa?
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                    Text(
                        text = Dinheiro(vaga.valorCentavos).formatado(),
                        style = FrilaTipo.valorEmDestaque,
                        color = FrilaTema.cores.tinta,
                    )
                    RotuloDeGrupo(texto = "Inclui", modifier = Modifier.padding(top = FrilaEspacamento.item))
                    LinhaBeneficio("Refeição", vaga.inclusos.incluiRefeicao)
                    LinhaBeneficio("Transporte", vaga.inclusos.incluiTransporte)
                    LinhaBeneficio("Material próprio exigido", vaga.inclusos.exigeMaterialProprio)
                }
            }

            estado.detalhe?.let { detalhe ->
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(texto = TextosAberturaDeVaga.DETALHES)
                    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                            LinhaDeTexto(
                                TextosAberturaDeVaga.POSICOES_ABERTAS,
                                TextosAberturaDeVaga.POSICOES_DE.format(detalhe.posicoesAbertas, detalhe.posicoes),
                            )
                            LinhaDeTexto(TextosAberturaDeVaga.RESPONSAVEL_NO_LOCAL, detalhe.responsavelLocal)
                            // O rateio dos 10% (Lei 13.419/2017) vem só do detalhe, e só quando a casa disse (iOS: `if let rateio`).
                            detalhe.participaRateio?.let { rateio ->
                                LinhaDeTexto(TextosAberturaDeVaga.RATEIO, if (rateio) TextosAberturaDeVaga.SIM else TextosAberturaDeVaga.NAO)
                            }
                            detalhe.observacoes?.takeIf { it.isNotBlank() }?.let {
                                LinhaDeTexto(TextosAberturaDeVaga.OBSERVACOES, it)
                            }
                        }
                    }
                }
            }

            estado.contato?.let { contato ->
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(texto = "Contato confirmado")
                    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                            LinhaDeTexto("Nome", contato.nome)
                            LinhaDeTexto("Telefone", contato.telefone)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LinhaDeTexto(rotulo: String, valor: String) {
    Text(text = "$rotulo: $valor", style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
}

@Composable
private fun LinhaBeneficio(rotulo: String, incluido: Boolean) {
    val estado = if (incluido) "incluído" else "não incluído"
    Text(
        text = "${if (incluido) "✓" else "—"} $rotulo",
        style = FrilaTipo.corpo,
        color = if (incluido) FrilaTema.cores.tinta else FrilaTema.cores.tintaSuave,
        modifier = Modifier.clearAndSetSemantics {
            contentDescription = "$rotulo: $estado"
        },
    )
}

/** "Sábado, 21 de novembro de 2026". */
private fun dataPorExtenso(data: java.time.LocalDate): String =
    FORMATO_DATA_POR_EXTENSO.format(data).replaceFirstChar { it.titlecase(PT_BR) }

/** "6 h" ou "6 h 30 min". */
private fun duracaoCurta(duracao: Duration): String {
    val horas = duracao.toHours()
    val minutos = duracao.toMinutesPart()
    return if (minutos == 0) "$horas h" else "$horas h $minutos min"
}

/** "6 h à noite": a duração e em que parte do dia o turno começa. */
private fun periodoDoRodape(duracao: Duration, horaDeInicio: Int): String {
    val parteDoDia = when (horaDeInicio) {
        in 5..11 -> "de manhã"
        in 12..17 -> "à tarde"
        else -> "à noite"
    }
    return "${duracaoCurta(duracao)} $parteDoDia"
}

/** Os textos da reputação da casa no detalhe da vaga (paridade com `TextosDoProfissional.Detalhe` do iOS). */
internal object TextosDaReputacaoDaCasa {
    const val SEM_AVALIACOES = "Ainda sem avaliações."
    const val AVALIACOES_TRABALHARIAM_LA_DE_NOVO = "avaliações indicam que trabalhariam lá de novo"
    fun contagem(positivas: Int, total: Int) = "$positivas de $total"
}

/** "7 de 8 avaliações indicam que trabalhariam lá de novo"; sem nenhuma avaliação (`total == 0`, o `semHistorico` do iOS), "Ainda sem avaliações.". */
internal fun textoDaReputacaoDaCasa(reputacao: ReputacaoDto): String =
    if (reputacao.total == 0) {
        TextosDaReputacaoDaCasa.SEM_AVALIACOES
    } else {
        "${TextosDaReputacaoDaCasa.contagem(reputacao.positivas, reputacao.total)} ${TextosDaReputacaoDaCasa.AVALIACOES_TRABALHARIAM_LA_DE_NOVO}"
    }
