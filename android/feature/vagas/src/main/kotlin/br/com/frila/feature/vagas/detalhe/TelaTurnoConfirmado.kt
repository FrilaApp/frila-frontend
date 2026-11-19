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
import androidx.compose.material.icons.filled.Person
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
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.FrilaBarraDeTopo
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeDado
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.feature.vagas.R
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val FUSO_BRASILIA = ZoneId.of("America/Sao_Paulo")
private val PT_BR = Locale.forLanguageTag("pt-BR")
private val FORMATO_DATA = DateTimeFormatter.ofPattern("EEEE, d 'de' MMMM 'de' yyyy", PT_BR)
private val FORMATO_HORA = DateTimeFormatter.ofPattern("HH:mm", PT_BR)

/**
 * Tela de Turno Confirmado (Item #6 da Paridade / US04 / `TelaResultadoDaCandidatura` do iOS).
 * Exibida imediatamente após a confirmação da candidatura em vaga de urgência.
 * Apresenta o resumo do turno e atalhos para Meus Turnos e para o Feed.
 */
@Composable
fun TelaTurnoConfirmado(
    vaga: VagaAbertaDto,
    aoVerMeusTurnos: () -> Unit,
    aoVoltarAoFeed: () -> Unit,
    modifier: Modifier = Modifier,
    quemRecebe: String? = null,
) {
    val inicio = try {
        Instant.parse(vaga.inicioEm).atZone(FUSO_BRASILIA)
    } catch (_: Exception) {
        Instant.now().atZone(FUSO_BRASILIA)
    }
    val fim = try {
        Instant.parse(vaga.fimEm).atZone(FUSO_BRASILIA)
    } catch (_: Exception) {
        inicio.plusHours(6)
    }
    val duracao = Duration.between(inicio, fim)
    val horas = duracao.toHours()
    val minutos = duracao.toMinutes() % 60
    val textoDuracao = if (minutos == 0L) "${horas} h" else "${horas} h ${minutos} min"
    val dataExtenso = FORMATO_DATA.format(inicio.toLocalDate()).replaceFirstChar { it.titlecase(PT_BR) }
    val periodoTexto = "$dataExtenso\ndas ${FORMATO_HORA.format(inicio)} às ${FORMATO_HORA.format(fim)}"

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = FrilaTema.cores.fundo,
        topBar = { FrilaBarraDeTopo(aoVoltar = aoVoltarAoFeed) },
        bottomBar = {
            RodapeAncorado {
                BotaoPrimario(
                    texto = stringResource(R.string.turno_confirmado_ver_turnos),
                    aoClicar = aoVerMeusTurnos,
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("botao-ver-meus-turnos"),
                )
                BotaoSecundario(
                    texto = stringResource(R.string.turno_confirmado_ver_outras_vagas),
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
                texto = stringResource(R.string.turno_confirmado_titulo),
                modifier = Modifier
                    .semantics { heading() }
                    .testTag("resultado-confirmada"),
            )

            CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    Text(
                        text = "${vaga.funcao.nome}, ${vaga.estabelecimento.nome}",
                        style = FrilaTipo.nome,
                        color = FrilaTema.cores.tinta,
                    )
                    FrilaLinhaDeDado(
                        icone = Icons.Default.DateRange,
                        valor = periodoTexto,
                        qualificador = "($textoDuracao de turno)",
                    )
                    FrilaLinhaDeDado(
                        icone = Icons.Default.Place,
                        valor = "${vaga.local}, ${vaga.regiaoAdministrativa}",
                    )
                    FrilaLinhaDeDado(
                        icone = Icons.Default.Person,
                        valor = stringResource(
                            R.string.turno_confirmado_quem_recebe,
                            quemRecebe?.takeIf { it.isNotBlank() } ?: vaga.estabelecimento.nome,
                        ),
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
