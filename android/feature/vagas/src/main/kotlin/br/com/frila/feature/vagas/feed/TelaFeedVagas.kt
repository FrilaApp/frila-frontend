package br.com.frila.feature.vagas.feed

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.RangeSlider
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeBusca
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaBottomSheet
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import kotlin.math.roundToInt

/** O leitor de tela diz "selecionado" ou "não selecionado" no chip de filtro, como sempre disse. */
private fun Modifier.estadoDoChip(selecionado: Boolean): Modifier =
    semantics { stateDescription = if (selecionado) "selecionado" else "não selecionado" }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TelaFeedVagas(
    viewModel: FeedVagasViewModel,
    aoAbrirDetalhe: (String) -> Unit,
    modifier: Modifier = Modifier,
    /** Abre a tela do ponto base quando o servidor recusa a lista por falta dele. Nulo deixa o erro comum, com "Tentar novamente". */
    aoDefinirPontoBase: (() -> Unit)? = null,
    /**
     * Abre os ajustes de notificação do aparelho. Com ele, o alto da lista mostra o aviso de quem está sem notificação (como o
     * `AvisoDePermissaoDePush` do iOS); nulo esconde o aviso.
     */
    aoAbrirAjustesDeNotificacao: (() -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    // Tela raiz: abre sem título de página, com a busca no alto. Meus turnos, Candidaturas e Conta são abas da raiz.
    Scaffold(modifier = modifier, containerColor = FrilaTema.cores.fundo) { paddingInterno ->
        PullToRefreshBox(
            isRefreshing = estado.atualizando,
            onRefresh = viewModel::atualizar,
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingInterno)
                .semantics {
                    contentDescription = if (estado.atualizando) "Atualizando vagas abertas" else if (estado.emCache) "Feed de vagas salvas" else "Feed de vagas abertas"
                },
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(bottom = FrilaEspacamento.grupo),
            ) {
                if (estado.emCache) {
                    item(key = "aviso-de-cache") {
                        AvisoFrila(
                            tom = TomAviso.INFORMATIVO,
                            mensagem = "Exibindo vagas salvas. Disponibilidade não confirmada; conecte-se para verificar se ainda estão abertas.",
                            modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
                        )
                    }
                }
                item(key = "busca") {
                    CampoBuscaVagas(
                        texto = estado.textoBusca,
                        aoAlterarTexto = viewModel::aoAlterarTextoBusca,
                    )
                }
                item(key = "filtros") { LinhaDeFiltros(estado = estado, viewModel = viewModel) }
                if (aoAbrirAjustesDeNotificacao != null) {
                    item(key = "aviso-de-notificacoes") {
                        AvisoDeNotificacoesDesligadas(
                            aoAbrirAjustes = aoAbrirAjustesDeNotificacao,
                            modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
                        )
                    }
                }
                item(key = "cabecalho") { CabecalhoDaLista(estado = estado) }

                when (estado.status) {
                    StatusFeed.CARREGANDO -> item(key = "carregando") { SkeletonFeedVagas() }
                    StatusFeed.ERRO -> item(key = "erro") {
                        if (estado.perfilIncompativel) {
                            PerfilIncompativelFeed()
                        } else if (estado.semPontoBase && aoDefinirPontoBase != null) {
                            SemPontoBaseFeed(aoDefinirPontoBase = aoDefinirPontoBase)
                        } else {
                            ErroFeed(mensagem = estado.mensagemErro, aoTentarNovamente = viewModel::tentarNovamente)
                        }
                    }
                    StatusFeed.VAZIO -> item(key = "vazio") {
                        VazioFeed(textoBusca = estado.textoBusca, comFiltro = estado.temFiltroAtivo, aoLimparFiltros = { viewModel.aoLimparFiltros() })
                    }
                    StatusFeed.SUCESSO -> items(estado.vagas, key = { it.id }) { vaga ->
                        LaunchedEffect(vaga.id) { viewModel.registrarVagaVista(vaga.id) }
                        // O último cartão na tela pede a página seguinte (como o `.task` do último cartão no iOS).
                        val ultima = vaga.id == estado.vagas.last().id
                        LaunchedEffect(vaga.id, ultima) { if (ultima) viewModel.carregarMais() }
                        CartaoDeVagaDoFeed(
                            vaga = vaga,
                            emDestaque = vaga.id == estado.vagas.first().id,
                            aoAbrir = { aoAbrirDetalhe(vaga.id) },
                            modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
                        )
                    }
                }
                if (estado.haMaisPaginas && (estado.status == StatusFeed.SUCESSO || estado.status == StatusFeed.VAZIO)) {
                    item(key = "carregar-mais") {
                        RodapeDaPaginacao(carregando = estado.carregandoMais, aoCarregarMais = { viewModel.carregarMais() })
                    }
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
private fun CampoBuscaVagas(texto: String, aoAlterarTexto: (String) -> Unit) {
    CampoDeBusca(
        texto = texto,
        aoMudar = aoAlterarTexto,
        dica = "Buscar função ou estabelecimento",
        modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
    )
}

/** Quantos filtros da folha estão valendo: o número vai no texto do botão, nunca num selo de pendência. */
private fun EstadoFeed.filtrosAvancadosAplicados(): Int =
    listOf(
        filtroRemuneracao != FiltroRemuneracao.QUALQUER,
        filtroPeriodo != FiltroPeriodo.QUALQUER,
        faixaRemuneracaoHora.ativa,
    ).count { it }

@Composable
private fun LinhaDeFiltros(estado: EstadoFeed, viewModel: FeedVagasViewModel) {
    val aplicados = estado.filtrosAvancadosAplicados()

    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        BotaoSecundario(
            texto = if (aplicados > 0) "Filtros ($aplicados)" else "Filtros",
            aoClicar = viewModel::aoAbrirFiltrosAvancados,
            modifier = Modifier
                .padding(horizontal = FrilaEspacamento.grupo)
                .semantics {
                    contentDescription = if (aplicados > 0) "Abrir filtros avançados, $aplicados aplicados" else "Abrir filtros avançados"
                },
        )

        Text(
            text = "Ordenar por:",
            style = FrilaTipo.rotuloDeGrupo,
            color = FrilaTema.cores.tintaSuave,
            modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo),
        )
        FileiraDeChips {
            items(OpcaoOrdenacaoVagas.entries.toList()) { opcao ->
                ChipFrila(
                    texto = opcao.rotulo,
                    selecionado = estado.opcaoOrdenacao == opcao,
                    aoClicar = { viewModel.aoSelecionarOrdenacao(opcao) },
                    escolhaUnica = true,
                    modifier = Modifier.estadoDoChip(estado.opcaoOrdenacao == opcao),
                )
            }
        }

        FileiraDeChips {
            items(FiltroDistancia.entries.toList()) { filtro ->
                ChipFrila(
                    texto = filtro.rotulo,
                    selecionado = estado.filtroDistancia == filtro,
                    aoClicar = { viewModel.aoSelecionarFiltroDistancia(filtro) },
                    escolhaUnica = true,
                    modifier = Modifier.estadoDoChip(estado.filtroDistancia == filtro),
                )
            }
        }

        if (estado.funcoesDisponiveis.isNotEmpty()) {
            FileiraDeChips {
                item {
                    ChipFrila(
                        texto = "Todas as funções",
                        selecionado = estado.filtroFuncao == null,
                        aoClicar = { viewModel.aoSelecionarFiltroFuncao(null) },
                        escolhaUnica = true,
                        modifier = Modifier.estadoDoChip(estado.filtroFuncao == null),
                    )
                }
                items(estado.funcoesDisponiveis) { funcao ->
                    ChipFrila(
                        texto = funcao,
                        selecionado = estado.filtroFuncao == funcao,
                        aoClicar = { viewModel.aoSelecionarFiltroFuncao(funcao) },
                        escolhaUnica = true,
                        modifier = Modifier.estadoDoChip(estado.filtroFuncao == funcao),
                    )
                }
            }
        }
    }
}

/** Fileira de chips que rola na horizontal e sangra até a borda da tela. */
@Composable
private fun FileiraDeChips(conteudo: androidx.compose.foundation.lazy.LazyListScope.() -> Unit) {
    LazyRow(
        modifier = Modifier.fillMaxWidth(),
        contentPadding = PaddingValues(horizontal = FrilaEspacamento.grupo),
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        content = conteudo,
    )
}

/** O que a lista é (abertas ou salvas) e, quando há vagas, quantas. Apoio, não título de página. */
@Composable
private fun CabecalhoDaLista(estado: EstadoFeed) {
    val cores = FrilaTema.cores
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = FrilaEspacamento.grupo, end = FrilaEspacamento.grupo, top = FrilaEspacamento.bloco),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = if (estado.emCache) "Vagas salvas" else "Vagas abertas",
            style = FrilaTipo.apoio,
            color = cores.tintaSuave,
        )
        Spacer(modifier = Modifier.weight(1f))
        if (estado.status == StatusFeed.SUCESSO && estado.vagas.isNotEmpty()) {
            Text(
                text = textoDaContagem(estado.vagas.size, estado.haMaisPaginas),
                style = FrilaTipo.apoio,
                color = cores.tintaSuave,
            )
        }
    }
}

