package br.com.frila.feature.vagas.candidatos

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.feature.vagas.publicacao.formatarData
import br.com.frila.feature.vagas.publicacao.formatarHora
import java.time.Instant
import kotlinx.coroutines.CancellationException

/** Tudo o que a tela pode pedir ao [CandidatosDaVagaViewModel]; o padrão `{}` mantém o teste de tela curto. */
data class AcoesCandidatosDaVaga(
    val aoCarregar: () -> Unit = {},
    val aoAtualizar: () -> Unit = {},
    val aoPedirEscolha: (CandidatoDto) -> Unit = {},
    val aoDesistirDaEscolha: () -> Unit = {},
    val aoConfirmarEscolha: () -> Unit = {},
    val aoVoltar: () -> Unit = {},
)

/**
 * Liga o [CandidatosDaVagaViewModel] ao [ConteudoCandidatosDaVaga]. [carregarFoto] baixa a miniatura da
 * `foto_url` assinada (o projeto não tem biblioteca de imagem); sem ele, ou em falha, o cartão mostra a
 * inicial do nome.
 */
@Composable
fun TelaCandidatosDaVaga(
    viewModel: CandidatosDaVagaViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    carregarFoto: suspend (String) -> ImageBitmap? = { null },
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoCandidatosDaVaga(
        estado = estado,
        acoes = AcoesCandidatosDaVaga(
            aoCarregar = { viewModel.carregar() },
            aoAtualizar = { viewModel.atualizar() },
            aoPedirEscolha = viewModel::pedirEscolha,
            aoDesistirDaEscolha = viewModel::desistirDaEscolha,
            aoConfirmarEscolha = { viewModel.confirmarEscolha() },
            aoVoltar = aoVoltar,
        ),
        carregarFoto = carregarFoto,
        modifier = modifier,
    )
}

