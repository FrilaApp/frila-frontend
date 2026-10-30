package br.com.frila.feature.vagas.feed

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RangeSlider
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.componentes.FrilaSkeleton
import br.com.frila.core.designsystem.componentes.semanticaDeFiltro
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaFeedVagas(
    viewModel: FeedVagasViewModel,
    aoAbrirDetalhe: (String) -> Unit,
    modifier: Modifier = Modifier,
    aoAbrirPerfil: () -> Unit = {},
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Vagas abertas", modifier = Modifier.semantics { heading() }) },
                actions = {
                    TextButton(
                        onClick = aoAbrirPerfil,
                        modifier = Modifier
                            .sizeIn(
                                minWidth = FrilaMetricas.alvoMinimo,
                                minHeight = FrilaMetricas.alvoMinimo,
                            )
                            .semantics { contentDescription = "Meu perfil" },
                    ) {
                        Text("Perfil")
                    }
                },
            )
        },
    ) { paddingInterno ->
        PullToRefreshBox(
            isRefreshing = estado.atualizando,
            onRefresh = viewModel::atualizar,
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .semantics {
                    contentDescription = if (estado.atualizando) "Atualizando vagas abertas" else "Feed de vagas abertas"
                },
        ) {
            Column(
                modifier = Modifier.fillMaxSize(),
            ) {
                CampoBuscaVagas(
                    texto = estado.textoBusca,
                    aoAlterarTexto = viewModel::aoAlterarTextoBusca,
                    aoLimpar = viewModel::aoLimparBusca,
                )
                LinhaDeFiltros(estado = estado, viewModel = viewModel)

                when (estado.status) {
                    StatusFeed.CARREGANDO -> SkeletonFeedVagas()
                    StatusFeed.ERRO -> ErroFeed(mensagem = estado.mensagemErro, aoTentarNovamente = viewModel::tentarNovamente)
                    StatusFeed.VAZIO -> VazioFeed(textoBusca = estado.textoBusca)
                    StatusFeed.SUCESSO -> ListaDeVagas(vagas = estado.vagas, aoAbrirDetalhe = aoAbrirDetalhe)
                }
            }
        }
    }

    if (estado.exibindoFiltrosAvancados) {
        FiltrosAvancadosVagas(
            filtroRemuneracao = estado.filtroRemuneracao,
            filtroPeriodo = estado.filtroPeriodo,
            faixaRemuneracaoHora = estado.faixaRemuneracaoHora,
            aoSelecionarRemuneracao = viewModel::aoSelecionarFiltroRemuneracao,
            aoSelecionarPeriodo = viewModel::aoSelecionarFiltroPeriodo,
            aoAlterarFaixaRemuneracaoHora = { viewModel.aoAlterarFaixaRemuneracaoHora(it, ativa = true) },
            aoAplicar = viewModel::aoFecharFiltrosAvancados,
            aoLimpar = viewModel::aoLimparFiltrosAvancados,
            aoFechar = viewModel::aoFecharFiltrosAvancados,
        )
    }
}

@Composable
private fun CampoBuscaVagas(
    texto: String,
    aoAlterarTexto: (String) -> Unit,
    aoLimpar: () -> Unit,
) {
    OutlinedTextField(
        value = texto,
        onValueChange = aoAlterarTexto,
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = FrilaEspacamento.medio,
                end = FrilaEspacamento.medio,
                top = FrilaEspacamento.pequeno,
            )
            .semantics {
                contentDescription = "Buscar vagas por função ou estabelecimento"
            },
        placeholder = { Text("Buscar função ou estabelecimento") },
        leadingIcon = {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = null,
            )
        },
        trailingIcon = if (texto.isNotEmpty()) {
            {
                IconButton(
                    onClick = aoLimpar,
                    modifier = Modifier
                        .sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        )
                        .semantics { contentDescription = "Limpar busca" },
                ) {
                    Icon(
                        imageVector = Icons.Default.Clear,
                        contentDescription = null,
                    )
                }
            }
        } else {
            null
        },
        singleLine = true,
    )
}

@Composable
private fun LinhaDeFiltros(estado: EstadoFeed, viewModel: FeedVagasViewModel) {
    Column(
        modifier = Modifier.padding(horizontal = FrilaEspacamento.medio, vertical = FrilaEspacamento.pequeno),
    ) {
        TextButton(
            onClick = viewModel::aoAbrirFiltrosAvancados,
            modifier = Modifier
                .align(Alignment.End)
                .sizeIn(
                    minWidth = FrilaMetricas.alvoMinimo,
                    minHeight = FrilaMetricas.alvoMinimo,
                )
                .semantics { contentDescription = "Abrir filtros avançados" },
        ) {
            Text("Filtros")
        }

        LazyRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
            items(FiltroDistancia.entries.toList()) { filtro ->
                FilterChip(
                    selected = estado.filtroDistancia == filtro,
                    onClick = { viewModel.aoSelecionarFiltroDistancia(filtro) },
                    label = { Text(filtro.rotulo) },
                    modifier = Modifier.semanticaDeFiltro(estado.filtroDistancia == filtro),
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
                        modifier = Modifier.semanticaDeFiltro(estado.filtroFuncao == null),
                    )
                }
                items(estado.funcoesDisponiveis) { funcao ->
                    FilterChip(
                        selected = estado.filtroFuncao == funcao,
                        onClick = { viewModel.aoSelecionarFiltroFuncao(funcao) },
                        label = { Text(funcao) },
                        modifier = Modifier.semanticaDeFiltro(estado.filtroFuncao == funcao),
                    )
                }
            }
        }
    }
}

