package br.com.frila.app

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.navDeepLink
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.cadastro.TelaCadastro
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.codigo.TelaCodigo
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.TelaEntrada
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.detalhe.MotivoIndisponibilidadeVaga
import br.com.frila.feature.vagas.detalhe.TelaDetalheVaga
import br.com.frila.feature.vagas.detalhe.TelaVagaIndisponivel
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import br.com.frila.feature.vagas.feed.TelaFeedVagas
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.TelaAjudaPerfil
import br.com.frila.feature.perfil.TelaLicencas
import br.com.frila.feature.perfil.TelaPerfil
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.OcorrenciaTurnoViewModel
import br.com.frila.feature.turnos.TelaAvaliacao
import br.com.frila.feature.turnos.TelaMeusTurnos
import br.com.frila.feature.turnos.TelaOcorrencia
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
    const val PERFIL = "perfil"
    const val OCORRENCIA = "ocorrencia/{turnoId}"
    const val DESBLOQUEIO = "desbloqueio"
    const val AJUDA = "ajuda"
    const val LICENCAS = "licencas"
    const val VAGA_INDISPONIVEL = "vaga_indisponivel"
    const val ATUALIZACAO_OBRIGATORIA = "atualizacao_obrigatoria"

    fun codigo(email: String) = "codigo/$email"
    fun detalhe(vagaId: String) = "detalhe/$vagaId"
    fun avaliacao(turnoId: String) = "avaliacao/$turnoId"
    fun ocorrencia(turnoId: String) = "ocorrencia/$turnoId"
}

object DeepLinks {
    const val DETALHE_VAGA = "frila://vagas/{vagaId}"
    const val MEUS_TURNOS = "frila://meus_turnos"
    const val SUPORTE = "frila://suporte?turno_id={turnoId}"
}

/**
 * Rota inicial (RN15): sem sessão válida vai para [Rotas.ENTRADA]; com sessão válida e
 * desbloqueio rápido ativado (RN15), passa primeiro por [Rotas.DESBLOQUEIO] em vez de abrir o
 * feed direto — é o gate real da flag `isBiometriaAtivada()`, não só a pintura do toggle no
 * perfil (MEDIDO, Shisui PR #591: antes desta correção nada consumia a flag na inicialização).
 * Sem biometria ativada, vai direto para [Rotas.FEED] — ver `AppNavegacaoTest`.
 */
fun rotaInicial(armazenamentoDeSessao: ArmazenamentoDeSessao): String = when {
    !armazenamentoDeSessao.estaAutenticado() -> Rotas.ENTRADA
    armazenamentoDeSessao.isBiometriaAtivada() -> Rotas.DESBLOQUEIO
    else -> Rotas.FEED
}

