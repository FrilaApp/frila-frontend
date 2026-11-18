package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

/** Liga o [PontoBaseViewModel] ao [ConteudoPontoBase], carrega o perfil ao abrir e avisa quem abriu quando o ponto foi salvo. */
@Composable
fun TelaPontoBase(
    viewModel: PontoBaseViewModel,
    aoVoltar: () -> Unit,
    aoSalvo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    LaunchedEffect(estado.salvo) { if (estado.salvo) aoSalvo() }
    ConteudoPontoBase(
        estado = estado,
        aoEscolher = viewModel::escolher,
        aoAlternarFuncao = viewModel::alternarFuncao,
        aoSalvar = { viewModel.salvar() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

/**
 * Ponto base do profissional: uma lista de regiões para escolher uma e, só para quem ainda não tem perfil, as funções.
 * TELA PROVISÓRIA: só listas nativas, sem estilo novo.
 */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoPontoBase(
    estado: EstadoPontoBase,
    aoEscolher: (OpcaoDePontoBase) -> Unit,
    aoAlternarFuncao: (String) -> Unit,
    aoSalvar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(TextosPontoBase.TITULO, style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() })
                },
                navigationIcon = {
                    IconButton(
                        onClick = aoVoltar,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = TextosPontoBase.VOLTAR)
                    }
                },
            )
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(FrilaEspacamento.medio),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
        ) {
            Text(TextosPontoBase.DICA, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (estado.carregando) Text(TextosPontoBase.CARREGANDO, style = MaterialTheme.typography.bodyMedium)
            if (estado.temPontoBaseSalvo) Text(TextosPontoBase.PONTO_BASE_SALVO, style = MaterialTheme.typography.bodyMedium)

            if (estado.semPerfil) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                    Text(TextosPontoBase.FUNCOES, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                    Text(
                        TextosPontoBase.FUNCOES_DICA,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    for (funcao in estado.funcoes) {
                        Linha(
                            texto = funcao.nome,
                            modifier = Modifier.toggleable(
                                value = funcao.id in estado.funcoesEscolhidas,
                                role = Role.Checkbox,
                                onValueChange = { aoAlternarFuncao(funcao.id) },
                            ),
                        ) { Checkbox(checked = funcao.id in estado.funcoesEscolhidas, onCheckedChange = null) }
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
                Text(
                    TextosPontoBase.ESCOLHA_A_REGIAO,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.semantics { heading() },
                )
                for (opcao in estado.opcoes) {
                    Linha(
                        texto = opcao.nome,
                        modifier = Modifier.selectable(
                            selected = opcao == estado.escolhida,
                            role = Role.RadioButton,
                            onClick = { aoEscolher(opcao) },
                        ),
                    ) { RadioButton(selected = opcao == estado.escolhida, onClick = null) }
                }
            }

            estado.erro?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                )
            }
            BotaoPrimario(
                texto = if (estado.salvando) TextosPontoBase.SALVANDO else TextosPontoBase.SALVAR,
                aoClicar = aoSalvar,
                habilitado = !estado.salvando && !estado.carregando,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun Linha(texto: String, modifier: Modifier, marcador: @Composable () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .sizeIn(minHeight = FrilaMetricas.alvoMinimo)
            .then(modifier),
    ) {
        marcador()
        Text(texto, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(start = FrilaEspacamento.pequeno))
    }
}
