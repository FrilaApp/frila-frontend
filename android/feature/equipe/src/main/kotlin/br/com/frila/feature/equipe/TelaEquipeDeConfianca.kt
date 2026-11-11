package br.com.frila.feature.equipe

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
import br.com.frila.core.rede.PerfilPublicoDto

/** Liga o [EquipeDeConfiancaViewModel] ao [ConteudoEquipeDeConfianca]. */
@Composable
fun TelaEquipeDeConfianca(
    viewModel: EquipeDeConfiancaViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoEquipeDeConfianca(
        tela = estado,
        aoTentarNovamente = { viewModel.carregar() },
        aoRemover = { viewModel.remover(it) },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

/**
 * Equipe de confiança do estabelecimento (RF18, UC11; paridade com `TelaEquipeDeConfianca.swift`):
 * explicação, lista com a remoção de cada profissional atrás de uma confirmação, estado vazio e
 * "tentar novamente" nos erros. O diálogo guarda só o `id` de quem está para sair.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoEquipeDeConfianca(
    tela: EstadoTelaEquipe,
    aoTentarNovamente: () -> Unit,
    aoRemover: (PerfilPublicoDto) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var idParaRemover by rememberSaveable { mutableStateOf<String?>(null) }
    val membros = (tela.estado as? EstadoEquipe.Conteudo)?.membros.orEmpty()
    val paraRemover = membros.firstOrNull { it.id == idParaRemover }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosEquipe.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier.sizeIn(
                            minWidth = FrilaMetricas.alvoMinimo,
                            minHeight = FrilaMetricas.alvoMinimo,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosEquipe.ROTULO_VOLTAR,
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
                    text = TextosEquipe.EXPLICACAO,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                )
            }
            tela.aviso?.let { aviso ->
                item {
                    Text(
                        text = aviso,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                    )
                }
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
                EstadoEquipe.Carregando -> item { Carregando() }
                EstadoEquipe.Vazio -> item { Vazio() }
                EstadoEquipe.SemRede -> item { ErroComRetry(TextosEquipe.SEM_REDE, aoTentarNovamente) }
                is EstadoEquipe.Erro -> item { ErroComRetry(estado.mensagem, aoTentarNovamente) }
                is EstadoEquipe.Conteudo -> {
                    items(estado.membros, key = { it.id }) { perfil ->
                        LinhaDoMembro(
                            perfil = perfil,
                            removendo = tela.removendo == perfil.id,
                            bloqueado = tela.ocupado,
                            aoRemover = { idParaRemover = perfil.id },
                        )
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    }
                }
            }
        }
    }

    if (paraRemover != null) {
        AlertDialog(
            onDismissRequest = { idParaRemover = null },
            title = {
                Text(text = TextosEquipe.CONFIRMAR_REMOCAO, modifier = Modifier.semantics { heading() })
            },
            text = { Text(text = TextosEquipe.efeitoRemocao(paraRemover.nome)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        idParaRemover = null
                        aoRemover(paraRemover)
                    },
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) { Text(TextosEquipe.CONFIRMAR_REMOVER, color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(
                    onClick = { idParaRemover = null },
                    modifier = Modifier.sizeIn(
                        minWidth = FrilaMetricas.alvoMinimo,
                        minHeight = FrilaMetricas.alvoMinimo,
                    ),
                ) { Text(TextosEquipe.CANCELAR) }
            },
        )
    }
}

@Composable
private fun LinhaDoMembro(
    perfil: PerfilPublicoDto,
    removendo: Boolean,
    bloqueado: Boolean,
    aoRemover: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = FrilaEspacamento.pequeno),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
    ) {
        Text(
            text = perfil.nome,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() },
        )
        perfil.funcoes?.takeIf { it.isNotEmpty() }?.let { funcoes ->
            Text(
                text = funcoes.joinToString(", "),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            text = TextosEquipe.reputacao(perfil.reputacao.positivas, perfil.reputacao.total),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
            BotaoSecundario(
                texto = if (removendo) TextosEquipe.REMOVENDO else TextosEquipe.REMOVER,
                aoClicar = aoRemover,
                habilitado = !bloqueado,
                modifier = Modifier.semantics { contentDescription = TextosEquipe.rotuloRemover(perfil.nome) },
            )
            if (removendo) CircularProgressIndicator(modifier = Modifier.size(24.dp))
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
        Text(text = TextosEquipe.CARREGANDO, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun Vazio() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = FrilaEspacamento.grande),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno),
    ) {
        Text(
            text = TextosEquipe.VAZIO_TITULO,
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.semantics { heading() },
        )
        Text(text = TextosEquipe.VAZIO_MENSAGEM, style = MaterialTheme.typography.bodyMedium)
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
        BotaoPrimario(texto = TextosEquipe.TENTAR_NOVAMENTE, aoClicar = aoTentarNovamente)
    }
}
