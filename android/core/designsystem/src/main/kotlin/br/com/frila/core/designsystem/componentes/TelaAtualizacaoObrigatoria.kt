package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Textos normativos em português brasileiro (guia de voz Frila). */
object TextosAtualizacaoObrigatoria {
    const val TITULO = "Atualização necessária"
    const val MENSAGEM_PADRAO = "Atualize o Frila para continuar."
    const val BOTAO_ATUALIZAR = "Atualizar agora"
}

/**
 * Utilitário de comparação semântica de versões no formato X.Y.Z.
 * Retorna true se a versão atual for estritamente menor que a versão mínima exigida.
 */
object ComparadorDeVersao {
    fun precisaAtualizar(versaoAtual: String, versaoMinima: String): Boolean {
        val partesAtual = normalizar(versaoAtual)
        val partesMinima = normalizar(versaoMinima)
        val maxLen = maxOf(partesAtual.size, partesMinima.size)

        for (i in 0 until maxLen) {
            val a = partesAtual.getOrElse(i) { 0 }
            val b = partesMinima.getOrElse(i) { 0 }
            if (a < b) return true
            if (a > b) return false
        }
        return false
    }

    private fun normalizar(versao: String): List<Int> {
        return versao.trim()
            .split(".")
            .map { pedaco ->
                pedaco.takeWhile { it.isDigit() }.toIntOrNull() ?: 0
            }
    }
}

/**
 * Tela de bloqueio por atualização obrigatória (paridade com `AtualizacaoObrigatoria.swift`).
 * Exibida quando a versão mínima exigida pela plataforma/backend é superior à versão instalada.
 *
 * No desenho do Fabrício é uma tela de entrada: o título e o motivo em cima, alinhados à margem, e a
 * única saída (o botão primário) ancorada embaixo. Sem ícone e sem outra ação: não há como seguir sem atualizar.
 */
@Composable
fun TelaAtualizacaoObrigatoria(
    aoAtualizar: () -> Unit,
    modifier: Modifier = Modifier,
    mensagem: String = TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
) {
    val cores = FrilaTema.cores

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(cores.fundo),
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    top = FrilaEspacamento.respiro,
                    bottom = FrilaEspacamento.grupo,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            TituloDaTela(TextosAtualizacaoObrigatoria.TITULO)
            Text(
                text = mensagem,
                style = FrilaTipo.corpo,
                color = cores.tintaSuave,
            )
        }

        RodapeAncorado {
            BotaoPrimario(
                texto = TextosAtualizacaoObrigatoria.BOTAO_ATUALIZAR,
                aoClicar = aoAtualizar,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}
