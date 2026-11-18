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
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.feature.vagas.painel.periodo
import br.com.frila.feature.vagas.publicacao.formatarReais

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
// A lista de candidaturas do profissional e a confirmação de retirar, em baixíssima fidelidade e só com componentes
// nativos, para a regra poder ser testada no emulador.

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

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoMinhasCandidaturas(estado: EstadoMinhasCandidaturas, acoes: AcoesMinhasCandidaturas, modifier: Modifier = Modifier) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text(TextosCandidaturas.TITULO, style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() }) },
                navigationIcon = {
                    IconButton(
                        onClick = acoes.aoVoltar,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = TextosCandidaturas.ROTULO_VOLTAR) }
                },
            )
        },
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
                contentPadding = PaddingValues(FrilaEspacamento.medio),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
            ) {
                if (estado.desatualizada) {
                    item {
                        Text(
                            text = TextosCandidaturas.DESATUALIZADA,
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                        )
                    }
                }
                when (val lista = estado.lista) {
                    ListaDeCandidaturas.Carregando -> item {
                        Box(
                            Modifier.fillMaxWidth().padding(FrilaEspacamento.grande).semantics { contentDescription = TextosCandidaturas.CARREGANDO },
                            contentAlignment = Alignment.Center,
                        ) { IndicadorCarregando() }
                    }
                    ListaDeCandidaturas.Vazia -> item {
                        EstadoVazio(titulo = TextosCandidaturas.VAZIO_TITULO, mensagem = TextosCandidaturas.VAZIO_MENSAGEM)
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
        Text(titulo, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = FrilaEspacamento.pequeno).semantics { heading() })
    }
    items(itens, key = { it.id }) { item -> CartaoDaCandidatura(item, acoes) }
}

@Composable
private fun CartaoDaCandidatura(item: ItemCandidatura, acoes: AcoesMinhasCandidaturas) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
            Column(
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = FrilaMetricas.alvoMinimo)
                    .clickable(onClickLabel = item.destino.dica) { acoes.aoAbrir(item.destino) },
            ) {
                Text(item.funcao, style = MaterialTheme.typography.titleMedium)
                Text(item.textoDoEstado, style = MaterialTheme.typography.titleSmall)
                Text(periodo(item.inicio, item.fim), style = MaterialTheme.typography.bodyMedium)
                Text(item.local, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(TextosCandidaturas.VALOR.format(formatarReais(item.valorCentavos)), style = MaterialTheme.typography.bodyMedium)
            }
            acoes.aoRetirar?.takeIf { item.pendente }?.let { aoRetirar ->
                BotaoSecundario(
                    texto = TextosCandidaturas.RETIRAR,
                    aoClicar = { aoRetirar(item) },
                    modifier = Modifier.fillMaxWidth().semantics { contentDescription = TextosCandidaturas.RETIRAR_CANDIDATURA_DE.format(item.funcao) },
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

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** A confirmação de retirar: pergunta antes de enviar, diz que está retirando e mostra o desfecho ou a recusa. */
@Composable
fun DialogoRetirarCandidatura(estado: EstadoRetirarCandidatura, aoConfirmar: () -> Unit, aoFechar: () -> Unit) {
    val retirada = estado.situacao == SituacaoDaRetirada.RETIRADA
    val podeRetirar = estado.situacao == SituacaoDaRetirada.PENDENTE
    AlertDialog(
        onDismissRequest = aoFechar,
        title = {
            Text(
                text = if (retirada) TextosCandidaturas.RETIRADA_TITULO else TextosCandidaturas.PERGUNTA_DA_RETIRADA,
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                val aoVivo = Modifier.semantics { liveRegion = LiveRegionMode.Polite }
                when (estado.situacao) {
                    SituacaoDaRetirada.RETIRADA -> Text(TextosCandidaturas.RETIRADA_MENSAGEM, modifier = aoVivo)
                    SituacaoDaRetirada.RETIRANDO -> Text(TextosCandidaturas.RETIRANDO, modifier = aoVivo)
                    SituacaoDaRetirada.PENDENTE -> Text(TextosCandidaturas.AVISO_DA_RETIRADA)
                    SituacaoDaRetirada.INDISPONIVEL -> Unit
                }
                estado.falha?.let { Text(it, color = MaterialTheme.colorScheme.error, modifier = aoVivo) }
            }
        },
        confirmButton = {
            if (podeRetirar || estado.situacao == SituacaoDaRetirada.RETIRANDO) {
                TextButton(onClick = aoConfirmar, enabled = podeRetirar) { Text(TextosCandidaturas.CONFIRMAR_RETIRADA) }
            }
        },
        dismissButton = {
            TextButton(onClick = aoFechar) { Text(if (podeRetirar) TextosCandidaturas.CANCELAR else TextosCandidaturas.FECHAR) }
        },
    )
}
