package br.com.frila.feature.equipe

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.PerfilPublicoDto

/** Liga o [EquipeDeConfiancaViewModel] ao [ConteudoEquipeDeConfianca]. */
@Composable
fun TelaEquipeDeConfianca(
    viewModel: EquipeDeConfiancaViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoChamarDeNovo: ((PerfilPublicoDto) -> Unit)? = null,
    aoDenunciar: ((PerfilPublicoDto) -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoEquipeDeConfianca(
        tela = estado,
        aoTentarNovamente = { viewModel.carregar() },
        aoRemover = { viewModel.remover(it) },
        aoVoltar = aoVoltar,
        modifier = modifier,
        aoChamarDeNovo = aoChamarDeNovo,
        aoDenunciar = aoDenunciar,
    )
}

/**
 * Equipe de confiança do estabelecimento (RF18, UC11; paridade com `TelaEquipeDeConfianca.swift`): lista de leitura
 * com a explicação, um cartão por profissional e as ações de cada um ("Chamar de novo" e "Remover", esta atrás de
 * uma confirmação), estado vazio e "tentar novamente" nos erros. Tela de escolha: sem laranja. O diálogo guarda
 * só o `id` de quem está para sair.
 */
@Composable
fun ConteudoEquipeDeConfianca(
    tela: EstadoTelaEquipe,
    aoTentarNovamente: () -> Unit,
    aoRemover: (PerfilPublicoDto) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    /** "Chamar de novo" por profissional da equipe (chamada direta). `null`, com a chave desligada, esconde o botão. */
    aoChamarDeNovo: ((PerfilPublicoDto) -> Unit)? = null,
    /** "Denunciar" por profissional da equipe, discreto no fim do cartão. `null` esconde a ação. */
    aoDenunciar: ((PerfilPublicoDto) -> Unit)? = null,
) {
    var idParaRemover by rememberSaveable { mutableStateOf<String?>(null) }
    val membros = (tela.estado as? EstadoEquipe.Conteudo)?.membros.orEmpty()
    val paraRemover = membros.firstOrNull { it.id == idParaRemover }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
    ) { preenchimento ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .padding(horizontal = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            item { TituloDaTela(TextosEquipe.TITULO) }
            item {
                Text(text = TextosEquipe.EXPLICACAO, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            }
            tela.aviso?.let { aviso ->
                item { AvisoFrila(tom = TomAviso.SUCESSO, mensagem = aviso) }
            }
            tela.mensagemErro?.let { erro ->
                item { AvisoFrila(tom = TomAviso.ERRO, mensagem = erro) }
            }

            when (val estado = tela.estado) {
                EstadoEquipe.Carregando -> item { EstadoCarregando(mensagem = TextosEquipe.CARREGANDO) }
                EstadoEquipe.Vazio -> item {
                    EstadoVazio(titulo = TextosEquipe.VAZIO_TITULO, mensagem = TextosEquipe.VAZIO_MENSAGEM)
                }
                EstadoEquipe.SemRede -> item {
                    EstadoErro(titulo = TextosEquipe.SEM_REDE, mensagem = null, aoTentarNovamente = aoTentarNovamente)
                }
                is EstadoEquipe.Erro -> item {
                    EstadoErro(titulo = estado.mensagem, mensagem = null, aoTentarNovamente = aoTentarNovamente)
                }
                is EstadoEquipe.Conteudo -> {
                    items(estado.membros, key = { it.id }) { perfil ->
                        CartaoDoMembro(
                            perfil = perfil,
                            removendo = tela.removendo == perfil.id,
                            bloqueado = tela.ocupado,
                            aoRemover = { idParaRemover = perfil.id },
                            aoChamarDeNovo = aoChamarDeNovo?.let { chamar -> { chamar(perfil) } },
                            aoDenunciar = aoDenunciar?.let { denunciar -> { denunciar(perfil) } },
                        )
                    }
                    item { Spacer(Modifier.height(FrilaEspacamento.grupo)) }
                }
            }
        }
    }

    if (paraRemover != null) {
        AlertDialog(
            onDismissRequest = { idParaRemover = null },
            containerColor = FrilaTema.cores.superficie,
            title = {
                Text(
                    text = TextosEquipe.CONFIRMAR_REMOCAO,
                    style = FrilaTipo.nome,
                    color = FrilaTema.cores.tinta,
                    modifier = Modifier.semantics { heading() },
                )
            },
            text = {
                Text(text = TextosEquipe.efeitoRemocao(paraRemover.nome), style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        idParaRemover = null
                        aoRemover(paraRemover)
                    },
                    modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo),
                ) { Text(TextosEquipe.CONFIRMAR_REMOVER, style = FrilaTipo.rotuloSecundario, color = FrilaTema.cores.tinta) }
            },
            dismissButton = {
                TextButton(
                    onClick = { idParaRemover = null },
                    modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo),
                ) { Text(TextosEquipe.CANCELAR, style = FrilaTipo.rotuloSecundario, color = FrilaTema.cores.tintaSuave) }
            },
        )
    }
}

@Composable
private fun CartaoDoMembro(
    perfil: PerfilPublicoDto,
    removendo: Boolean,
    bloqueado: Boolean,
    aoRemover: () -> Unit,
    aoChamarDeNovo: (() -> Unit)? = null,
    aoDenunciar: (() -> Unit)? = null,
) {
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
            Text(
                text = perfil.nome,
                style = FrilaTipo.nome,
                color = FrilaTema.cores.tinta,
                modifier = Modifier.semantics { heading() },
            )
            perfil.funcoes?.takeIf { it.isNotEmpty() }?.let { funcoes ->
                Text(text = funcoes.joinToString(", "), style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
            }
            Text(
                text = TextosEquipe.reputacao(perfil.reputacao.positivas, perfil.reputacao.total),
                style = FrilaTipo.apoio,
                color = FrilaTema.cores.tintaSuave,
            )
            if (aoChamarDeNovo != null) {
                BotaoSecundario(
                    texto = TextosEquipe.CHAMAR_DE_NOVO,
                    aoClicar = aoChamarDeNovo,
                    habilitado = !bloqueado,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = FrilaEspacamento.item)
                        .semantics { contentDescription = TextosEquipe.rotuloChamarDeNovo(perfil.nome) },
                )
            }
            AcaoDiscreta(
                texto = if (removendo) TextosEquipe.REMOVENDO else TextosEquipe.REMOVER,
                aoClicar = aoRemover,
                habilitado = !bloqueado,
                modifier = Modifier.semantics { contentDescription = TextosEquipe.rotuloRemover(perfil.nome) },
            )
            if (aoDenunciar != null) {
                AcaoDiscreta(
                    texto = TextosEquipe.DENUNCIAR,
                    aoClicar = aoDenunciar,
                    habilitado = !bloqueado,
                    modifier = Modifier.semantics { contentDescription = TextosEquipe.rotuloDenunciar(perfil.nome) },
                )
            }
        }
    }
}