/** "30 vagas" quando é tudo; "30 vagas carregadas" quando o servidor tem mais (como `contagem(total:haMais:)` do iOS). */
internal fun textoDaContagem(total: Int, haMais: Boolean): String = when {
    haMais && total == 1 -> "1 vaga carregada"
    haMais -> "$total vagas carregadas"
    total == 1 -> "1 vaga"
    else -> "$total vagas"
}

/**
 * O fim da lista quando o servidor tem mais vagas: o indicador enquanto a página seguinte vem e, fora isso, "Carregar mais vagas".
 * O botão cobre o que o último cartão não dispara sozinho: depois de uma falha, ou quando os filtros locais esvaziaram o que veio.
 */
@Composable
private fun RodapeDaPaginacao(carregando: Boolean, aoCarregarMais: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
        contentAlignment = Alignment.Center,
    ) {
        if (carregando) {
            IndicadorCarregando(
                modifier = Modifier
                    .testTag(TAG_CARREGANDO_MAIS)
                    .semantics { contentDescription = TEXTO_CARREGANDO_MAIS },
            )
        } else {
            BotaoSecundario(
                texto = TEXTO_CARREGAR_MAIS,
                aoClicar = aoCarregarMais,
                modifier = Modifier.fillMaxWidth().testTag(TAG_CARREGAR_MAIS),
            )
        }
    }
}

