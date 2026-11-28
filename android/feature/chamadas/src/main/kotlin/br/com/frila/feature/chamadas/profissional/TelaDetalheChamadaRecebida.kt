package br.com.frila.feature.chamadas.profissional

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaBottomSheet
import br.com.frila.core.designsystem.componentes.FrilaDivisoria
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.PerfilPublicoDto

/** Liga o [ChamadaRecebidaViewModel] ao [ConteudoDaChamadaRecebida]. A tela é recriada por chamada (`key`). */
@Composable
fun TelaDetalheChamadaRecebida(
    viewModel: ChamadaRecebidaViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    /** "Ver meu turno" depois do aceite; nulo faz o botão só voltar. */
    aoAbrirTurno: ((turnoId: String) -> Unit)? = null,
    /** Denúncia e bloqueio de quem chamou (CD-RF12); a tela só reserva o lugar, o chamador traz o conteúdo. */
    acoesDeSeguranca: (@Composable (PerfilPublicoDto) -> Unit)? = null,
    /** Bloqueada a casa, a chamada não se responde mais (o servidor a encerra, RF26): some o rodapé de aceitar e recusar. */
    bloqueado: Boolean = false,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoDaChamadaRecebida(
        tela = estado,
        aoTentarNovamente = { viewModel.carregar() },
        aoAceitar = { viewModel.aceitar() },
        aoAbrirRecusa = viewModel::abrirRecusa,
        aoFecharRecusa = viewModel::fecharRecusa,
        aoEscolherMotivo = viewModel::escolherMotivo,
        aoConfirmarRecusa = { viewModel.recusar() },
        aoVoltar = aoVoltar,
        aoAbrirTurno = aoAbrirTurno ?: { aoVoltar() },
        acoesDeSeguranca = acoesDeSeguranca,
        bloqueado = bloqueado,
        modifier = modifier,
    )
}

