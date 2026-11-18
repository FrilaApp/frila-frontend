package br.com.frila.feature.perfil

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CampoDeBusca
import br.com.frila.core.designsystem.componentes.ChipFrila
import br.com.frila.core.designsystem.componentes.EstadoVazio
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import java.text.Normalizer

/** Liga o [PontoBaseViewModel] ao [ConteudoPontoBase], carrega o perfil ao abrir e avisa quem abriu quando o ponto foi salvo. */
@Composable
fun TelaPontoBase(
    viewModel: PontoBaseViewModel,
    aoVoltar: () -> Unit,
    aoSalvo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    LaunchedEffect(estado.salvo) { if (estado.salvo) aoSalvo() }
    ConteudoPontoBase(
        estado = estado,
        aoEscolher = viewModel::escolher,
        aoAlternarFuncao = viewModel::alternarFuncao,
        aoSalvar = { viewModel.salvar() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

/**
 * Ponto base do profissional (T1 e T1c do desenho): escolha única de uma região, numa lista com check e busca, e, só para
 * quem ainda não tem perfil, as funções em chips (seleção múltipla). O Salvar é o único primário e fica no rodapé
 * ancorado, com o erro logo acima dele. A busca só filtra a lista que já está na tela.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ConteudoPontoBase(
    estado: EstadoPontoBase,
    aoEscolher: (OpcaoDePontoBase) -> Unit,
    aoAlternarFuncao: (String) -> Unit,
    aoSalvar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    var busca by remember { mutableStateOf("") }
    val opcoesVisiveis = remember(estado.opcoes, busca) {
        val termo = semAcentos(busca)
        if (termo.isBlank()) estado.opcoes else estado.opcoes.filter { semAcentos(it.nome).contains(termo) }
    }
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { BarraDeTopoDoPerfil(aoVoltar = aoVoltar) },
        bottomBar = {
            RodapeAncorado {
                estado.erro?.let { MensagemJuntoAoBotao(it) }
                BotaoPrimario(
                    texto = if (estado.salvando) TextosPontoBase.SALVANDO else TextosPontoBase.SALVAR,
                    aoClicar = aoSalvar,
                    habilitado = !estado.salvando && !estado.carregando,
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
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                TituloDaTela(TextosPontoBase.TITULO)
                Text(TextosPontoBase.DICA, style = FrilaTipo.apoio, color = cores.tintaSuave)
                if (estado.carregando) Text(TextosPontoBase.CARREGANDO, style = FrilaTipo.apoio, color = cores.tintaSuave)
                if (estado.temPontoBaseSalvo) Text(TextosPontoBase.PONTO_BASE_SALVO, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }

            if (estado.semPerfil) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(TextosPontoBase.FUNCOES)
                    Text(TextosPontoBase.FUNCOES_DICA, style = FrilaTipo.apoio, color = cores.tintaSuave)
                    FlowRow(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                        for (funcao in estado.funcoes) {
                            ChipFrila(
                                texto = funcao.nome,
                                selecionado = funcao.id in estado.funcoesEscolhidas,
                                aoClicar = { aoAlternarFuncao(funcao.id) },
                            )
                        }
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosPontoBase.ESCOLHA_A_REGIAO)
                CampoDeBusca(texto = busca, aoMudar = { busca = it }, dica = TextosPontoBase.BUSCAR_REGIAO)
                if (opcoesVisiveis.isEmpty()) {
                    EstadoVazio(
                        titulo = TextosPontoBase.semResultado(busca.trim()),
                        mensagem = TextosPontoBase.SEM_RESULTADO_DICA,
                    )
                } else {
                    FrilaGrupoDeLinhas {
                        for (opcao in opcoesVisiveis) {
                            linha {
                                FrilaLinhaDeOpcao(
                                    titulo = opcao.nome,
                                    marcada = opcao == estado.escolhida,
                                    aoClicar = { aoEscolher(opcao) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/** Minúsculas e sem acento, para a busca achar "Guara" em "Guará". */
private fun semAcentos(texto: String): String =
    Normalizer.normalize(texto, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase()
