package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.dominio.regra.instanteDoServidor

/**
 * Enviada a chamada, a tela mostra o que foi combinado, até quando o profissional responde e o caminho para
 * acompanhar (desenho do iOS `ResumoDaChamadaEnviada`, V11). Sem [aoAcompanhar] o link não aparece.
 */
@Composable
internal fun ResumoDaChamadaEnviada(
    tela: EstadoChamadaDireta,
    aoAcompanhar: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val chamada = tela.resultado ?: return
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
        AvisoFrila(tom = TomAviso.SUCESSO, mensagem = TextosChamadaCasa.SUCESSO)
        runCatching { instanteDoServidor(chamada.expiraEm) }.getOrNull()?.let { expira ->
            Text(
                text = TextosChamadaCasa.prazoDeResposta(dataEHora(expira)),
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tinta,
            )
        }
        RotuloDeGrupo(TextosChamadaCasa.RESUMO_DA_CHAMADA)
        CartaoFrila(modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                Linha(TextosChamadaCasa.VALOR_TOTAL, dinheiro(tela.valorCentavos), destaque = true)
                Linha(TextosChamadaCasa.HORARIO, TextosChamadaCasa.intervalo(dataEHora(tela.inicio), hora(tela.fim)))
                Linha(TextosChamadaCasa.RESPONSAVEL, tela.responsavel.trim())
            }
        }
        if (aoAcompanhar != null) {
            LinkFrila(texto = TextosChamadaCasa.ACOMPANHAR_TITULO, aoClicar = aoAcompanhar)
        }
    }
}

@Composable
private fun Linha(rotulo: String, valor: String, destaque: Boolean = false) {
    Column(
        modifier = Modifier.fillMaxWidth().semantics(mergeDescendants = true) { },
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
    ) {
        Text(rotulo, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
        Text(
            valor,
            style = if (destaque) FrilaTipo.valorEmDestaque else FrilaTipo.corpo,
            color = FrilaTema.cores.tinta,
        )
    }
}
