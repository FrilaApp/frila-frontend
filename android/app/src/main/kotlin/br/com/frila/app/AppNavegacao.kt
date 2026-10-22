package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.cadastro.TelaCadastro
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.codigo.TelaCodigo
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.TelaEntrada
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.detalhe.TelaDetalheVaga
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.TelaFeedVagas
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.TelaAvaliacao
import br.com.frila.feature.turnos.TelaMeusTurnos
import org.koin.androidx.compose.koinViewModel
import org.koin.compose.koinInject
import org.koin.core.parameter.parametersOf

/** Rotas da navegação declarativa. Única fonte de verdade dos destinos possíveis do app. */
object Rotas {
    const val ENTRADA = "entrada"
    const val CODIGO = "codigo/{email}"
    const val CADASTRO = "cadastro"
    const val FEED = "feed"
    const val DETALHE = "detalhe/{vagaId}"
    const val MEUS_TURNOS = "meus_turnos"
    const val AVALIACAO = "avaliacao/{turnoId}"

    fun codigo(email: String) = "codigo/$email"
    fun detalhe(vagaId: String) = "detalhe/$vagaId"
    fun avaliacao(turnoId: String) = "avaliacao/$turnoId"
}

/**
 * Rota inicial: [Rotas.FEED] se já há sessão válida em [ArmazenamentoDeSessao], senão
 * [Rotas.ENTRADA]. É a mesma regra que decide se o app mostra login ou o feed direto na
 * abertura — ver `AppNavegacaoTest`.
 */
fun rotaInicial(armazenamentoDeSessao: ArmazenamentoDeSessao): String =
    if (armazenamentoDeSessao.estaAutenticado()) Rotas.FEED else Rotas.ENTRADA

@Composable
fun AppNavegacao(
    armazenamentoDeSessao: ArmazenamentoDeSessao = koinInject(),
    navController: NavHostController = rememberNavController(),
) {
    val destinoInicial = remember(armazenamentoDeSessao) { rotaInicial(armazenamentoDeSessao) }

    NavHost(navController = navController, startDestination = destinoInicial) {
        composable(Rotas.ENTRADA) {
            val viewModel: EntradaViewModel = koinViewModel()
            TelaEntrada(
                viewModel = viewModel,
                aoReceberCodigo = {
                    navController.navigate(Rotas.codigo(viewModel.estado.value.email))
                },
            )
        }

        composable(Rotas.CODIGO) { entrada ->
            val email = entrada.arguments?.getString("email").orEmpty()
            val viewModel: CodigoViewModel = koinViewModel(parameters = { parametersOf(email) })
            TelaCodigo(
                viewModel = viewModel,
                aoAutenticar = {
                    navController.navigate(Rotas.CADASTRO) {
                        popUpTo(Rotas.ENTRADA) { inclusive = true }
                    }
                },
            )
        }

        composable(Rotas.CADASTRO) {
            val viewModel: CadastroViewModel = koinViewModel()
            TelaCadastro(
                viewModel = viewModel,
                aoConcluir = {
                    navController.navigate(Rotas.FEED) {
                        popUpTo(Rotas.CADASTRO) { inclusive = true }
                    }
                },
            )
        }

        composable(Rotas.FEED) {
            val viewModel: FeedVagasViewModel = koinViewModel()
            TelaFeedVagas(
                viewModel = viewModel,
                aoAbrirDetalhe = { vagaId -> navController.navigate(Rotas.detalhe(vagaId)) },
            )
        }

        composable(Rotas.DETALHE) { entrada ->
            val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
            val feedAnterior = navController.previousBackStackEntry?.let {
                koinViewModel<FeedVagasViewModel>(viewModelStoreOwner = it)
            }
            val vaga: VagaAbertaDto? = feedAnterior?.encontrarVagaPorId(vagaId)

            if (vaga != null) {
                val viewModel: DetalheVagaViewModel = koinViewModel(parameters = { parametersOf(vaga) })
                TelaDetalheVaga(viewModel = viewModel)
            }
        }

        composable(Rotas.MEUS_TURNOS) {
            val viewModel: MeusTurnosViewModel = koinViewModel()
            TelaMeusTurnos(
                viewModel = viewModel,
                criarCheckinViewModel = { turnoId ->
                    // Contrato de `/rpc/meus_turnos` ainda não traz a coordenada da vaga
                    // (schema `VagaResumo`), só `local`/`regiao_administrativa` em texto — por
                    // ora o check-in sempre degrada para o caminho "sem localização" (manual
                    // pendente, RN06), até o backend expor a coordenada aqui.
                    koinViewModel(parameters = { parametersOf(turnoId, null) })
                },
                aoAbrirAvaliacao = { turnoId -> navController.navigate(Rotas.avaliacao(turnoId)) },
            )
        }

        composable(Rotas.AVALIACAO) { entrada ->
            val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
            val viewModel: AvaliacaoViewModel = koinViewModel()
            TelaAvaliacao(
                turnoId = turnoId,
                viewModel = viewModel,
                aoVoltar = { navController.popBackStack() },
            )
        }
    }
}
