package br.com.frila.app

import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import br.com.frila.feature.chamadas.casa.AcompanharChamadasViewModel
import br.com.frila.feature.chamadas.casa.ChamadaDiretaViewModel
import br.com.frila.feature.chamadas.casa.BuscaDeProfissionaisViewModel
import br.com.frila.feature.chamadas.casa.PerfilPublicoViewModel
import br.com.frila.feature.chamadas.casa.RascunhoDeVagaDaBusca
import br.com.frila.feature.chamadas.casa.HorarioDaBusca
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.feature.perfil.EnderecosOficiais
import br.com.frila.feature.chamadas.casa.TelaAcompanharChamadas
import br.com.frila.feature.chamadas.casa.TelaBuscaDeProfissionais
import br.com.frila.feature.chamadas.casa.TelaChamadaDireta
import br.com.frila.feature.chamadas.casa.TelaPerfilPublico
import java.time.Instant
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

    /** Busca de profissionais (tela provisória): só existe no grafo com a chave `busca_profissionais` ligada. */
    const val BUSCA = "chamada/buscar/{estabelecimentoId}"

    /** "Publicar para todos" da busca vazia: a publicação de vaga já com o serviço e o horário buscados. */
    const val PUBLICAR_DA_BUSCA = "chamada/publicar-da-busca/{estabelecimentoId}/{funcaoId}?inicio={inicio}&fim={fim}"

    private const val SEM_HORARIO = -1L

    private const val SEM_REGIAO = -1

    fun perfilPublico(estabelecimentoId: String, profissionalId: String) =
        "chamada/perfil/${Uri.encode(estabelecimentoId)}/${Uri.encode(profissionalId)}"

    /** [regiaoId] é o da busca, quando a chamada nasce dela (0.2.88). */
    fun chamar(estabelecimentoId: String, profissionalId: String, regiaoId: Int? = null) =
        "chamada/chamar/${Uri.encode(estabelecimentoId)}/${Uri.encode(profissionalId)}" +
            (regiaoId?.let { "?regiaoId=$it" } ?: "")

    fun acompanhar(vagaId: String) = "chamada/acompanhar/${Uri.encode(vagaId)}"

    fun buscar(estabelecimentoId: String) = "chamada/buscar/${Uri.encode(estabelecimentoId)}"

    /** O horário vai em segundos desde 1970 (UTC), ou fica de fora quando a busca não filtrou por horário. */
    fun publicarDaBusca(rascunho: RascunhoDeVagaDaBusca) =
        "chamada/publicar-da-busca/${Uri.encode(rascunho.estabelecimentoId)}/${Uri.encode(rascunho.funcaoId)}" +
            (rascunho.horario?.let { "?inicio=${it.inicio.epochSecond}&fim=${it.fim.epochSecond}" } ?: "")

    internal fun horarioDaRota(inicio: Long?, fim: Long?): HorarioDaBusca? {
        if (inicio == null || fim == null || inicio == SEM_HORARIO || fim == SEM_HORARIO) return null
        return HorarioDaBusca(Instant.ofEpochSecond(inicio), Instant.ofEpochSecond(fim)).takeIf { it.valido }
    }

    internal val argumentoDeHorario = listOf("inicio", "fim").map { nome ->
        navArgument(nome) {
            type = NavType.LongType
            defaultValue = SEM_HORARIO
        }
    }

    internal fun regiaoDaRota(valor: Int?): Int? = valor?.takeIf { it != SEM_REGIAO }

    internal val argumentoDeRegiao = navArgument("regiaoId") {
        type = NavType.IntType
        defaultValue = SEM_REGIAO
    }
}

internal fun NavGraphBuilder.rotasDaChamadaDiretaCasa(
    navController: NavHostController,
    guardaBiometrico: GuardaBiometrico,
    /** Chave `busca_profissionais` (RN46): desligada, as rotas da busca nem existem no grafo. */
    buscaProfissionaisHabilitada: Boolean = false,
    servicoMembros: ServicoMembros? = null,
    /** Abre o link fora do app e, se nenhum app o tratar, mostra o aviso com o endereço (ver [abrirExterno]). */
    abrirForaDoApp: (Intent, AvisoDeAberturaExterna) -> Unit,
) {
    if (buscaProfissionaisHabilitada) rotasDaBuscaDeProfissionais(navController, guardaBiometrico, servicoMembros, abrirForaDoApp)
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

/** Busca de profissionais e o "Publicar para todos" dela. Tela PROVISÓRIA, atrás da chave `busca_profissionais`. */
private fun NavGraphBuilder.rotasDaBuscaDeProfissionais(
    navController: NavHostController,
    guardaBiometrico: GuardaBiometrico,
    servicoMembros: ServicoMembros?,
    abrirForaDoApp: (Intent, AvisoDeAberturaExterna) -> Unit,
) {
    composable(
        route = RotasChamadaCasa.BUSCA,
        arguments = listOf(navArgument("estabelecimentoId") { type = NavType.StringType }),
    ) { entrada ->
        RotaProtegida(guardaBiometrico) {
            val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
            val viewModel: BuscaDeProfissionaisViewModel = koinViewModel(parameters = { parametersOf(estabelecimentoId) })
            TelaBuscaDeProfissionais(
                viewModel = viewModel,
                aoVoltar = { navController.popBackStack() },
                aoAbrirPerfil = { navController.navigate(RotasChamadaCasa.perfilPublico(estabelecimentoId, it)) },
                aoPublicarParaTodos = { navController.navigate(RotasChamadaCasa.publicarDaBusca(it)) },
                aoAbrirTermos = {
                    val url = EnderecosOficiais.padrao.termosDeUso
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    abrirForaDoApp(intent, AvisoDeAberturaExterna.semNavegador(url))
                },
                aoAbrirPolitica = {
                    val url = EnderecosOficiais.padrao.politicaDePrivacidade
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    abrirForaDoApp(intent, AvisoDeAberturaExterna.semNavegador(url))
                },
            )
        }
    }

    composable(
        route = RotasChamadaCasa.PUBLICAR_DA_BUSCA,
        arguments = listOf(
            navArgument("estabelecimentoId") { type = NavType.StringType },
            navArgument("funcaoId") { type = NavType.StringType },
        ) + RotasChamadaCasa.argumentoDeHorario,
    ) { entrada ->
        RotaProtegida(guardaBiometrico) {
            val funcaoId = entrada.arguments?.getString("funcaoId").orEmpty()
            val horario = RotasChamadaCasa.horarioDaRota(
                entrada.arguments?.getLong("inicio"),
                entrada.arguments?.getLong("fim"),
            )
            RotaPublicarVaga(
                estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty(),
                servicoMembros = servicoMembros,
                aoVoltar = { navController.popBackStack() },
                aoPreparar = { vaga ->
                    vaga.escolherFuncao(funcaoId)
                    horario?.let {
                        vaga.editarInicio(it.inicio)
                        vaga.editarFim(it.fim)
                    }
                },
            )
        }
    }
}
