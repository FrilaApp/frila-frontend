package br.com.frila.app

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavController
import androidx.navigation.NavHostController
import br.com.frila.core.designsystem.componentes.AbaFrila
import br.com.frila.core.designsystem.componentes.FrilaBarraDeAbas
import br.com.frila.core.designsystem.componentes.IconeMaleta
import br.com.frila.feature.vagas.candidaturas.TextosCandidaturas

// Abas das telas raiz, como no iOS (`FluxoDoProfissional.swift` e `FluxoDoContratante.swift`): o profissional tem Vagas, Meus
// turnos, Candidaturas e Conta; a casa tem Minhas vagas e Conta. Só as raízes têm barra: tela aberta por cima a esconde.

/** Quem está usando o app, para saber que abas mostrar. */
internal sealed interface PapelDaRaiz {
    data object Profissional : PapelDaRaiz

    /** A casa em uso. `rotaDeMinhasVagas` já vem montada por [Rotas.minhasVagas], com o id e o nome da casa. */
    data class Contratante(val rotaDeMinhasVagas: String) : PapelDaRaiz
}

/** Uma aba: o rótulo, o ícone, o padrão da rota (o que o grafo conhece) e a rota para onde o toque leva. */
internal data class AbaDaRaiz(val rotulo: String, val icone: ImageVector, val padrao: String, val rota: String = padrao)

internal object TextosDasAbas {
    const val VAGAS = "Vagas"
    const val MEUS_TURNOS = "Meus turnos"
    const val MINHAS_VAGAS = "Minhas vagas"
    const val CONTA = "Conta"
}

internal fun abasDaRaiz(papel: PapelDaRaiz): List<AbaDaRaiz> = when (papel) {
    PapelDaRaiz.Profissional -> listOf(
        AbaDaRaiz(TextosDasAbas.VAGAS, IconeMaleta, Rotas.FEED),
        AbaDaRaiz(TextosDasAbas.MEUS_TURNOS, Icons.Default.DateRange, Rotas.MEUS_TURNOS),
        AbaDaRaiz(TextosCandidaturas.TITULO, Icons.AutoMirrored.Filled.Send, Rotas.MINHAS_CANDIDATURAS),
        AbaDaRaiz(TextosDasAbas.CONTA, Icons.Default.AccountCircle, Rotas.PERFIL),
    )
    is PapelDaRaiz.Contratante -> listOf(
        AbaDaRaiz(TextosDasAbas.MINHAS_VAGAS, IconeMaleta, Rotas.MINHAS_VAGAS, rota = papel.rotaDeMinhasVagas),
        AbaDaRaiz(TextosDasAbas.CONTA, Icons.Default.AccountCircle, Rotas.PERFIL),
    )
}

/** A aba da tela em que a pessoa está, pelo padrão da rota do destino; nulo fora das telas raiz (a barra some). */
internal fun abaDaRota(abas: List<AbaDaRaiz>, padraoAtual: String?): Int? =
    abas.indexOfFirst { it.padrao == padraoAtual }.takeIf { it >= 0 }

/** O papel quando só a rota diz quem é (link que cai direto numa raiz, sem passar pela abertura). O Perfil não diz. */
internal fun papelPelaRota(padraoAtual: String?): PapelDaRaiz? = when (padraoAtual) {
    Rotas.FEED, Rotas.MEUS_TURNOS, Rotas.MINHAS_CANDIDATURAS -> PapelDaRaiz.Profissional
    else -> null
}

/** Guarda o papel entre recriações da tela (girar o aparelho, voltar do segundo plano). */
internal val SalvadorDoPapelDaRaiz: Saver<PapelDaRaiz?, String> = Saver(
    save = { papel ->
        when (papel) {
            null -> ""
            PapelDaRaiz.Profissional -> "profissional"
            is PapelDaRaiz.Contratante -> "casa:" + papel.rotaDeMinhasVagas
        }
    },
    restore = { texto ->
        when {
            texto == "profissional" -> PapelDaRaiz.Profissional
            texto.startsWith("casa:") -> PapelDaRaiz.Contratante(texto.removePrefix("casa:"))
            else -> null
        }
    },
)

/**
 * O padrão da rota do topo da pilha, lido do próprio controlador a cada mudança. Não usa o destino que o aviso de
 * mudança traz: quando um guarda redireciona de dentro de outro aviso (o do desbloqueio faz isso), os avisos chegam
 * fora de ordem e o último a chegar é o da tela que NÃO ficou; a barra de abas apareceria por cima do desbloqueio.
 */
@Composable
internal fun padraoDoTopoDaPilha(navController: NavHostController): String? {
    var padrao by remember(navController) { mutableStateOf(navController.currentDestination?.route) }
    DisposableEffect(navController) {
        val aoMudar = NavController.OnDestinationChangedListener { controlador, _, _ -> padrao = controlador.currentDestination?.route }
        navController.addOnDestinationChangedListener(aoMudar)
        onDispose { navController.removeOnDestinationChangedListener(aoMudar) }
    }
    return padrao
}

/** Há barra de abas nesta tela? Só nas raízes do papel; quem desenha a tela usa isto para não recuar duas vezes embaixo. */
internal fun temBarraDaRaiz(papel: PapelDaRaiz?, padraoAtual: String?): Boolean {
    val abas = abasDaRaiz(papel ?: papelPelaRota(padraoAtual) ?: return false)
    return abaDaRota(abas, padraoAtual) != null
}

/**
 * A barra de abas da raiz do app. A primeira aba é o chão da pilha: trocar de aba volta até ela e abre a escolhida
 * por cima, então "voltar" numa outra aba leva à primeira, e "voltar" na primeira sai do app. Se a primeira aba não está na pilha (link que abriu direto noutra raiz), a aba atual é que dá lugar.
 */
@Composable
internal fun BarraDaRaiz(navController: NavHostController, papel: PapelDaRaiz?, padraoAtual: String?) {
    if (padraoAtual == null) return
    val abas = abasDaRaiz(papel ?: papelPelaRota(padraoAtual) ?: return)
    val atual = abaDaRota(abas, padraoAtual) ?: return

    FrilaBarraDeAbas(
        abas = abas.map { AbaFrila(it.rotulo, it.icone) },
        selecionada = atual,
        aoSelecionar = { indice ->
            if (indice != atual) {
                val chao = abas.first().padrao
                val chaoNaPilha = runCatching { navController.getBackStackEntry(chao) }.isSuccess
                // Sem guardar o estado da aba que sai (`saveState`/`restoreState`): o estado guardado sobrevive à saída da
                // conta e reapareceria para a conta seguinte. Cada aba abre de novo e recarrega do servidor.
                navController.navigate(abas[indice].rota) {
                    if (chaoNaPilha) popUpTo(chao) else popUpTo(padraoAtual) { inclusive = true }
                    launchSingleTop = true
                }
            }
        },
    )
}
