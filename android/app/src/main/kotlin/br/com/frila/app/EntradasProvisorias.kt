package br.com.frila.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

// L2-8: onde cada tela do Lote 2 do Android entra no app. As telas do Lote 2 são PROVISÓRIAS e as telas que já existem (Perfil, Feed) não têm
// lugar para elas, então a entrada é uma linha de texto sob a tela, montada aqui. Os rótulos são os títulos das próprias telas (nenhum texto
// novo). Candidaturas já virou aba da raiz (`AbasDaRaiz.kt`). Onde o iOS põe as outras: "Pessoas e locais bloqueados" fica em
// "Conta e dados" do Perfil, para os dois papéis; "Contestar" fica dentro de "Por que recebo vagas" (que o Android só terá no Lote 3), no Perfil do profissional.

internal const val ENTRADA_BLOQUEIOS = "entrada-bloqueios"
internal const val ENTRADA_CONTESTAR_DESPACHO = "entrada-contestar-despacho"

internal class EntradaProvisoria(val tag: String, val rotulo: String, val aoTocar: () -> Unit)

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** A tela de sempre, com as linhas de entrada embaixo. Sem entradas, a tela fica como era. */
@Composable
internal fun ComEntradasProvisorias(entradas: List<EntradaProvisoria>, conteudo: @Composable () -> Unit) {
    if (entradas.isEmpty()) {
        conteudo()
        return
    }
    Column(Modifier.fillMaxSize()) {
        Box(Modifier.weight(1f)) { conteudo() }
        entradas.forEach { entrada ->
            TextButton(
                onClick = entrada.aoTocar,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag(entrada.tag),
            ) {
                Text(entrada.rotulo)
            }
        }
    }
}