/**
 * Chamada recebida (CD-I5b; paridade com `TelaDetalheChamadaRecebida.swift`): tela de decisão. Quem chamou,
 * função, horário, região e faixa de distância e o valor total num cartão; recado, o que está incluso, o aviso de
 * segurança e o prazo para responder. "Aceitar chamada" (o único laranja) e "Recusar chamada" (com motivo
 * opcional numa folha) ficam no rodapé ancorado, só com a chamada aberta; enquanto responde, o aceite fica
 * desligado no lugar. Depois do aceite a tela mostra o local e o responsável liberados (RN36). Nunca mostra
 * telefone nem endereço antes do aceite.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoDaChamadaRecebida(
    tela: EstadoChamadaRecebida,
    aoTentarNovamente: () -> Unit,
    aoAceitar: () -> Unit,
    aoAbrirRecusa: () -> Unit,
    aoFecharRecusa: () -> Unit,
    aoEscolherMotivo: (String?) -> Unit,
    aoConfirmarRecusa: () -> Unit,
    aoVoltar: () -> Unit,
    aoAbrirTurno: (String) -> Unit,
    modifier: Modifier = Modifier,
    acoesDeSeguranca: (@Composable (PerfilPublicoDto) -> Unit)? = null,
    bloqueado: Boolean = false,
) {
    val detalhe = tela.detalhe
    val resultado = tela.resultado
    // Aceita pelo resultado deste toque ou pelo detalhe de uma chamada reaberta (push, lista) ou conferida depois de um erro.
    val aceita = tela.chamadaAceita
    val turnoAceito = tela.turnoAceito
    val recusada = resultado != null && resultado.chamada.estado == "recusada"
    // Decidindo: a chamada está aberta e sem resposta. Respondendo, o aceite continua no lugar, só desligado.
    val decidindo = detalhe != null && !aceita && !recusada && !bloqueado &&
        (tela.podeResponder || (tela.respondendo && detalhe.estado == "aberta" && tela.mensagemDeConcorrencia == null))

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            if (decidindo) {
                RodapeAncorado {
                    tela.erro?.let { MensagemJuntoAoBotao(it) }
                    BotaoPrimario(
                        texto = TextosChamadaProfissional.ACEITAR_CHAMADA,
                        aoClicar = aoAceitar,
                        habilitado = !tela.respondendo,
                        modifier = Modifier.fillMaxWidth().testTag("aceitar-chamada"),
                    )
                    BotaoSecundario(
                        texto = TextosChamadaProfissional.RECUSAR_CHAMADA,
                        aoClicar = aoAbrirRecusa,
                        habilitado = !tela.respondendo,
                        modifier = Modifier.fillMaxWidth().testTag("recusar-chamada"),
                    )
                }
            } else if (aceita && turnoAceito != null) {
                RodapeAncorado {
                    BotaoPrimario(
                        texto = TextosChamadaProfissional.VER_TURNO,
                        aoClicar = { aoAbrirTurno(turnoAceito) },
                        modifier = Modifier.fillMaxWidth().testTag("ver-turno-aceito"),
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
                .padding(horizontal = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(TextosChamadaProfissional.RECEBIDA_TITULO)
            when {
                tela.carregando -> EstadoCarregando(mensagem = TextosChamadaProfissional.CARREGANDO)
                detalhe == null -> ErroDeCargaChamada(
                    mensagem = tela.erro ?: TextosChamadaProfissional.ERRO,
                    aoTentarNovamente = aoTentarNovamente,
                    modifierDoBotao = Modifier.testTag("tentar-novamente-chamada"),
                )
                aceita -> Aceita(resultado?.local ?: detalhe.local, resultado?.responsavelLocal ?: detalhe.responsavelLocal)
                recusada -> {
                    AvisoFrila(
                        tom = TomAviso.INFORMATIVO,
                        mensagem = TextosChamadaProfissional.CHAMADA_RECUSADA,
                        modifier = Modifier.testTag("chamada-recusada"),
                    )
                    acoesDeSeguranca?.invoke(detalhe.outraParte)
                }
                else -> {
                    tela.mensagemDeConcorrencia?.let { aviso ->
                        AvisoFrila(
                            tom = TomAviso.ALERTA,
                            mensagem = aviso,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }.testTag("aviso-concorrencia"),
                        )
                    }
                    Resumo(detalhe)
                    acoesDeSeguranca?.invoke(detalhe.outraParte)
                }
            }
        }
    }

    if (tela.mostrarRecusa) {
        FrilaBottomSheet(
            onDismissRequest = aoFecharRecusa,
            titulo = TextosChamadaProfissional.RECUSAR_CHAMADA,
        ) {
            FolhaDeRecusa(tela, aoEscolherMotivo, aoConfirmarRecusa, aoFecharRecusa)
        }
    }
}

/** Depois do aceite: o aviso e, num cartão, o local e o responsável liberados pela RN36. "Ver meu turno" vai no rodapé. */
@Composable
private fun Aceita(local: String?, responsavel: String?) {
    val cores = FrilaTema.cores
    AvisoFrila(
        tom = TomAviso.SUCESSO,
        mensagem = TextosChamadaProfissional.CHAMADA_ACEITA,
        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }.testTag("chamada-aceita"),
    )
    if (local != null || responsavel != null) {
        CartaoFrila(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                if (local != null) {
                    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                        Text(text = TextosChamadaProfissional.ENDERECO_DO_TURNO, style = FrilaTipo.apoio, color = cores.tintaSuave)
                        Text(text = local, style = FrilaTipo.nome, color = cores.tinta)
                    }
                }
                if (responsavel != null) {
                    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                        Text(text = TextosChamadaProfissional.RESPONSAVEL_NO_LOCAL, style = FrilaTipo.apoio, color = cores.tintaSuave)
                        Text(text = responsavel, style = FrilaTipo.corpo, color = cores.tinta)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Resumo(detalhe: ChamadaDetalheDto) {
    val cores = FrilaTema.cores
    val contaNova = detalhe.contaNova == true

    // Selos informam e não se tocam: o prazo para responder e, se for o caso, a casa sem turnos concluídos.
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        SeloDeStatus(
            texto = "${TextosChamadaProfissional.RESPONDER_ATE} ${FormatoChamada.hora(detalhe.expiraEm)}",
            estilo = EstiloDoSelo.CONTORNO,
            modifier = Modifier.testTag("responder-ate"),
        )
        if (contaNova) {
            SeloDeStatus(texto = TextosChamadaProfissional.CONTA_NOVA_BADGE, estilo = EstiloDoSelo.CONTORNO)
        }
    }

    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            Text(
                text = detalhe.outraParte.nome,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
            Text(text = detalhe.funcao.nome, style = FrilaTipo.corpo, color = cores.tinta)
            if (contaNova) {
                Text(text = TextosChamadaProfissional.CONTA_NOVA_AVISO, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }
            FrilaLinhaDeDado(
                icone = Icons.Default.DateRange,
                valor = TextosChamadaProfissional.intervalo(
                    inicio = FormatoChamada.dataEHora(detalhe.inicioEm),
                    fim = FormatoChamada.hora(detalhe.fimEm),
                ),
            )
            val faixa = detalhe.distanciaFaixa?.let(TextosChamadaProfissional::faixaDeDistancia)
            val lugar = listOfNotNull(detalhe.regiaoAdministrativa, faixa).joinToString(" • ")
            if (lugar.isNotEmpty()) {
                FrilaLinhaDeDado(icone = Icons.Default.Place, valor = lugar)
            }
            FrilaDivisoria(modifier = Modifier.padding(vertical = FrilaEspacamento.item))
            Text(
                text = FormatoChamada.dinheiro(detalhe.valorCentavos),
                style = FrilaTipo.valorEmDestaque,
                color = cores.tinta,
            )
        }
    }

    detalhe.recado?.takeIf { it.isNotBlank() }?.let { recado ->
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            RotuloDeGrupo(TextosChamadaProfissional.RECADO_DO_CONTRATANTE)
            Text(text = recado, style = FrilaTipo.corpo, color = cores.tinta)
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        RotuloDeGrupo(TextosChamadaProfissional.INCLUSOS)
        if (detalhe.incluiRefeicao) FrilaLinhaDeDado(Icons.Default.Check, TextosChamadaProfissional.REFEICAO_INCLUSA)
        if (detalhe.incluiTransporte) FrilaLinhaDeDado(Icons.Default.Check, TextosChamadaProfissional.TRANSPORTE_INCLUSO)
        if (detalhe.exigeMaterialProprio) FrilaLinhaDeDado(Icons.Default.Check, TextosChamadaProfissional.EXIGE_MATERIAL_PROPRIO)
        if (!detalhe.incluiRefeicao && !detalhe.incluiTransporte && !detalhe.exigeMaterialProprio) {
            Text(text = TextosChamadaProfissional.NENHUM_BENEFICIO, style = FrilaTipo.apoio, color = cores.tintaSuave)
        }
    }

    AvisoFrila(tom = TomAviso.INFORMATIVO, mensagem = TextosChamadaProfissional.AVISO_SEGURANCA)
}

/** Folha da recusa: o motivo (opcional) numa lista com check, "Recusar chamada" e "Cancelar". */
@Composable
private fun FolhaDeRecusa(
    tela: EstadoChamadaRecebida,
    aoEscolherMotivo: (String?) -> Unit,
    aoConfirmar: () -> Unit,
    aoCancelar: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
    ) {
        EscolhaUnica(
            titulo = TextosChamadaProfissional.MOTIVO_TITULO,
            opcoes = listOf<Pair<String?, String>>(null to TextosChamadaProfissional.MOTIVO_NENHUM) +
                MOTIVOS_DE_RECUSA.map { it to TextosChamadaProfissional.motivo(it) },
            selecionada = tela.motivoSelecionado,
            aoEscolher = aoEscolherMotivo,
            habilitado = !tela.respondendo,
            modifier = Modifier.testTag("motivos-recusa"),
        )
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            BotaoPrimario(
                texto = TextosChamadaProfissional.RECUSAR_CHAMADA,
                aoClicar = aoConfirmar,
                habilitado = !tela.respondendo,
                modifier = Modifier.fillMaxWidth().testTag("confirmar-recusa-chamada"),
            )
            BotaoSecundario(
                texto = TextosChamadaProfissional.CANCELAR,
                aoClicar = aoCancelar,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
