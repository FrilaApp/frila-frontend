package br.com.frila.feature.vagas.feed

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaDivisoria
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.FrilaSkeleton
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.focoAcessivelFrila
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** O texto do botão dentro do cartão. O cartão inteiro abre o detalhe: o botão só diz isso. */
internal const val ROTULO_DO_CARTAO_DE_VAGA = "Ver detalhes da vaga"

/**
 * Cartão de vaga do feed (T2 do desenho do Fabrício). Ainda não mora no design system: é o cartão de raio 36
 * com o botão de raio 16 dentro (par concêntrico), que só o feed usa. Quando o sistema o ganhar, sai daqui.
 *
 * Quatro grupos, na ordem em que se lê: quem (a casa e o selo do modo), dá para ir? (função, quando, distância),
 * compensa? (o valor, o maior texto do cartão) e a ação. O cartão inteiro é UM alvo de toque: o "botão" é só o
 * desenho do que o toque faz, nunca um segundo alvo dentro do primeiro. Só o cartão [emDestaque] leva o botão
 * laranja (o único da tela); os demais levam o secundário. Sem sombra: o destaque é o botão.
 */
@Composable
fun CartaoDeVagaDoFeed(
    vaga: ItemVaga,
    emDestaque: Boolean,
    aoAbrir: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val forma = RoundedCornerShape(FrilaRaios.cartaoDeVaga)
    val interacao = remember { MutableInteractionSource() }
    val pressionado by interacao.collectIsPressedAsState()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .focoAcessivelFrila(forma = forma)
            .clip(forma)
            .background(if (pressionado && !emDestaque) cores.superficiePressionada else cores.superficie, forma)
            .border(1.dp, cores.borda, forma)
            .clickable(
                interactionSource = interacao,
                indication = null,
                onClickLabel = "Abrir detalhes da vaga de ${vaga.funcaoNome}",
                role = Role.Button,
                onClick = aoAbrir,
            )
            // 32 em cima: no canto de 36, dá ao nome e ao selo a mesma folga real que o botão tem embaixo.
            .padding(start = 20.dp, top = FrilaEspacamento.secao, end = 20.dp, bottom = 20.dp),
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            verticalAlignment = Alignment.Top,
        ) {
            Text(
                text = vaga.estabelecimentoNome,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier
                    .weight(1f)
                    .semantics { heading() },
            )
            SeloDoModo(modo = vaga.modo)
        }

        Column(
            modifier = Modifier.padding(top = 20.dp),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            FrilaLinhaDeDado(icone = IconeFuncao, valor = vaga.funcaoNome)
            FrilaLinhaDeDado(icone = Icons.Default.DateRange, valor = vaga.horarioFormatado)
            FrilaLinhaDeDado(
                icone = Icons.Default.Place,
                valor = "%.1f km".format(java.util.Locale("pt", "BR"), vaga.distanciaKm),
                qualificador = "de distância",
            )
        }

        FrilaDivisoria(modifier = Modifier.padding(vertical = FrilaEspacamento.bloco))

        Text(text = vaga.valorFormatado, style = FrilaTipo.valorEmDestaque, color = cores.tinta)

        BotaoDoCartao(
            texto = ROTULO_DO_CARTAO_DE_VAGA,
            emDestaque = emDestaque,
            pressionado = pressionado,
            modifier = Modifier.padding(top = 20.dp),
        )
    }
}

/** O selo do modo: roxo só para aceite direto ("é agora"); por seleção é contorno, sem cor. */
@Composable
internal fun SeloDoModo(modo: String, modifier: Modifier = Modifier) {
    if (modo == "urgencia") {
        SeloDeStatus(texto = "Urgência", estilo = EstiloDoSelo.URGENCIA, modifier = modifier)
    } else {
        SeloDeStatus(texto = "Por seleção", estilo = EstiloDoSelo.CONTORNO, modifier = modifier)
    }
}

/** O desenho do botão do cartão: raio 16 (não cápsula), 48dp no mínimo; laranja só no cartão em destaque. */
@Composable
private fun BotaoDoCartao(
    texto: String,
    emDestaque: Boolean,
    pressionado: Boolean,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val forma = RoundedCornerShape(FrilaRaios.interno)
    val fundo = when {
        emDestaque && pressionado -> cores.acaoPressionada
        emDestaque -> cores.acao
        pressionado -> cores.superficiePressionada
        else -> cores.superficie
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = FrilaMetricas.alturaBotao)
            .background(fundo, forma)
            .then(if (emDestaque) Modifier else Modifier.border(1.dp, cores.borda, forma))
            .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = texto,
            style = if (emDestaque) FrilaTipo.rotuloDoPrimario else FrilaTipo.rotuloSecundario,
            color = if (emDestaque) cores.sobreAcao else cores.tinta,
            textAlign = TextAlign.Center,
        )
    }
}

/** O esqueleto do cartão de vaga enquanto o feed carrega: mesma forma, ossos no lugar do texto. */
@Composable
fun CartaoDeVagaEsqueleto(modifier: Modifier = Modifier) {
    val cores = FrilaTema.cores
    val forma = RoundedCornerShape(FrilaRaios.cartaoDeVaga)

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(cores.superficie, forma)
            .border(1.dp, cores.borda, forma)
            .padding(start = 20.dp, top = FrilaEspacamento.secao, end = 20.dp, bottom = 20.dp),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.55f).height(22.dp))
        Column(
            modifier = Modifier.padding(top = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.4f).height(18.dp))
            FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.5f).height(18.dp))
            FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.45f).height(18.dp))
        }
        FrilaSkeleton(modifier = Modifier.padding(top = FrilaEspacamento.bloco).fillMaxWidth(0.4f).height(28.dp))
    }
}