@Composable
fun AppNavegacao(
    armazenamentoDeSessao: ArmazenamentoDeSessao = koinInject(),
    monitorDeConectividade: MonitorDeConectividade = koinInject(),
    navController: NavHostController = rememberNavController(),
    aoPronto: (() -> Unit)? = null,
) {
    val destinoInicial = remember(armazenamentoDeSessao) { rotaInicial(armazenamentoDeSessao) }
    // RN15: gate em memória independente de rotaInicial — pega deep link (frila://vagas/...,
    // frila://meus_turnos, frila://suporte) que chega direto numa rota autenticada sem passar
    // pela decisão de abertura (MEDIDO, Shisui PR #591). Ver GuardaBiometrico.
    val guardaBiometrico = remember(armazenamentoDeSessao) {
        GuardaBiometrico(sessaoDesbloqueadaInicial = !armazenamentoDeSessao.isBiometriaAtivada())
    }

    DisposableEffect(navController, guardaBiometrico) {
        val listener = instalarGuardaBiometrico(navController, guardaBiometrico)
        onDispose { navController.removeOnDestinationChangedListener(listener) }
    }

    // RNF04 (bloqueante do Shisui, PR #604): collectAsState() não é lifecycle-aware — a
    // composição ficava viva com a Activity parada, então o StateFlow nunca perdia assinante e
    // o callback do ConnectivityManager nunca era desregistrado em segundo plano (MEDIDO:
    // dumpsys connectivity continuava mostrando os registros depois de +15s/+24s em background).
    val statusConectividade by monitorDeConectividade.status.collectAsStateWithLifecycle()

    Box(modifier = Modifier.fillMaxSize()) {
        NavHost(navController = navController, startDestination = destinoInicial) {
            composable(Rotas.ENTRADA) {
                val viewModel: EntradaViewModel = koinViewModel()
                LaunchedEffect(Unit) {
                    aoPronto?.invoke()
                }
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
                LaunchedEffect(viewModel) { viewModel.carregar() }
                val estadoFeed by viewModel.estado.collectAsStateWithLifecycle()
                LaunchedEffect(estadoFeed.status) {
                    if (estadoFeed.status != StatusFeed.CARREGANDO) {
                        aoPronto?.invoke()
                    }
                }
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = { vagaId -> navController.navigate(Rotas.detalhe(vagaId)) },
                    aoAbrirPerfil = { navController.navigate(Rotas.PERFIL) },
                )
            }

            composable(
                route = Rotas.DETALHE,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.DETALHE_VAGA }),
            ) { entrada ->
                val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                val feedAnterior = navController.previousBackStackEntry?.let {
                    koinViewModel<FeedVagasViewModel>(viewModelStoreOwner = it)
                }
                val estadoFeed = feedAnterior?.estado?.collectAsStateWithLifecycle()?.value
                val vaga: VagaAbertaDto? = estadoFeed?.let { feedAnterior.encontrarVagaPorId(vagaId) }

                if (vaga != null) {
                    val viewModel: DetalheVagaViewModel = koinViewModel(parameters = { parametersOf(vaga) })
                    Column {
                        if (estadoFeed.emCache) Text(
                            "Disponibilidade não confirmada. Conecte-se e atualize o feed antes de se candidatar.",
                            modifier = Modifier.padding(16.dp),
                        )
                        TelaDetalheVaga(viewModel = viewModel)
                    }
                } else {
                    TelaVagaIndisponivel(
                        motivo = MotivoIndisponibilidadeVaga.NAO_ENCONTRADA,
                        aoVoltarParaFeed = {
                            navController.navigate(Rotas.FEED) {
                                popUpTo(Rotas.FEED) { inclusive = true }
                            }
                        },
                    )
                }
            }

            composable(Rotas.VAGA_INDISPONIVEL) {
                TelaVagaIndisponivel(
                    motivo = MotivoIndisponibilidadeVaga.NAO_ENCONTRADA,
                    aoVoltarParaFeed = {
                        navController.navigate(Rotas.FEED) {
                            popUpTo(Rotas.FEED) { inclusive = true }
                        }
                    },
                )
            }

            composable(
                route = Rotas.MEUS_TURNOS,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.MEUS_TURNOS }),
            ) {
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

            composable(
                route = Rotas.OCORRENCIA,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.SUPORTE }),
            ) { entrada ->
                val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
                val viewModel: OcorrenciaTurnoViewModel = koinViewModel(parameters = { parametersOf(turnoId) })
                TelaOcorrencia(
                    viewModel = viewModel,
                    aoVoltar = { navController.popBackStack() },
                )
            }

            composable(Rotas.DESBLOQUEIO) {
                LaunchedEffect(Unit) {
                    aoPronto?.invoke()
                }
                TelaDesbloqueioBiometrico(
                    aoDesbloquear = {
                        val destino = guardaBiometrico.aoDesbloquearComSucesso()
                        navController.navigate(destino) {
                            popUpTo(0) { inclusive = true }
                        }
                    },
                    aoEntrarComOutraConta = {
                        guardaBiometrico.liberarAposLimparSessao()
                        navController.navigate(Rotas.ENTRADA) {
                            popUpTo(0) { inclusive = true }
                        }
                    },
                )
            }

            composable(Rotas.PERFIL) {
                val viewModel: PerfilViewModel = koinViewModel()
                TelaPerfil(
                    viewModel = viewModel,
                    aoDeslogar = {
                        guardaBiometrico.liberarAposLimparSessao()
                        navController.navigate(Rotas.ENTRADA) {
                            popUpTo(0) { inclusive = true }
                        }
                    },
                    aoAbrirAjuda = { navController.navigate(Rotas.AJUDA) },
                )
            }

            composable(Rotas.AJUDA) {
                val contexto = LocalContext.current
                TelaAjudaPerfil(
                    aoVoltar = { navController.popBackStack() },
                    aoNavegarParaLicencas = { navController.navigate(Rotas.LICENCAS) },
                    aoNavegarParaTermos = { url ->
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            contexto.startActivity(intent)
                        } catch (_: Exception) { }
                    },
                    aoNavegarParaPrivacidade = { url ->
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            contexto.startActivity(intent)
                        } catch (_: Exception) { }
                    },
                    aoAbrirEmailSuporte = { email ->
                        try {
                            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$email")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            contexto.startActivity(intent)
                        } catch (_: Exception) { }
                    },
                )
            }

            composable(Rotas.LICENCAS) {
                TelaLicencas(
                    aoVoltar = { navController.popBackStack() },
                )
            }

            composable(Rotas.ATUALIZACAO_OBRIGATORIA) {
                val contexto = androidx.compose.ui.platform.LocalContext.current
                br.com.frila.core.designsystem.componentes.TelaAtualizacaoObrigatoria(
                    aoAtualizar = {
                        val uriLoja = android.net.Uri.parse("market://details?id=${contexto.packageName}")
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, uriLoja).apply {
                            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        try {
                            contexto.startActivity(intent)
                        } catch (e: Exception) {
                            contexto.startActivity(
                                android.content.Intent(
                                    android.content.Intent.ACTION_VIEW,
                                    android.net.Uri.parse("https://play.google.com/store/apps/details?id=${contexto.packageName}"),
                                ).apply {
                                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                },
                            )
                        }
                    },
                )
            }
        }

        // RNF01 (cartão 9Q0sJIzW): banner flutuante centralizado sobre o NavHost — nunca dentro
        // de uma tela de feature individual (escopo explícito do cartão).
        BannerDeConectividade(
            status = statusConectividade,
            modifier = Modifier.align(Alignment.TopCenter).padding(16.dp),
        )
    }
}

/** Extraído para ser testável sozinho, sem montar o grafo Koin/NavHost completo. */
@Composable
fun BannerDeConectividade(status: StatusConectividade, modifier: Modifier = Modifier) {
    AnimatedVisibility(
        visible = status == StatusConectividade.SEM_CONEXAO,
        modifier = modifier,
    ) {
        AvisoFrila(
            tom = TomAviso.ALERTA,
            mensagem = "Sem conexão com a internet. Verifique sua rede.",
        )
    }
}
