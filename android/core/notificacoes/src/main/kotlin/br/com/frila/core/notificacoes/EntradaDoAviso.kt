package br.com.frila.core.notificacoes

import android.app.Activity
import android.os.Bundle
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * O toque num push que ainda não foi atendido: o link `frila://aviso` que o [ResolvedorDeDeepLinkPush] montou. Só a
 * [EntradaDoAvisoActivity] escreve aqui, e ela não é exportada: outro app não põe aviso nenhum na fila.
 */
object CaixaDoAvisoDoToque {
    private val _link = MutableStateFlow<String?>(null)
    val link: StateFlow<String?> = _link.asStateFlow()

    internal fun entregar(link: String) {
        _link.value = link
    }

    /** O aviso foi atendido (ou descartado): o próximo toque é que vale. */
    fun consumir() {
        _link.value = null
    }
}

/**
 * Onde o toque na notificação entra (`android:exported="false"`): guarda o aviso na [CaixaDoAvisoDoToque] e abre o
 * app como o ícone abre, sem tela própria. A `MainActivity` é exportada, então um `frila://aviso` mandado direto a ela
 * por outro app não é aviso.
 */
class EntradaDoAvisoActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.dataString?.takeIf { it.startsWith(PREFIXO_DO_LINK) }?.let(CaixaDoAvisoDoToque::entregar)
        packageManager.getLaunchIntentForPackage(packageName)?.let(::startActivity)
        finish()
    }

    companion object {
        internal const val PREFIXO_DO_LINK = "frila://aviso?"
    }
}
