package br.com.frila.feature.chamadas.profissional

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SelectableDates
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeNavegacao
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** Liga o [PreferenciasChamadaViewModel] ao [ConteudoPreferenciasDeChamada]. */
@Composable
fun TelaPreferenciasDeChamada(
    viewModel: PreferenciasChamadaViewModel,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    /** Abre "Editar serviços"; nulo esconde o atalho. */
    aoEditarServicos: (() -> Unit)? = null,
    /** Chave `busca_profissionais` (RN46): desligada, o bloco "Aceito chamadas diretas" e as pendências não aparecem. */
    buscaProfissionaisHabilitada: Boolean = false,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoPreferenciasDeChamada(
        tela = estado,
        aoTentarNovamente = { viewModel.carregar() },
        aoAlternarAceitaChamadas = viewModel::alternarAceitaChamadas,
        aoAlternarAceitaDeQuemJaTrabalhou = viewModel::alternarAceitaDeQuemJaTrabalhou,
        aoAlternarPausa = viewModel::alternarPausa,
        aoEscolherDataDaPausa = viewModel::escolherDataDaPausa,
        aoEscolherAntecedencia = viewModel::escolherAntecedencia,
        aoEscolherQuemPodeChamar = viewModel::escolherQuemPodeChamar,
        aoSalvar = { viewModel.salvar() },
        aoVoltar = aoVoltar,
        aoEditarServicos = aoEditarServicos,
        buscaProfissionaisHabilitada = buscaProfissionaisHabilitada,
        modifier = modifier,
    )
}

