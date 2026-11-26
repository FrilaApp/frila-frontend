package br.com.frila.feature.vagas.escala

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
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
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
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
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.feature.vagas.publicacao.BarraDeTopoDoFormulario
import br.com.frila.feature.vagas.publicacao.CampoDeSelecao
import br.com.frila.feature.vagas.publicacao.FUSO_DA_VAGA
import br.com.frila.feature.vagas.publicacao.ModoDaVaga
import br.com.frila.feature.vagas.publicacao.SeletorDeInstante
import br.com.frila.feature.vagas.publicacao.TextosPublicarVaga
import br.com.frila.feature.vagas.publicacao.avisoValorDiaria
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** Tudo o que a tela pode pedir ao [EscalaDeEventoViewModel]; o padrão `{}` mantém o teste de tela curto. */
data class AcoesEscala(
    val aoCarregarFuncoes: () -> Unit = {},
    val aoEditarNome: (String) -> Unit = {},
    val aoEditarData: (LocalDate) -> Unit = {},
    val aoAdicionarVaga: () -> Unit = {},
    val aoRemoverVaga: (Int) -> Unit = {},
    val aoEscolherFuncao: (id: Int, funcaoId: String) -> Unit = { _, _ -> },
    val aoEditarInicio: (id: Int, Instant) -> Unit = { _, _ -> },
    val aoEditarFim: (id: Int, Instant) -> Unit = { _, _ -> },
    val aoEscolherModo: (id: Int, ModoDaVaga) -> Unit = { _, _ -> },
    val aoEditarValor: (id: Int, String) -> Unit = { _, _ -> },
    val aoEditarPosicoes: (id: Int, String) -> Unit = { _, _ -> },
    val aoAlternarRefeicao: (id: Int, Boolean) -> Unit = { _, _ -> },
    val aoAlternarTransporte: (id: Int, Boolean) -> Unit = { _, _ -> },
    val aoAlternarMaterial: (id: Int, Boolean) -> Unit = { _, _ -> },
    val aoEditarResponsavel: (id: Int, String) -> Unit = { _, _ -> },
    val aoEditarTraje: (id: Int, String) -> Unit = { _, _ -> },
    val aoEditarObservacoes: (id: Int, String) -> Unit = { _, _ -> },
    val aoPublicar: () -> Unit = {},
    val aoVoltar: () -> Unit = {},
    /** Depois de publicada: sai da tela para a lista de vagas. */
    val aoConcluir: () -> Unit = {},
)

/** Liga o [EscalaDeEventoViewModel] ao [ConteudoEscalaDeEvento]. */
@Composable
fun TelaEscalaDeEvento(
    viewModel: EscalaDeEventoViewModel,
    aoConcluir: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(Unit) { viewModel.carregarFuncoes() }
    ConteudoEscalaDeEvento(
        estado = estado,
        enderecoDoEvento = viewModel.enderecoDoEvento,
        acoes = AcoesEscala(
            aoCarregarFuncoes = { viewModel.carregarFuncoes() },
            aoEditarNome = viewModel::editarNome,
            aoEditarData = viewModel::editarData,
            aoAdicionarVaga = viewModel::adicionarVaga,
            aoRemoverVaga = viewModel::removerVaga,
            aoEscolherFuncao = viewModel::escolherFuncao,
            aoEditarInicio = viewModel::editarInicio,
            aoEditarFim = viewModel::editarFim,
            aoEscolherModo = viewModel::escolherModo,
            aoEditarValor = viewModel::editarValor,
            aoEditarPosicoes = viewModel::editarPosicoes,
            aoAlternarRefeicao = viewModel::alternarRefeicao,
            aoAlternarTransporte = viewModel::alternarTransporte,
            aoAlternarMaterial = viewModel::alternarMaterialProprio,
            aoEditarResponsavel = viewModel::editarResponsavel,
            aoEditarTraje = viewModel::editarTraje,
            aoEditarObservacoes = viewModel::editarObservacoes,
            aoPublicar = { viewModel.publicar() },
            aoVoltar = aoVoltar,
            aoConcluir = aoConcluir,
        ),
        modifier = modifier,
    )
}

