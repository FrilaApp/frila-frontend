// TELA PROVISÓRIA (sistema do Fabrício): ele revê depois
package br.com.frila.feature.vagas.detalhe

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.feature.vagas.R


/**
 * Tela de Conflito de Horário (Item #9 da Paridade / `TelaResultadoDaCandidatura(resultado: .inelegivel(.turnoSobreposto))` do iOS).
 * Exibida quando a candidatura é recusada com 422 inelegível (turno_sobreposto).
 * Apresenta a explicação do conflito, os dados da vaga original e o botão de retorno ao feed.
 */
@Composable
fun TelaConflitoHorario(
    vaga: VagaAbertaDto,
    aoVoltarAoFeed: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val periodo = periodoDoResultado(vaga)

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltarAoFeed) },
        bottomBar = {
            RodapeAncorado {
                BotaoPrimario(
                    texto = stringResource(R.string.conflito_horario_ver_outras_vagas),
                    aoClicar = aoVoltarAoFeed,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("voltar-para-lista"),
                )
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
                texto = stringResource(R.string.conflito_horario_titulo),
                modifier = Modifier
                    .semantics { heading() }
                    .testTag("resultado-turno-sobreposto"),
            )

            Text(
                text = stringResource(R.string.conflito_horario_mensagem),
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tintaSuave,
            )

            RotuloDeGrupo(texto = stringResource(R.string.conflito_horario_vaga_original))

            CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    Text(
                        text = "${vaga.funcao.nome}, ${vaga.estabelecimento.nome}",
                        style = FrilaTipo.nome,
                        color = FrilaTema.cores.tinta,
                    )
                    // Sem período de verdade (data ilegível, fim que não vem depois do início), a linha some: nada de horário inventado.
                    periodo?.let {
                        FrilaLinhaDeDado(
                            icone = Icons.Default.DateRange,
                            valor = it.periodo,
                            qualificador = "(${it.duracao} de turno)",
                        )
                    }
                    FrilaLinhaDeDado(
                        icone = Icons.Default.Place,
                        valor = "${vaga.local}, ${vaga.regiaoAdministrativa}",
                    )
                    Text(
                        text = Dinheiro(vaga.valorCentavos).formatado(),
                        style = FrilaTipo.valorEmDestaque,
                        color = FrilaTema.cores.tinta,
                        modifier = Modifier.padding(top = FrilaEspacamento.item),
                    )
                }
            }
        }
    }
}
