package br.com.frila.feature.vagas.publicacao

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.FrilaBottomSheet
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.VagaPublicadaDto
import java.time.Instant

/** Tudo o que a tela pode pedir ao [PublicarVagaViewModel]; o padrão `{}` mantém o teste de tela curto. */
data class AcoesPublicarVaga(
    val aoCarregarFuncoes: () -> Unit = {},
    val aoEscolherFuncao: (String) -> Unit = {},
    val aoEditarInicio: (Instant) -> Unit = {},
    val aoEditarFim: (Instant) -> Unit = {},
    val aoEscolherModo: (ModoDaVaga) -> Unit = {},
    val aoEditarLocal: (String) -> Unit = {},
    val aoEditarValor: (String) -> Unit = {},
    val aoEditarPosicoes: (String) -> Unit = {},
    val aoMaisUmaPosicao: () -> Unit = {},
    val aoMenosUmaPosicao: () -> Unit = {},
    val aoAlternarRefeicao: (Boolean) -> Unit = {},
    val aoAlternarTransporte: (Boolean) -> Unit = {},
    val aoAlternarMaterial: (Boolean) -> Unit = {},
    val aoEditarResponsavel: (String) -> Unit = {},
    val aoEditarTraje: (String) -> Unit = {},
    val aoEditarObservacoes: (String) -> Unit = {},
    val aoAlternarRateio: (Boolean) -> Unit = {},
    val aoPublicar: () -> Unit = {},
    val aoVoltar: () -> Unit = {},
)

/** Liga o [PublicarVagaViewModel] ao [ConteudoPublicarVaga]. */
@Composable
fun TelaPublicarVaga(
    viewModel: PublicarVagaViewModel,
    aoPublicar: (VagaPublicadaDto) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(Unit) { viewModel.carregarFuncoes() }
    LaunchedEffect(estado.publicada) {
        estado.publicada?.let(aoPublicar)
    }
    ConteudoPublicarVaga(
        estado = estado,
        acoes = AcoesPublicarVaga(
            aoCarregarFuncoes = { viewModel.carregarFuncoes() },
            aoEscolherFuncao = viewModel::escolherFuncao,
            aoEditarInicio = viewModel::editarInicio,
            aoEditarFim = viewModel::editarFim,
            aoEscolherModo = viewModel::escolherModo,
            aoEditarLocal = viewModel::editarLocal,
            aoEditarValor = viewModel::editarValor,
            aoEditarPosicoes = viewModel::editarPosicoes,
            aoMaisUmaPosicao = viewModel::maisUmaPosicao,
            aoMenosUmaPosicao = viewModel::menosUmaPosicao,
            aoAlternarRefeicao = viewModel::alternarRefeicao,
            aoAlternarTransporte = viewModel::alternarTransporte,
            aoAlternarMaterial = viewModel::alternarMaterialProprio,
            aoEditarResponsavel = viewModel::editarResponsavel,
            aoEditarTraje = viewModel::editarTraje,
            aoEditarObservacoes = viewModel::editarObservacoes,
            aoAlternarRateio = viewModel::alternarRateio,
            aoPublicar = { viewModel.publicar() },
            aoVoltar = aoVoltar,
        ),
        modifier = modifier,
    )
}

