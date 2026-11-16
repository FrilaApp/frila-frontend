package br.com.frila.app

import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import br.com.frila.feature.chamadas.casa.AcompanharChamadasViewModel
import br.com.frila.feature.chamadas.casa.ChamadaDiretaViewModel
import br.com.frila.feature.chamadas.casa.PerfilPublicoViewModel
import br.com.frila.feature.chamadas.casa.TelaAcompanharChamadas
import br.com.frila.feature.chamadas.casa.TelaChamadaDireta
import br.com.frila.feature.chamadas.casa.TelaPerfilPublico
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/**
 * Destinos do lado da casa na chamada direta (perfil público, folha de chamar, acompanhar). Ficam num arquivo
 * próprio para o grafo principal só ganhar uma chamada. As rotas existem sempre; quem decide mostrar a entrada
 * é a chave `chamada_direta` (`chamadaDiretaHabilitada` em [AppNavegacao]), e a folha confere a chave de novo
 * ao carregar.
 */
internal object RotasChamadaCasa {
    const val PERFIL_PUBLICO = "chamada/perfil/{estabelecimentoId}/{profissionalId}"
    const val CHAMAR = "chamada/chamar/{estabelecimentoId}/{profissionalId}?regiaoId={regiaoId}"
    const val ACOMPANHAR = "chamada/acompanhar/{vagaId}"

    private const val SEM_REGIAO = -1

    fun perfilPublico(estabelecimentoId: String, profissionalId: String) =
        "chamada/perfil/${Uri.encode(estabelecimentoId)}/${Uri.encode(profissionalId)}"

    /** [regiaoId] é o da busca, quando a chamada nasce dela (0.2.88). */
    fun chamar(estabelecimentoId: String, profissionalId: String, regiaoId: Int? = null) =
        "chamada/chamar/${Uri.encode(estabelecimentoId)}/${Uri.encode(profissionalId)}" +
            (regiaoId?.let { "?regiaoId=$it" } ?: "")

    fun acompanhar(vagaId: String) = "chamada/acompanhar/${Uri.encode(vagaId)}"

    internal fun regiaoDaRota(valor: Int?): Int? = valor?.takeIf { it != SEM_REGIAO }

    internal val argumentoDeRegiao = navArgument("regiaoId") {
        type = NavType.IntType
        defaultValue = SEM_REGIAO
    }
}

internal fun NavGraphBuilder.rotasDaChamadaDiretaCasa(navController: NavHostController, guardaBiometrico: GuardaBiometrico) {
    composable(
        route = RotasChamadaCasa.PERFIL_PUBLICO,
        arguments = listOf(
            navArgument("estabelecimentoId") { type = NavType.StringType },
            navArgument("profissionalId") { type = NavType.StringType },
        ),
    ) { entrada ->
        RotaProtegida(guardaBiometrico) {
            val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
            val profissionalId = entrada.arguments?.getString("profissionalId").orEmpty()
            val viewModel: PerfilPublicoViewModel = koinViewModel(parameters = { parametersOf(profissionalId) })
            TelaPerfilPublico(
                viewModel = viewModel,
                aoVoltar = { navController.popBackStack() },
                aoChamar = { navController.navigate(RotasChamadaCasa.chamar(estabelecimentoId, it.id)) },
            )
        }
    }

    composable(
        route = RotasChamadaCasa.CHAMAR,
        arguments = listOf(
            navArgument("estabelecimentoId") { type = NavType.StringType },
            navArgument("profissionalId") { type = NavType.StringType },
            RotasChamadaCasa.argumentoDeRegiao,
        ),
    ) { entrada ->
        RotaProtegida(guardaBiometrico) {
            val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
            val profissionalId = entrada.arguments?.getString("profissionalId").orEmpty()
            val regiaoId = RotasChamadaCasa.regiaoDaRota(entrada.arguments?.getInt("regiaoId"))
            val viewModel: ChamadaDiretaViewModel = koinViewModel(
                parameters = { parametersOf(profissionalId, estabelecimentoId, regiaoId) },
            )
            TelaChamadaDireta(
                viewModel = viewModel,
                aoFechar = { navController.popBackStack() },
                aoAcompanhar = { vagaId -> navController.navigate(RotasChamadaCasa.acompanhar(vagaId)) },
            )
        }
    }

    composable(
        route = RotasChamadaCasa.ACOMPANHAR,
        arguments = listOf(navArgument("vagaId") { type = NavType.StringType }),
    ) { entrada ->
        RotaProtegida(guardaBiometrico) {
            val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
            val viewModel: AcompanharChamadasViewModel = koinViewModel(parameters = { parametersOf(vagaId) })
            TelaAcompanharChamadas(viewModel = viewModel, aoVoltar = { navController.popBackStack() })
        }
    }
}