/** Folha Material 3 dos filtros adicionais do RF05/RF10/RN01. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FiltrosAvancadosVagas(
    filtroRemuneracao: FiltroRemuneracao,
    filtroPeriodo: FiltroPeriodo,
    faixaRemuneracaoHora: FaixaRemuneracaoHora = FaixaRemuneracaoHora.PADRAO,
    aoSelecionarRemuneracao: (FiltroRemuneracao) -> Unit,
    aoSelecionarPeriodo: (FiltroPeriodo) -> Unit,
    aoAlterarFaixaRemuneracaoHora: (ClosedFloatingPointRange<Float>) -> Unit = {},
    aoAplicar: () -> Unit,
    aoLimpar: () -> Unit,
    aoFechar: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = aoFechar) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = FrilaEspacamento.medio,
                    end = FrilaEspacamento.medio,
                    bottom = FrilaEspacamento.medio,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
        ) {
            Text(
                text = "Filtros avançados",
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.semantics { heading() },
            )

            // RF05/RN01: RangeSlider para faixa de remuneração líquida por hora
            val minFormatado = faixaRemuneracaoHora.minima.roundToInt()
            val maxFormatado = faixaRemuneracaoHora.maxima.roundToInt()
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Remuneração por hora (líquida)",
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    text = "R$ $minFormatado/h a R$ $maxFormatado/h",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            RangeSlider(
                value = faixaRemuneracaoHora.minima..faixaRemuneracaoHora.maxima,
                onValueChange = { range ->
                    aoAlterarFaixaRemuneracaoHora(range)
                },
                valueRange = FaixaRemuneracaoHora.LIMITE_MINIMO..FaixaRemuneracaoHora.LIMITE_MAXIMO,
                steps = 25,
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics {
                        contentDescription = "Faixa de remuneração de R$ $minFormatado por hora até R$ $maxFormatado por hora"
                    },
            )

            Text(
                text = "Remuneração mínima",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.semantics { heading() },
            )
            LazyRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                items(FiltroRemuneracao.entries.toList()) { filtro ->
                    val selecionado = filtroRemuneracao == filtro
                    FilterChip(
                        selected = selecionado,
                        onClick = { aoSelecionarRemuneracao(filtro) },
                        label = { Text(filtro.rotulo) },
                        modifier = Modifier.semanticaDeFiltro(selecionado),
                    )
                }
            }
            Text(
                text = "Período do dia",
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.semantics { heading() },
            )
            LazyRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                items(FiltroPeriodo.entries.toList()) { filtro ->
                    val selecionado = filtroPeriodo == filtro
                    FilterChip(
                        selected = selecionado,
                        onClick = { aoSelecionarPeriodo(filtro) },
                        label = { Text(filtro.rotulo) },
                        modifier = Modifier.semanticaDeFiltro(selecionado),
                    )
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = FrilaEspacamento.minimo),
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
            ) {
                BotaoPrimario(
                    texto = "Aplicar filtros",
                    aoClicar = aoAplicar,
                    modifier = Modifier.weight(1f),
                )
                BotaoSecundario(
                    texto = "Limpar",
                    aoClicar = aoLimpar,
                    modifier = Modifier.weight(1f),
                )
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
                modifier = Modifier.fillMaxWidth(),
                aoClicar = { aoAbrirDetalhe(vaga.id) },
                rotuloDaAcao = "Abrir detalhes da vaga de ${vaga.funcaoNome}",
            ) {
                Text(
                    text = vaga.funcaoNome,
                    style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.semantics { heading() },
                )
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

/**
 * RNF10/RNF04: skeleton do feed enquanto carrega, em vez de um spinner genérico sem geometria.
 * Replica os 4 cartões de [CartaoVaga] (título, estabelecimento, horário, valor+distância) para
 * já indicar o formato do conteúdo que está vindo. Container único com `liveRegion` — os ossos
 * individuais ([FrilaSkeleton]) são `clearAndSetSemantics {}`, então o TalkBack anuncia só isto,
 * uma vez, em vez de uma vez por osso (MEDIDO, Byakugan: 16 anúncios antes desta correção).
 */
@Composable
private fun SkeletonFeedVagas(quantidade: Int = 4) {
    LazyColumn(
        contentPadding = PaddingValues(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
        modifier = Modifier
            .fillMaxSize()
            .semantics {
                liveRegion = LiveRegionMode.Polite
                contentDescription = "Carregando lista de vagas..."
            },
    ) {
        items(quantidade) {
            CartaoVaga(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto)) {
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.6f).height(20.dp), shape = RoundedCornerShape(FrilaRaios.pequeno))
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.8f).height(16.dp), shape = RoundedCornerShape(FrilaRaios.pequeno))
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.45f).height(14.dp), shape = RoundedCornerShape(FrilaRaios.pequeno))
                    FrilaSkeleton(modifier = Modifier.fillMaxWidth(0.45f).height(14.dp), shape = RoundedCornerShape(FrilaRaios.pequeno))
                }
            }
        }
    }
}

@Composable
private fun VazioFeed(textoBusca: String) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(FrilaEspacamento.grande),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = if (textoBusca.isNotBlank()) {
                "Nenhuma vaga encontrada para \"${textoBusca.trim()}\"."
            } else {
                "Nenhuma vaga encontrada com esses filtros."
            },
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun ErroFeed(mensagem: String?, aoTentarNovamente: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        Text(
            text = mensagem ?: "Não foi possível carregar as vagas.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { error(mensagem ?: "Não foi possível carregar as vagas.") },
        )
        BotaoSecundario(texto = "Tentar novamente", aoClicar = aoTentarNovamente)
    }
}
