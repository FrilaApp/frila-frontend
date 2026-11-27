package br.com.frila.feature.vagas.detalhe

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
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Textos da recusa por função (paridade com `TextosDoProfissional.Candidatura` do iOS). */
internal object TextosFuncaoIncompativel {
    const val TITULO = "Função diferente"
    const val MENSAGEM = "Esta vaga exige uma função que não está cadastrada no seu perfil profissional."
    const val AJUSTAR_FUNCOES = "Ajustar minhas funções"
}

/**
 * Resultado da candidatura recusada com `422 inelegivel` (`funcao_incompativel`), como
 * `TelaResultadoDaCandidatura(resultado: .inelegivel(.funcaoIncompativel))` do iOS (`TelasDaCandidatura.swift:285-295`):
 * o primário leva a ajustar as funções, e a volta para a lista fica logo abaixo, em secundário.
 */
@Composable
fun TelaFuncaoIncompativel(
    aoAjustarFuncoes: () -> Unit,
    aoVoltarAoFeed: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltarAoFeed) },
        bottomBar = {
            RodapeAncorado {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    BotaoPrimario(
                        texto = TextosFuncaoIncompativel.AJUSTAR_FUNCOES,
                        aoClicar = aoAjustarFuncoes,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("ajustar-minhas-funcoes"),
                    )
                    BotaoSecundario(
                        texto = TextosVagaIndisponivel.BOTAO_VOLTAR_PADRAO,
                        aoClicar = aoVoltarAoFeed,
                        modifier = Modifier
                            .fillMaxWidth()
                            .testTag("voltar-para-lista"),
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
                .padding(horizontal = FrilaEspacamento.grupo)
                .padding(top = FrilaEspacamento.item, bottom = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(
                texto = TextosFuncaoIncompativel.TITULO,
                modifier = Modifier
                    .semantics { heading() }
                    .testTag("resultado-funcao-incompativel"),
            )
            Text(
                text = TextosFuncaoIncompativel.MENSAGEM,
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tintaSuave,
            )
        }
    }
}
