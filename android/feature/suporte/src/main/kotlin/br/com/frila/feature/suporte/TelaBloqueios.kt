package br.com.frila.feature.suporte

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
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
    )
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/**
 * "Pessoas e locais bloqueados" (RF26, decisão A8; paridade com `TelaBloqueios.swift`): explicação, a lista com o
 * desbloqueio de cada item atrás de uma confirmação, estado vazio e "tentar novamente" nos erros. O diálogo guarda só a
 * chave do item que está para ser desbloqueado. Sem fiação: quem a abre é o L2-8.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoBloqueios(
    tela: EstadoTelaBloqueios,
    aoTentarNovamente: () -> Unit,
    aoDesbloquear: (ItemBloqueioDto) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var chaveParaDesbloquear by rememberSaveable { mutableStateOf<String?>(null) }
    val itens = (tela.estado as? EstadoBloqueios.Conteudo)?.itens.orEmpty()
    val paraDesbloquear = itens.firstOrNull { chaveDoBloqueio(it) == chaveParaDesbloquear }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosBloqueios.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosBloqueios.ROTULO_VOLTAR,
                        )
                    }
                },
            )
        },
    ) { preenchimento ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .padding(horizontal = FrilaEspacamento.medio),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            item {
                Text(
                    text = TextosBloqueios.EXPLICACAO,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                )
            }
            tela.mensagemErro?.let { erro ->
                item {
                    Text(
                        text = erro,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
            }

            when (val estado = tela.estado) {
                EstadoBloqueios.Carregando -> item { Carregando() }
                EstadoBloqueios.Vazio -> item { Vazio() }
                EstadoBloqueios.SemRede -> item { ErroComRetry(TextosBloqueios.SEM_REDE, aoTentarNovamente) }
                is EstadoBloqueios.Erro -> item { ErroComRetry(estado.mensagem, aoTentarNovamente) }
                is EstadoBloqueios.Conteudo -> {
                    items(estado.itens, key = { chaveDoBloqueio(it) }) { item ->
                        val chave = chaveDoBloqueio(item)
                        LinhaDoBloqueio(
                            item = item,
                            desbloqueando = tela.desbloqueando == chave,
                            bloqueado = tela.desbloqueando != null,
                            aoDesbloquear = { chaveParaDesbloquear = chave },
                        )
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    }
                }
            }
        }
    }

    if (paraDesbloquear != null) {
        AlertDialog(
            onDismissRequest = { chaveParaDesbloquear = null },
            title = { Text(text = TextosBloqueios.CONFIRMAR_DESBLOQUEIO, modifier = Modifier.semantics { heading() }) },
            text = { Text(text = TextosBloqueios.efeitoDesbloqueio(paraDesbloquear.nome)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        chaveParaDesbloquear = null
                        aoDesbloquear(paraDesbloquear)
                    },
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosBloqueios.DESBLOQUEAR) }
            },
            dismissButton = {
                TextButton(
                    onClick = { chaveParaDesbloquear = null },
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosBloqueios.CANCELAR) }
            },
        )
    }
}

@Composable
private fun LinhaDoBloqueio(
    item: ItemBloqueioDto,
    desbloqueando: Boolean,
    bloqueado: Boolean,
    aoDesbloquear: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = FrilaEspacamento.pequeno),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
    ) {
        Text(text = item.nome, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        Text(
            text = TextosBloqueios.rotuloDoTipo(item.alvoTipo),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
            BotaoSecundario(
                texto = if (desbloqueando) TextosBloqueios.DESBLOQUEANDO else TextosBloqueios.DESBLOQUEAR,
                aoClicar = aoDesbloquear,
                habilitado = !bloqueado,
                modifier = Modifier.semantics { contentDescription = TextosBloqueios.rotuloDesbloquear(item.nome) },
            )
            if (desbloqueando) CircularProgressIndicator(modifier = Modifier.size(24.dp))
        }
    }
}

@Composable
private fun Carregando() {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = FrilaEspacamento.grande),
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CircularProgressIndicator(modifier = Modifier.size(24.dp))
        Text(text = TextosBloqueios.CARREGANDO, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun Vazio() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = FrilaEspacamento.grande),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
    ) {
        Text(text = TextosBloqueios.VAZIO_TITULO, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        Text(text = TextosBloqueios.VAZIO_MENSAGEM, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun ErroComRetry(mensagem: String, aoTentarNovamente: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = FrilaEspacamento.grande),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(
            text = mensagem,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.error,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
        )
        BotaoPrimario(texto = TextosBloqueios.TENTAR_NOVAMENTE, aoClicar = aoTentarNovamente)
    }
}
