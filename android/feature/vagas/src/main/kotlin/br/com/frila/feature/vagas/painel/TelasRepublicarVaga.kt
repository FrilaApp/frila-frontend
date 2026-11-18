package br.com.frila.feature.vagas.painel

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.FrilaBottomSheet
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.feature.vagas.publicacao.BarraDeTopoDoFormulario
import br.com.frila.feature.vagas.publicacao.SeletorDeInstante
import java.time.Instant

/** Liga o [RepublicarVagaViewModel] ao [ConteudoRepublicarVaga]. [aoFechar] recebe o id da vaga nova, ou `null` se não republicou. */
@Composable
fun TelaRepublicarVaga(viewModel: RepublicarVagaViewModel, aoFechar: (novaVagaId: String?) -> Unit, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsState()
    ConteudoRepublicarVaga(
        estado = estado,
        aoMudarInicio = viewModel::mudarInicio,
        aoMudarFim = viewModel::mudarFim,
        aoConfirmar = { viewModel.republicar() },
        aoFechar = { aoFechar(estado.vagaPublicadaId) },
        modifier = modifier,
    )
}

/**
 * Republicar a vaga com outro horário: formulário curto. O título, a frase de apoio e os dois instantes (data e
 * hora em campos que abrem o seletor nativo) ficam no conteúdo; a mensagem de erro e o primário "Confirmar
 * republicação" ficam ancorados embaixo. Desistir é a ação discreta no fim do conteúdo.
 */
@Composable
fun ConteudoRepublicarVaga(
    estado: EstadoRepublicarVaga,
    aoMudarInicio: (Instant) -> Unit,
    aoMudarFim: (Instant) -> Unit,
    aoConfirmar: () -> Unit,
    aoFechar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val republicada = estado.vagaPublicadaId != null
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = {
            BarraDeTopoDoFormulario(
                aoVoltar = aoFechar,
                rotuloDoVoltar = TextosCancelarVaga.VOLTAR,
                habilitado = !estado.enviando,
            )
        },
        bottomBar = {
            RodapeAncorado {
                if (republicada) {
                    MensagemJuntoAoBotao(TextosRepublicarVaga.SUCESSO)
                    BotaoSecundario(TextosRepublicarVaga.OK, aoFechar, Modifier.fillMaxWidth())
                } else {
                    estado.mensagemErro?.let { MensagemJuntoAoBotao(it) }
                    if (estado.enviando) MensagemJuntoAoBotao(TextosRepublicarVaga.ENVIANDO)
                    BotaoPrimario(
                        texto = if (estado.camposBloqueados) TextosRepublicarVaga.TENTAR_NOVAMENTE else TextosRepublicarVaga.CONFIRMAR,
                        aoClicar = aoConfirmar,
                        modifier = Modifier.fillMaxWidth(),
                        habilitado = estado.podeConfirmar,
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
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(TextosRepublicarVaga.TITULO)
            if (!republicada) {
                Text(text = TextosRepublicarVaga.SUBTITULO, style = FrilaTipo.corpo, color = cores.tinta)
                SeletorDeInstante(
                    titulo = TextosRepublicarVaga.INICIO,
                    rotuloData = TextosRepublicarVaga.DATA_DE.format(TextosRepublicarVaga.INICIO.lowercase()),
                    rotuloHora = TextosRepublicarVaga.HORA_DE.format(TextosRepublicarVaga.INICIO.lowercase()),
                    instante = estado.inicio,
                    erro = estado.erroInicio,
                    habilitado = estado.podeMudarHorario,
                    textoDeConfirmar = TextosRepublicarVaga.OK,
                    textoDeCancelar = TextosRepublicarVaga.CANCELAR,
                    aoMudar = aoMudarInicio,
                )
                SeletorDeInstante(
                    titulo = TextosRepublicarVaga.TERMINO,
                    rotuloData = TextosRepublicarVaga.DATA_DE.format(TextosRepublicarVaga.TERMINO.lowercase()),
                    rotuloHora = TextosRepublicarVaga.HORA_DE.format(TextosRepublicarVaga.TERMINO.lowercase()),
                    instante = estado.fim,
                    erro = estado.erroFim,
                    habilitado = estado.podeMudarHorario,
                    textoDeConfirmar = TextosRepublicarVaga.OK,
                    textoDeCancelar = TextosRepublicarVaga.CANCELAR,
                    aoMudar = aoMudarFim,
                )
                AcaoDiscreta(texto = TextosRepublicarVaga.CANCELAR, aoClicar = aoFechar, habilitado = !estado.enviando)
            }
        }
    }
}

/** Liga o [RepublicarPosicoesRestantesViewModel] ao [DialogoRepublicarPosicoesRestantes]. */
@Composable
fun TelaRepublicarPosicoesRestantes(viewModel: RepublicarPosicoesRestantesViewModel, aoFechar: () -> Unit) {
    val estado by viewModel.estado.collectAsState()
    DialogoRepublicarPosicoesRestantes(estado = estado, aoConfirmar = { viewModel.executar() }, aoFechar = aoFechar)
}

/**
 * A confirmação do atalho, numa folha: diz que a urgência confirma o primeiro profissional na hora e mostra a
 * recusa do servidor logo acima do botão. Confirmar compromete (o primeiro a aceitar já é confirmado), então é
 * o único primário da folha; desistir é a ação discreta.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DialogoRepublicarPosicoesRestantes(estado: EstadoRepublicarPosicoesRestantes, aoConfirmar: () -> Unit, aoFechar: () -> Unit) {
    val cores = FrilaTema.cores
    FrilaBottomSheet(
        onDismissRequest = aoFechar,
        titulo = TextosRepublicarPosicoesRestantes.CONFIRMACAO_TITULO,
        aoFechar = null,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.bloco),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            Text(text = TextosRepublicarPosicoesRestantes.botao(estado.posicoesRestantes), style = FrilaTipo.nome, color = cores.tinta)
            Text(text = TextosRepublicarPosicoesRestantes.CONFIRMACAO_MENSAGEM, style = FrilaTipo.corpo, color = cores.tinta)
            estado.erro?.let { MensagemJuntoAoBotao(it) }
            if (estado.carregando) MensagemJuntoAoBotao(TextosRepublicarPosicoesRestantes.REPUBLICANDO)
            BotaoPrimario(
                texto = TextosRepublicarPosicoesRestantes.CONFIRMAR,
                aoClicar = aoConfirmar,
                habilitado = !estado.carregando && estado.vagaPublicadaId == null,
                modifier = Modifier.fillMaxWidth(),
            )
            AcaoDiscreta(texto = TextosRepublicarPosicoesRestantes.CANCELAR, aoClicar = aoFechar)
        }
    }
}
