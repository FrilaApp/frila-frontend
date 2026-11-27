package br.com.frila.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria

/**
 * Abre a página do app na loja (`market://`) e, sem loja, no navegador. Devolve `null` quando um dos dois abriu, ou o aviso com o
 * endereço da loja para copiar quando nenhum abriu. Os dois passam por [abrirExterno]: antes o segundo `startActivity` ficava sem
 * proteção dentro do `catch` do primeiro e, num aparelho sem loja e sem navegador, derrubava o app na tela que impede o uso.
 */
internal fun abrirLojaDoApp(contexto: Context, pacote: String): AvisoDeAberturaExterna? {
    val loja = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pacote")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
    if (abrirExterno(contexto, loja)) return null
    val enderecoNaWeb = "https://play.google.com/store/apps/details?id=$pacote"
    val navegador = Intent(Intent.ACTION_VIEW, Uri.parse(enderecoNaWeb)).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
    return if (abrirExterno(contexto, navegador)) null else AvisoDeAberturaExterna.semLojaNemNavegador(enderecoNaWeb)
}

/** O portão de versão com o botão "Atualizar" ligado à loja; sem loja nem navegador, o aviso mostra o endereço para copiar. */
@Composable
internal fun PortaoDeAtualizacaoDaLoja(
    versaoAtual: String,
    versaoMinima: String?,
    verificando: Boolean,
    mensagem: String = TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO,
    pacote: String,
    contexto: Context = LocalContext.current,
    conteudo: @Composable () -> Unit,
) {
    var aviso by rememberSaveable(stateSaver = AvisoDeAberturaExterna.Salvador) { mutableStateOf<AvisoDeAberturaExterna?>(null) }
    PortaoDeAtualizacao(
        versaoAtual = versaoAtual,
        versaoMinima = versaoMinima,
        verificando = verificando,
        mensagem = mensagem,
        aoAtualizar = { aviso = abrirLojaDoApp(contexto, pacote) },
        conteudo = conteudo,
    )
    aviso?.let { DialogoDeAberturaExterna(aviso = it, aoFechar = { aviso = null }) }
}
