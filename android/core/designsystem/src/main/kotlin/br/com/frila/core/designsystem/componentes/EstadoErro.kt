package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Erro de tela inteira ou de seção (RNF10), no desenho do Fabrício: o que falhou e o que fazer, em
 * tinta, sem vermelho e sem ícone de alerta (problema não tem cor). Tentar de novo é botão
 * SECUNDÁRIO: o laranja fica para a ação que avança ou compromete, e uma tela de erro não é isso.
 */
@Composable
fun EstadoErro(
    modifier: Modifier = Modifier,
    titulo: String = "Algo deu errado",
    mensagem: String? = "Não foi possível carregar as informações. Verifique sua conexão e tente novamente.",
    textoBotao: String = "Tentar novamente",
    aoTentarNovamente: (() -> Unit)? = null,
) {
    val cores = FrilaTema.cores
    // Mensagem vazia ou em branco não aparece na tela (mais abaixo), então também não é o que se anuncia: cai no título.
    val descricaoErro = mensagem?.takeIf { it.isNotBlank() } ?: titulo

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = FrilaEspacamento.grupo,
                end = FrilaEspacamento.grupo,
                top = FrilaEspacamento.respiro,
                bottom = FrilaEspacamento.grupo,
            )
            .semantics { error(descricaoErro) },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item, Alignment.CenterVertically),
    ) {
        Text(
            text = titulo,
            style = FrilaTipo.corpo,
            color = cores.tinta,
            textAlign = TextAlign.Center,
            modifier = Modifier.semantics { heading() },
        )
        if (!mensagem.isNullOrBlank()) {
            Text(
                text = mensagem,
                style = FrilaTipo.apoio,
                color = cores.tintaSuave,
                textAlign = TextAlign.Center,
            )
        }
        if (aoTentarNovamente != null) {
            BotaoSecundario(
                texto = textoBotao,
                aoClicar = aoTentarNovamente,
                modifier = Modifier.padding(top = FrilaEspacamento.item),
            )
        }
    }
}
