package br.com.frila.feature.vagas.candidaturas

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.feature.vagas.painel.periodo
import br.com.frila.feature.vagas.publicacao.formatarReais

/** A lista de candidaturas do profissional e a confirmação de retirar. */

/** Tudo o que a lista pode pedir a quem a abriu. `aoRetirar` nulo esconde o botão de retirar. */
data class AcoesMinhasCandidaturas(
    val aoCarregar: () -> Unit = {},
    val aoAtualizar: () -> Unit = {},
    val aoAbrir: (DestinoDaCandidatura) -> Unit = {},
    val aoVoltar: () -> Unit = {},
    val aoRetirar: ((ItemCandidatura) -> Unit)? = null,
)

/** Liga o [MinhasCandidaturasViewModel] ao [ConteudoMinhasCandidaturas] e carrega ao abrir. */
@Composable
fun TelaMinhasCandidaturas(
    viewModel: MinhasCandidaturasViewModel,
    aoVoltar: () -> Unit,
    aoAbrir: (DestinoDaCandidatura) -> Unit,
    modifier: Modifier = Modifier,
    aoRetirar: ((ItemCandidatura) -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoMinhasCandidaturas(
        estado = estado,
        acoes = AcoesMinhasCandidaturas(
            aoCarregar = { viewModel.carregar() },
            aoAtualizar = { viewModel.atualizar() },
            aoAbrir = aoAbrir,
            aoVoltar = aoVoltar,
            aoRetirar = aoRetirar,
        ),
        modifier = modifier,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoMinhasCandidaturas(estado: EstadoMinhasCandidaturas, acoes: AcoesMinhasCandidaturas, modifier: Modifier = Modifier) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = acoes.aoVoltar) },
    ) { preenchimento ->
        PullToRefreshBox(
            isRefreshing = estado.atualizando,
            onRefresh = acoes.aoAtualizar,
            modifier = Modifier.fillMaxSize().padding(preenchimento).semantics {
                contentDescription = if (estado.atualizando) TextosCandidaturas.ATUALIZANDO else TextosCandidaturas.LISTA
            },
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = FrilaEspacamento.grupo),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
            ) {
                item(key = "titulo") { TituloDaTela(TextosCandidaturas.TITULO, modifier = margem) }
                if (estado.desatualizada) {
                    item(key = "desatualizada") {
                        AvisoFrila(tom = TomAviso.ALERTA, mensagem = TextosCandidaturas.DESATUALIZADA, modifier = margem)
                    }
                }
                when (val lista = estado.lista) {
                    ListaDeCandidaturas.Carregando -> item {
                        Box(Modifier.fillMaxWidth().semantics { contentDescription = TextosCandidaturas.CARREGANDO }) {
                            EstadoCarregando(modifier = Modifier.fillMaxWidth())
                        }
                    }
                    ListaDeCandidaturas.Vazia -> item {
                        EstadoVazio(
                            titulo = TextosCandidaturas.VAZIO_TITULO,
                            mensagem = TextosCandidaturas.VAZIO_MENSAGEM,
                        )
                    }
                    is ListaDeCandidaturas.Erro -> item {
                        EstadoErro(
                            titulo = TextosCandidaturas.ERRO_TITULO,
                            mensagem = lista.mensagem,
                            textoBotao = TextosCandidaturas.TENTAR_DE_NOVO,
                            aoTentarNovamente = acoes.aoCarregar.takeIf { lista.podeTentarDeNovo },
                        )
                    }
                    is ListaDeCandidaturas.Carregadas -> {
                        secao(TextosCandidaturas.AGUARDANDO, lista.pendentes, acoes)
                        secao(TextosCandidaturas.ANTERIORES, lista.anteriores, acoes)
                    }
                }
            }
        }
    }
}

private fun LazyListScope.secao(titulo: String, itens: List<ItemCandidatura>, acoes: AcoesMinhasCandidaturas) {
    if (itens.isEmpty()) return
    item(key = "secao-$titulo") {
        RotuloDeGrupo(titulo, modifier = margem.padding(top = FrilaEspacamento.item))
    }
    items(itens, key = { it.id }) { item -> CartaoDaCandidatura(item, acoes) }
}

/** A margem lateral da tela, para o que não traz a sua (título, seções, cartões). */
private val margem: Modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo)

/** O selo diz o estado da candidatura: aguardando é contorno, escolhida é amarelo, o que fechou sem você é tinta suave. */
private fun estiloDoSelo(item: ItemCandidatura): EstiloDoSelo = when {
    item.pendente -> EstiloDoSelo.CONTORNO
    item.textoDoEstado == TextosCandidaturas.ESTADO_ACEITA -> EstiloDoSelo.CONFIRMADO
    else -> EstiloDoSelo.ENCERRADO
}

