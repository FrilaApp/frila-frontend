package br.com.frila.feature.vagas.painel

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
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
import br.com.frila.core.designsystem.componentes.FrilaDivisoria
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
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
    /** Nulo é a lista como tela raiz (aba "Minhas vagas"): sem a barra do voltar, e o nome da casa abre a tela no lugar do título. */
    val aoVoltar: (() -> Unit)? = {},
    /** As três ações da vaga (L2-3). `null` esconde o botão: a tela só oferece o que quem a abriu sabe atender. */
    val aoCancelarVaga: ((ItemMinhaVaga) -> Unit)? = null,
    val aoRepublicarVaga: ((ItemMinhaVaga) -> Unit)? = null,
    val aoRepublicarPosicoesRestantes: ((ItemMinhaVaga) -> Unit)? = null,
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
    aoVoltar: (() -> Unit)?,
    aoVerCandidatos: (vagaId: String, posicoesAbertas: Int, inicioDaVaga: Instant?) -> Unit,
    aoPublicarVaga: (estabelecimentoId: String) -> Unit,
    modifier: Modifier = Modifier,
    aoAcompanharTurno: (vagaId: String, posicaoId: String) -> Unit = { _, _ -> },
    aoCancelarVaga: ((ItemMinhaVaga) -> Unit)? = null,
    aoRepublicarVaga: ((ItemMinhaVaga) -> Unit)? = null,
    aoRepublicarPosicoesRestantes: ((ItemMinhaVaga) -> Unit)? = null,
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
            aoCancelarVaga = aoCancelarVaga,
            aoRepublicarVaga = aoRepublicarVaga,
            aoRepublicarPosicoesRestantes = aoRepublicarPosicoesRestantes,
        ),
        modifier = modifier,
    )
}

/**
 * Minhas vagas do contratante (UC07; paridade com `TelaMinhasVagas` de `MinhasVagas.swift`): seções
 * Precisa de atenção, Hoje, Próximas e Encerradas, cada vaga num cartão com selos, período, local, posições,
 * confirmações e valor. É tela de escolha: a lista não leva laranja, e o único primário é "Publicar vaga",
 * ancorado embaixo quando há vagas e quando não há.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoMinhasVagas(
    estado: EstadoMinhasVagas,
    nomeEstabelecimento: String?,
    acoes: AcoesMinhasVagas,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { acoes.aoVoltar?.let { FrilaBarraDeTopo(aoVoltar = it) } },
        bottomBar = {
            if (estado.lista is ListaMinhasVagas.Sucesso || estado.lista == ListaMinhasVagas.Vazio) {
                RodapeAncorado {
                    BotaoPrimario(
                        texto = TextosMinhasVagas.PUBLICAR_VAGA,
                        aoClicar = acoes.aoPublicarVaga,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
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
                    contentDescription = if (estado.atualizando) TextosMinhasVagas.ATUALIZANDO else TextosMinhasVagas.LISTA
                },
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
            ) {
                if (acoes.aoVoltar != null) {
                    item {
                        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                            TituloDaTela(TextosMinhasVagas.TITULO)
                            if (!nomeEstabelecimento.isNullOrBlank()) {
                                Text(text = nomeEstabelecimento, style = FrilaTipo.apoio, color = cores.tintaSuave)
                            }
                        }
                    }
                } else if (!nomeEstabelecimento.isNullOrBlank()) {
                    // Raiz: a aba já diz "Minhas vagas"; o que abre a tela é de qual casa são.
                    item { TituloDaTela(nomeEstabelecimento) }
                }
                if (estado.desatualizada) {
                    item { AvisoFrila(tom = TomAviso.ALERTA, mensagem = TextosMinhasVagas.DESATUALIZADA) }
                }
                when (val lista = estado.lista) {
                    ListaMinhasVagas.Carregando -> item {
                        EstadoCarregando(modifier = Modifier.semantics { contentDescription = TextosMinhasVagas.CARREGANDO })
                    }
                    ListaMinhasVagas.Vazio -> item {
                        EstadoVazio(
                            titulo = TextosMinhasVagas.VAZIA_TITULO,
                            mensagem = TextosMinhasVagas.VAZIA_MENSAGEM,
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
                                RotuloDeGrupo(texto = secao.titulo, modifier = Modifier.padding(top = FrilaEspacamento.bloco))
                            }
                            items(itens, key = { it.id }) { item -> CartaoDaVaga(item, acoes) }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CartaoDaVaga(item: ItemMinhaVaga, acoes: AcoesMinhasVagas) {
    val cores = FrilaTema.cores
    val aoVerCandidatos = acoes.aoVerCandidatos
    val aoAcompanharTurno = acoes.aoAcompanharTurno
    val temSelo = item.recemPublicada || item.oculta || item.selecao || item.comecaEm != null
    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
            if (temSelo) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                    verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                ) {
                    item.comecaEm?.let { SeloDeStatus(texto = textoDoInicio(it), estilo = EstiloDoSelo.URGENCIA) }
                    if (item.recemPublicada) SeloDeStatus(texto = TextosMinhasVagas.RECEM_PUBLICADA, estilo = EstiloDoSelo.CONFIRMADO)
                    if (item.oculta) SeloDeStatus(texto = TextosMinhasVagas.OCULTA, estilo = EstiloDoSelo.ENCERRADO)
                    if (item.selecao) SeloDeStatus(texto = TextosMinhasVagas.MODO_SELECAO, estilo = EstiloDoSelo.CONTORNO)
                }
            }
            Text(text = item.funcao, style = FrilaTipo.nome, color = cores.tinta)
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                periodo(item.inicio, item.fim).takeIf { it.isNotBlank() }?.let {
                    FrilaLinhaDeDado(icone = Icons.Default.DateRange, valor = it)
                }
                FrilaLinhaDeDado(icone = Icons.Default.Place, valor = item.local)
                FrilaLinhaDeDado(
                    icone = Icons.Default.Person,
                    valor = "${posicoes(item.totalPosicoes)} · ${confirmadas(item.confirmadas, item.totalPosicoes)}",
                )
                if (item.candidatosPendentes > 0) {
                    FrilaLinhaDeDado(
                        icone = Icons.Default.Notifications,
                        valor = if (item.candidatosPendentes == 1) {
                            TextosMinhasVagas.CANDIDATO_UM
                        } else {
                            TextosMinhasVagas.CANDIDATOS_VARIOS.format(item.candidatosPendentes)
                        },
                    )
                }
                if (item.emAtraso > 0) {
                    FrilaLinhaDeDado(
                        icone = Icons.Default.Warning,
                        valor = if (item.emAtraso == 1) {
                            TextosMinhasVagas.EM_ATRASO_UM
                        } else {
                            TextosMinhasVagas.EM_ATRASO_VARIOS.format(item.emAtraso)
                        },
                    )
                }
            }
            FrilaDivisoria()
            Text(
                text = valorPorPessoa(item.valorCentavos),
                style = FrilaTipo.valorEmDestaque,
                color = cores.tinta,
            )
            if (item.turnos.isNotEmpty() || item.podeVerCandidatos) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    item.turnos.forEach { turno ->
                        val nome = turno.nomeProfissional ?: TextosMinhasVagas.PROFISSIONAL_SEM_NOME
                        BotaoSecundario(
                            texto = TextosMinhasVagas.ACOMPANHAR_TURNO_DE.format(nome),
                            aoClicar = { aoAcompanharTurno(item.id, turno.posicaoId) },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    if (item.podeVerCandidatos) {
                        BotaoSecundario(
                            texto = TextosMinhasVagas.VER_CANDIDATOS,
                            aoClicar = { aoVerCandidatos(item) },
                            modifier = Modifier
                                .fillMaxWidth()
                                .semantics { contentDescription = TextosMinhasVagas.VER_CANDIDATOS_DE.format(item.funcao) },
                        )
                    }
                }
            }
            AcoesDaVaga(item, acoes)
        }
    }
}

/**
 * Republicar posições vazias e republicar com outro horário (links: abrem outra tela ou uma confirmação) e
 * cancelar (ação discreta, no fim). Cada uma só aparece se a vaga permite e há quem atenda.
 */
