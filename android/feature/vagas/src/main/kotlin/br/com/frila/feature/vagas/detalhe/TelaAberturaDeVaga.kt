package br.com.frila.feature.vagas.detalhe

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.IndicadorCarregando
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.rede.VagaDto

/**
 * Liga o [AberturaDeVagaViewModel] ao [ConteudoAberturaDeVaga] e carrega ao abrir. [vagaAberta] desenha a vaga que
 * aceita candidatura; quem monta a navegação põe ali a `TelaDetalheVaga`, com `vaga.paraVagaAberta()` e o detalhe.
 */
@Composable
fun TelaAberturaDeVaga(
    viewModel: AberturaDeVagaViewModel,
    aoVoltarParaFeed: () -> Unit,
    modifier: Modifier = Modifier,
    vagaAberta: @Composable (VagaDto) -> Unit,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoAberturaDeVaga(estado, aoTentarDeNovo = { viewModel.carregar() }, aoVoltarParaFeed = aoVoltarParaFeed, modifier = modifier, vagaAberta = vagaAberta)
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** Os quatro momentos de abrir a vaga pelo id: carregando, falha com "Tentar de novo", vaga indisponível e a vaga aberta. */
@Composable
fun ConteudoAberturaDeVaga(
    estado: EstadoAberturaDeVaga,
    aoTentarDeNovo: () -> Unit,
    aoVoltarParaFeed: () -> Unit,
    modifier: Modifier = Modifier,
    vagaAberta: @Composable (VagaDto) -> Unit,
) {
    when (estado) {
        EstadoAberturaDeVaga.Carregando -> Box(
            modifier = modifier.fillMaxSize().semantics { contentDescription = TextosAberturaDeVaga.CARREGANDO },
            contentAlignment = Alignment.Center,
        ) { IndicadorCarregando() }
        is EstadoAberturaDeVaga.Falha -> Box(modifier = modifier.fillMaxSize().padding(FrilaEspacamento.grande), contentAlignment = Alignment.Center) {
            EstadoErro(
                titulo = TextosAberturaDeVaga.ERRO_TITULO,
                mensagem = estado.mensagem,
                textoBotao = TextosAberturaDeVaga.TENTAR_DE_NOVO,
                aoTentarNovamente = aoTentarDeNovo.takeIf { estado.podeTentarDeNovo },
            )
        }
        is EstadoAberturaDeVaga.Indisponivel -> TelaVagaIndisponivel(
            motivo = estado.motivo,
            aoVoltarParaFeed = aoVoltarParaFeed,
            modifier = modifier,
            modo = estado.modo,
            vagaCancelada = estado.vagaCancelada,
        )
        is EstadoAberturaDeVaga.Aberta -> vagaAberta(estado.vaga)
    }
}
