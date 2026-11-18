package br.com.frila.feature.vagas.detalhe

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.FrilaDivisoria
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Rodapé do detalhe da vaga (T3). Ainda não mora no design system: o `RodapeAncorado` não tem o estado "no fim".
 * Dois estados, ligados à rolagem. [noFim] falso (lendo): só o botão primário, de largura cheia, sobre o fundo.
 * [noFim] verdadeiro (o cartão inteiro já apareceu): barra em superfície com o fio de `bordaNav` em cima, o valor
 * (Prodigy 20) e o período embaixo à esquerda, e o mesmo botão à direita. Com a fonte do sistema grande (1,5x ou
 * mais), o valor sobe para cima do botão. A altura do botão é a mesma nos dois estados, para a rolagem não oscilar.
 *
 * [mensagem] é o que a ação disse (erro ou resultado), em [br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao],
 * logo acima do botão. O botão desligado é o "botão em conferência": no lugar, cinza, sem indicador girando.
 */
@Composable
fun RodapeDoDetalheDaVaga(
    valor: String,
    periodo: String,
    noFim: Boolean,
    textoDoBotao: String,
    aoClicar: () -> Unit,
    habilitado: Boolean,
    modifier: Modifier = Modifier,
    mensagem: (@Composable () -> Unit)? = null,
) {
    val cores = FrilaTema.cores
    val fonteGrande = LocalDensity.current.fontScale >= 1.5f

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(if (noFim) cores.superficie else cores.fundo)
            .navigationBarsPadding(),
    ) {
        if (noFim) FrilaDivisoria(cor = cores.bordaNav)
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    top = FrilaEspacamento.bloco,
                    bottom = FrilaEspacamento.item,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            mensagem?.invoke()
            val botao = @Composable { modificador: Modifier ->
                BotaoPrimario(texto = textoDoBotao, aoClicar = aoClicar, habilitado = habilitado, modifier = modificador)
            }
            when {
                !noFim -> botao(Modifier.fillMaxWidth())
                fonteGrande -> {
                    ValorEPeriodo(valor, periodo)
                    botao(Modifier.fillMaxWidth())
                }
                else -> Row(
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    ValorEPeriodo(valor, periodo)
                    botao(Modifier.weight(1f))
                }
            }
        }
    }
}

@Composable
private fun ValorEPeriodo(valor: String, periodo: String) {
    val cores = FrilaTema.cores
    Column(modifier = Modifier.clearAndSetSemantics { contentDescription = "$valor por $periodo" }) {
        Text(text = valor, style = FrilaTipo.valorDoRodape, color = cores.tinta)
        Text(text = periodo, style = FrilaTipo.apoio, color = cores.tintaSuave)
    }
}
