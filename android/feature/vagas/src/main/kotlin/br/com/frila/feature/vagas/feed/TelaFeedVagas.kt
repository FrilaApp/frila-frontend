package br.com.frila.feature.vagas.feed

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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaFeedVagas(
    viewModel: FeedVagasViewModel,
    aoAbrirDetalhe: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = { CenterAlignedTopAppBar(title = { Text("Vagas abertas") }) },
    ) { paddingInterno ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno),
        ) {
            LinhaDeFiltros(estado = estado, viewModel = viewModel)

            when (estado.status) {
                StatusFeed.CARREGANDO -> CarregandoFeed()
                StatusFeed.ERRO -> ErroFeed(mensagem = estado.mensagemErro, aoTentarNovamente = viewModel::tentarNovamente)
                StatusFeed.VAZIO -> VazioFeed()
                StatusFeed.SUCESSO -> ListaDeVagas(vagas = estado.vagas, aoAbrirDetalhe = aoAbrirDetalhe)
            }
        }
    }
}

@Composable
private fun LinhaDeFiltros(estado: EstadoFeed, viewModel: FeedVagasViewModel) {
    Column(
        modifier = Modifier.padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
    ) {
        LazyRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
            items(FiltroDistancia.entries.toList()) { filtro ->
                FilterChip(
                    selected = estado.filtroDistancia == filtro,
                    onClick = { viewModel.aoSelecionarFiltroDistancia(filtro) },
                    label = { Text(filtro.rotulo) },
                )
            }
        }

        if (estado.funcoesDisponiveis.isNotEmpty()) {
            LazyRow(
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
            ) {
                item {
                    FilterChip(
                        selected = estado.filtroFuncao == null,
                        onClick = { viewModel.aoSelecionarFiltroFuncao(null) },
                        label = { Text("Todas as funções") },
                    )
                }
                items(estado.funcoesDisponiveis) { funcao ->
                    FilterChip(
                        selected = estado.filtroFuncao == funcao,
                        onClick = { viewModel.aoSelecionarFiltroFuncao(funcao) },
                        label = { Text(funcao) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ListaDeVagas(vagas: List<ItemVaga>, aoAbrirDetalhe: (String) -> Unit) {
    LazyColumn(
        contentPadding = PaddingValues(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
    ) {
        items(vagas, key = { it.id }) { vaga ->
            CartaoVaga(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = FrilaMetricas.alvoMinimo)
                    .clickable { aoAbrirDetalhe(vaga.id) },
            ) {
                Text(text = vaga.funcaoNome, style = MaterialTheme.typography.titleSmall)
                Text(text = vaga.estabelecimentoNome, style = MaterialTheme.typography.bodyMedium)
                Text(text = vaga.horarioFormatado, style = MaterialTheme.typography.bodySmall)
                Text(
                    text = "${vaga.valorFormatado} · ${"%.1f".format(vaga.distanciaKm)} km",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}

@Composable
private fun CarregandoFeed() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator()
    }
}

@Composable
private fun VazioFeed() {
    Box(
        modifier = Modifier.fillMaxSize().padding(FrilaEspacamento.grande),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Nenhuma vaga encontrada com esses filtros.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ErroFeed(mensagem: String?, aoTentarNovamente: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        Text(
            text = mensagem ?: "Não foi possível carregar as vagas.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
        BotaoSecundario(texto = "Tentar novamente", aoClicar = aoTentarNovamente)
    }
}