/**
 * Publicar a escala de um evento (RF19): o evento no alto e, embaixo, uma vaga por função, cada uma num cartão. Um só
 * botão primário ancorado: "Publicar escala" publica tudo ou nada; o erro e o aviso de publicação pendente ficam
 * junto do botão, e cada campo mostra o próprio erro. Com a escala pendente o formulário trava e o botão vira
 * "Tentar novamente". Pronta, a tela dá lugar à confirmação com "Ver minhas vagas".
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoEscalaDeEvento(
    estado: EstadoEscalaDeEvento,
    enderecoDoEvento: String,
    acoes: AcoesEscala,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    // Qual vaga está escolhendo a função na folha; o id da vaga sobrevive à rotação.
    var escolhendoFuncaoDe by rememberSaveable { mutableStateOf<Int?>(null) }
    var escolhendoData by rememberSaveable { mutableStateOf(false) }

    if (estado.concluida) {
        ConfirmacaoDaEscala(vagas = estado.publicada?.vagas?.size ?: 0, aoConcluir = acoes.aoConcluir, modifier = modifier)
        return
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = {
            BarraDeTopoDoFormulario(
                aoVoltar = acoes.aoVoltar,
                rotuloDoVoltar = TextosEscala.ROTULO_VOLTAR,
                habilitado = !estado.enviando,
            )
        },
        bottomBar = {
            RodapeAncorado {
                estado.erro?.let { MensagemJuntoAoBotao(it.mensagem) }
                if (estado.pendente != null && !estado.enviando) MensagemJuntoAoBotao(TextosEscala.PENDENTE)
                BotaoPrimario(
                    texto = when {
                        estado.enviando -> TextosEscala.PUBLICANDO
                        estado.pendente != null -> TextosEscala.TENTAR_NOVAMENTE
                        else -> TextosEscala.PUBLICAR
                    },
                    aoClicar = acoes.aoPublicar,
                    habilitado = !estado.enviando,
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
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                TituloDaTela(TextosEscala.TITULO)
                Text(text = TextosEscala.SUBTITULO, style = FrilaTipo.corpo, color = cores.tintaSuave)
            }

            // O evento
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                RotuloDeGrupo(TextosEscala.EVENTO)
                CampoDeTexto(
                    valor = estado.nome,
                    aoMudar = acoes.aoEditarNome,
                    rotulo = TextosEscala.NOME,
                    apoio = TextosEscala.NOME_AJUDA,
                    erro = estado.errosDoEvento[CampoDoEvento.NOME],
                    habilitado = estado.podeEditar,
                )
                CampoDeSelecao(
                    rotulo = TextosEscala.DATA,
                    valor = formatarDia(estado.data),
                    aoClicar = { escolhendoData = true },
                    habilitado = estado.podeEditar,
                    apoio = TextosEscala.DATA_AJUDA,
                    erro = estado.errosDoEvento[CampoDoEvento.DATA],
                    descricao = "${TextosEscala.DATA_DO_EVENTO}: ${formatarDia(estado.data)}",
                )
                Text(
                    text = TextosEscala.ENDERECO.format(enderecoDoEvento),
                    style = FrilaTipo.apoio,
                    color = estado.errosDoEvento[CampoDoEvento.ESTABELECIMENTO]?.let { cores.tinta } ?: cores.tintaSuave,
                )
                estado.errosDoEvento[CampoDoEvento.ESTABELECIMENTO]?.let { Text(text = it, style = FrilaTipo.apoio, color = cores.tinta) }
            }

            // As funções
            when {
                estado.carregandoFuncoes -> Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                ) {
                    IndicadorCarregando(modifier = Modifier.size(24.dp))
                    Text(TextosEscala.FUNCOES_CARREGANDO, style = FrilaTipo.apoio, color = cores.tintaSuave)
                }
                estado.falhaAoCarregarFuncoes -> Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    AvisoFrila(tom = TomAviso.ERRO, mensagem = TextosEscala.FUNCOES_FALHA)
                    BotaoSecundario(texto = TextosEscala.TENTAR_NOVAMENTE, aoClicar = acoes.aoCarregarFuncoes)
                }
            }

            estado.itens.forEachIndexed { indice, item ->
                CartaoDaVaga(
                    indice = indice,
                    total = estado.itens.size,
                    item = item,
                    estado = estado,
                    acoes = acoes,
                    aoEscolherFuncao = { escolhendoFuncaoDe = item.id },
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                if (estado.itens.size < EstadoEscalaDeEvento.MAXIMO_DE_VAGAS) {
                    BotaoSecundario(
                        texto = TextosEscala.ADICIONAR,
                        aoClicar = acoes.aoAdicionarVaga,
                        habilitado = estado.podeAdicionar,
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    Text(
                        text = TextosEscala.LIMITE.format(EstadoEscalaDeEvento.MAXIMO_DE_VAGAS),
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                }
                Text(text = TextosEscala.POSICOES_NA_ESCALA, style = FrilaTipo.apoio, color = cores.tintaSuave)
                Text(
                    text = TextosEscala.TOTAL_DA_ESCALA.format(estado.totalDePessoas),
                    style = FrilaTipo.rotuloSecundario,
                    color = cores.tinta,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
            }
        }
    }

    escolhendoFuncaoDe?.let { idDaVaga ->
        val escolhida = estado.itens.firstOrNull { it.id == idDaVaga }?.funcaoId
        FrilaBottomSheet(
            onDismissRequest = { escolhendoFuncaoDe = null },
            titulo = TextosEscala.FUNCAO_ESCOLHA,
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
                                marcada = escolhida == funcao.id,
                                aoClicar = {
                                    acoes.aoEscolherFuncao(idDaVaga, funcao.id)
                                    escolhendoFuncaoDe = null
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    if (escolhendoData) {
        SeletorDeDia(
            dia = estado.data,
            aoEscolher = {
                acoes.aoEditarData(it)
                escolhendoData = false
            },
            aoFechar = { escolhendoData = false },
        )
    }
}

/** Uma vaga da escala: função, quando, valor, posições, modo, inclusos, responsável e, em "Mais opções", traje e observações. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CartaoDaVaga(
    indice: Int,
    total: Int,
    item: ItemDaEscala,
    estado: EstadoEscalaDeEvento,
    acoes: AcoesEscala,
    aoEscolherFuncao: () -> Unit,
) {
    val cores = FrilaTema.cores
    val erros = estado.errosDosItens[item.id].orEmpty()
    var maisOpcoes by rememberSaveable(item.id) { mutableStateOf(false) }
    val id = item.id

    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
            Text(
                text = TextosEscala.VAGA.format(indice + 1, total),
                style = FrilaTipo.nome,
                color = cores.tinta,
                modifier = Modifier.semantics { heading() },
            )

            CampoDeSelecao(
                rotulo = TextosPublicarVaga.FUNCAO,
                valor = estado.funcoes.firstOrNull { it.id == item.funcaoId }?.nome ?: TextosEscala.FUNCAO_SELECIONAR,
                aoClicar = aoEscolherFuncao,
                habilitado = estado.podeEditar && estado.funcoes.isNotEmpty(),
                erro = erros[CampoDoItem.FUNCAO],
            )

            SeletorDeInstante(
                titulo = TextosPublicarVaga.INICIO,
                rotuloData = TextosPublicarVaga.DATA_DO_INICIO,
                rotuloHora = TextosPublicarVaga.HORA_DO_INICIO,
                instante = item.inicio,
                erro = erros[CampoDoItem.INICIO],
                habilitado = estado.podeEditar,
                textoDeConfirmar = TextosPublicarVaga.CONFIRMAR,
                textoDeCancelar = TextosPublicarVaga.CANCELAR,
                aoMudar = { acoes.aoEditarInicio(id, it) },
            )
            SeletorDeInstante(
                titulo = TextosPublicarVaga.FIM,
                rotuloData = TextosPublicarVaga.DATA_DO_FIM,
                rotuloHora = TextosPublicarVaga.HORA_DO_FIM,
                instante = item.fim,
                erro = erros[CampoDoItem.FIM],
                habilitado = estado.podeEditar,
                textoDeConfirmar = TextosPublicarVaga.CONFIRMAR,
                textoDeCancelar = TextosPublicarVaga.CANCELAR,
                aoMudar = { acoes.aoEditarFim(id, it) },
            )

            // Modo: duas escolhas, uma só vale.
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosPublicarVaga.MODO)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    ChipFrila(
                        texto = TextosPublicarVaga.MODO_URGENCIA,
                        selecionado = item.modo == ModoDaVaga.URGENCIA,
                        aoClicar = { acoes.aoEscolherModo(id, ModoDaVaga.URGENCIA) },
                        habilitado = estado.podeEditar,
                        escolhaUnica = true,
                    )
                    ChipFrila(
                        texto = TextosPublicarVaga.MODO_SELECAO,
                        selecionado = item.modo == ModoDaVaga.SELECAO,
                        aoClicar = { acoes.aoEscolherModo(id, ModoDaVaga.SELECAO) },
                        habilitado = estado.podeEditar && estado.selecaoDisponivel(item),
                        escolhaUnica = true,
                    )
                }
                Text(
                    text = when {
                        item.modo == ModoDaVaga.SELECAO -> TextosPublicarVaga.MODO_SELECAO_EXPLICACAO
                        estado.selecaoDisponivel(item) -> TextosPublicarVaga.MODO_URGENCIA_EXPLICACAO
                        else -> TextosPublicarVaga.MODO_SELECAO_SO_COM_ANTECEDENCIA
                    },
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
                erros[CampoDoItem.MODO]?.let { Text(text = it, style = FrilaTipo.apoio, color = cores.tinta) }
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                CampoDeTexto(
                    valor = item.valor,
                    aoMudar = { acoes.aoEditarValor(id, it) },
                    rotulo = TextosPublicarVaga.VALOR,
                    apoio = TextosPublicarVaga.VALOR_AJUDA,
                    erro = erros[CampoDoItem.VALOR],
                    habilitado = estado.podeEditar,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                )
                avisoValorDiaria(item.valorCentavos)?.let { aviso ->
                    Text(text = aviso, style = FrilaTipo.apoio, color = cores.tintaSuave)
                }
            }
            CampoDeTexto(
                valor = item.posicoes,
                aoMudar = { acoes.aoEditarPosicoes(id, it) },
                rotulo = TextosPublicarVaga.POSICOES,
                apoio = TextosEscala.POSICOES_CAMPO,
                erro = erros[CampoDoItem.POSICOES],
                habilitado = estado.podeEditar,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosPublicarVaga.INCLUSOS)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    ChipFrila(
                        texto = TextosPublicarVaga.REFEICAO,
                        selecionado = item.incluiRefeicao,
                        aoClicar = { acoes.aoAlternarRefeicao(id, !item.incluiRefeicao) },
                        habilitado = estado.podeEditar,
                    )
                    ChipFrila(
                        texto = TextosPublicarVaga.TRANSPORTE,
                        selecionado = item.incluiTransporte,
                        aoClicar = { acoes.aoAlternarTransporte(id, !item.incluiTransporte) },
                        habilitado = estado.podeEditar,
                    )
                    ChipFrila(
                        texto = TextosPublicarVaga.MATERIAL,
                        selecionado = item.exigeMaterialProprio,
                        aoClicar = { acoes.aoAlternarMaterial(id, !item.exigeMaterialProprio) },
                        habilitado = estado.podeEditar,
                    )
                }
            }
            CampoDeTexto(
                valor = item.responsavelLocal,
                aoMudar = { acoes.aoEditarResponsavel(id, it) },
                rotulo = TextosPublicarVaga.RESPONSAVEL,
                erro = erros[CampoDoItem.RESPONSAVEL],
                habilitado = estado.podeEditar,
            )

            BotaoSecundario(
                texto = if (maisOpcoes) TextosEscala.MENOS_OPCOES else TextosPublicarVaga.MAIS_OPCOES,
                aoClicar = { maisOpcoes = !maisOpcoes },
                modifier = Modifier.fillMaxWidth(),
            )
            if (maisOpcoes || erros.containsKey(CampoDoItem.TRAJE) || erros.containsKey(CampoDoItem.OBSERVACOES)) {
                CampoDeTexto(
                    valor = item.traje,
                    aoMudar = { acoes.aoEditarTraje(id, it) },
                    rotulo = TextosPublicarVaga.TRAJE,
                    erro = erros[CampoDoItem.TRAJE],
                    habilitado = estado.podeEditar,
                )
                CampoDeTexto(
                    valor = item.observacoes,
                    aoMudar = { acoes.aoEditarObservacoes(id, it) },
                    rotulo = TextosPublicarVaga.OBSERVACOES,
                    apoio = TextosPublicarVaga.OBSERVACOES_AJUDA,
                    erro = erros[CampoDoItem.OBSERVACOES],
                    habilitado = estado.podeEditar,
                    umaLinha = false,
                    linhasMinimas = 3,
                )
            }

            if (estado.itens.size > 1) {
                BotaoSecundario(
                    texto = TextosEscala.REMOVER.format(indice + 1),
                    aoClicar = { acoes.aoRemoverVaga(id) },
                    habilitado = estado.podeRemover,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

/** Escala publicada: a confirmação e um só caminho adiante, "Ver minhas vagas". */
@Composable
private fun ConfirmacaoDaEscala(vagas: Int, aoConcluir: () -> Unit, modifier: Modifier = Modifier) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        bottomBar = {
            RodapeAncorado {
                BotaoPrimario(texto = TextosEscala.VER_MINHAS_VAGAS, aoClicar = aoConcluir, modifier = Modifier.fillMaxWidth())
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.secao),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            TituloDaTela(TextosEscala.PUBLICADA_TITULO)
            AvisoFrila(
                tom = TomAviso.SUCESSO,
                mensagem = if (vagas == 1) TextosEscala.PUBLICADA_UMA else TextosEscala.PUBLICADA_VARIAS.format(vagas),
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
    }
}

