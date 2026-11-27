package br.com.frila.feature.vagas.feed

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento

/** Se o aparelho entrega as notificações do Frila (o aviso de Vagas, como o `PermissaoDePushModelo.estado` do iOS). */
enum class PermissaoDeNotificacao { CONCEDIDA, NAO_PEDIDA, NEGADA }

/**
 * Os textos do aviso, os do iOS (`TextosDoPush.Aviso` e `TextosDoPush.Explicacao.ativar`), na versão do profissional. No iOS
 * estão marcados como provisórios.
 */
object TextosAvisoDeNotificacoes {
    const val NEGADA =
        "As notificações estão desativadas. Você não recebe o aviso de vaga nova nem os lembretes dos seus turnos."
    const val NAO_PEDIDA = "Ative as notificações para saber de uma vaga nova na hora."
    const val ABRIR_AJUSTES = "Abrir Ajustes"
    const val ATIVAR = "Ativar notificações"

    const val TAG_NEGADA = "aviso-push-negado"
    const val TAG_NAO_PEDIDA = "aviso-push-nao-pedido"
}

/**
 * O estado de agora. As notificações ligadas valem como concedida. Desligadas no Android 13+ sem a permissão
 * `POST_NOTIFICATIONS` contam como não pedida: o Android não diz se ela nunca foi pedida ou se foi negada de vez, e o primeiro
 * toque tenta o pedido do sistema. Desligadas com a permissão dada (ou antes do Android 13), só os Ajustes ligam de novo.
 */
fun lerPermissaoDeNotificacao(contexto: Context): PermissaoDeNotificacao = when {
    NotificationManagerCompat.from(contexto).areNotificationsEnabled() -> PermissaoDeNotificacao.CONCEDIDA
    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        ContextCompat.checkSelfPermission(contexto, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED ->
        PermissaoDeNotificacao.NAO_PEDIDA
    else -> PermissaoDeNotificacao.NEGADA
}

/**
 * O aviso fixo no alto de Vagas para quem está sem notificação (paridade com `AvisoDePermissaoDePush` do iOS). Negada: o
 * caminho é pelos Ajustes. Não pedida: "Ativar notificações" faz o pedido do sistema, e uma recusa ali passa o aviso para os
 * Ajustes. Concedida: não ocupa espaço. O estado é relido quando a tela volta (a pessoa pode ter mudado nos Ajustes).
 */
@Composable
fun AvisoDeNotificacoesDesligadas(
    aoAbrirAjustes: () -> Unit,
    modifier: Modifier = Modifier,
    lerPermissao: (Context) -> PermissaoDeNotificacao = ::lerPermissaoDeNotificacao,
) {
    val contexto = LocalContext.current
    var leitura by remember { mutableIntStateOf(0) }
    LifecycleResumeEffect(Unit) {
        leitura++
        onPauseOrDispose { }
    }
    var recusouAqui by rememberSaveable { mutableStateOf(false) }
    val lida = remember(leitura, recusouAqui) { lerPermissao(contexto) }
    val permissao = if (lida == PermissaoDeNotificacao.NAO_PEDIDA && recusouAqui) PermissaoDeNotificacao.NEGADA else lida
    val pedir = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { concedida ->
        if (!concedida) recusouAqui = true
        leitura++
    }

    when (permissao) {
        PermissaoDeNotificacao.CONCEDIDA -> Unit
        PermissaoDeNotificacao.NEGADA -> Aviso(
            mensagem = TextosAvisoDeNotificacoes.NEGADA,
            tom = TomAviso.ALERTA,
            botao = TextosAvisoDeNotificacoes.ABRIR_AJUSTES,
            aoTocar = aoAbrirAjustes,
            modifier = modifier.testTag(TextosAvisoDeNotificacoes.TAG_NEGADA),
        )
        PermissaoDeNotificacao.NAO_PEDIDA -> Aviso(
            mensagem = TextosAvisoDeNotificacoes.NAO_PEDIDA,
            tom = TomAviso.INFORMATIVO,
            botao = TextosAvisoDeNotificacoes.ATIVAR,
            aoTocar = { pedir.launch(Manifest.permission.POST_NOTIFICATIONS) },
            modifier = modifier.testTag(TextosAvisoDeNotificacoes.TAG_NAO_PEDIDA),
        )
    }
}

@Composable
private fun Aviso(mensagem: String, tom: TomAviso, botao: String, aoTocar: () -> Unit, modifier: Modifier) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        AvisoFrila(tom = tom, mensagem = mensagem)
        BotaoSecundario(texto = botao, aoClicar = aoTocar, modifier = Modifier.fillMaxWidth())
    }
}
