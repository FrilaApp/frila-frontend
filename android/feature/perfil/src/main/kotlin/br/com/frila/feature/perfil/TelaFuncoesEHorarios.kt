// TELA PROVISÓRIA (sistema do Fabrício): ele revê depois
package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto

@Composable
fun TelaFuncoesEHorarios(
    viewModel: FuncoesEHorariosViewModel,
    aoVoltar: () -> Unit,
    aoSalvo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    LaunchedEffect(estado.salvo) { if (estado.salvo) aoSalvo() }

    ConteudoFuncoesEHorarios(
        estado = estado,
        aoAlternarFuncao = viewModel::alternarFuncao,
        aoSelecionarDia = viewModel::selecionarDia,
        aoAdicionarJanela = viewModel::adicionarJanela,
        aoRemoverJanela = viewModel::removerJanela,
        aoSalvar = { viewModel.salvar() },
        aoTentarRecarregar = { viewModel.carregar() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

fun nomeDoDiaSemana(dia: Int): String = when (dia) {
    0 -> "Domingo"
    1 -> "Segunda-feira"
    2 -> "Terça-feira"
    3 -> "Quarta-feira"
    4 -> "Quinta-feira"
    5 -> "Sexta-feira"
    6 -> "Sábado"
    else -> ""
}

fun JanelaDeDisponibilidadeDto.atravessaMeiaNoite(): Boolean {
    val regex = Regex("^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")
    if (!regex.matches(inicio) || !regex.matches(fim)) return false
    val (hIni, mIni) = inicio.split(":").map { it.toInt() }
    val (hFim, mFim) = fim.split(":").map { it.toInt() }
    val minIni = hIni * 60 + mIni
    val minFim = hFim * 60 + mFim
    return minFim < minIni
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ConteudoFuncoesEHorarios(
    estado: EstadoFuncoesEHorarios,
    aoAlternarFuncao: (String) -> Unit,
    aoSelecionarDia: (Int) -> Unit,
    aoAdicionarJanela: (Int, String, String) -> Boolean,
    aoRemoverJanela: (JanelaDeDisponibilidadeDto) -> Unit,
    aoSalvar: () -> Unit,
    aoTentarRecarregar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    var horaInicio by remember(estado.diaSelecionado) { mutableStateOf("08:00") }
    var horaFim by remember(estado.diaSelecionado) { mutableStateOf("16:00") }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { BarraDeTopoDoPerfil(aoVoltar = aoVoltar) },
        bottomBar = {
            RodapeAncorado {
                val mensagemAbaixo = estado.erro ?: if (estado.precisaDefinirPontoBase) {
                    stringResource(R.string.funcoes_horarios_erro_sem_ponto_base)
                } else null
                mensagemAbaixo?.let { MensagemJuntoAoBotao(it) }
                BotaoPrimario(
                    texto = if (estado.salvando) stringResource(R.string.funcoes_horarios_salvando) else stringResource(R.string.funcoes_horarios_salvar),
                    aoClicar = aoSalvar,
                    habilitado = !estado.salvando && !estado.carregando && !estado.precisaDefinirPontoBase,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("botao-salvar-funcoes-horarios"),
                )
            }
        },
    ) { preenchimento ->
        if (estado.carregando) {
            IndicadorCarregando(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(preenchimento),
            )
        } else if (estado.erro != null && estado.funcoesDisponiveis.isEmpty()) {
            EstadoErro(
                mensagem = estado.erro,
                aoTentarNovamente = aoTentarRecarregar,
                modifier = Modifier
                    .fillMaxSize()
                    .padding(preenchimento),
            )
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(preenchimento)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.secao),
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
                    TituloDaTela(stringResource(R.string.funcoes_horarios_titulo))
                    Text(
                        text = stringResource(R.string.funcoes_horarios_dica),
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                }

                // (a) Funções exercidas
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(stringResource(R.string.funcoes_horarios_secao_funcoes))
                    Text(
                        text = stringResource(R.string.funcoes_horarios_dica_funcoes),
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                    ) {
                        estado.funcoesDisponiveis.forEach { funcao ->
                            ChipFrila(
                                texto = funcao.nome,
                                selecionado = funcao.id in estado.funcoesSelecionadas,
                                aoClicar = { aoAlternarFuncao(funcao.id) },
                                modifier = Modifier.testTag("chip-funcao-${funcao.id}"),
                            )
                        }
                    }
                }

                // (b) Disponibilidade semanal
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(stringResource(R.string.funcoes_horarios_secao_disponibilidade))
                    Text(
                        text = stringResource(R.string.funcoes_horarios_dica_disponibilidade),
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )

                    // Seletor de dia da semana (0..6)
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio),
                        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio),
                    ) {
                        listOf(
                            0 to "Dom",
                            1 to "Seg",
                            2 to "Ter",
                            3 to "Qua",
                            4 to "Qui",
                            5 to "Sex",
                            6 to "Sáb",
                        ).forEach { (dia, rotulo) ->
                            ChipFrila(
                                texto = rotulo,
                                selecionado = estado.diaSelecionado == dia,
                                aoClicar = { aoSelecionarDia(dia) },
                                escolhaUnica = true,
                                modifier = Modifier.testTag("dia-$dia"),
                            )
                        }
                    }

                    // Janelas do dia selecionado
                    val janelasDoDia = estado.disponibilidades.filter { it.diaSemana == estado.diaSelecionado }
                    val nomeDia = nomeDoDiaSemana(estado.diaSelecionado)
                    Text(
                        text = nomeDia,
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )

                    if (janelasDoDia.isEmpty()) {
                        Text(
                            text = stringResource(R.string.funcoes_horarios_sem_horarios),
                            style = FrilaTipo.apoio,
                            color = cores.tintaSuave,
                        )
                    } else {
                        FrilaGrupoDeLinhas {
                            janelasDoDia.forEach { janela ->
                                linha {
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        val textoFaixa = if (janela.atravessaMeiaNoite()) {
                                            stringResource(R.string.funcoes_horarios_faixa_ate_dia_seguinte, janela.inicio, janela.fim)
                                        } else {
                                            stringResource(R.string.funcoes_horarios_faixa, janela.inicio, janela.fim)
                                        }
                                        Text(
                                            text = textoFaixa,
                                            style = FrilaTipo.corpo,
                                            color = cores.tinta,
                                        )
                                        IconButton(
                                            onClick = { aoRemoverJanela(janela) },
                                            modifier = Modifier.testTag("remover-janela-${janela.inicio}-${janela.fim}"),
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.Close,
                                                contentDescription = stringResource(R.string.funcoes_horarios_remover_horario),
                                                tint = cores.tintaSuave,
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Formulário de adição de faixa
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                    ) {
                        CampoDeTexto(
                            valor = horaInicio,
                            aoMudar = { horaInicio = it },
                            rotulo = stringResource(R.string.funcoes_horarios_inicio),
                            modifier = Modifier
                                .weight(1f)
                                .testTag("campo-inicio"),
                        )
                        CampoDeTexto(
                            valor = horaFim,
                            aoMudar = { horaFim = it },
                            rotulo = stringResource(R.string.funcoes_horarios_fim),
                            modifier = Modifier
                                .weight(1f)
                                .testTag("campo-fim"),
                        )
                    }

                    estado.erroValidacaoHorario?.let { erroHorario ->
                        Text(
                            text = erroHorario,
                            style = FrilaTipo.apoio,
                            color = cores.tinta,
                            modifier = Modifier.testTag("erro-validacao-horario"),
                        )
                    }

                    BotaoSecundario(
                        texto = stringResource(R.string.funcoes_horarios_adicionar_horario),
                        aoClicar = { aoAdicionarJanela(estado.diaSelecionado, horaInicio, horaFim) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("botao-adicionar-horario"),
                    )
                }
            }
        }
    }
}
