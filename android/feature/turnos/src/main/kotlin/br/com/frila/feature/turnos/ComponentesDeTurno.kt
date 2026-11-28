package br.com.frila.feature.turnos

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.LinhaDeEtapas
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin

// Componentes do redesign que só o turno usa e que ainda não existem no design system (R3).
// Para subir ao sistema depois: CartaoDeStatusDoTurno, EscolhaBinaria e MensagemDeAcao.

/** As quatro etapas do turno, nesta ordem (desenho do Fabrício, "Linha de etapas"). */
internal val EtapasDoTurno = listOf("Confirmado", "A caminho", "Presença", "Concluído")

/** O selo do cartão de um turno e, quando há caminho a mostrar, a etapa atual (índice de [EtapasDoTurno]). */
internal data class SeloDoTurno(val texto: String, val estilo: EstiloDoSelo, val etapa: Int?)

/**
 * O selo e a etapa de um turno. O toque do check-in nunca confirma a presença sozinho: só o check-in
 * verificado (pelo GPS ou confirmado pela casa) leva o turno à etapa "Presença"; o manual pendente
 * continua na etapa de antes até a casa confirmar.
 */
internal fun seloDoTurno(turno: ItemTurno, comprovanteAtual: ComprovanteCheckin?): SeloDoTurno = when (turno.estado) {
    "cumprida" -> SeloDoTurno("Cumprido", EstiloDoSelo.CONTORNO, etapa = null)
    "cancelada" -> SeloDoTurno("Cancelado", EstiloDoSelo.ENCERRADO, etapa = null)
    "confirmada" -> {
        val tipo = (comprovanteAtual ?: turno.comprovante)?.tipoVerificacao
        when {
            tipo == TipoVerificacaoCheckin.GEOLOCALIZADO || tipo == TipoVerificacaoCheckin.MANUAL_CONFIRMADO ->
                SeloDoTurno("Presença marcada", EstiloDoSelo.ANDAMENTO, etapa = 2)
            turno.aCaminhoEm != null -> SeloDoTurno("A caminho", EstiloDoSelo.ANDAMENTO, etapa = 1)
            else -> SeloDoTurno("Confirmado", EstiloDoSelo.CONFIRMADO, etapa = 0)
        }
    }
    else -> SeloDoTurno(turno.estado, EstiloDoSelo.CONTORNO, etapa = null)
}

/**
 * Cartão de status do turno: selo, função, casa, dia e horário, valor e, quando o turno ainda está no caminho,
 * a linha de etapas. O que a pessoa faz neste turno (presença, avaliação, ações discretas) entra em [conteudo],
 * dentro do mesmo cartão. Sem sombra, sem laranja: o laranja é só do botão que avança.
 */
@Composable
internal fun CartaoDeStatusDoTurno(
    turno: ItemTurno,
    selo: SeloDoTurno,
    modifier: Modifier = Modifier,
    conteudo: @Composable ColumnScope.() -> Unit,
) {
    val cores = FrilaTema.cores
    CartaoFrila(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            Box(modifier = Modifier.semantics(mergeDescendants = true) { contentDescription = "Status: ${selo.texto}" }) {
                SeloDeStatus(texto = selo.texto, estilo = selo.estilo)
            }
            Text(
                text = turno.funcaoNome,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
            Text(text = turno.estabelecimentoNome, style = FrilaTipo.corpo, color = cores.tintaSuave)
            Text(text = turno.dataHorarioFormatado, style = FrilaTipo.corpo, color = cores.tinta)
            // Item 242: o endereço da vaga logo abaixo do horário, como o iOS (TelaMeusTurnos.swift:52). O contrato manda `local` sempre;
            // só o `ponto` (o "Ver no mapa") depende do turno confirmado.
            turno.local?.takeIf { it.isNotBlank() }?.let {
                Text(text = it, style = FrilaTipo.corpo, color = cores.tinta, modifier = Modifier.testTag("local-do-turno-${turno.turnoId}"))
            }
            turno.quemRecebeNaTela?.let { Text(text = stringResource(R.string.turno_quem_recebe, it), style = FrilaTipo.corpo, color = cores.tinta) }
            Text(text = turno.valorFormatado, style = FrilaTipo.rotuloSecundario, color = cores.tinta)
            if (selo.etapa != null) {
                Spacer(modifier = Modifier.height(FrilaEspacamento.item))
                LinhaDeEtapas(etapas = EtapasDoTurno, atual = selo.etapa)
                Spacer(modifier = Modifier.height(FrilaEspacamento.item))
            }
            conteudo()
        }
    }
}

