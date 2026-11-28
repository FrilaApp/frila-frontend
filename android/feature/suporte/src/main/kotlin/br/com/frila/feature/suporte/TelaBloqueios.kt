package br.com.frila.feature.suporte

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.ItemBloqueioDto

/** Liga o [BloqueiosViewModel] ao [ConteudoBloqueios]. */
@Composable
fun TelaBloqueios(
    viewModel: BloqueiosViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoBloqueios(
        tela = estado,
        aoTentarNovamente = { viewModel.carregar() },
        aoDesbloquear = { viewModel.desbloquear(it) },
        aoVoltar = aoVoltar,
        modifier = modifier,
        aoAtualizar = { viewModel.atualizar() },
    )
}

/**
 * "Pessoas e locais bloqueados" (RF26, decisão A8; paridade com `TelaBloqueios.swift`): explicação, a lista com o
 * desbloqueio de cada item atrás de uma confirmação, estado vazio e "tentar novamente" nos erros. O diálogo guarda só a
 * chave do item que está para ser desbloqueado.
 *
 * Tela de leitura: sem laranja. O desbloqueio é um botão secundário na própria linha; enquanto um roda, os outros
 * ficam desligados e o rótulo vira "Desbloqueando…" no lugar.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoBloqueios(
    tela: EstadoTelaBloqueios,
    aoTentarNovamente: () -> Unit,
    aoDesbloquear: (ItemBloqueioDto) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    /** CLD9Yg3e: puxar para atualizar, como o `.refreshable` do iOS. */
    aoAtualizar: () -> Unit = {},
) {
    var chaveParaDesbloquear by rememberSaveable { mutableStateOf<String?>(null) }
    val itens = (tela.estado as? EstadoBloqueios.Conteudo)?.itens.orEmpty()
    val paraDesbloquear = itens.firstOrNull { chaveDoBloqueio(it) == chaveParaDesbloquear }
    val cores = FrilaTema.cores

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
    ) { preenchimento ->
        // Puxar para atualizar (iOS `.refreshable`), em qualquer estado da tela. Com a lista na tela o ViewModel a mantém.
        PullToRefreshBox(
            isRefreshing = tela.atualizando,
            onRefresh = aoAtualizar,
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento),
        ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                top = FrilaEspacamento.item,
                bottom = FrilaEspacamento.grupo,
            ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            item {
                Column(
                    modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo),
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                ) {
                    TituloDaTela(TextosBloqueios.TITULO)
                    Text(text = TextosBloqueios.EXPLICACAO, style = FrilaTipo.apoio, color = cores.tintaSuave)
                }
            }
            tela.mensagemErro?.let { erro ->
                item {
                    AvisoFrila(
                        tom = TomAviso.ERRO,
                        mensagem = erro,
                        modifier = Modifier
                            .padding(horizontal = FrilaEspacamento.grupo)
                            .semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
            }

            when (val estado = tela.estado) {
                EstadoBloqueios.Carregando -> item { EstadoCarregando(mensagem = TextosBloqueios.CARREGANDO) }
                EstadoBloqueios.Vazio -> item {
                    EstadoVazio(titulo = TextosBloqueios.VAZIO_TITULO, mensagem = TextosBloqueios.VAZIO_MENSAGEM)
                }
                EstadoBloqueios.SemRede -> item {
                    EstadoErro(titulo = TextosBloqueios.SEM_REDE, mensagem = null, aoTentarNovamente = aoTentarNovamente)
                }
                is EstadoBloqueios.Erro -> item {
                    EstadoErro(titulo = estado.mensagem, mensagem = null, aoTentarNovamente = aoTentarNovamente)
                }
                is EstadoBloqueios.Conteudo -> item {
                    FrilaGrupoDeLinhas(modifier = Modifier.padding(horizontal = FrilaEspacamento.grupo)) {
                        estado.itens.forEach { item ->
                            val chave = chaveDoBloqueio(item)
                            linha {
                                LinhaDoBloqueio(
                                    item = item,
                                    desbloqueando = tela.desbloqueando == chave,
                                    bloqueado = tela.desbloqueando != null || tela.atualizando,
                                    aoDesbloquear = { chaveParaDesbloquear = chave },
                                )
                            }
                        }
                    }
                }
            }
        }
        }
    }

    if (paraDesbloquear != null) {
        DialogoDeConfirmacao(
            titulo = TextosBloqueios.CONFIRMAR_DESBLOQUEIO,
            mensagem = TextosBloqueios.efeitoDesbloqueio(paraDesbloquear.nome),
            textoConfirmar = TextosBloqueios.DESBLOQUEAR,
            aoConfirmar = {
                chaveParaDesbloquear = null
                aoDesbloquear(paraDesbloquear)
            },
            textoCancelar = TextosBloqueios.CANCELAR,
            aoCancelar = { chaveParaDesbloquear = null },
        )
    }
}

/** Com a fonte do sistema grande, o botão desce para baixo do nome: lado a lado o nome quebraria no meio da palavra. */
private const val ESCALA_DA_FONTE_PARA_EMPILHAR = 1.3f

@Composable
private fun LinhaDoBloqueio(
    item: ItemBloqueioDto,
    desbloqueando: Boolean,
    bloqueado: Boolean,
    aoDesbloquear: () -> Unit,
) {
    val cores = FrilaTema.cores
    val empilhar = LocalDensity.current.fontScale >= ESCALA_DA_FONTE_PARA_EMPILHAR
    val identificacao: @Composable (Modifier) -> Unit = { m ->
        Column(modifier = m, verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
            Text(text = item.nome, style = FrilaTipo.nome, color = cores.tinta)
            Text(text = TextosBloqueios.rotuloDoTipo(item.alvoTipo), style = FrilaTipo.apoio, color = cores.tintaSuave)
        }
    }
    val botao: @Composable () -> Unit = {
        BotaoSecundario(
            texto = if (desbloqueando) TextosBloqueios.DESBLOQUEANDO else TextosBloqueios.DESBLOQUEAR,
            aoClicar = aoDesbloquear,
            habilitado = !bloqueado,
            modifier = Modifier.semantics { contentDescription = TextosBloqueios.rotuloDesbloquear(item.nome) },
        )
    }
    val moldura = Modifier
        .fillMaxWidth()
        .heightIn(min = FrilaMetricas.alvoMinimo)
        .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item)
    if (empilhar) {
        Column(modifier = moldura, verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            identificacao(Modifier)
            botao()
        }
    } else {
        Row(
            modifier = moldura,
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            identificacao(Modifier.weight(1f))
            botao()
        }
    }
}
