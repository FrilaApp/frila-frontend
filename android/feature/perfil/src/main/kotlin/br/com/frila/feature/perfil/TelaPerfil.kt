package br.com.frila.feature.perfil

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.ReputacaoDto
import kotlin.math.roundToInt

/**
 * Perfil do profissional (RF03/RF16/RF25/RN15/RNF08, UC09/UC16): reputação sempre com
 * denominador (RN08), nunca uma média sem contexto (RN07); logout e exclusão de conta são
 * locais primeiro (RN15) — a sessão só é limpa depois da confirmação (logout) ou do sucesso
 * da Edge Function (exclusão), nunca antes.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TelaPerfil(
    viewModel: PerfilViewModel,
    modifier: Modifier = Modifier,
    aoDeslogar: () -> Unit = {},
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()

    // RF25/UC16: a exclusão com sucesso expulsa a navegação do mesmo jeito que o logout —
    // a sessão local já foi limpa pelo ViewModel antes de chegar aqui.
    LaunchedEffect(estado.statusExclusao) {
        if (estado.statusExclusao == StatusExclusao.SUCESSO) {
            aoDeslogar()
        }
    }

    Scaffold(
        modifier = modifier,
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Meu Perfil", modifier = Modifier.semantics { heading() }) },
            )
        },
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
                aoAbrirExclusao = viewModel::abrirDialogoExclusao,
                paddingValues = paddingInterno,
            )
        }

        when (estado.statusExclusao) {
            StatusExclusao.DIALOGO_ABERTO -> DialogoConfirmarExclusao(
                aoConfirmar = { viewModel.confirmarExclusao() },
                aoCancelar = viewModel::cancelarExclusao,
            )
            StatusExclusao.EXCLUINDO -> DialogoExcluindo()
            StatusExclusao.ERRO -> DialogoErroExclusao(
                mensagem = estado.mensagemErroExclusao,
                aoFechar = viewModel::cancelarExclusao,
            )
            StatusExclusao.OCIOSO, StatusExclusao.SUCESSO -> Unit
        }
    }
}

@Composable
private fun ConteudoDoPerfil(
    funcoes: List<FuncaoDto>,
    reputacao: ReputacaoDto?,
    aoDeslogar: () -> Unit,
    aoAbrirExclusao: () -> Unit,
    paddingValues: PaddingValues,
) {
    Column(
        modifier = Modifier.fillMaxSize().padding(paddingValues).padding(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        BlocoDeReputacao(reputacao)
        BlocoDeFuncoes(funcoes)
        BlocoDeConta(aoDeslogar = aoDeslogar, aoAbrirExclusao = aoAbrirExclusao)
    }
}

/** RN07/RN08: binária com denominador obrigatório. Nunca nota, nunca média sem "de quantas". */
@Composable
private fun BlocoDeReputacao(reputacao: ReputacaoDto?) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Reputação",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
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
        Text(
            text = "Funções cadastradas",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
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
                    Surface(
                        shape = MaterialTheme.shapes.small,
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
                    ) {
                        Text(
                            text = funcao.nome,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(
                                horizontal = FrilaEspacamento.pequeno,
                                vertical = FrilaEspacamento.minimo,
                            ),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BlocoDeConta(aoDeslogar: () -> Unit, aoAbrirExclusao: () -> Unit) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "Conta",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.semantics { heading() },
        )
        BotaoSecundario(
            texto = "Sair da conta",
            aoClicar = aoDeslogar,
            modifier = Modifier.fillMaxWidth().padding(top = FrilaEspacamento.pequeno),
        )
        BotaoDestrutivo(
            texto = "Excluir conta",
            aoClicar = aoAbrirExclusao,
            modifier = Modifier.fillMaxWidth().padding(top = FrilaEspacamento.pequeno),
        )
    }
}

/**
 * Botão de ação destrutiva: cores `error`/`onError` do tema, mesmo alvo mínimo 48dp dos
 * demais botões do design system (RNF10). Não há um componente de design system para isto
 * ainda — só `BotaoPrimario`/`BotaoSecundario`, nenhum em tom de perigo.
 */
@Composable
private fun BotaoDestrutivo(texto: String, aoClicar: () -> Unit, modifier: Modifier = Modifier) {
    Button(
        onClick = aoClicar,
        modifier = modifier
            .sizeIn(
                minWidth = FrilaMetricas.alvoMinimo,
                minHeight = FrilaMetricas.alvoMinimo,
            )
            .heightIn(min = FrilaMetricas.alturaBotao)
            .widthIn(min = FrilaMetricas.alvoMinimo),
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.error,
            contentColor = MaterialTheme.colorScheme.onError,
        ),
    ) {
        Text(text = texto, style = MaterialTheme.typography.titleSmall)
    }
}

/** RF25/UC16: confirmação explícita, com o alerta de irreversibilidade exigido pela LGPD. */
@Composable
private fun DialogoConfirmarExclusao(aoConfirmar: () -> Unit, aoCancelar: () -> Unit) {
    AlertDialog(
        onDismissRequest = aoCancelar,
        title = {
            Text(
                "Excluir conta definitivamente?",
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            Text(
                "Esta ação não pode ser desfeita. Seus turnos futuros serão cancelados sem " +
                    "penalidade para você, e seus dados pessoais serão apagados em até 15 dias, " +
                    "conforme a LGPD.",
            )
        },
        confirmButton = {
            TextButton(
                onClick = aoConfirmar,
                modifier = Modifier.sizeIn(
                    minWidth = FrilaMetricas.alvoMinimo,
                    minHeight = FrilaMetricas.alvoMinimo,
                ),
            ) {
                Text("Sim, excluir minha conta", color = MaterialTheme.colorScheme.error)
            }
        },
        dismissButton = {
            TextButton(
                onClick = aoCancelar,
                modifier = Modifier.sizeIn(
                    minWidth = FrilaMetricas.alvoMinimo,
                    minHeight = FrilaMetricas.alvoMinimo,
                ),
            ) { Text("Cancelar") }
        },
    )
}

@Composable
private fun DialogoExcluindo() {
    AlertDialog(
        onDismissRequest = {},
        title = { Text("Excluindo conta…", modifier = Modifier.semantics { heading() }) },
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator()
            }
        },
        confirmButton = {},
    )
}

@Composable
private fun DialogoErroExclusao(mensagem: String?, aoFechar: () -> Unit) {
    AlertDialog(
        onDismissRequest = aoFechar,
        title = {
            Text(
                "Não foi possível excluir a conta",
                modifier = Modifier.semantics { heading() },
            )
        },
        text = {
            val textoErro = mensagem ?: "Tente de novo em instantes."
            Text(textoErro, modifier = Modifier.semantics { error(textoErro) })
        },
        confirmButton = {
            TextButton(
                onClick = aoFechar,
                modifier = Modifier.sizeIn(
                    minWidth = FrilaMetricas.alvoMinimo,
                    minHeight = FrilaMetricas.alvoMinimo,
                ),
            ) { Text("Entendi") }
        },
    )
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
            modifier = Modifier.semantics { error(mensagem ?: "Não foi possível carregar seu perfil.") },
        )
        BotaoSecundario(texto = "Tentar novamente", aoClicar = aoTentarNovamente)
    }
}
