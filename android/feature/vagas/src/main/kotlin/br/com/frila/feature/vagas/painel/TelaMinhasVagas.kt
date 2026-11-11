package br.com.frila.feature.vagas.painel

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoVaga
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.feature.vagas.publicacao.formatarData
import br.com.frila.feature.vagas.publicacao.formatarHora
import br.com.frila.feature.vagas.publicacao.formatarReais
import java.time.Duration
import java.time.Instant

/** Tudo o que a tela pode pedir ao [MinhasVagasViewModel] e a quem a abriu; o padrão `{}` mantém o teste curto. */
data class AcoesMinhasVagas(
    val aoCarregar: () -> Unit = {},
    val aoAtualizar: () -> Unit = {},
    val aoVerCandidatos: (ItemMinhaVaga) -> Unit = {},
    val aoAcompanharTurno: (vagaId: String, posicaoId: String) -> Unit = { _, _ -> },
    val aoPublicarVaga: () -> Unit = {},
    val aoVoltar: () -> Unit = {},
)

/**
 * Liga o [MinhasVagasViewModel] ao [ConteudoMinhasVagas].
 *
 * [aoVerCandidatos] recebe o que `CandidatosDaVagaViewModel` precisa da vaga: o id, quantas posições
 * seguem abertas e o início (`null` se o servidor mandou um instante ilegível). [aoPublicarVaga] recebe o
 * id do estabelecimento. Abrir as telas de destino é de quem monta a navegação.
 */
@Composable
fun TelaMinhasVagas(
    viewModel: MinhasVagasViewModel,
    aoVoltar: () -> Unit,
    aoVerCandidatos: (vagaId: String, posicoesAbertas: Int, inicioDaVaga: Instant?) -> Unit,
    aoPublicarVaga: (estabelecimentoId: String) -> Unit,
    modifier: Modifier = Modifier,
    aoAcompanharTurno: (vagaId: String, posicaoId: String) -> Unit = { _, _ -> },
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoMinhasVagas(
        estado = estado,
        nomeEstabelecimento = viewModel.nomeEstabelecimento,
        acoes = AcoesMinhasVagas(
            aoCarregar = { viewModel.carregar() },
            aoAtualizar = { viewModel.atualizar() },
            aoVerCandidatos = { aoVerCandidatos(it.id, it.posicoesAbertas, it.inicio) },
            aoAcompanharTurno = aoAcompanharTurno,
            aoPublicarVaga = { aoPublicarVaga(viewModel.estabelecimentoId) },
            aoVoltar = aoVoltar,
        ),
        modifier = modifier,
    )
}