/**
 * Gestão de candidatos pelo contratante (UC04; paridade com `TelaCandidatosDaVaga` de
 * `CandidatosDaVaga.swift`). A lista fica na ordem em que o servidor a entrega (RN06): o selo "Da sua
 * equipe" nunca reordena. Puxar atualiza; erro de releitura com candidatos na tela só avisa que a lista
 * pode estar velha.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoCandidatosDaVaga(
    estado: EstadoCandidatosDaVaga,
    acoes: AcoesCandidatosDaVaga,
    modifier: Modifier = Modifier,
    carregarFoto: suspend (String) -> ImageBitmap? = { null },
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosCandidatosDaVaga.TITULO,
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.semantics { heading() },
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = acoes.aoVoltar,
                        modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = TextosCandidatosDaVaga.ROTULO_VOLTAR,
                        )
                    }
                },
            )
        },
    ) { preenchimento ->
        PullToRefreshBox(
            isRefreshing = estado.atualizando,
            onRefresh = acoes.aoAtualizar,
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .semantics {
                    contentDescription = if (estado.atualizando) TextosCandidatosDaVaga.ATUALIZANDO else TextosCandidatosDaVaga.LISTA
                },
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(FrilaEspacamento.medio),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
            ) {
                when (estado.lista) {
                    EstadoDosCandidatos.Carregando -> item {
                        Box(Modifier.fillMaxWidth().padding(FrilaEspacamento.grande), contentAlignment = Alignment.Center) {
                            IndicadorCarregando()
                        }
                    }
                    EstadoDosCandidatos.SemConexao -> item {
                        EstadoErro(
                            titulo = TextosCandidatosDaVaga.FALHA_TITULO,
                            mensagem = TextosCandidatosDaVaga.SEM_CONEXAO,
                            textoBotao = TextosCandidatosDaVaga.TENTAR_NOVAMENTE,
                            aoTentarNovamente = acoes.aoCarregar,
                        )
                    }
                    EstadoDosCandidatos.Falha -> item {
                        EstadoErro(
                            titulo = TextosCandidatosDaVaga.FALHA_TITULO,
                            mensagem = TextosCandidatosDaVaga.FALHA,
                            textoBotao = TextosCandidatosDaVaga.TENTAR_NOVAMENTE,
                            aoTentarNovamente = acoes.aoCarregar,
                        )
                    }
                    EstadoDosCandidatos.Vazio -> {
                        item { Avisos(estado) }
                        item {
                            EstadoVazio(
                                titulo = TextosCandidatosDaVaga.VAZIO_TITULO,
                                mensagem = TextosCandidatosDaVaga.VAZIO_MENSAGEM,
                            )
                        }
                    }
                    is EstadoDosCandidatos.Carregados -> {
                        item { Avisos(estado) }
                        items(estado.lista.candidatos, key = { it.candidaturaId }) { candidato ->
                            CartaoDoCandidato(
                                candidato = candidato,
                                escolhendoEste = estado.escolhendo == candidato.candidaturaId,
                                podeEscolher = estado.escolhendo == null,
                                aoEscolher = { acoes.aoPedirEscolha(candidato) },
                                carregarFoto = carregarFoto,
                            )
                        }
                    }
                }
            }
        }
    }

    estado.emConfirmacao?.let { candidato ->
        val nome = candidato.profissional.nome
        AlertDialog(
            onDismissRequest = acoes.aoDesistirDaEscolha,
            title = { Text(TextosCandidatosDaVaga.PERGUNTA_DA_ESCOLHA, modifier = Modifier.semantics { heading() }) },
            text = {
                Text(
                    if (estado.ultimaPosicao) {
                        TextosCandidatosDaVaga.AVISO_DA_ULTIMA_POSICAO.format(nome)
                    } else {
                        TextosCandidatosDaVaga.AVISO_DA_ESCOLHA.format(nome)
                    },
                )
            },
            confirmButton = {
                TextButton(
                    onClick = acoes.aoConfirmarEscolha,
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosCandidatosDaVaga.CONFIRMAR) }
            },
            dismissButton = {
                TextButton(
                    onClick = acoes.aoDesistirDaEscolha,
                    modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                ) { Text(TextosCandidatosDaVaga.CANCELAR) }
            },
        )
    }
}

/** Explicação, prazo de escolha (RN24), lista possivelmente velha, e o resultado ou a falha da última escolha. */
@Composable
private fun Avisos(estado: EstadoCandidatosDaVaga) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        Text(
            text = TextosCandidatosDaVaga.EXPLICACAO,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        estado.prazoDeEscolha?.let { prazo ->
            Text(
                text = if (estado.prazoPassou) {
                    TextosCandidatosDaVaga.PRAZO_PASSOU
                } else {
                    TextosCandidatosDaVaga.PRAZO_DE_ESCOLHA.format(prazoPorExtenso(prazo))
                },
                style = MaterialTheme.typography.titleSmall,
            )
        }
        if (estado.desatualizada) {
            Text(
                text = TextosCandidatosDaVaga.DESATUALIZADA,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
        estado.resultado?.let { resultado ->
            Text(
                text = (if (resultado.vagaPreenchida) TextosCandidatosDaVaga.CONFIRMADO_E_VAGA_PREENCHIDA else TextosCandidatosDaVaga.CONFIRMADO)
                    .format(resultado.nome),
                style = MaterialTheme.typography.titleSmall,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
        estado.falha?.let { falha ->
            Text(
                text = mensagemDaFalha(falha),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
            )
        }
    }
}

private fun prazoPorExtenso(prazo: Instant): String = "${formatarData(prazo)} às ${formatarHora(prazo)}"

internal fun mensagemDaFalha(falha: FalhaDaEscolha): String = when (falha) {
    FalhaDaEscolha.PosicaoJaPreenchida -> TextosCandidatosDaVaga.POSICAO_JA_PREENCHIDA
    is FalhaDaEscolha.CandidaturaIndisponivel -> TextosCandidatosDaVaga.CANDIDATURA_INDISPONIVEL.format(falha.nome)
    FalhaDaEscolha.SelecaoEncerrada -> TextosCandidatosDaVaga.SELECAO_ENCERRADA
    is FalhaDaEscolha.TurnoSobreposto -> TextosCandidatosDaVaga.TURNO_SOBREPOSTO.format(falha.nome)
    is FalhaDaEscolha.Inelegivel -> TextosCandidatosDaVaga.INELEGIVEL.format(falha.nome)
    FalhaDaEscolha.VagaOculta -> TextosCandidatosDaVaga.VAGA_OCULTA
    FalhaDaEscolha.SemPermissao -> TextosCandidatosDaVaga.SEM_PERMISSAO
    FalhaDaEscolha.PerfilIncompativel -> TextosCandidatosDaVaga.PERFIL_INCOMPATIVEL
    FalhaDaEscolha.ContaSuspensa -> TextosCandidatosDaVaga.CONTA_SUSPENSA
    FalhaDaEscolha.SessaoExpirada -> TextosCandidatosDaVaga.SESSAO_EXPIRADA
    FalhaDaEscolha.SemRede -> TextosCandidatosDaVaga.SEM_REDE_NA_ESCOLHA
    is FalhaDaEscolha.ResultadoIncerto -> TextosCandidatosDaVaga.RESULTADO_INCERTO.format(falha.nome)
    FalhaDaEscolha.Generica -> TextosCandidatosDaVaga.GENERICO
}

@Composable
private fun CartaoDoCandidato(
    candidato: CandidatoDto,
    escolhendoEste: Boolean,
    podeEscolher: Boolean,
    aoEscolher: () -> Unit,
    carregarFoto: suspend (String) -> ImageBitmap?,
) {
    val perfil = candidato.profissional
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
            Row(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto), verticalAlignment = Alignment.CenterVertically) {
                Foto(nome = perfil.nome, fotoUrl = perfil.fotoUrl, carregarFoto = carregarFoto)
                Column(
                    modifier = Modifier.weight(1f).semantics(mergeDescendants = true) {},
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio),
                ) {
                    Text(text = perfil.nome, style = MaterialTheme.typography.titleMedium)
                    if (candidato.daEquipe) {
                        // Texto e ícone, nunca só cor (D7). O selo não altera a ordem da lista (RN06).
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
                            Icon(Icons.Filled.Star, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.primary)
                            Text(
                                text = TextosCandidatosDaVaga.DA_EQUIPE,
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                    perfil.funcoes?.takeIf { it.isNotEmpty() }?.let { funcoes ->
                        Text(
                            text = TextosCandidatosDaVaga.FUNCOES.format(funcoes.joinToString(", ")),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                    Text(
                        text = textoDaReputacao(candidato),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            BotaoPrimario(
                texto = if (escolhendoEste) TextosCandidatosDaVaga.ESCOLHENDO else TextosCandidatosDaVaga.ESCOLHER,
                aoClicar = aoEscolher,
                habilitado = podeEscolher,
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics { contentDescription = TextosCandidatosDaVaga.ESCOLHER_NOME.format(perfil.nome) },
            )
        }
    }
}

private fun textoDaReputacao(candidato: CandidatoDto): String {
    val reputacao = candidato.profissional.reputacao
    if (reputacao.total == 0) return TextosCandidatosDaVaga.SEM_AVALIACOES
    val avaliacoes = TextosCandidatosDaVaga.AVALIACOES.format(reputacao.positivas, reputacao.total)
    val comparecimento = reputacao.taxaComparecimento
        ?.let { TextosCandidatosDaVaga.COMPARECIMENTO.format(Math.round(it * 100).toInt()) }
    return listOfNotNull(avaliacoes, comparecimento).joinToString(" · ")
}

/** Miniatura do candidato: a foto baixada se houver, senão a inicial do nome. Decorativa para o leitor de tela. */
@Composable
private fun Foto(nome: String, fotoUrl: String?, carregarFoto: suspend (String) -> ImageBitmap?) {
    var foto by remember(fotoUrl) { mutableStateOf<ImageBitmap?>(null) }
    LaunchedEffect(fotoUrl) {
        if (fotoUrl != null) {
            foto = try {
                carregarFoto(fotoUrl)
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                null
            }
        }
    }
    val tamanho = 48.dp
    val imagem = foto
    if (imagem != null) {
        Image(
            bitmap = imagem,
            contentDescription = TextosCandidatosDaVaga.FOTO_DE.format(nome),
            contentScale = ContentScale.Crop,
            modifier = Modifier.size(tamanho).clip(CircleShape).testTag("foto-do-candidato"),
        )
    } else {
        Box(
            modifier = Modifier
                .size(tamanho)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.secondaryContainer)
                .testTag("inicial-do-candidato"),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = nome.trim().take(1).uppercase(),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSecondaryContainer,
                textAlign = TextAlign.Center,
                modifier = Modifier.clearAndSetSemantics {},
            )
        }
    }
}
