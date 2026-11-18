package br.com.frila.feature.equipe.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.EstadoErro
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Liga o [TrocarDeCasaViewModel] ao [ConteudoTrocarDeCasa]. */
@Composable
fun TelaTrocarDeCasa(
    viewModel: TrocarDeCasaViewModel,
    casaEmUsoId: String?,
    aoEscolher: (CasaDoMembro) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    ConteudoTrocarDeCasa(
        lista = estado,
        casaEmUsoId = casaEmUsoId,
        aoEscolher = aoEscolher,
        aoTentarNovamente = { viewModel.carregar() },
        aoVoltar = aoVoltar,
        modifier = modifier,
    )
}

/**
 * Trocar de casa: uma lista de escolha única com a casa em uso marcada. Tocar em outra casa a escolhe; tocar na que já
 * está em uso só volta. Sem animação: a escolha é imediata.
 */
@Composable
fun ConteudoTrocarDeCasa(
    lista: ListaDeCasas,
    casaEmUsoId: String?,
    aoEscolher: (CasaDoMembro) -> Unit,
    aoTentarNovamente: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltar) },
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
                TituloDaTela(TextosEquipeDaCasa.TROCAR_TITULO)
                Text(text = TextosEquipeDaCasa.TROCAR_EXPLICACAO, style = FrilaTipo.corpo, color = cores.tintaSuave)
            }
            when (lista) {
                ListaDeCasas.Carregando -> EstadoCarregando(mensagem = TextosEquipeDaCasa.TROCAR_CARREGANDO)
                ListaDeCasas.Erro -> EstadoErro(titulo = TextosEquipeDaCasa.TROCAR_FALHA, mensagem = null, aoTentarNovamente = aoTentarNovamente)
                is ListaDeCasas.Conteudo -> FrilaGrupoDeLinhas {
                    lista.casas.forEach { casa ->
                        linha {
                            FrilaLinhaDeOpcao(
                                titulo = casa.nome,
                                subtitulo = casa.papel?.let(::rotuloDoPapel),
                                marcada = casa.id == casaEmUsoId,
                                aoClicar = { if (casa.id == casaEmUsoId) aoVoltar() else aoEscolher(casa) },
                            )
                        }
                    }
                }
            }
        }
    }
}