/**
 * Preferências de chamada (CD-I5d; paridade com `TelaPreferenciasDeChamada.swift`, mais o "Aceito chamadas
 * diretas" e as pendências da busca, CD-P10 a CD-P12): mesma ordem de campos do iOS, com o pedido do titular
 * no topo. Interruptores nativos em linhas de grupo; pausa por data (diálogo de data), antecedência e "quem pode
 * me chamar" em listas com check. "Salvar preferências" fica no rodapé ancorado, com o erro e o "salvo" acima.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConteudoPreferenciasDeChamada(
    tela: EstadoPreferenciasChamada,
    aoTentarNovamente: () -> Unit,
    aoAlternarAceitaChamadas: (Boolean) -> Unit,
    aoAlternarAceitaDeQuemJaTrabalhou: (Boolean) -> Unit,
    aoAlternarPausa: (Boolean) -> Unit,
    aoEscolherDataDaPausa: (LocalDate) -> Unit,
    aoEscolherAntecedencia: (Int) -> Unit,
    aoEscolherQuemPodeChamar: (String) -> Unit,
    aoSalvar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
    aoEditarServicos: (() -> Unit)? = null,
    buscaProfissionaisHabilitada: Boolean = false,
    hoje: LocalDate = LocalDate.now(FormatoChamada.fuso),
) {
    var escolhendoData by rememberSaveable { mutableStateOf(false) }
    val formularioPronto = tela.carregou && !tela.carregando

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
        bottomBar = {
            if (formularioPronto) {
                RodapeAncorado {
                    tela.erro?.let { MensagemJuntoAoBotao(it) }
                    if (tela.sucesso) {
                        MensagemJuntoAoBotao(
                            texto = TextosChamadaProfissional.PREFERENCIAS_SALVAS,
                            modifier = Modifier.testTag("preferencias-sucesso"),
                        )
                    }
                    BotaoPrimario(
                        texto = TextosChamadaProfissional.PREFERENCIAS_SALVAR,
                        aoClicar = aoSalvar,
                        habilitado = !tela.salvando,
                        modifier = Modifier.fillMaxWidth().testTag("salvar-preferencias-chamada"),
                    )
                }
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(TextosChamadaProfissional.PREFERENCIAS_TITULO)
            when {
                tela.carregando -> EstadoCarregando(mensagem = TextosChamadaProfissional.CARREGANDO)
                !tela.carregou -> ErroDeCargaChamada(
                    mensagem = tela.erro ?: TextosChamadaProfissional.ERRO,
                    aoTentarNovamente = aoTentarNovamente,
                )
                else -> Formulario(
                    tela = tela,
                    aoAlternarAceitaChamadas = aoAlternarAceitaChamadas,
                    aoAlternarAceitaDeQuemJaTrabalhou = aoAlternarAceitaDeQuemJaTrabalhou,
                    aoAlternarPausa = aoAlternarPausa,
                    aoAbrirData = { escolhendoData = true },
                    aoEscolherAntecedencia = aoEscolherAntecedencia,
                    aoEscolherQuemPodeChamar = aoEscolherQuemPodeChamar,
                    aoEditarServicos = aoEditarServicos,
                    buscaProfissionaisHabilitada = buscaProfissionaisHabilitada,
                )
            }
        }
    }

    if (escolhendoData) {
        val estadoDaData = rememberDatePickerState(
            initialSelectedDateMillis = tela.pausadoAte.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long): Boolean =
                    Instant.ofEpochMilli(utcTimeMillis).atZone(ZoneOffset.UTC).toLocalDate().isAfter(hoje)
            },
        )
        DatePickerDialog(
            onDismissRequest = { escolhendoData = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        estadoDaData.selectedDateMillis?.let { millis ->
                            aoEscolherDataDaPausa(Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate())
                        }
                        escolhendoData = false
                    },
                ) { Text(TextosChamadaProfissional.CONFIRMAR) }
            },
            dismissButton = {
                TextButton(onClick = { escolhendoData = false }) { Text(TextosChamadaProfissional.CANCELAR) }
            },
        ) { DatePicker(state = estadoDaData) }
    }
}

@Composable
private fun Formulario(
    tela: EstadoPreferenciasChamada,
    aoAlternarAceitaChamadas: (Boolean) -> Unit,
    aoAlternarAceitaDeQuemJaTrabalhou: (Boolean) -> Unit,
    aoAlternarPausa: (Boolean) -> Unit,
    aoAbrirData: () -> Unit,
    aoEscolherAntecedencia: (Int) -> Unit,
    aoEscolherQuemPodeChamar: (String) -> Unit,
    aoEditarServicos: (() -> Unit)?,
    buscaProfissionaisHabilitada: Boolean,
) {
    val livre = !tela.salvando
    val cores = FrilaTema.cores

    if (buscaProfissionaisHabilitada) {
        // "Aceito chamadas diretas" (CD-P10 a CD-P12): o pedido do titular, sem "autorizo" nem "consinto" (J1).
        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
            FrilaGrupoDeLinhas {
                linha {
                    LinhaComChave(
                        titulo = TextosChamadaProfissional.ACEITO_TEXTO,
                        ligado = tela.aceitaChamadas,
                        aoMudar = aoAlternarAceitaChamadas,
                        habilitado = livre,
                        modifier = Modifier.testTag("chave-aceita-chamadas"),
                    )
                }
            }
            Text(text = TextosChamadaProfissional.ACEITO_EXPLICACAO, style = FrilaTipo.apoio, color = cores.tintaSuave)
            Text(text = TextosChamadaProfissional.ACEITO_O_QUE_APARECE, style = FrilaTipo.apoio, color = cores.tintaSuave)
            Text(text = TextosChamadaProfissional.ACEITO_DESLIGAR, style = FrilaTipo.apoio, color = cores.tintaSuave)
            val pendencias = tela.pendencias.mapNotNull(TextosChamadaProfissional::pendencia)
            if (tela.aceitaChamadas && pendencias.isNotEmpty()) {
                CartaoFrila(modifier = Modifier.fillMaxWidth().testTag("pendencias-busca")) {
                    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                        RotuloDeGrupo(TextosChamadaProfissional.PENDENCIAS_TITULO)
                        pendencias.forEach { Text(text = "• $it", style = FrilaTipo.corpo, color = cores.tinta) }
                    }
                }
            }
        }
    }

    // Serviços com preço são da chamada direta (existem no iOS), não da busca: não dependem da chave `busca_profissionais`.
    if (aoEditarServicos != null) {
        FrilaGrupoDeLinhas {
            linha {
                FrilaLinhaDeNavegacao(
                    titulo = TextosChamadaProfissional.EDITAR_SERVICOS,
                    aoClicar = aoEditarServicos,
                    modifier = Modifier.testTag("editar-servicos"),
                )
            }
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        FrilaGrupoDeLinhas {
            linha {
                LinhaComChave(
                    titulo = TextosChamadaProfissional.RECEBER_DE_QUEM_JA_TRABALHOU,
                    subtitulo = TextosChamadaProfissional.RECEBER_DE_QUEM_JA_TRABALHOU_SUBTITULO,
                    ligado = tela.aceitaDeQuemJaTrabalhou,
                    aoMudar = aoAlternarAceitaDeQuemJaTrabalhou,
                    habilitado = livre,
                    modifier = Modifier.testTag("toggle-receber-chamadas"),
                )
            }
            linha {
                LinhaComChave(
                    titulo = TextosChamadaProfissional.PAUSAR_CHAMADAS,
                    ligado = tela.pausar,
                    aoMudar = aoAlternarPausa,
                    habilitado = livre,
                    modifier = Modifier.testTag("toggle-pausa-chamadas"),
                )
            }
            if (tela.pausar) {
                linha {
                    FrilaLinhaDeNavegacao(
                        titulo = "${TextosChamadaProfissional.PAUSAR_ATE_DATA}: ${FormatoChamada.data(tela.pausadoAte)}",
                        aoClicar = { if (livre) aoAbrirData() },
                        modifier = Modifier.testTag("data-pausa-chamadas"),
                    )
                }
            }
        }
        if (tela.pausar) {
            Text(
                text = TextosChamadaProfissional.retomadaDaPausa(FormatoChamada.data(tela.diaDaRetomada)),
                style = FrilaTipo.apoio,
                color = cores.tintaSuave,
            )
        }
    }

    EscolhaUnica(
        titulo = TextosChamadaProfissional.ANTECEDENCIA_MINIMA,
        opcoes = listOf(
            2 to TextosChamadaProfissional.ANTECEDENCIA_2H,
            6 to TextosChamadaProfissional.ANTECEDENCIA_6H,
            24 to TextosChamadaProfissional.ANTECEDENCIA_24H,
            48 to TextosChamadaProfissional.ANTECEDENCIA_48H,
        ),
        selecionada = tela.antecedenciaMinimaH,
        aoEscolher = aoEscolherAntecedencia,
        habilitado = livre,
        modifier = Modifier.testTag("picker-antecedencia-chamada"),
    )

    EscolhaUnica(
        titulo = TextosChamadaProfissional.QUEM_PODE_CHAMAR,
        opcoes = listOf(
            "todos" to TextosChamadaProfissional.QUEM_TODOS,
            "so_cnpj" to TextosChamadaProfissional.QUEM_SO_CNPJ,
        ),
        selecionada = tela.aceitaDe,
        aoEscolher = aoEscolherQuemPodeChamar,
        habilitado = livre,
        modifier = Modifier.testTag("picker-quem-pode-chamar"),
    )

    Text(
        text = TextosChamadaProfissional.AVISO_CHAMADAS_EXISTENTES,
        style = FrilaTipo.apoio,
        color = cores.tintaSuave,
    )
}
