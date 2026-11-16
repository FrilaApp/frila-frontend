package br.com.frila.app

import android.net.Uri
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import br.com.frila.feature.chamadas.profissional.ChamadaRecebidaViewModel
import br.com.frila.feature.chamadas.profissional.EditarServicosViewModel
import br.com.frila.feature.chamadas.profissional.PreferenciasChamadaViewModel
import br.com.frila.feature.chamadas.profissional.TelaDetalheChamadaRecebida
import br.com.frila.feature.chamadas.profissional.TelaEditarServicos
import br.com.frila.feature.chamadas.profissional.TelaPreferenciasDeChamada
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/**
 * Destinos do lado do profissional na chamada direta (preferências, serviços com preço, chamada recebida). Num
 * arquivo próprio, como as rotas da casa: o grafo principal só ganha uma chamada. As rotas existem sempre; quem
 * decide mostrar a entrada é a chave `chamada_direta` (`chamadaDiretaHabilitada` em [AppNavegacao]) e, em cada tela,
 * o `403 recurso_desligado` do servidor (RN46). Ainda não há aviso de push da chamada no Android: a rota da chamada
 * recebida já aceita o link `frila://chamadas/{chamadaId}` para o roteamento do push ligar depois.
 */
internal object RotasChamadaProfissional {
    const val PREFERENCIAS = "chamada/preferencias"
    const val SERVICOS = "chamada/servicos"
    const val RECEBIDA = "chamada/recebida/{chamadaId}"
    const val DEEP_LINK_RECEBIDA = "frila://chamadas/{chamadaId}"

    fun recebida(chamadaId: String) = "chamada/recebida/${Uri.encode(chamadaId)}"
}

internal fun NavGraphBuilder.rotasDaChamadaDiretaProfissional(
    navController: NavHostController,
    guardaBiometrico: GuardaBiometrico,
    /** Chave `busca_profissionais`: desligada, as preferências escondem "Aceito chamadas diretas" e as pendências. */
    buscaProfissionaisHabilitada: Boolean = false,
) {
    composable(RotasChamadaProfissional.PREFERENCIAS) {
        RotaProtegida(guardaBiometrico) {
            val viewModel: PreferenciasChamadaViewModel = koinViewModel()
            TelaPreferenciasDeChamada(
                viewModel = viewModel,
                aoVoltar = { navController.popBackStack() },
                aoEditarServicos = { navController.navigate(RotasChamadaProfissional.SERVICOS) },
                buscaProfissionaisHabilitada = buscaProfissionaisHabilitada,
            )
        }
    }

    composable(RotasChamadaProfissional.SERVICOS) {
        RotaProtegida(guardaBiometrico) {
            val viewModel: EditarServicosViewModel = koinViewModel()
            TelaEditarServicos(viewModel = viewModel, aoVoltar = { navController.popBackStack() })
        }
    }

    composable(
        route = RotasChamadaProfissional.RECEBIDA,
        arguments = listOf(navArgument("chamadaId") { type = NavType.StringType }),
        deepLinks = listOf(navDeepLink { uriPattern = RotasChamadaProfissional.DEEP_LINK_RECEBIDA }),
    ) { entrada ->
        RotaProtegida(guardaBiometrico) {
            val chamadaId = entrada.arguments?.getString("chamadaId").orEmpty()
            // A chave é a chamada: um aviso de outra chamada na mesma posição da pilha recria o ViewModel.
            val viewModel: ChamadaRecebidaViewModel = koinViewModel(key = chamadaId, parameters = { parametersOf(chamadaId) })
            TelaDetalheChamadaRecebida(
                viewModel = viewModel,
                aoVoltar = { navController.popBackStack() },
                aoAbrirTurno = { turnoId -> navController.navigate("meus_turnos/${Uri.encode(turnoId)}") },
            )
        }
    }
}