@Composable
private fun AcoesDaVaga(item: ItemMinhaVaga, acoes: AcoesMinhasVagas) {
    val temAlguma = (acoes.aoRepublicarPosicoesRestantes != null && item.republicavelEmUrgencia > 0) ||
        (acoes.aoRepublicarVaga != null && item.podeRepublicar) ||
        (acoes.aoCancelarVaga != null && item.podeCancelar)
    if (temAlguma) {
        Column { AcoesDaVagaEmLinhas(item, acoes) }
    }
}

@Composable
private fun AcoesDaVagaEmLinhas(item: ItemMinhaVaga, acoes: AcoesMinhasVagas) {
    acoes.aoRepublicarPosicoesRestantes?.takeIf { item.republicavelEmUrgencia > 0 }?.let { aoTocar ->
        LinkFrila(
            texto = TextosRepublicarPosicoesRestantes.botao(item.republicavelEmUrgencia),
            aoClicar = { aoTocar(item) },
        )
    }
    acoes.aoRepublicarVaga?.takeIf { item.podeRepublicar }?.let { aoTocar ->
        LinkFrila(
            texto = TextosRepublicarVaga.TITULO,
            aoClicar = { aoTocar(item) },
            modifier = Modifier.semantics { contentDescription = TextosRepublicarVaga.REPUBLICAR_VAGA_DE.format(item.funcao) },
        )
    }
    acoes.aoCancelarVaga?.takeIf { item.podeCancelar }?.let { aoTocar ->
        AcaoDiscreta(
            texto = TextosCancelarVaga.TITULO,
            aoClicar = { aoTocar(item) },
            modifier = Modifier.semantics { contentDescription = TextosCancelarVaga.CANCELAR_VAGA_DE.format(item.funcao) },
        )
    }
}

/** "R$ 160,00 por pessoa": o dinheiro em destaque e o resto em apoio, na mesma linha. */
@Composable
private fun valorPorPessoa(valorCentavos: Long): AnnotatedString {
    val reais = formatarReais(valorCentavos)
    val frase = TextosMinhasVagas.VALOR_POR_PESSOA.format(reais)
    val apoio = FrilaTipo.apoio.toSpanStyle().copy(fontFamily = FontFamily.Default, color = FrilaTema.cores.tintaSuave)
    return buildAnnotatedString {
        append(frase)
        if (frase.startsWith(reais)) addStyle(apoio, reais.length, frase.length)
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