internal const val TEXTO_CARREGAR_MAIS = "Carregar mais vagas"
internal const val TEXTO_CARREGANDO_MAIS = "Carregando mais vagas"
internal const val TAG_CARREGAR_MAIS = "feed-carregar-mais"
internal const val TAG_CARREGANDO_MAIS = "feed-carregando-mais"

/** Folha dos filtros adicionais do RF05/RF10/RN01. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
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
    FrilaBottomSheet(onDismissRequest = aoFechar, titulo = "Filtros avançados") {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    bottom = FrilaEspacamento.grupo,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            // RF05/RN01: RangeSlider para faixa de remuneração líquida por hora
            val minFormatado = faixaRemuneracaoHora.minima.roundToInt()
            val maxFormatado = faixaRemuneracaoHora.maxima.roundToInt()
            RotuloDeGrupo(texto = "Remuneração por hora (líquida)")
            Text(
                text = "R$ $minFormatado/h a R$ $maxFormatado/h",
                style = FrilaTipo.apoio,
                color = FrilaTema.cores.tintaSuave,
            )
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

            RotuloDeGrupo(texto = "Remuneração mínima", modifier = Modifier.padding(top = FrilaEspacamento.item))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                FiltroRemuneracao.entries.forEach { filtro ->
                    val selecionado = filtroRemuneracao == filtro
                    ChipFrila(
                        texto = filtro.rotulo,
                        selecionado = selecionado,
                        aoClicar = { aoSelecionarRemuneracao(filtro) },
                        escolhaUnica = true,
                        modifier = Modifier.estadoDoChip(selecionado),
                    )
                }
            }
            RotuloDeGrupo(texto = "Período do dia", modifier = Modifier.padding(top = FrilaEspacamento.item))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                FiltroPeriodo.entries.forEach { filtro ->
                    val selecionado = filtroPeriodo == filtro
                    ChipFrila(
                        texto = filtro.rotulo,
                        selecionado = selecionado,
                        aoClicar = { aoSelecionarPeriodo(filtro) },
                        escolhaUnica = true,
                        modifier = Modifier.estadoDoChip(selecionado),
                    )
                }
            }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = FrilaEspacamento.bloco),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                BotaoPrimario(
                    texto = "Aplicar filtros",
                    aoClicar = aoAplicar,
                    modifier = Modifier.fillMaxWidth(),
                )
                BotaoSecundario(
                    texto = "Limpar",
                    aoClicar = aoLimpar,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

/**
 * RNF10/RNF04: esqueleto do feed enquanto carrega, em vez de um indicador genérico sem geometria. Replica o
 * cartão de vaga para já indicar o formato do que está vindo. Container único com `liveRegion`: os ossos
 * ([br.com.frila.core.designsystem.componentes.FrilaSkeleton]) são `clearAndSetSemantics {}`, então o TalkBack
 * anuncia só isto, uma vez, em vez de uma vez por osso (MEDIDO, Byakugan: 16 anúncios antes desta correção).
 */
