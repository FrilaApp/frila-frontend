package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

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
 * Tela de bloqueio por atualização obrigatória (Cartão v1.2 / Paridade com `AtualizacaoObrigatoria.swift`).
 * Exibida quando a versão mínima exigida pela plataforma/backend é superior à versão instalada.
 */
@Composable
fun TelaAtualizacaoObrigatoria(
    aoAtualizar: () -> Unit,
    modifier: Modifier = Modifier,
    mensagem: String = TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(FrilaEspacamento.grande),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grande),
        ) {
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .background(MaterialTheme.colorScheme.primaryContainer, shape = CircleShape)
                    .clearAndSetSemantics { },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                    modifier = Modifier.size(40.dp),
                )
            }

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
            ) {
                Text(
                    text = TextosAtualizacaoObrigatoria.TITULO,
                    style = MaterialTheme.typography.titleLarge,
                    color = MaterialTheme.colorScheme.onBackground,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.semantics { heading() },
                )
                Text(
                    text = mensagem,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }

            BotaoPrimario(
                texto = TextosAtualizacaoObrigatoria.BOTAO_ATUALIZAR,
                aoClicar = aoAtualizar,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = FrilaEspacamento.medio),
            )
        }
    }
}