/**
 * O cartão da candidatura (como o da T7): selo de estado acima, a função, quando, onde e quanto. Identidade e dados
 * abrem o destino; a ação de retirar é outro alvo, ao lado e nunca dentro do primeiro, em ação discreta (desistir
 * é risco, não avanço: sem laranja).
 */
@Composable
private fun CartaoDaCandidatura(item: ItemCandidatura, acoes: AcoesMinhasCandidaturas) {
    CartaoFrila(modifier = margem.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            Column(
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = FrilaMetricas.alvoMinimo)
                    .clickable(onClickLabel = item.destino.dica) { acoes.aoAbrir(item.destino) },
            ) {
                SeloDeStatus(texto = item.textoDoEstado, estilo = estiloDoSelo(item))
                Text(item.funcao, style = FrilaTipo.nome, color = FrilaTema.cores.tinta)
                FrilaLinhaDeDado(icone = Icons.Default.DateRange, valor = periodo(item.inicio, item.fim))
                FrilaLinhaDeDado(icone = Icons.Default.Place, valor = item.local)
                Text(
                    text = TextosCandidaturas.VALOR.format(formatarReais(item.valorCentavos)),
                    style = FrilaTipo.rotuloSecundario,
                    color = FrilaTema.cores.tinta,
                )
            }
            acoes.aoRetirar?.takeIf { item.pendente }?.let { aoRetirar ->
                AcaoDiscreta(
                    texto = TextosCandidaturas.RETIRAR,
                    aoClicar = { aoRetirar(item) },
                    modifier = Modifier.semantics { contentDescription = TextosCandidaturas.RETIRAR_CANDIDATURA_DE.format(item.funcao) },
                )
            }
        }
    }
}

/** Liga o [RetirarCandidaturaViewModel] ao [DialogoRetirarCandidatura]. */
@Composable
fun TelaRetirarCandidatura(viewModel: RetirarCandidaturaViewModel, aoFechar: () -> Unit) {
    val estado by viewModel.estado.collectAsState()
    DialogoRetirarCandidatura(estado = estado, aoConfirmar = { viewModel.retirar() }, aoFechar = aoFechar)
}

/**
 * A confirmação de retirar: pergunta antes de enviar, diz que está retirando e mostra o desfecho ou a recusa.
 * Diálogo nativo, uma só confirmação, com a consequência escrita. Retirar não é avançar: o botão é secundário e
 * "Cancelar" é ação discreta. A falha vem em tinta, sem vermelho.
 */
@Composable
fun DialogoRetirarCandidatura(estado: EstadoRetirarCandidatura, aoConfirmar: () -> Unit, aoFechar: () -> Unit) {
    val cores = FrilaTema.cores
    val retirada = estado.situacao == SituacaoDaRetirada.RETIRADA
    val podeRetirar = estado.situacao == SituacaoDaRetirada.PENDENTE
    AlertDialog(
        onDismissRequest = aoFechar,
        containerColor = cores.superficie,
        shape = RoundedCornerShape(FrilaRaios.cartao),
        title = {
            Text(
                text = if (retirada) TextosCandidaturas.RETIRADA_TITULO else TextosCandidaturas.PERGUNTA_DA_RETIRADA,
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                val aoVivo = Modifier.semantics { liveRegion = LiveRegionMode.Polite }
                when (estado.situacao) {
                    SituacaoDaRetirada.RETIRADA -> Text(TextosCandidaturas.RETIRADA_MENSAGEM, style = FrilaTipo.corpo, color = cores.tinta, modifier = aoVivo)
                    SituacaoDaRetirada.RETIRANDO -> Text(TextosCandidaturas.RETIRANDO, style = FrilaTipo.corpo, color = cores.tinta, modifier = aoVivo)
                    SituacaoDaRetirada.PENDENTE -> Text(TextosCandidaturas.AVISO_DA_RETIRADA, style = FrilaTipo.corpo, color = cores.tinta)
                    SituacaoDaRetirada.INDISPONIVEL -> Unit
                }
                estado.falha?.let { Text(it, style = FrilaTipo.corpo, color = cores.tinta, modifier = aoVivo) }
            }
        },
        confirmButton = {
            if (podeRetirar || estado.situacao == SituacaoDaRetirada.RETIRANDO) {
                BotaoSecundario(texto = TextosCandidaturas.CONFIRMAR_RETIRADA, aoClicar = aoConfirmar, habilitado = podeRetirar)
            }
        },
        dismissButton = {
            AcaoDiscreta(texto = if (podeRetirar) TextosCandidaturas.CANCELAR else TextosCandidaturas.FECHAR, aoClicar = aoFechar)
        },
    )
}