@Composable
private fun SkeletonFeedVagas(quantidade: Int = 3) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item)
            .semantics {
                liveRegion = LiveRegionMode.Polite
                contentDescription = "Carregando lista de vagas..."
            },
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
    ) {
        repeat(quantidade) { CartaoDeVagaEsqueleto() }
    }
}

/**
 * O vazio da lista, como o iOS (`TelaVagas.swift` `estadoVazio`): com filtro valendo, o fato e "Limpar filtros"; sem filtro,
 * só o fato. O vazio da busca por texto segue com o texto dele.
 */
@Composable
private fun VazioFeed(textoBusca: String, comFiltro: Boolean, aoLimparFiltros: () -> Unit) {
    when {
        textoBusca.isNotBlank() -> EstadoVazio(
            titulo = "Nenhuma vaga encontrada para \"${textoBusca.trim()}\".",
            mensagem = "Tente outra busca ou mude os filtros.",
        )
        comFiltro -> EstadoVazio(
            titulo = TextosVazioDoFeed.COM_FILTROS_TITULO,
            mensagem = TextosVazioDoFeed.COM_FILTROS_MENSAGEM,
            textoAcao = TextosVazioDoFeed.LIMPAR_FILTROS,
            aoClicarAcao = aoLimparFiltros,
        )
        else -> EstadoVazio(titulo = TextosVazioDoFeed.SEM_FILTROS_TITULO, mensagem = TextosVazioDoFeed.SEM_FILTROS_MENSAGEM)
    }
}

/** Os textos do iOS (`TextosDoProfissional.Lista`, `vazioSemFiltros*`, `vazioComFiltros*` e `limparFiltros`). */
internal object TextosVazioDoFeed {
    const val SEM_FILTROS_TITULO = "Nenhuma vaga aberta agora."
    const val SEM_FILTROS_MENSAGEM = "Volte mais tarde para ver novas vagas."
    const val COM_FILTROS_TITULO = "Nenhuma vaga com esses filtros."
    const val COM_FILTROS_MENSAGEM = "Tente outros filtros para ver mais vagas."
    const val LIMPAR_FILTROS = "Limpar filtros"
}

/** Sem ponto base o servidor não tem de onde medir a distância: a saída é defini-lo. Textos iguais aos do iOS. */
@Composable
private fun SemPontoBaseFeed(aoDefinirPontoBase: () -> Unit) {
    EstadoVazio(
        titulo = "Falta o seu ponto base",
        mensagem = "Sem ele, não dá para medir a distância até as vagas nem avisar você das que ficam perto.",
        textoAcao = "Definir ponto base",
        aoClicarAcao = aoDefinirPontoBase,
    )
}

/** Conta de contratante: a lista não é dela e "tentar de novo" falharia sempre, então só o aviso, sem botão (como o iOS). */
@Composable
private fun PerfilIncompativelFeed() {
    AvisoFrila(
        tom = TomAviso.ALERTA,
        mensagem = TEXTO_PERFIL_INCOMPATIVEL,
        modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo),
    )
}

@Composable
private fun ErroFeed(mensagem: String?, aoTentarNovamente: () -> Unit) {
    EstadoErro(
        titulo = mensagem ?: "Não foi possível carregar as vagas.",
        mensagem = null,
        aoTentarNovamente = aoTentarNovamente,
    )
}
