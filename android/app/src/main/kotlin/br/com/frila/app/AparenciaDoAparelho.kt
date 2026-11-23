package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.feature.perfil.TelaAparencia
import java.io.IOException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

@Composable
internal fun TemaDoAparelho(temaEscuro: Flow<Boolean>, conteudo: @Composable () -> Unit) {
    val escuro by temaEscuro.collectAsStateWithLifecycle(initialValue = false)
    FrilaTheme(temaEscuro = escuro, content = conteudo)
}

@Composable
internal fun AparenciaDoAparelho(preferencias: PreferenciasAparencia, aoVoltar: () -> Unit) {
    val escuro by preferencias.temaEscuro.collectAsStateWithLifecycle(initialValue = false)
    val escopo = rememberCoroutineScope()
    var salvando by remember { mutableStateOf(false) }
    var falhou by remember { mutableStateOf(false) }
    TelaAparencia(
        temaEscuro = escuro,
        salvando = salvando,
        falhou = falhou,
        aoVoltar = aoVoltar,
        aoEscolher = { escolha ->
            escopo.launch {
                salvando = true
                falhou = false
                try {
                    withTimeout(2_000) { preferencias.escolher(escolha) }
                } catch (_: TimeoutCancellationException) {
                    falhou = true
                } catch (_: IOException) {
                    falhou = true
                } finally {
                    salvando = false
                }
            }
        },
    )
}
