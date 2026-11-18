package br.com.frila.feature.vagas.painel

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Liga o [CancelarVagaViewModel] ao [ConteudoCancelarVaga]. [aoFechar] recebe `true` se a vaga foi cancelada. */
@Composable
fun TelaCancelarVaga(viewModel: CancelarVagaViewModel, aoFechar: (cancelou: Boolean) -> Unit, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsState()
    ConteudoCancelarVaga(
        estado = estado,
        motivos = viewModel.motivos,
        aoEscolherMotivo = viewModel::escolherMotivo,
        aoMudarDetalhes = viewModel::mudarDetalhes,
        aoConfirmar = { viewModel.confirmar() },
        aoFechar = { aoFechar(estado.concluida) },
        modifier = modifier,
    )
}

/**
 * Cancelar a vaga inteira (RN12, UC08). É uma decisão neutra: sem laranja e sem vermelho, porque a tela não
 * empurra para cancelar. O efeito vem escrito antes do motivo, o motivo é uma lista com check, e confirmar é o
 * botão SECUNDÁRIO ancorado embaixo, com a recusa do servidor logo acima dele. "Voltar" fica no fim do conteúdo.
 */
@Composable
fun ConteudoCancelarVaga(
    estado: EstadoCancelarVaga,
    motivos: List<MotivoDeCancelamentoDaVaga>,
    aoEscolherMotivo: (MotivoDeCancelamentoDaVaga) -> Unit,
    aoMudarDetalhes: (String) -> Unit,
    aoConfirmar: () -> Unit,
    aoFechar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        bottomBar = {
            RodapeAncorado {
                if (estado.concluida) {
                    MensagemJuntoAoBotao(TextosCancelarVaga.CANCELADA)
                    BotaoSecundario(TextosCancelarVaga.FECHAR, aoFechar, Modifier.fillMaxWidth())
                } else {
                    estado.erro?.let { MensagemJuntoAoBotao(it) }
                    if (estado.enviando) MensagemJuntoAoBotao(TextosCancelarVaga.ENVIANDO)
                    BotaoSecundario(TextosCancelarVaga.CONFIRMAR, aoConfirmar, Modifier.fillMaxWidth(), habilitado = estado.podeConfirmar)
                }
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(TextosCancelarVaga.TITULO)
            if (!estado.concluida) {
                Text(text = estado.aviso, style = FrilaTipo.corpo, color = cores.tinta)
                FrilaGrupoDeLinhas(titulo = TextosCancelarVaga.MOTIVO_TITULO) {
                    motivos.forEach { motivo ->
                        linha {
                            FrilaLinhaDeOpcao(
                                titulo = motivo.texto,
                                marcada = estado.motivo == motivo,
                                aoClicar = { aoEscolherMotivo(motivo) },
                                habilitada = !estado.enviando,
                            )
                        }
                    }
                }
                CampoDeTexto(
                    valor = estado.detalhes,
                    aoMudar = aoMudarDetalhes,
                    rotulo = if (estado.motivo?.exigeDetalhes == true) {
                        TextosCancelarVaga.DETALHES_OBRIGATORIOS
                    } else {
                        TextosCancelarVaga.DETALHES_OPCIONAIS
                    },
                    habilitado = !estado.enviando,
                    umaLinha = false,
                    linhasMinimas = 3,
                )
                LinkFrila(texto = TextosCancelarVaga.VOLTAR, aoClicar = aoFechar, habilitado = !estado.enviando)
            }
        }
    }
}