/**
 * Publicação de vaga pelo contratante (RF04, RN02, RN24, UC01; paridade com `TelaPublicarVaga` de
 * `PublicarVaga.swift`). Tela de formulário: título, seções com rótulo, campos com o rótulo acima, escolha
 * única em lista com check, seleção múltipla em chips e UM botão primário ancorado embaixo. Cada campo mostra
 * o próprio erro; o erro global e o aviso de publicação pendente ficam juntos do botão.
 * Com uma publicação pendente o formulário trava e o botão vira "Tentar novamente".
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ConteudoPublicarVaga(
    estado: EstadoPublicarVaga,
    acoes: AcoesPublicarVaga,
    modifier: Modifier = Modifier,
) {
    var seletorDeFuncaoAberto by rememberSaveable { mutableStateOf(false) }
    var maisOpcoesAberto by rememberSaveable { mutableStateOf(false) }
    val cores = FrilaTema.cores

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = {
            BarraDeTopoDoFormulario(
                aoVoltar = acoes.aoVoltar,
                rotuloDoVoltar = TextosPublicarVaga.ROTULO_VOLTAR,
                habilitado = !estado.enviando,
            )
        },
        bottomBar = {
            RodapeAncorado {
                estado.erro?.let { MensagemJuntoAoBotao(it.mensagem) }
                if (estado.naFila) MensagemJuntoAoBotao(TextosPublicarVaga.NA_FILA)
                if (estado.pendente != null && !estado.naFila && !estado.enviando && !estado.concluida) {
                    MensagemJuntoAoBotao(TextosPublicarVaga.PENDENTE)
                }
                if (estado.concluida) MensagemJuntoAoBotao(TextosPublicarVaga.CONCLUIDA)
                BotaoPrimario(
                    texto = when {
                        estado.naFila -> TextosPublicarVaga.PUBLICAR
                        estado.enviando -> TextosPublicarVaga.PUBLICANDO
                        estado.pendente != null -> TextosPublicarVaga.TENTAR_NOVAMENTE
                        else -> TextosPublicarVaga.PUBLICAR
                    },
                    aoClicar = acoes.aoPublicar,
                    habilitado = !estado.enviando && !estado.concluida && !estado.naFila,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(TextosPublicarVaga.TITULO)

            // Função
            when {
                estado.carregandoFuncoes -> Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(TextosPublicarVaga.FUNCAO)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                    ) {
                        IndicadorCarregando(modifier = Modifier.size(24.dp))
                        Text(TextosPublicarVaga.FUNCOES_CARREGANDO, style = FrilaTipo.apoio, color = cores.tintaSuave)
                    }
                }
                estado.falhaAoCarregarFuncoes -> Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(TextosPublicarVaga.FUNCAO)
                    AvisoFrila(tom = TomAviso.ERRO, mensagem = TextosPublicarVaga.FUNCOES_FALHA)
                    BotaoSecundario(texto = TextosPublicarVaga.TENTAR_NOVAMENTE, aoClicar = acoes.aoCarregarFuncoes)
                }
                else -> CampoDeSelecao(
                    rotulo = TextosPublicarVaga.FUNCAO,
                    valor = estado.funcoes.firstOrNull { it.id == estado.funcaoId }?.nome ?: TextosPublicarVaga.FUNCAO_SELECIONAR,
                    aoClicar = { seletorDeFuncaoAberto = true },
                    habilitado = estado.podeEditar,
                    erro = estado.errosDeCampo[CampoPublicacao.FUNCAO],
                )
            }

            // Quando
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                RotuloDeGrupo(TextosPublicarVaga.QUANDO)
                SeletorDeInstante(
                    titulo = TextosPublicarVaga.INICIO,
                    rotuloData = TextosPublicarVaga.DATA_DO_INICIO,
                    rotuloHora = TextosPublicarVaga.HORA_DO_INICIO,
                    instante = estado.inicio,
                    erro = estado.errosDeCampo[CampoPublicacao.INICIO],
                    habilitado = estado.podeEditar,
                    textoDeConfirmar = TextosPublicarVaga.CONFIRMAR,
                    textoDeCancelar = TextosPublicarVaga.CANCELAR,
                    aoMudar = acoes.aoEditarInicio,
                )
                SeletorDeInstante(
                    titulo = TextosPublicarVaga.FIM,
                    rotuloData = TextosPublicarVaga.DATA_DO_FIM,
                    rotuloHora = TextosPublicarVaga.HORA_DO_FIM,
                    instante = estado.fim,
                    erro = estado.errosDeCampo[CampoPublicacao.FIM],
                    habilitado = estado.podeEditar,
                    textoDeConfirmar = TextosPublicarVaga.CONFIRMAR,
                    textoDeCancelar = TextosPublicarVaga.CANCELAR,
                    aoMudar = acoes.aoEditarFim,
                )
                if (estado.duracao.toMinutes() > 0) {
                    Text(
                        text = TextosPublicarVaga.DURACAO.format(formatarDuracao(estado.duracao)),
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                }
            }

            // Modo
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                FrilaGrupoDeLinhas(titulo = TextosPublicarVaga.MODO) {
                    linha {
                        FrilaLinhaDeOpcao(
                            titulo = TextosPublicarVaga.MODO_URGENCIA,
                            subtitulo = TextosPublicarVaga.MODO_URGENCIA_EXPLICACAO,
                            marcada = estado.modo == ModoDaVaga.URGENCIA,
                            aoClicar = { acoes.aoEscolherModo(ModoDaVaga.URGENCIA) },
                            habilitada = estado.podeEditar,
                        )
                    }
                    linha {
                        FrilaLinhaDeOpcao(
                            titulo = TextosPublicarVaga.MODO_SELECAO,
                            subtitulo = if (estado.selecaoDisponivel) {
                                TextosPublicarVaga.MODO_SELECAO_EXPLICACAO
                            } else {
                                TextosPublicarVaga.MODO_SELECAO_SO_COM_ANTECEDENCIA
                            },
                            marcada = estado.modo == ModoDaVaga.SELECAO,
                            aoClicar = { acoes.aoEscolherModo(ModoDaVaga.SELECAO) },
                            habilitada = estado.podeEditar && estado.selecaoDisponivel,
                        )
                    }
                }
                estado.errosDeCampo[CampoPublicacao.MODO]?.let { Text(text = it, style = FrilaTipo.apoio, color = cores.tinta) }
            }

            // Local, valor e posições
            CampoDeTexto(
                valor = estado.local,
                aoMudar = acoes.aoEditarLocal,
                rotulo = TextosPublicarVaga.LOCAL,
                apoio = TextosPublicarVaga.LOCAL_AJUDA,
                erro = estado.errosDeCampo[CampoPublicacao.LOCAL] ?: estado.errosDeCampo[CampoPublicacao.ESTABELECIMENTO],
                habilitado = estado.podeEditar,
            )
            CampoDeTexto(
                valor = estado.valor,
                aoMudar = acoes.aoEditarValor,
                rotulo = TextosPublicarVaga.VALOR,
                apoio = TextosPublicarVaga.VALOR_AJUDA,
                erro = estado.errosDeCampo[CampoPublicacao.VALOR],
                habilitado = estado.podeEditar,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            )
            // Os botões − e + descem até a caixa do campo (a altura do rótulo acompanha a fonte do sistema).
            val alturaDoRotulo = with(LocalDensity.current) { FrilaTipo.rotuloDeGrupo.lineHeight.toDp() }
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                BotaoSecundario(
                    texto = "−",
                    aoClicar = acoes.aoMenosUmaPosicao,
                    habilitado = estado.podeEditar,
                    modifier = Modifier
                        .padding(top = alturaDoRotulo + FrilaEspacamento.item)
                        .semantics { contentDescription = TextosPublicarVaga.MENOS_UMA_POSICAO },
                )
                CampoDeTexto(
                    valor = estado.posicoes,
                    aoMudar = acoes.aoEditarPosicoes,
                    rotulo = TextosPublicarVaga.POSICOES,
                    apoio = TextosPublicarVaga.POSICOES_AJUDA,
                    erro = estado.errosDeCampo[CampoPublicacao.POSICOES],
                    habilitado = estado.podeEditar,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.weight(1f),
                )
                BotaoSecundario(
                    texto = "+",
                    aoClicar = acoes.aoMaisUmaPosicao,
                    habilitado = estado.podeEditar,
                    modifier = Modifier
                        .padding(top = alturaDoRotulo + FrilaEspacamento.item)
                        .semantics { contentDescription = TextosPublicarVaga.MAIS_UMA_POSICAO },
                )
            }
            estado.valorTotalCentavos?.let { total ->
                CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
                        modifier = Modifier.semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
                    ) {
                        Text(text = totalDaVaga(formatarReais(total)), style = FrilaTipo.valorEmDestaque, color = cores.tinta)
                        val posicoes = estado.posicoesNumero ?: 1
                        Text(
                            text = if (posicoes == 1) TextosPublicarVaga.TOTAL_SINGULAR else TextosPublicarVaga.TOTAL_PLURAL.format(posicoes),
                            style = FrilaTipo.apoio,
                            color = cores.tintaSuave,
                        )
                        estado.valorPorHoraCentavos?.let {
                            Text(
                                text = TextosPublicarVaga.VALOR_POR_HORA.format(formatarReais(it)),
                                style = FrilaTipo.apoio,
                                color = cores.tintaSuave,
                            )
                        }
                    }
                }
            }

            // Inclusos
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosPublicarVaga.INCLUSOS)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    ChipFrila(
                        texto = TextosPublicarVaga.REFEICAO,
                        selecionado = estado.incluiRefeicao,
                        aoClicar = { acoes.aoAlternarRefeicao(!estado.incluiRefeicao) },
                        habilitado = estado.podeEditar,
                    )
                    ChipFrila(
                        texto = TextosPublicarVaga.TRANSPORTE,
                        selecionado = estado.incluiTransporte,
                        aoClicar = { acoes.aoAlternarTransporte(!estado.incluiTransporte) },
                        habilitado = estado.podeEditar,
                    )
                    ChipFrila(
                        texto = TextosPublicarVaga.MATERIAL,
                        selecionado = estado.exigeMaterialProprio,
                        aoClicar = { acoes.aoAlternarMaterial(!estado.exigeMaterialProprio) },
                        habilitado = estado.podeEditar,
                    )
                }
            }
            CampoDeTexto(
                valor = estado.responsavelLocal,
                aoMudar = acoes.aoEditarResponsavel,
                rotulo = TextosPublicarVaga.RESPONSAVEL,
                erro = estado.errosDeCampo[CampoPublicacao.RESPONSAVEL],
                habilitado = estado.podeEditar,
            )

            // Mais opções
            FrilaGrupoDeLinhas {
                linha {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = FrilaMetricas.alvoMinimo)
                            .clickable(role = Role.Button) { maisOpcoesAberto = !maisOpcoesAberto }
                            .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                    ) {
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
                            Text(TextosPublicarVaga.MAIS_OPCOES, style = FrilaTipo.rotuloSecundario, color = cores.tinta)
                            Text(TextosPublicarVaga.MAIS_OPCOES_AJUDA, style = FrilaTipo.apoio, color = cores.tintaSuave)
                        }
                        Icon(
                            imageVector = if (maisOpcoesAberto) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                            contentDescription = null,
                            tint = cores.tintaSuave,
                            modifier = Modifier.size(24.dp),
                        )
                    }
                }
            }
            if (maisOpcoesAberto) {
                CampoDeTexto(
                    valor = estado.traje,
                    aoMudar = acoes.aoEditarTraje,
                    rotulo = TextosPublicarVaga.TRAJE,
                    erro = estado.errosDeCampo[CampoPublicacao.TRAJE],
                    habilitado = estado.podeEditar,
                )
                FlowRow {
                    ChipFrila(
                        texto = TextosPublicarVaga.RATEIO,
                        selecionado = estado.participaRateio,
                        aoClicar = { acoes.aoAlternarRateio(!estado.participaRateio) },
                        habilitado = estado.podeEditar,
                    )
                }
                CampoDeTexto(
                    valor = estado.observacoes,
                    aoMudar = acoes.aoEditarObservacoes,
                    rotulo = TextosPublicarVaga.OBSERVACOES,
                    apoio = TextosPublicarVaga.OBSERVACOES_AJUDA,
                    erro = estado.errosDeCampo[CampoPublicacao.OBSERVACOES],
                    habilitado = estado.podeEditar,
                    umaLinha = false,
                    linhasMinimas = 3,
                )
            }
        }
    }

    if (seletorDeFuncaoAberto) {
        FrilaBottomSheet(
            onDismissRequest = { seletorDeFuncaoAberto = false },
            titulo = TextosPublicarVaga.FUNCAO_ESCOLHA,
            aoFechar = null,
        ) {
            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            ) {
                FrilaGrupoDeLinhas {
                    estado.funcoes.forEach { funcao ->
                        linha {
                            FrilaLinhaDeOpcao(
                                titulo = funcao.nome,
                                subtitulo = funcao.categoria,
                                marcada = estado.funcaoId == funcao.id,
                                aoClicar = {
                                    acoes.aoEscolherFuncao(funcao.id)
                                    seletorDeFuncaoAberto = false
                                },
                            )
                        }
                    }
                }
            }
        }
    }
}

/** "Total da vaga: R$ 280,00": o dinheiro em destaque e o rótulo em apoio, na mesma linha. */
@Composable
private fun totalDaVaga(reais: String): AnnotatedString {
    val frase = TextosPublicarVaga.TOTAL_DA_VAGA.format(reais)
    val apoio = FrilaTipo.apoio.toSpanStyle().copy(fontFamily = FontFamily.Default, color = FrilaTema.cores.tintaSuave)
    return buildAnnotatedString {
        append(frase)
        if (frase.endsWith(reais)) addStyle(apoio, 0, frase.length - reais.length)
    }
}