/** O dia do evento no seletor nativo do Material 3. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SeletorDeDia(dia: LocalDate, aoEscolher: (LocalDate) -> Unit, aoFechar: () -> Unit) {
    val estadoDoSeletor = rememberDatePickerState(initialSelectedDateMillis = dia.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli())
    DatePickerDialog(
        onDismissRequest = aoFechar,
        confirmButton = {
            TextButton(
                onClick = {
                    val escolhido = estadoDoSeletor.selectedDateMillis
                    if (escolhido == null) aoFechar() else aoEscolher(Instant.ofEpochMilli(escolhido).atZone(ZoneOffset.UTC).toLocalDate())
                },
            ) { Text(TextosPublicarVaga.CONFIRMAR) }
        },
        dismissButton = { TextButton(onClick = aoFechar) { Text(TextosPublicarVaga.CANCELAR) } },
    ) {
        DatePicker(state = estadoDoSeletor, title = { Text(TextosEscala.DATA_DO_EVENTO, modifier = Modifier.padding(FrilaEspacamento.bloco)) })
    }
}

/** "12/12/2026": o mesmo formato das datas da publicação de vaga. */
internal fun formatarDia(dia: LocalDate): String = br.com.frila.feature.vagas.publicacao.formatarData(dia.atStartOfDay(FUSO_DA_VAGA).toInstant())