/** Botão de ação do cartão: primário (laranja) só quando [destaque]; senão, secundário. Ocupa a largura toda. */
@Composable
internal fun BotaoDeAcaoDoTurno(
    texto: String,
    aoClicar: () -> Unit,
    destaque: Boolean,
    modifier: Modifier = Modifier,
    habilitado: Boolean = true,
    presenca: Boolean = false,
) {
    if (destaque) {
        BotaoPrimario(
            texto = texto,
            aoClicar = aoClicar,
            modifier = modifier.fillMaxWidth(),
            habilitado = habilitado,
            alturaMinima = if (presenca) FrilaMetricas.alturaBotaoDePresenca else FrilaMetricas.alturaBotao,
        )
    } else {
        BotaoSecundario(texto = texto, aoClicar = aoClicar, modifier = modifier.fillMaxWidth(), habilitado = habilitado)
    }
}

/**
 * Mensagem de uma ação que falhou ou que ainda corre, logo acima do botão que a disparou: em tinta, no corpo, sem
 * cor de alerta e sem ícone (problema não tem cor). Igual à `MensagemJuntoAoBotao` do sistema, mas assertiva para o
 * leitor de tela e com `error(...)`, como as telas de turno já anunciavam o erro. Subir ao sistema com essa opção.
 */
@Composable
internal fun MensagemDeAcao(texto: String, modifier: Modifier = Modifier, comoErro: Boolean = true) {
    Text(
        text = texto,
        style = FrilaTipo.corpo,
        color = FrilaTema.cores.tinta,
        modifier = modifier
            .fillMaxWidth()
            .semantics {
                liveRegion = if (comoErro) LiveRegionMode.Assertive else LiveRegionMode.Polite
                if (comoErro) error(texto)
            },
    )
}

/**
 * Escolha binária (T5): duas opções lado a lado, 48dp, com o visual do botão secundário; a escolhida fica como o chip
 * marcado (tinta com texto claro). Mutuamente exclusivas, nada pré-selecionado. Quem chama grava no toque.
 */
@Composable
internal fun EscolhaBinaria(
    rotuloSim: String,
    rotuloNao: String,
    escolha: Boolean?,
    aoEscolher: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    habilitada: Boolean = true,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        OpcaoBinaria(
            texto = rotuloSim,
            marcada = escolha == true,
            aoClicar = { aoEscolher(true) },
            habilitada = habilitada,
            modifier = Modifier.weight(1f).fillMaxHeight(),
        )
        OpcaoBinaria(
            texto = rotuloNao,
            marcada = escolha == false,
            aoClicar = { aoEscolher(false) },
            habilitada = habilitada,
            modifier = Modifier.weight(1f).fillMaxHeight(),
        )
    }
}

@Composable
private fun OpcaoBinaria(
    texto: String,
    marcada: Boolean,
    aoClicar: () -> Unit,
    habilitada: Boolean,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val interacao = remember { MutableInteractionSource() }
    val pressionada by interacao.collectIsPressedAsState()
    val fundo = when {
        marcada && pressionada -> cores.tintaPressionada
        marcada -> cores.tinta
        pressionada -> cores.superficiePressionada
        else -> cores.superficie
    }
    Box(
        modifier = modifier
            .sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo)
            .heightIn(min = FrilaMetricas.alturaBotao)
            .clip(CircleShape)
            .background(fundo, CircleShape)
            .then(if (marcada) Modifier else Modifier.border(BorderStroke(1.dp, cores.borda), CircleShape))
            .selectable(
                selected = marcada,
                enabled = habilitada,
                interactionSource = interacao,
                indication = null,
                role = Role.RadioButton,
                onClick = aoClicar,
            )
            .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = texto,
            style = FrilaTipo.rotuloSecundario,
            color = if (marcada) cores.sobreTinta else if (habilitada) cores.tinta else cores.tintaSuave,
            textAlign = TextAlign.Center,
        )
    }
}
