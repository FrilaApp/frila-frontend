package br.com.frila.feature.perfil

import android.content.ClipData
import android.content.Intent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.dominio.modelo.CodigoErroAPI

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
fun ItemExportarDados(viewModel: ExportarDadosViewModel) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val contexto = LocalContext.current
    val titulo = stringResource(R.string.exportar_dados_titulo)
    LaunchedEffect(estado.arquivo) {
        val arquivo = estado.arquivo ?: return@LaunchedEffect
        try {
            val uri = FileProvider.getUriForFile(contexto, "${contexto.packageName}.fileprovider", arquivo)
            val envio = Intent(Intent.ACTION_SEND).apply {
                type = "application/json"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(null, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            contexto.startActivity(Intent.createChooser(envio, titulo))
            viewModel.compartilhamentoAberto()
        } catch (_: Exception) {
            viewModel.falhouAoCompartilhar()
        }
    }
    ConteudoItemExportarDados(estado) { viewModel.exportar(contexto.cacheDir) }
}

@Composable
internal fun ConteudoItemExportarDados(estado: EstadoExportarDados, aoExportar: () -> Unit) {
    Column(Modifier.fillMaxWidth()) {
        TextButton(
            onClick = aoExportar,
            enabled = !estado.carregando && estado.arquivo == null,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).testTag("perfil-exportar-dados"),
        ) {
            Text(stringResource(R.string.exportar_dados_titulo))
        }
        Text(stringResource(R.string.exportar_dados_explicacao))
        if (estado.carregando) {
            Text(stringResource(R.string.historico_turnos_gerando), Modifier.semantics { liveRegion = LiveRegionMode.Polite })
        }
        estado.erro?.let { erro ->
            val recurso = when (erro) {
                CodigoErroAPI.NAO_AUTENTICADO -> R.string.exportar_dados_sessao_expirada
                CodigoErroAPI.NAO_ENCONTRADO -> R.string.exportar_dados_nao_encontrado
                CodigoErroAPI.SEM_REDE -> R.string.por_que_recebo_vagas_erro_sem_rede
                else -> R.string.exportar_dados_erro
            }
            Text(stringResource(recurso), Modifier.semantics { liveRegion = LiveRegionMode.Assertive })
        }
    }
}
