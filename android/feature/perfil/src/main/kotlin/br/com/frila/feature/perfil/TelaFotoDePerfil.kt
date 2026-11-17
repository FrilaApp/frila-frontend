package br.com.frila.feature.perfil

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas

/**
 * A tela da foto de perfil (L1-3b), só o envio: escolher, aviso de "sem rosto" com "Enviar mesmo assim" ou "Escolher outra foto", andamento e resultado.
 * Ver a foto atual, remover e pedir nova análise vêm depois. Textos do iOS em [TextosDaFotoDePerfil].
 */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
fun TelaFotoDePerfil(
    etapa: EtapaDaFoto,
    aoEscolherFoto: () -> Unit,
    aoEnviarMesmoAssim: () -> Unit,
    aoEscolherOutra: () -> Unit,
    aoTentarDeNovo: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.medio),
    ) {
        Text(TextosDaFotoDePerfil.TITULO, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.semantics { heading() })
        when (etapa) {
            EtapaDaFoto.Parada -> {
                Text(TextosDaFotoDePerfil.EXPLICACAO, style = MaterialTheme.typography.bodyLarge)
                Botao(TextosDaFotoDePerfil.ESCOLHER_FOTO, destaque = true, aoClicar = aoEscolherFoto)
            }
            EtapaDaFoto.Preparando -> Andamento(TextosDaFotoDePerfil.PREPARANDO)
            EtapaDaFoto.Enviando -> Andamento(TextosDaFotoDePerfil.ENVIANDO)
            EtapaDaFoto.AvisoSemRosto -> {
                Text(TextosDaFotoDePerfil.AVISO_SEM_ROSTO, style = MaterialTheme.typography.bodyLarge)
                Botao(TextosDaFotoDePerfil.ENVIAR_MESMO_ASSIM, destaque = true, aoClicar = aoEnviarMesmoAssim)
                Botao(TextosDaFotoDePerfil.ESCOLHER_OUTRA_FOTO, destaque = false, aoClicar = aoEscolherOutra)
            }
            is EtapaDaFoto.Bloqueada -> {
                Text(TextosDaFotoDePerfil.bloqueio(etapa.motivo), style = MaterialTheme.typography.bodyLarge)
                Botao(TextosDaFotoDePerfil.TENTAR_OUTRA_FOTO, destaque = true, aoClicar = aoEscolherOutra)
            }
            is EtapaDaFoto.Enviada -> {
                Text(TextosDaFotoDePerfil.TITULO_EM_ANALISE, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                Text(TextosDaFotoDePerfil.TEXTO_EM_ANALISE, style = MaterialTheme.typography.bodyLarge)
            }
            is EtapaDaFoto.Falhou -> {
                Text(etapa.mensagem, style = MaterialTheme.typography.bodyLarge)
                Botao(TextosDaFotoDePerfil.TENTAR_DE_NOVO, destaque = true, aoClicar = aoTentarDeNovo)
                Botao(TextosDaFotoDePerfil.ESCOLHER_OUTRA_FOTO, destaque = false, aoClicar = aoEscolherOutra)
            }
        }
    }
}

@Composable
private fun Andamento(texto: String) {
    CircularProgressIndicator()
    Text(texto, style = MaterialTheme.typography.bodyLarge)
}

@Composable
private fun Botao(texto: String, destaque: Boolean, aoClicar: () -> Unit) {
    val modificador = Modifier.fillMaxWidth().sizeIn(minHeight = FrilaMetricas.alturaBotao)
    if (destaque) {
        Button(onClick = aoClicar, modifier = modificador) { Text(texto) }
    } else {
        OutlinedButton(onClick = aoClicar, modifier = modificador) { Text(texto) }
    }
}

/** Liga a tela ao [FotoDePerfilViewModel] e ao seletor de fotos do sistema (nenhuma permissão: o seletor só entrega a foto escolhida). A fiação é do L1-7. */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
fun TelaFotoDePerfilConectada(viewModel: FotoDePerfilViewModel) {
    val etapa by viewModel.etapa.collectAsState()
    val seletor = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) viewModel.escolher(uri.toString())
    }
    TelaFotoDePerfil(
        etapa = etapa,
        aoEscolherFoto = { seletor.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
        aoEnviarMesmoAssim = viewModel::enviarMesmoAssim,
        aoEscolherOutra = viewModel::escolherOutra,
        aoTentarDeNovo = viewModel::tentarDeNovo,
    )
}
