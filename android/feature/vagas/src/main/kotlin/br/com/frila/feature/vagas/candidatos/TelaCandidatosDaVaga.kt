package br.com.frila.feature.vagas.candidatos

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaBottomSheet
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.PerfilPublicoDto
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
    /** Denunciar quem se candidatou (id do perfil público no [PerfilPublicoDto]). `null` esconde a ação. */
    val aoDenunciar: ((PerfilPublicoDto) -> Unit)? = null,
    /** "Ver perfil público" de quem se candidatou, com o id do profissional (como o iOS). `null` esconde o link. */
    val aoVerPerfil: ((profissionalId: String) -> Unit)? = null,
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
    aoDenunciar: ((PerfilPublicoDto) -> Unit)? = null,
    aoVerPerfil: ((profissionalId: String) -> Unit)? = null,
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
            aoDenunciar = aoDenunciar,
            aoVerPerfil = aoVerPerfil,
        ),
        carregarFoto = carregarFoto,
        modifier = modifier,
    )
}

/**
 * Gestão de candidatos pelo contratante (UC04; paridade com `TelaCandidatosDaVaga` de
 * `CandidatosDaVaga.swift`). É uma decisão: cada pessoa num cartão (nome, selo "Da sua equipe", funções e
 * reputação como fato), "Escolher" no cartão e a confirmação da escolha, com o único primário, numa folha. A
 * lista fica na ordem em que o servidor a entrega (RN06): o selo nunca reordena. Puxar atualiza; erro de
 * releitura com candidatos na tela só avisa que a lista pode estar velha. O resultado e a recusa da última
 * escolha ficam ancorados embaixo, em tinta.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoCandidatosDaVaga(
    estado: EstadoCandidatosDaVaga,
    acoes: AcoesCandidatosDaVaga,
    modifier: Modifier = Modifier,
    carregarFoto: suspend (String) -> ImageBitmap? = { null },
) {
    val cores = FrilaTema.cores
    val mensagemDaAcao = estado.falha?.let(::mensagemDaFalha)
        ?: estado.resultado?.let { resultado ->
            (if (resultado.vagaPreenchida) TextosCandidatosDaVaga.CONFIRMADO_E_VAGA_PREENCHIDA else TextosCandidatosDaVaga.CONFIRMADO)
                .format(resultado.nome)
        }
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = acoes.aoVoltar) },
        bottomBar = {
            if (mensagemDaAcao != null) {
                RodapeAncorado { MensagemJuntoAoBotao(mensagemDaAcao) }
            }
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
                contentPadding = PaddingValues(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
            ) {
                item { TituloDaTela(TextosCandidatosDaVaga.TITULO) }
                when (estado.lista) {
                    EstadoDosCandidatos.Carregando -> item { EstadoCarregando() }
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
                                aoDenunciar = acoes.aoDenunciar?.let { denunciar -> { denunciar(candidato.profissional) } },
                                aoVerPerfil = acoes.aoVerPerfil?.let { ver -> { ver(candidato.profissional.id) } },
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
        FrilaBottomSheet(
            onDismissRequest = acoes.aoDesistirDaEscolha,
            titulo = TextosCandidatosDaVaga.PERGUNTA_DA_ESCOLHA,
            aoFechar = null,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
            ) {
                Text(
                    text = if (estado.ultimaPosicao) {
                        TextosCandidatosDaVaga.AVISO_DA_ULTIMA_POSICAO.format(nome)
                    } else {
                        TextosCandidatosDaVaga.AVISO_DA_ESCOLHA.format(nome)
                    },
                    style = FrilaTipo.corpo,
                    color = cores.tinta,
                )
                BotaoPrimario(
                    texto = TextosCandidatosDaVaga.CONFIRMAR,
                    aoClicar = acoes.aoConfirmarEscolha,
                    modifier = Modifier.fillMaxWidth(),
                )
                AcaoDiscreta(texto = TextosCandidatosDaVaga.CANCELAR, aoClicar = acoes.aoDesistirDaEscolha)
            }
        }
    }
}

/** Explicação, prazo de escolha (RN24) e lista possivelmente velha. O resultado e a falha da escolha ficam no rodapé. */
@Composable
private fun Avisos(estado: EstadoCandidatosDaVaga) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        Text(text = TextosCandidatosDaVaga.EXPLICACAO, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
        estado.prazoDeEscolha?.let { prazo ->
            AvisoFrila(
                tom = TomAviso.INFORMATIVO,
                mensagem = if (estado.prazoPassou) {
                    TextosCandidatosDaVaga.PRAZO_PASSOU
                } else {
                    TextosCandidatosDaVaga.PRAZO_DE_ESCOLHA.format(prazoPorExtenso(prazo))
                },
            )
        }
        if (estado.desatualizada) {
            AvisoFrila(tom = TomAviso.ALERTA, mensagem = TextosCandidatosDaVaga.DESATUALIZADA)
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
    aoDenunciar: (() -> Unit)?,
    carregarFoto: suspend (String) -> ImageBitmap?,
    aoVerPerfil: (() -> Unit)? = null,
) {
    val perfil = candidato.profissional
    val cores = FrilaTema.cores
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
            Row(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco), verticalAlignment = Alignment.CenterVertically) {
                Foto(nome = perfil.nome, fotoUrl = perfil.fotoUrl, carregarFoto = carregarFoto)
                Column(
                    modifier = Modifier.weight(1f).semantics(mergeDescendants = true) {},
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                ) {
                    Text(text = perfil.nome, style = FrilaTipo.nome, color = cores.tinta)
                    // Texto e ícone, nunca só cor (D7). O selo não altera a ordem da lista (RN06).
                    if (candidato.daEquipe) {
                        SeloDeStatus(texto = TextosCandidatosDaVaga.DA_EQUIPE, estilo = EstiloDoSelo.CONTORNO, icone = Icons.Filled.Star)
                    }
                }
            }
            Column(
                modifier = Modifier.semantics(mergeDescendants = true) {},
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                perfil.funcoes?.takeIf { it.isNotEmpty() }?.let { funcoes ->
                    FrilaLinhaDeDado(
                        icone = Icons.Filled.Person,
                        valor = TextosCandidatosDaVaga.FUNCOES.format(funcoes.joinToString(", ")),
                    )
                }
                FrilaLinhaDeDado(icone = Icons.Filled.Star, valor = textoDaReputacao(candidato))
            }
            PerfilRicoDoCandidato(perfil = perfil, candidaturaId = candidato.candidaturaId)
            if (aoVerPerfil != null) {
                LinkFrila(
                    texto = TextosCandidatosDaVaga.VER_PERFIL,
                    aoClicar = aoVerPerfil,
                    modifier = Modifier
                        .testTag("perfil-do-candidato-${candidato.candidaturaId}")
                        .semantics { contentDescription = TextosCandidatosDaVaga.VER_PERFIL_DE.format(perfil.nome) },
                )
            }
            BotaoSecundario(
                texto = if (escolhendoEste) TextosCandidatosDaVaga.ESCOLHENDO else TextosCandidatosDaVaga.ESCOLHER,
                aoClicar = aoEscolher,
                habilitado = podeEscolher,
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics { contentDescription = TextosCandidatosDaVaga.ESCOLHER_NOME.format(perfil.nome) },
            )
            if (aoDenunciar != null) {
                AcaoDiscreta(
                    texto = TextosCandidatosDaVaga.DENUNCIAR,
                    aoClicar = aoDenunciar,
                    modifier = Modifier.semantics { contentDescription = TextosCandidatosDaVaga.DENUNCIAR_NOME.format(perfil.nome) },
                )
            }
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
                .background(FrilaTema.cores.superficiePressionada)
                .testTag("inicial-do-candidato"),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = nome.trim().take(1).uppercase(),
                style = FrilaTipo.nome,
                color = FrilaTema.cores.tinta,
                textAlign = TextAlign.Center,
                modifier = Modifier.clearAndSetSemantics {},
            )
        }
    }
}
