package br.com.frila.feature.perfil

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.EstadoCarregando
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * A tela da foto de perfil (L1-3b), só o envio: escolher, aviso de "sem rosto" com "Enviar mesmo assim" ou "Escolher outra foto", andamento e resultado.
 * Com a foto recusada ou não publicada, mostra o estado e oferece "Tentar outra foto" e "Pedir nova análise". Ver a foto aprovada e remover vêm depois. Textos do iOS em [TextosDaFotoDePerfil].
 *
 * A ação que segue fica no rodapé ancorado: o único primário da tela, com a mensagem de uma falha logo acima dele.
 * [aoVoltar] é opcional: a rota que não o informa fica só com o voltar do sistema.
 */
@Composable
fun TelaFotoDePerfil(
    etapa: EtapaDaFoto,
    aoEscolherFoto: () -> Unit,
    aoEnviarMesmoAssim: () -> Unit,
    aoEscolherOutra: () -> Unit,
    aoTentarDeNovo: () -> Unit,
    aoVoltar: (() -> Unit)? = null,
    situacao: SituacaoDaFoto = SituacaoDaFoto(),
    aoPedirNovaAnalise: () -> Unit = {},
) {
    val cores = FrilaTema.cores
    Scaffold(
        containerColor = cores.fundo,
        topBar = { if (aoVoltar != null) BarraDeTopoDoPerfil(aoVoltar = aoVoltar) },
        bottomBar = {
            when (etapa) {
                EtapaDaFoto.Parada -> when (situacao.midia?.estado) {
                    "recusada", "nao_publicada" -> RodapeAncorado {
                        situacao.aviso?.let { MensagemJuntoAoBotao(it) }
                        BotaoPrimario(TextosDaFotoDePerfil.TENTAR_OUTRA_FOTO, aoEscolherFoto, Modifier.fillMaxWidth())
                        if (situacao.podePedirNovaAnalise) {
                            BotaoSecundario(TextosDaFotoDePerfil.PEDIR_NOVA_ANALISE, aoPedirNovaAnalise, Modifier.fillMaxWidth())
                        }
                    }
                    // A nova análise já pedida: nada a fazer além de esperar, como depois de enviar.
                    "em_analise" -> Unit
                    else -> RodapeAncorado {
                        BotaoPrimario(TextosDaFotoDePerfil.ESCOLHER_FOTO, aoEscolherFoto, Modifier.fillMaxWidth())
                    }
                }
                EtapaDaFoto.AvisoSemRosto -> RodapeAncorado {
                    BotaoPrimario(TextosDaFotoDePerfil.ENVIAR_MESMO_ASSIM, aoEnviarMesmoAssim, Modifier.fillMaxWidth())
                    BotaoSecundario(TextosDaFotoDePerfil.ESCOLHER_OUTRA_FOTO, aoEscolherOutra, Modifier.fillMaxWidth())
                }
                is EtapaDaFoto.Bloqueada -> RodapeAncorado {
                    BotaoPrimario(TextosDaFotoDePerfil.TENTAR_OUTRA_FOTO, aoEscolherOutra, Modifier.fillMaxWidth())
                }
                is EtapaDaFoto.Falhou -> RodapeAncorado {
                    MensagemJuntoAoBotao(etapa.mensagem)
                    BotaoPrimario(TextosDaFotoDePerfil.TENTAR_DE_NOVO, aoTentarDeNovo, Modifier.fillMaxWidth())
                    BotaoSecundario(TextosDaFotoDePerfil.ESCOLHER_OUTRA_FOTO, aoEscolherOutra, Modifier.fillMaxWidth())
                }
                EtapaDaFoto.Preparando, EtapaDaFoto.Enviando, is EtapaDaFoto.Enviada -> Unit
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo, vertical = FrilaEspacamento.item),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            TituloDaTela(TextosDaFotoDePerfil.TITULO)
            when (etapa) {
                EtapaDaFoto.Parada -> when (situacao.midia?.estado) {
                    "recusada", "nao_publicada" -> {
                        Text(
                            TextosDaFotoDePerfil.TITULO_NAO_PUBLICADA,
                            style = FrilaTipo.nome,
                            color = cores.tinta,
                            modifier = Modifier.semantics { heading() },
                        )
                        Corpo(
                            when {
                                situacao.novaAnaliseJaPedida -> TextosDaFotoDePerfil.TEXTO_NOVA_ANALISE_JA_PEDIDA
                                situacao.midia?.estado == "nao_publicada" -> TextosDaFotoDePerfil.TEXTO_NAO_PUBLICADA
                                else -> TextosDaFotoDePerfil.motivoDaRecusa(situacao.midia?.motivoRecusa)
                            },
                        )
                    }
                    "em_analise" -> {
                        Text(
                            TextosDaFotoDePerfil.TITULO_EM_ANALISE,
                            style = FrilaTipo.nome,
                            color = cores.tinta,
                            modifier = Modifier.semantics { heading() },
                        )
                        Corpo(TextosDaFotoDePerfil.TEXTO_EM_ANALISE)
                    }
                    else -> Corpo(TextosDaFotoDePerfil.EXPLICACAO)
                }
                EtapaDaFoto.Preparando -> EstadoCarregando(mensagem = TextosDaFotoDePerfil.PREPARANDO)
                EtapaDaFoto.Enviando -> EstadoCarregando(mensagem = TextosDaFotoDePerfil.ENVIANDO)
                EtapaDaFoto.AvisoSemRosto -> Corpo(TextosDaFotoDePerfil.AVISO_SEM_ROSTO)
                is EtapaDaFoto.Bloqueada -> Corpo(TextosDaFotoDePerfil.bloqueio(etapa.motivo))
                is EtapaDaFoto.Enviada -> {
                    Text(
                        TextosDaFotoDePerfil.TITULO_EM_ANALISE,
                        style = FrilaTipo.nome,
                        color = cores.tinta,
                        modifier = Modifier.semantics { heading() },
                    )
                    Corpo(TextosDaFotoDePerfil.TEXTO_EM_ANALISE)
                }
                // A mensagem da falha vai no rodapé, junto ao botão que tenta de novo.
                is EtapaDaFoto.Falhou -> Unit
            }
        }
    }
}

@Composable
private fun Corpo(texto: String) {
    Text(texto, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta, modifier = Modifier.fillMaxWidth())
}

/** Liga a tela ao [FotoDePerfilViewModel] e ao seletor de fotos do sistema (nenhuma permissão: o seletor só entrega a foto escolhida). A fiação é do L1-7. */
@Composable
fun TelaFotoDePerfilConectada(viewModel: FotoDePerfilViewModel, aoVoltar: (() -> Unit)? = null) {
    val etapa by viewModel.etapa.collectAsState()
    val situacao by viewModel.situacao.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    val seletor = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) viewModel.escolher(uri.toString())
    }
    TelaFotoDePerfil(
        etapa = etapa,
        aoEscolherFoto = { seletor.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
        aoEnviarMesmoAssim = viewModel::enviarMesmoAssim,
        aoEscolherOutra = viewModel::escolherOutra,
        aoTentarDeNovo = viewModel::tentarDeNovo,
        aoVoltar = aoVoltar,
        situacao = situacao,
        aoPedirNovaAnalise = viewModel::pedirNovaAnalise,
    )
}
