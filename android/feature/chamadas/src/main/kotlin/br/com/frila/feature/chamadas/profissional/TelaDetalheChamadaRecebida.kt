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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import br.com.frila.core.designsystem.componentes.FrilaBottomSheet
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
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
        modifier = modifier,
    )
}

/**
 * Chamada recebida (CD-I5b; paridade com `TelaDetalheChamadaRecebida.swift`): quem chamou, função, valor total,
 * horário, região e faixa de distância, recado, o que está incluso, até quando responder e o aviso de segurança.
 * Aceitar e recusar (com motivo opcional numa folha) só aparecem com a chamada aberta; depois do aceite a tela
 * mostra o local e o responsável liberados (RN36). Nunca mostra telefone nem endereço antes do aceite.
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
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = { BarraDoTopoChamada(TextosChamadaProfissional.RECEBIDA_TITULO, aoVoltar) },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            val detalhe = tela.detalhe
            val resultado = tela.resultado
            tela.erro?.let { erro ->
                AvisoFrila(tom = TomAviso.ERRO, mensagem = erro, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive })
            }
            when {
                tela.carregando -> Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = FrilaEspacamento.grande),
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    Text(text = TextosChamadaProfissional.CARREGANDO, style = MaterialTheme.typography.bodyMedium)
                }
                detalhe == null -> BotaoPrimario(
                    texto = TextosChamadaProfissional.TENTAR_NOVAMENTE,
                    aoClicar = aoTentarNovamente,
                    modifier = Modifier.testTag("tentar-novamente-chamada"),
                )
                resultado != null && resultado.chamada.estado == "aceita" -> Aceita(resultado.local, resultado.responsavelLocal, resultado.turnoId, aoAbrirTurno)
                resultado != null && resultado.chamada.estado == "recusada" -> {
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
                    if (tela.podeResponder) {
                        BotaoPrimario(
                            texto = TextosChamadaProfissional.ACEITAR_CHAMADA,
                            aoClicar = aoAceitar,
                            modifier = Modifier.fillMaxWidth().testTag("aceitar-chamada"),
                        )
                        BotaoSecundario(
                            texto = TextosChamadaProfissional.RECUSAR_CHAMADA,
                            aoClicar = aoAbrirRecusa,
                            modifier = Modifier.fillMaxWidth().testTag("recusar-chamada"),
                        )
                    }
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

@Composable
private fun Aceita(local: String?, responsavel: String?, turnoId: String?, aoAbrirTurno: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio)) {
        AvisoFrila(
            tom = TomAviso.SUCESSO,
            mensagem = TextosChamadaProfissional.CHAMADA_ACEITA,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite }.testTag("chamada-aceita"),
        )
        if (local != null) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
                Text(
                    text = TextosChamadaProfissional.ENDERECO_DO_TURNO,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(text = local, style = MaterialTheme.typography.titleMedium)
            }
        }
        if (responsavel != null) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
                Text(
                    text = TextosChamadaProfissional.RESPONSAVEL_NO_LOCAL,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(text = responsavel, style = MaterialTheme.typography.bodyLarge)
            }
        }
        if (turnoId != null) {
            BotaoPrimario(
                texto = TextosChamadaProfissional.VER_TURNO,
                aoClicar = { aoAbrirTurno(turnoId) },
                modifier = Modifier.fillMaxWidth().testTag("ver-turno-aceito"),
            )
        }
    }
}

@Composable
private fun Resumo(detalhe: ChamadaDetalheDto) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = detalhe.outraParte.nome,
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.weight(1f).semantics { heading() },
            )
            if (detalhe.contaNova == true) {
                Text(
                    text = TextosChamadaProfissional.CONTA_NOVA_BADGE,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.tertiary,
                )
            }
        }
        if (detalhe.contaNova == true) {
            Text(
                text = TextosChamadaProfissional.CONTA_NOVA_AVISO,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(text = detalhe.funcao.nome, style = MaterialTheme.typography.titleMedium)
        Text(text = FormatoChamada.dinheiro(detalhe.valorCentavos), style = MaterialTheme.typography.headlineMedium)
        Text(
            text = TextosChamadaProfissional.intervalo(
                inicio = FormatoChamada.dataEHora(detalhe.inicioEm),
                fim = FormatoChamada.hora(detalhe.fimEm),
            ),
            style = MaterialTheme.typography.bodyLarge,
        )
        val faixa = detalhe.distanciaFaixa?.let(TextosChamadaProfissional::faixaDeDistancia)
        Text(
            text = listOfNotNull(detalhe.regiaoAdministrativa, faixa).joinToString(" • "),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }

    detalhe.recado?.takeIf { it.isNotBlank() }?.let { recado ->
        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
        Text(
            text = TextosChamadaProfissional.RECADO_DO_CONTRATANTE,
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        Text(text = recado, style = MaterialTheme.typography.bodyLarge)
    }

    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    Text(
        text = TextosChamadaProfissional.INCLUSOS,
        style = MaterialTheme.typography.titleSmall,
        modifier = Modifier.semantics { heading() },
    )
    if (detalhe.incluiRefeicao) Text(TextosChamadaProfissional.REFEICAO_INCLUSA, style = MaterialTheme.typography.bodyLarge)
    if (detalhe.incluiTransporte) Text(TextosChamadaProfissional.TRANSPORTE_INCLUSO, style = MaterialTheme.typography.bodyLarge)
    if (detalhe.exigeMaterialProprio) Text(TextosChamadaProfissional.EXIGE_MATERIAL_PROPRIO, style = MaterialTheme.typography.bodyLarge)
    if (!detalhe.incluiRefeicao && !detalhe.incluiTransporte && !detalhe.exigeMaterialProprio) {
        Text(
            text = TextosChamadaProfissional.NENHUM_BENEFICIO,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }

    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
    Text(
        text = "${TextosChamadaProfissional.RESPONDER_ATE} ${FormatoChamada.hora(detalhe.expiraEm)}",
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.tertiary,
        modifier = Modifier.testTag("responder-ate"),
    )
    Text(
        text = TextosChamadaProfissional.AVISO_SEGURANCA,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
}

@Composable
private fun FolhaDeRecusa(
    tela: EstadoChamadaRecebida,
    aoEscolherMotivo: (String?) -> Unit,
    aoConfirmar: () -> Unit,
    aoCancelar: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
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
