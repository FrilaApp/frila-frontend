package br.com.frila.app

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavHostController
import androidx.navigation.compose.currentBackStackEntryAsState
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

/**
 * A barra de abas, para o `bottomBar` da raiz do app. Trocar de aba troca a raiz da pilha (guardando e devolvendo o
 * estado de cada uma), então "voltar" numa raiz sai do app em vez de passear pelas abas já visitadas.
 */
@Composable
internal fun BarraDaRaiz(navController: NavHostController, papel: PapelDaRaiz?) {
    val entrada by navController.currentBackStackEntryAsState()
    val padraoAtual = entrada?.destination?.route ?: return
    val abas = abasDaRaiz(papel ?: papelPelaRota(padraoAtual) ?: return)
    val atual = abaDaRota(abas, padraoAtual) ?: return

    FrilaBarraDeAbas(
        abas = abas.map { AbaFrila(it.rotulo, it.icone) },
        selecionada = atual,
        aoSelecionar = { indice ->
            if (indice != atual) {
                navController.navigate(abas[indice].rota) {
                    popUpTo(padraoAtual) {
                        inclusive = true
                        saveState = true
                    }
                    launchSingleTop = true
                    restoreState = true
                }
            }
        },
    )
}