/**
 * Minhas vagas do contratante (UC07; paridade com `TelaMinhasVagas` de `MinhasVagas.swift`): seções
 * Precisa de atenção, Hoje, Próximas e Encerradas, cada vaga com período, valor, posições e confirmações.
 * "Publicar vaga" fica na barra quando há vagas, e no estado vazio quando não há.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoMinhasVagas(
    estado: EstadoMinhasVagas,
    nomeEstabelecimento: String?,
    acoes: AcoesMinhasVagas,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = TextosMinhasVagas.TITULO,
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
                            contentDescription = TextosMinhasVagas.ROTULO_VOLTAR,
                        )
                    }
                },
                actions = {
                    if (estado.lista is ListaMinhasVagas.Sucesso) {
                        TextButton(
                            onClick = acoes.aoPublicarVaga,
                            modifier = Modifier.sizeIn(minWidth = FrilaMetricas.alvoMinimo, minHeight = FrilaMetricas.alvoMinimo),
                        ) { Text(TextosMinhasVagas.PUBLICAR_VAGA) }
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
                    contentDescription = if (estado.atualizando) TextosMinhasVagas.ATUALIZANDO else TextosMinhasVagas.LISTA
                },
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(FrilaEspacamento.medio),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
            ) {
                if (!nomeEstabelecimento.isNullOrBlank()) {
                    item { Text(text = nomeEstabelecimento, style = MaterialTheme.typography.titleMedium) }
                }
                if (estado.desatualizada) {
                    item {
                        Text(
                            text = TextosMinhasVagas.DESATUALIZADA,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                        )
                    }
                }
                when (val lista = estado.lista) {
                    ListaMinhasVagas.Carregando -> item {
                        Box(
                            Modifier.fillMaxWidth().padding(FrilaEspacamento.grande).semantics {
                                contentDescription = TextosMinhasVagas.CARREGANDO
                            },
                            contentAlignment = Alignment.Center,
                        ) { IndicadorCarregando() }
                    }
                    ListaMinhasVagas.Vazio -> item {
                        EstadoVazio(
                            titulo = TextosMinhasVagas.VAZIA_TITULO,
                            mensagem = TextosMinhasVagas.VAZIA_MENSAGEM,
                            textoAcao = TextosMinhasVagas.PUBLICAR_VAGA,
                            aoClicarAcao = acoes.aoPublicarVaga,
                        )
                    }
                    is ListaMinhasVagas.Erro -> item {
                        EstadoErro(
                            titulo = TextosMinhasVagas.ERRO_TITULO,
                            mensagem = lista.erro.mensagem,
                            textoBotao = TextosMinhasVagas.TENTAR_DE_NOVO,
                            aoTentarNovamente = if (lista.erro.podeTentarDeNovo) acoes.aoCarregar else null,
                        )
                    }
                    is ListaMinhasVagas.Sucesso -> SecaoMinhasVagas.entries.forEach { secao ->
                        val itens = lista.daSecao(secao)
                        if (itens.isNotEmpty()) {
                            item(key = "secao-${secao.name}") {
                                Text(
                                    text = secao.titulo,
                                    style = MaterialTheme.typography.titleMedium,
                                    modifier = Modifier.padding(top = FrilaEspacamento.pequeno).semantics { heading() },
                                )
                            }
                            items(itens, key = { it.id }) { item -> CartaoDaVaga(item, acoes.aoVerCandidatos, acoes.aoAcompanharTurno) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CartaoDaVaga(
    item: ItemMinhaVaga,
    aoVerCandidatos: (ItemMinhaVaga) -> Unit,
    aoAcompanharTurno: (vagaId: String, posicaoId: String) -> Unit,
) {
    CartaoVaga(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo)) {
            Text(text = item.funcao, style = MaterialTheme.typography.titleMedium)
            if (item.recemPublicada) {
                Text(
                    text = TextosMinhasVagas.RECEM_PUBLICADA,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
            }
            if (item.oculta) {
                Text(text = TextosMinhasVagas.OCULTA, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.error)
            }
            Text(text = periodo(item.inicio, item.fim), style = MaterialTheme.typography.bodyMedium)
            Text(
                text = item.local,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                text = TextosMinhasVagas.VALOR_POR_PESSOA.format(formatarReais(item.valorCentavos)),
                style = MaterialTheme.typography.bodyMedium,
            )
            Text(
                text = "${posicoes(item.totalPosicoes)} · ${confirmadas(item.confirmadas, item.totalPosicoes)}",
                style = MaterialTheme.typography.bodyMedium,
            )
            if (item.selecao) {
                Text(
                    text = TextosMinhasVagas.MODO_SELECAO,
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            item.comecaEm?.let {
                Text(
                    text = textoDoInicio(it),
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
            if (item.candidatosPendentes > 0) {
                Text(
                    text = if (item.candidatosPendentes == 1) {
                        TextosMinhasVagas.CANDIDATO_UM
                    } else {
                        TextosMinhasVagas.CANDIDATOS_VARIOS.format(item.candidatosPendentes)
                    },
                    style = MaterialTheme.typography.titleSmall,
                )
            }
            if (item.emAtraso > 0) {
                Text(
                    text = if (item.emAtraso == 1) TextosMinhasVagas.EM_ATRASO_UM else TextosMinhasVagas.EM_ATRASO_VARIOS.format(item.emAtraso),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                )
            }
            item.turnos.forEach { turno ->
                val nome = turno.nomeProfissional ?: TextosMinhasVagas.PROFISSIONAL_SEM_NOME
                BotaoSecundario(
                    texto = TextosMinhasVagas.ACOMPANHAR_TURNO_DE.format(nome),
                    aoClicar = { aoAcompanharTurno(item.id, turno.posicaoId) },
                    modifier = Modifier.fillMaxWidth().padding(top = FrilaEspacamento.pequeno),
                )
            }
            if (item.podeVerCandidatos) {
                BotaoSecundario(
                    texto = TextosMinhasVagas.VER_CANDIDATOS,
                    aoClicar = { aoVerCandidatos(item) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = FrilaEspacamento.pequeno)
                        .semantics { contentDescription = TextosMinhasVagas.VER_CANDIDATOS_DE.format(item.funcao) },
                )
            }
        }
    }
}

private fun posicoes(total: Int): String =
    if (total == 1) TextosMinhasVagas.POSICOES_UMA else TextosMinhasVagas.POSICOES_VARIAS.format(total)

private fun confirmadas(confirmadas: Int, total: Int): String =
    if (total == 1) TextosMinhasVagas.CONFIRMADAS_UMA.format(confirmadas) else TextosMinhasVagas.CONFIRMADAS_VARIAS.format(confirmadas, total)

/** "10/11/2026, 18:00 – 21:00" no mesmo dia; "10/11/2026 18:00 – 11/11/2026 02:00" em dias diferentes. */
internal fun periodo(inicio: Instant?, fim: Instant?): String {
    if (inicio == null || fim == null) return ""
    val dataDoInicio = formatarData(inicio)
    return if (dataDoInicio == formatarData(fim)) {
        TextosMinhasVagas.PERIODO_MESMO_DIA.format(dataDoInicio, formatarHora(inicio), formatarHora(fim))
    } else {
        TextosMinhasVagas.PERIODO.format("$dataDoInicio ${formatarHora(inicio)}", "${formatarData(fim)} ${formatarHora(fim)}")
    }
}

/**
 * "Começa em 2 h 15 min" ou "Começa em 40 min", arredondando os minutos para cima (paridade com
 * `tempoAteInicio` do iOS). Sem tempo restante, a vaga já devia ter começado: "Menos de um minuto para começar".
 */
internal fun textoDoInicio(duracao: Duration): String {
    val minutos = Math.ceil(duracao.toMillis() / 60_000.0).toLong()
    if (minutos <= 0) return TextosMinhasVagas.MENOS_DE_UM_MINUTO
    val horas = minutos / 60
    val resto = minutos % 60
    val tempo = if (horas > 0) TextosMinhasVagas.HORA_MINUTO.format(horas, resto) else TextosMinhasVagas.APENAS_MINUTOS.format(minutos)
    return TextosMinhasVagas.COMECA_EM.format(tempo)
}
