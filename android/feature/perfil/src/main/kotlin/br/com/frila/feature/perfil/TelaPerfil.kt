package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AssistChip
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.ReputacaoDto
import kotlin.math.roundToInt

/**
 * Perfil do profissional (RF03/RF16, UC09): reputação sempre com denominador (RN08), nunca uma
 * média sem contexto (RN07), e logout local (RN15) sem mandar nada à rede.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TelaPerfil(
    viewModel: PerfilViewModel,
    modifier: Modifier = Modifier,
    aoDeslogar: () -> Unit = {},
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    Scaffold(
        modifier = modifier,
        topBar = { CenterAlignedTopAppBar(title = { Text("Meu Perfil") }) },
    ) { paddingInterno ->
        when (estado.status) {
            StatusPerfil.CARREGANDO -> Carregando(paddingInterno)
            StatusPerfil.ERRO -> Erro(
                mensagem = estado.mensagemErro,
                aoTentarNovamente = viewModel::carregar,
                paddingValues = paddingInterno,
            )
            StatusPerfil.SUCESSO -> ConteudoDoPerfil(
                funcoes = estado.perfil?.funcoes.orEmpty(),
                reputacao = estado.perfil?.reputacao,
                aoDeslogar = {
                    viewModel.aoDeslogar()
                    aoDeslogar()
                },
                paddingValues = paddingInterno,
            )
        }
    }
}

@Composable
private fun ConteudoDoPerfil(
    funcoes: List<FuncaoDto>,
    reputacao: ReputacaoDto?,
    aoDeslogar: () -> Unit,
    paddingValues: PaddingValues,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(paddingValues).padding(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        BlocoDeReputacao(reputacao)
        BlocoDeFuncoes(funcoes)
        BlocoDeConta(aoDeslogar)
    }
}

/** RN07/RN08: binária com denominador obrigatório. Nunca nota, nunca média sem "de quantas". */
@Composable
private fun BlocoDeReputacao(reputacao: ReputacaoDto?) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(text = "Reputação", style = MaterialTheme.typography.titleSmall)
        Column(
            modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
        ) {
            if (reputacao == null || reputacao.total == 0) {
                Text(text = "Sem histórico de avaliações", style = MaterialTheme.typography.bodyMedium)
            } else {
                Text(
                    text = "${reputacao.positivas} de ${reputacao.total} recomendariam de novo",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(
                    text = "Taxa de comparecimento: ${formatarTaxa(reputacao.taxaComparecimento)}",
                    style = MaterialTheme.typography.bodySmall,
                )
                Text(
                    text = "${reputacao.turnosRealizados} turnos realizados",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}

private fun formatarTaxa(taxa: Double?): String =
    if (taxa == null) "Sem histórico" else "${(taxa * 100).roundToInt()}%"

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BlocoDeFuncoes(funcoes: List<FuncaoDto>) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(text = "Funções cadastradas", style = MaterialTheme.typography.titleSmall)
        if (funcoes.isEmpty()) {
            Text(
                text = "Nenhuma função cadastrada ainda.",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
            )
        } else {
            FlowRow(
                modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
            ) {
                funcoes.forEach { funcao ->
                    AssistChip(onClick = {}, label = { Text(funcao.nome) })
                }
            }
        }
    }
}

@Composable
private fun BlocoDeConta(aoDeslogar: () -> Unit) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(text = "Conta", style = MaterialTheme.typography.titleSmall)
        BotaoSecundario(
            texto = "Sair da conta",
            aoClicar = aoDeslogar,
            modifier = Modifier.fillMaxWidth().padding(top = FrilaEspacamento.pequeno),
        )
    }
}

@Composable
private fun Carregando(paddingValues: PaddingValues) {
    Box(
        modifier = Modifier.fillMaxSize().padding(paddingValues),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun Erro(
    mensagem: String?,
    aoTentarNovamente: () -> Unit,
    paddingValues: PaddingValues,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(paddingValues).padding(FrilaEspacamento.grande),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio, Alignment.CenterVertically),
    ) {
        Text(
            text = mensagem ?: "Não foi possível carregar seu perfil.",
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
        BotaoSecundario(texto = "Tentar novamente", aoClicar = aoTentarNovamente)
    }
}
