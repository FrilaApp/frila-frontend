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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.conta.TelaContaSuspensa
import br.com.frila.feature.conta.TelaExclusaoDeConta
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.cadastro.TelaCadastro
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.codigo.TelaCodigo
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.TelaEntrada
import br.com.frila.feature.vagas.candidatos.CandidatosDaVagaViewModel
import br.com.frila.feature.vagas.candidatos.TelaCandidatosDaVaga
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.detalhe.MotivoIndisponibilidadeVaga
import br.com.frila.feature.vagas.detalhe.TelaDetalheVaga
import br.com.frila.feature.vagas.detalhe.TelaVagaIndisponivel
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import br.com.frila.feature.vagas.feed.TelaFeedVagas
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.vagas.painel.TelaMinhasVagas
import br.com.frila.feature.equipe.EquipeDeConfiancaViewModel
import br.com.frila.feature.equipe.TelaEquipeDeConfianca
import br.com.frila.feature.estabelecimento.CadastroEstabelecimentoViewModel
import br.com.frila.feature.estabelecimento.TelaCadastroEstabelecimento
import br.com.frila.feature.perfil.EnderecosOficiais
import br.com.frila.feature.perfil.ApresentacaoERegioesViewModel
import br.com.frila.feature.perfil.PontoBaseViewModel
import br.com.frila.feature.perfil.FotoDePerfilViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.TelaApresentacaoERegioes
import br.com.frila.feature.perfil.TelaPontoBase
import br.com.frila.feature.perfil.TelaFotoDePerfilConectada
import br.com.frila.feature.perfil.TelaAjudaPerfil
import br.com.frila.feature.perfil.TelaLicencas
import br.com.frila.feature.perfil.TelaPerfil
import br.com.frila.feature.perfil.TelaVerificacaoDocumento
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.suporte.TelaDenuncia
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.OcorrenciaTurnoViewModel
import br.com.frila.feature.turnos.StatusMeusTurnos
import br.com.frila.feature.turnos.TelaAvaliacao
import br.com.frila.feature.turnos.TelaMeusTurnos
import br.com.frila.feature.turnos.TelaOcorrencia
import br.com.frila.feature.turnos.TelaTurnoNaoEncontrado
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import org.koin.androidx.compose.koinViewModel
import org.koin.compose.getKoin
import org.koin.compose.koinInject
import org.koin.core.parameter.parametersOf

/** Rotas da navegação declarativa. Única fonte de verdade dos destinos possíveis do app. */
object Rotas {
    const val ENTRADA = "entrada"
    const val CODIGO = "codigo/{email}"
    const val CADASTRO = "cadastro"
    /** Pergunta ao servidor quem é a conta e segue para a tela do papel (#782, #783). */
    const val ABERTURA = "abertura"
    const val FEED = "feed"
    const val DETALHE = "detalhe/{vagaId}"
    const val MEUS_TURNOS = "meus_turnos"
    const val AVALIACAO = "avaliacao/{turnoId}"
    const val PERFIL = "perfil"
    const val APRESENTACAO = "perfil_apresentacao"
    const val PONTO_BASE = "perfil_ponto_base"
    const val FOTO_DE_PERFIL = "perfil_foto"
    const val SELO_CONFIANCA = "selo_confianca"
    const val OCORRENCIA = "ocorrencia/{turnoId}"
    const val DESBLOQUEIO = "desbloqueio"
    const val AJUDA = "ajuda"
    const val LICENCAS = "licencas"
    const val VAGA_INDISPONIVEL = "vaga_indisponivel"
    const val ATUALIZACAO_OBRIGATORIA = "atualizacao_obrigatoria"
    const val TURNO_NAO_ENCONTRADO = "turno_nao_encontrado"
    const val TURNO_AVISO = "meus_turnos/{turnoId}"
    const val EXCLUSAO_DE_CONTA = "exclusao_de_conta"
    const val CONTA_SUSPENSA = "conta_suspensa?motivo={motivo}&desde={desde}"
    const val DENUNCIA = "denuncia/{alvoTipo}/{alvoId}?turnoId={turnoId}&chamadaId={chamadaId}"
    const val EQUIPE = "equipe/{estabelecimentoId}"
    const val CADASTRO_ESTABELECIMENTO = "cadastro_estabelecimento"
    const val PUBLICAR_VAGA = "publicar_vaga/{estabelecimentoId}"
    const val MINHAS_VAGAS = "minhas_vagas/{estabelecimentoId}?nomeEstabelecimento={nomeEstabelecimento}&vagaRecemPublicadaId={vagaRecemPublicadaId}"
    const val TURNO_DO_CONTRATANTE = "turno_do_contratante/{estabelecimentoId}/{vagaId}/{posicaoId}"
    const val CANDIDATOS_DA_VAGA = "candidatos_da_vaga/{vagaId}?posicoesAbertas={posicoesAbertas}&inicioDaVaga={inicioDaVaga}"

    fun codigo(email: String) = "codigo/$email"
    fun detalhe(vagaId: String) = "detalhe/$vagaId"
    fun avaliacao(turnoId: String) = "avaliacao/$turnoId"
    fun ocorrencia(turnoId: String) = "ocorrencia/$turnoId"
    fun turnoAviso(turnoId: String) = "meus_turnos/$turnoId"

    /** `motivo` e `desde` são opcionais e já formatados para exibição (o Android ainda não lê `situacao_da_conta`). */
    fun contaSuspensa(motivo: String? = null, desde: String? = null): String {
        val parametros = listOfNotNull(
            motivo?.let { "motivo=${Uri.encode(it)}" },
            desde?.let { "desde=${Uri.encode(it)}" },
        )
        return if (parametros.isEmpty()) "conta_suspensa" else "conta_suspensa?" + parametros.joinToString("&")
    }

    /** `alvoId` é o `id` do `PerfilPublico`; `turnoId` e `chamadaId` só associam a denúncia (contrato 0.2.71). */
    fun denuncia(alvoTipo: TipoDeAlvo, alvoId: String, turnoId: String? = null, chamadaId: String? = null): String {
        val parametros = listOfNotNull(
            turnoId?.let { "turnoId=${Uri.encode(it)}" },
            chamadaId?.let { "chamadaId=${Uri.encode(it)}" },
        )
        val base = "denuncia/${alvoTipo.chave}/${Uri.encode(alvoId)}"
        return if (parametros.isEmpty()) base else base + "?" + parametros.joinToString("&")
    }

    fun equipe(estabelecimentoId: String) = "equipe/$estabelecimentoId"

    fun publicarVaga(estabelecimentoId: String) = "publicar_vaga/${Uri.encode(estabelecimentoId)}"

    /** O turno da posição `posicaoId` da vaga `vagaId`, lido do painel do estabelecimento. */
    fun turnoDoContratante(estabelecimentoId: String, vagaId: String, posicaoId: String) =
        "turno_do_contratante/${Uri.encode(estabelecimentoId)}/${Uri.encode(vagaId)}/${Uri.encode(posicaoId)}"

    /** `nomeEstabelecimento` e `vagaRecemPublicadaId` são opcionais; a vaga recém-publicada sobe na lista. */
    fun minhasVagas(estabelecimentoId: String, nomeEstabelecimento: String? = null, vagaRecemPublicadaId: String? = null): String {
        val parametros = listOfNotNull(
            nomeEstabelecimento?.let { "nomeEstabelecimento=${Uri.encode(it)}" },
            vagaRecemPublicadaId?.let { "vagaRecemPublicadaId=${Uri.encode(it)}" },
        )
        val base = "minhas_vagas/${Uri.encode(estabelecimentoId)}"
        return if (parametros.isEmpty()) base else base + "?" + parametros.joinToString("&")
    }

    /**
     * `posicoesAbertas` e `inicioDaVaga` são opcionais: a tela de origem os informa quando conhece a vaga.
     * O início vai em ISO-8601 UTC, como o contrato o entrega.
     */
    fun candidatosDaVaga(vagaId: String, posicoesAbertas: Int? = null, inicioDaVaga: Instant? = null): String {
        val parametros = listOfNotNull(
            posicoesAbertas?.let { "posicoesAbertas=$it" },
            inicioDaVaga?.let { "inicioDaVaga=${Uri.encode(it.toString())}" },
        )
        val base = "candidatos_da_vaga/${Uri.encode(vagaId)}"
        return if (parametros.isEmpty()) base else base + "?" + parametros.joinToString("&")
    }
}

object DeepLinks {
    const val DETALHE_VAGA = "frila://vagas/{vagaId}"
    const val MEUS_TURNOS = "frila://meus_turnos"
    const val TURNO_AVISO = "frila://meus_turnos/{turnoId}"
    const val SUPORTE = "frila://suporte?turno_id={turnoId}"
}

/**
 * Rota inicial (RN15): sem sessão válida vai para [Rotas.ENTRADA]; com sessão válida e
 * desbloqueio rápido ativado (RN15), passa primeiro por [Rotas.DESBLOQUEIO] em vez de abrir o
 * feed direto — é o gate real da flag `isBiometriaAtivada()`, não só a pintura do toggle no
 * perfil (MEDIDO, Shisui PR #591: antes desta correção nada consumia a flag na inicialização).
 * Sem biometria ativada, vai direto para [Rotas.FEED] — ver `AppNavegacaoTest`.
 */
fun rotaInicial(armazenamentoDeSessao: ArmazenamentoDeSessao, biometriaHabilitada: Boolean = false): String = when {
    !armazenamentoDeSessao.estaAutenticado() -> Rotas.ENTRADA
    biometriaHabilitada && armazenamentoDeSessao.isBiometriaAtivada() -> Rotas.DESBLOQUEIO
    else -> Rotas.FEED
}

@Composable
fun AppNavegacao(
    /**
     * #789: o padrão é o [CoordenadorDeLogout], porque as saídas desta navegação (conta suspensa, "outra conta"
     * no desbloqueio) chamam `limparSessao()` aqui, e só o coordenador fecha o cliente Ktor da conta que saiu.
     * Grafo sem o coordenador (testes com Koin mínimo) usa o armazenamento; o de produção sempre o tem
     * (`KoinGrafoTest`), e o token em memória já não passa de uma conta a outra pelo próprio `ClienteSupabase`.
     */
    armazenamentoDeSessao: ArmazenamentoDeSessao = getKoin().getOrNull<CoordenadorDeLogout>() ?: koinInject(),
    monitorDeConectividade: MonitorDeConectividade = koinInject(),
    navController: NavHostController = rememberNavController(),
    aoPronto: (() -> Unit)? = null,
    /**
     * Trava do selo de confiança (RN14): desligada por padrão até a moderação e os termos serem
     * validados pelos sócios. Desligada, a rota [Rotas.SELO_CONFIANCA] nem existe no grafo e o
     * perfil não consulta o estado do selo.
     */
    recursoSeloHabilitado: Boolean = false,
    /**
     * Chave `chamada_direta` (`configuracao_do_app`): desligada, "Chamar de novo" nem aparece na equipe de
     * confiança. Ligada, a equipe leva à folha de chamar do lado da casa.
     */
    chamadaDiretaHabilitada: Boolean = false,
    /**
     * Chave `busca_profissionais` (`configuracao_do_app`, RN46): desligada, as preferências de chamada ficam como no
     * iOS de hoje, sem o "Aceito chamadas diretas" nem as pendências da busca.
     */
    buscaProfissionaisHabilitada: Boolean = false,
    /**
     * Chave `checkin_por_codigo` (`configuracao_do_app`, a do servidor): ligada, o profissional digita o código que a casa mostra e a casa vê o
     * código do turno. Desligada (padrão), a tela de turnos fica como antes.
     */
    checkinPorCodigoHabilitado: Boolean = false,
    /**
     * Quem é membro de um estabelecimento ganha no perfil os atalhos da equipe de confiança e da
     * publicação de vaga; contratante sem casa ganha o do cadastro. Nulo (grafo sem o serviço) esconde
     * todos. Conta de profissional recebe `422 perfil_incompativel` e também não vê nenhum.
     */
    servicoMembros: ServicoMembros? = getKoin().getOrNull(),
    /** Lê o painel para a rota do turno do contratante. Nulo (grafo sem o serviço) mostra a falha da rota. */
    servicoVagas: ServicoVagas? = getKoin().getOrNull(),
    /**
     * Decide a tela inicial pelo papel da conta, depois do código e a cada abertura com sessão. Nulo (grafo
     * sem o serviço) mantém o caminho antigo: cadastro depois do código e feed na abertura.
     */
    avaliadorDeDestino: AvaliadorDeDestino? = getKoin().getOrNull(),
    /**
     * C0-8: conta as sessões apagadas (token recusado, Sair, exclusão). Sem sessão, tela de dentro só falha, e a
     * navegação volta à entrada, como o iOS (`FrilaApp.swift:519`). Nulo (grafo sem a [SessaoComCacheVagas]) não observa.
     */
    encerramentosDaSessao: StateFlow<Int>? = (getKoin().getOrNull<ArmazenamentoDeSessao>() as? SessaoComCacheVagas)?.encerramentos,
    /**
     * C0-11 (decisão de 16/11/2026: o Android fica só com o que o iOS tem): o iOS não tem desbloqueio por biometria.
     * Desligada (padrão; nada no app a liga), a abertura não pede a digital nem a quem a tinha ligado antes.
     */
    biometriaHabilitada: Boolean = false,
    /**
     * Chave `perfil_rico` (`configuracao_do_app`, a do servidor): ligada, o profissional vê no perfil o atalho "Apresentação e regiões". Desligada
     * (padrão), o perfil fica como era.
     */
    perfilRicoHabilitado: Boolean = false,
    /** Chave `foto_de_perfil` (`configuracao_do_app`, a do servidor): ligada, o profissional vê no perfil o atalho "Foto de perfil". Desligada (padrão), não vê. */
    fotoDePerfilHabilitada: Boolean = false,
) {
    val destinoInicial = remember(armazenamentoDeSessao, avaliadorDeDestino, biometriaHabilitada) {
        rotaInicial(armazenamentoDeSessao, biometriaHabilitada).let { if (it == Rotas.FEED && avaliadorDeDestino != null) Rotas.ABERTURA else it }
    }
    // RN15: gate em memória independente de rotaInicial — pega deep link (frila://vagas/...,
    // frila://meus_turnos, frila://suporte) que chega direto numa rota autenticada sem passar
    // pela decisão de abertura (MEDIDO, Shisui PR #591). Ver GuardaBiometrico.
    val guardaBiometrico = remember(armazenamentoDeSessao, biometriaHabilitada) {
        GuardaBiometrico(sessaoDesbloqueadaInicial = !(biometriaHabilitada && armazenamentoDeSessao.isBiometriaAtivada()))
    }

    DisposableEffect(navController, guardaBiometrico) {
        val listener = instalarGuardaBiometrico(navController, guardaBiometrico)
        onDispose { navController.removeOnDestinationChangedListener(listener) }
    }

    // C0-8: toda saída da sessão (Sair, exclusão, 401 na abertura, outra conta, sessão que caiu) termina aqui, numa
    // navegação só: quem chega com a pilha já reduzida à entrada não navega de novo.
    fun irParaEntrada() {
        guardaBiometrico.liberarAposLimparSessao()
        if (navController.currentDestination?.route == Rotas.ENTRADA && navController.previousBackStackEntry == null) return
        navController.navigate(Rotas.ENTRADA) {
            popUpTo(0) { inclusive = true }
        }
    }

    // C0-9: a profissional denuncia a casa pelo turno dela, como o iOS (`TelaMeuTurno.swift:125`).
    val denunciarCasa: (String, String) -> Unit = { casaId, turnoId ->
        navController.navigate(Rotas.denuncia(TipoDeAlvo.ESTABELECIMENTO, casaId, turnoId = turnoId))
    }

    // N3 e N16: confere ao abrir (link frila:// sem sessão, pilha restaurada) e a cada sessão apagada. O cliente de
    // rede apaga fora da thread principal quando o Auth recusa o token, e a navegação só anda na principal.
    // Sem sessão, tela de dentro só falha.
    LaunchedEffect(encerramentosDaSessao, navController, guardaBiometrico) {
        encerramentosDaSessao?.collect {
            withContext(Dispatchers.Main.immediate) {
                val rota = navController.currentDestination?.route
                if (rota != null && rota !in GuardaBiometrico.ROTAS_SEM_GATE && !armazenamentoDeSessao.estaAutenticado()) {
                    irParaEntrada()
                }
            }
        }
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
                        navController.navigate(if (avaliadorDeDestino != null) Rotas.ABERTURA else Rotas.CADASTRO) {
                            popUpTo(Rotas.ENTRADA) { inclusive = true }
                        }
                    },
                )
            }

            composable(Rotas.ABERTURA) {
                RotaProtegida(guardaBiometrico) {
                    if (avaliadorDeDestino != null) {
                        RotaDeAbertura(
                            avaliador = avaliadorDeDestino,
                            aoDecidir = { destino ->
                                if (destino is DestinoDaConta.Contratante) {
                                    // A casa não tem feed para voltar: o Perfil (Sair, Equipe, Excluir conta) fica
                                    // como raiz da pilha, e a tela inicial da casa entra por cima dele. "Voltar" da
                                    // tela inicial leva ao Perfil; "Voltar" no Perfil sai do app (pilha nunca vazia).
                                    navController.navigate(Rotas.PERFIL) {
                                        popUpTo(Rotas.ABERTURA) { inclusive = true }
                                    }
                                    navController.navigate(destino.rota())
                                } else {
                                    navController.navigate(destino.rota()) {
                                        popUpTo(Rotas.ABERTURA) { inclusive = true }
                                    }
                                }
                            },
                            aoSessaoVencida = {
                                // 401: a renovação já falhou; sai da árvore autenticada como o logout faz.
                                armazenamentoDeSessao.limparSessao()
                                irParaEntrada()
                            },
                            aoTerminarDeAvaliar = { aoPronto?.invoke() },
                        )
                    }
                }
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
                RotaProtegida(guardaBiometrico) {
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
                        aoAbrirMeusTurnos = { navController.navigate(Rotas.MEUS_TURNOS) },
                        aoDefinirPontoBase = { navController.navigate(Rotas.PONTO_BASE) },
                    )
                }
            }

            composable(
                route = Rotas.DETALHE,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.DETALHE_VAGA }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
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
            }

            composable(Rotas.VAGA_INDISPONIVEL) {
                RotaProtegida(guardaBiometrico) {
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

            composable(Rotas.TURNO_NAO_ENCONTRADO) {
                RotaProtegida(guardaBiometrico) {
                    TelaTurnoNaoEncontrado(
                        aoVoltar = { navController.popBackStack() },
                        aoVerMeusTurnos = {
                            navController.navigate(Rotas.MEUS_TURNOS) {
                                popUpTo(Rotas.MEUS_TURNOS) { inclusive = true }
                            }
                        },
                    )
                }
            }

            composable(
                route = Rotas.TURNO_AVISO,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.TURNO_AVISO }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
                    val viewModel: MeusTurnosViewModel = koinViewModel()
                    val estado by viewModel.estado.collectAsStateWithLifecycle()

                    LaunchedEffect(turnoId) {
                        viewModel.carregar()
                    }

                    when (estado.status) {
                        StatusMeusTurnos.CARREGANDO -> {
                            Box(
                                modifier = Modifier.fillMaxSize(),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = "Carregando...",
                                    style = androidx.compose.material3.MaterialTheme.typography.bodyMedium,
                                )
                            }
                        }
                        StatusMeusTurnos.SUCESSO -> {
                            val turnoEncontrado = estado.agendados.any { it.turnoId == turnoId } ||
                                estado.historicoCompleto.any { it.turnoId == turnoId }
                            if (turnoEncontrado) {
                                ComConfirmacaoPorCodigo(
                                    habilitada = checkinPorCodigoHabilitado,
                                    aoPresencaVerificada = { viewModel.carregar() },
                                ) {
                                    TelaMeusTurnos(
                                        viewModel = viewModel,
                                        criarCheckinViewModel = { turno ->
                                            // C0-7: um check-in por turno (key), com o ponto da vaga para medir a distância.
                                            koinViewModel(key = "checkin-${turno.turnoId}", parameters = { parametersOf(turno.turnoId, turno.pontoDaVaga) })
                                        },
                                        aoAbrirAvaliacao = { id -> navController.navigate(Rotas.avaliacao(id)) },
                                        aoDenunciarEstabelecimento = denunciarCasa,
                                    )
                                }
                            } else {
                                TelaTurnoNaoEncontrado(
                                    aoVoltar = { navController.popBackStack() },
                                    aoVerMeusTurnos = {
                                        navController.navigate(Rotas.MEUS_TURNOS) {
                                            popUpTo(Rotas.MEUS_TURNOS) { inclusive = true }
                                        }
                                    },
                                )
                            }
                        }
                        StatusMeusTurnos.VAZIO -> {
                            TelaTurnoNaoEncontrado(
                                aoVoltar = { navController.popBackStack() },
                                aoVerMeusTurnos = {
                                    navController.navigate(Rotas.MEUS_TURNOS) {
                                        popUpTo(Rotas.MEUS_TURNOS) { inclusive = true }
                                    }
                                },
                            )
                        }
                        StatusMeusTurnos.ERRO -> {
                            // Não transforma erro de conexão em "não encontrado" (DestinosDoAviso.swift:208)
                            ComConfirmacaoPorCodigo(
                                habilitada = checkinPorCodigoHabilitado,
                                aoPresencaVerificada = { viewModel.carregar() },
                            ) {
                                TelaMeusTurnos(
                                    viewModel = viewModel,
                                    criarCheckinViewModel = { turno ->
                                        // C0-7: um check-in por turno (key), com o ponto da vaga para medir a distância.
                                        koinViewModel(key = "checkin-${turno.turnoId}", parameters = { parametersOf(turno.turnoId, turno.pontoDaVaga) })
                                    },
                                    aoAbrirAvaliacao = { id -> navController.navigate(Rotas.avaliacao(id)) },
                                    aoDenunciarEstabelecimento = denunciarCasa,
                                )
                            }
                        }
                    }
                }
            }

            composable(
                route = Rotas.MEUS_TURNOS,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.MEUS_TURNOS }),
            ) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: MeusTurnosViewModel = koinViewModel()
                    LaunchedEffect(viewModel) { viewModel.carregar() }
                    ComConfirmacaoPorCodigo(
                        habilitada = checkinPorCodigoHabilitado,
                        aoPresencaVerificada = { viewModel.carregar() },
                    ) {
                        TelaMeusTurnos(
                            viewModel = viewModel,
                            criarCheckinViewModel = { turno ->
                                // C0-7: um check-in por turno (key; antes todos os cartões dividiam um só), com o ponto
                                // da vaga (`VagaResumo.ponto`), para medir a distância até ela (RN06).
                                koinViewModel(key = "checkin-${turno.turnoId}", parameters = { parametersOf(turno.turnoId, turno.pontoDaVaga) })
                            },
                            aoAbrirAvaliacao = { turnoId -> navController.navigate(Rotas.avaliacao(turnoId)) },
                            aoDenunciarEstabelecimento = denunciarCasa,
                        )
                    }
                }
            }

            composable(Rotas.AVALIACAO) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
                    val viewModel: AvaliacaoViewModel = koinViewModel()
                    TelaAvaliacao(
                        turnoId = turnoId,
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.OCORRENCIA,
                deepLinks = listOf(navDeepLink { uriPattern = DeepLinks.SUPORTE }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val turnoId = entrada.arguments?.getString("turnoId").orEmpty()
                    val viewModel: OcorrenciaTurnoViewModel = koinViewModel(parameters = { parametersOf(turnoId) })
                    TelaOcorrencia(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(Rotas.DESBLOQUEIO) {
                if (!biometriaHabilitada) {
                    // C0-11 (P2 do Lince no #854): com a trava desligada não há desbloqueio, mas o Android ainda restaura
                    // uma pilha salva nesta rota (processo morto, rotação). Não desenha a tela, que pediria a digital
                    // sozinha, e segue para o destino normal da conta.
                    LaunchedEffect(Unit) {
                        navController.navigate(destinoInicial) {
                            popUpTo(0) { inclusive = true }
                        }
                    }
                    return@composable
                }
                LaunchedEffect(Unit) {
                    aoPronto?.invoke()
                }
                TelaDesbloqueioBiometrico(
                    aoDesbloquear = {
                        val liberado = guardaBiometrico.aoDesbloquearComSucesso()
                        // Sem deep link pendente a guarda devolve o feed: a casa não pode cair nele (#783).
                        val destino = if (liberado == Rotas.FEED && avaliadorDeDestino != null) Rotas.ABERTURA else liberado
                        navController.navigate(destino) {
                            popUpTo(0) { inclusive = true }
                        }
                    },
                    aoEntrarComOutraConta = { irParaEntrada() },
                    armazenamentoDeSessao = armazenamentoDeSessao,
                )
            }

            composable(Rotas.PERFIL) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: PerfilViewModel = koinViewModel()
                    LaunchedEffect(viewModel) { viewModel.carregar() }
                    val viewModelSelo: VerificacaoIdentidadeViewModel? =
                        if (recursoSeloHabilitado) koinViewModel() else null
                    val estadoSelo = viewModelSelo?.estado?.collectAsStateWithLifecycle()?.value
                    // Ao voltar do fluxo do selo a rota entra de novo em composição e relê o estado.
                    LaunchedEffect(viewModelSelo) { viewModelSelo?.carregar() }
                    var casas by remember { mutableStateOf<CasasDaConta>(CasasDaConta.Desconhecidas) }
                    LaunchedEffect(servicoMembros) { casas = buscarCasasDaConta(servicoMembros) }
                    val primeiraCasa = casas as? CasasDaConta.Primeira
                    TelaPerfil(
                        viewModel = viewModel,
                        manterAtalhosDeContratanteNoErro = primeiraCasa != null,
                        recursoSeloHabilitado = recursoSeloHabilitado,
                        verificacaoIdentidade = estadoSelo?.verificacao,
                        podeSolicitarSelo = estadoSelo?.podeSolicitar == true,
                        aoAbrirSelo = { navController.navigate(Rotas.SELO_CONFIANCA) },
                        aoDeslogar = { irParaEntrada() },
                        aoAbrirAjuda = { navController.navigate(Rotas.AJUDA) },
                        aoAbrirExclusaoDeConta = { navController.navigate(Rotas.EXCLUSAO_DE_CONTA) },
                        aoAbrirEquipe = primeiraCasa?.let { casa ->
                            { navController.navigate(Rotas.equipe(casa.id)) }
                        },
                        aoPublicarVaga = primeiraCasa?.let { casa ->
                            { navController.navigate(Rotas.publicarVaga(casa.id)) }
                        },
                        aoMinhasVagas = primeiraCasa?.let { casa ->
                            { navController.navigate(Rotas.minhasVagas(casa.id, casa.nome)) }
                        },
                        aoCadastrarEstabelecimento = if (casas == CasasDaConta.Nenhuma) {
                            { navController.navigate(Rotas.CADASTRO_ESTABELECIMENTO) }
                        } else {
                            null
                        },
                        // Busca de profissionais (tela provisória): só para quem é membro de uma casa e com a chave ligada.
                        aoEncontrarProfissional = if (buscaProfissionaisHabilitada && primeiraCasa != null) {
                            { navController.navigate(RotasChamadaCasa.buscar(primeiraCasa.id)) }
                        } else {
                            null
                        },
                        // Preferências de chamada são do profissional (como `suportaChamadaDireta` no iOS): quem tem
                        // casa, ou pode cadastrar uma, é contratante e não vê o atalho. Só `Desconhecidas` (conta de
                        // profissional recebe `perfil_incompativel` da lista de casas) o mostra.
                        aoAbrirChamadasDiretas = if (chamadaDiretaHabilitada && casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(RotasChamadaProfissional.PREFERENCIAS) }
                        } else {
                            null
                        },
                        // L1-7c: apresentação e foto são do profissional, como as preferências de chamada (mesma regra de `casas`).
                        aoAbrirApresentacao = if (perfilRicoHabilitado && casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(Rotas.APRESENTACAO) }
                        } else {
                            null
                        },
                        aoAbrirFotoDePerfil = if (fotoDePerfilHabilitada && casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(Rotas.FOTO_DE_PERFIL) }
                        } else {
                            null
                        },
                        // O ponto base é do profissional (mesma regra de `casas`). Sem chave: sem ele a lista de vagas não abre.
                        aoAbrirPontoBase = if (casas == CasasDaConta.Desconhecidas) {
                            { navController.navigate(Rotas.PONTO_BASE) }
                        } else {
                            null
                        },
                    )
                }
            }

            // Ao salvar, volta para quem abriu: a lista de vagas recarrega sozinha ao reaparecer.
            composable(Rotas.PONTO_BASE) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: PontoBaseViewModel = koinViewModel()
                    TelaPontoBase(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        aoSalvo = { navController.popBackStack() },
                    )
                }
            }

            composable(Rotas.APRESENTACAO) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: ApresentacaoERegioesViewModel = koinViewModel()
                    TelaApresentacaoERegioes(viewModel = viewModel, aoVoltar = { navController.popBackStack() })
                }
            }

            composable(Rotas.FOTO_DE_PERFIL) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: FotoDePerfilViewModel = koinViewModel()
                    TelaFotoDePerfilConectada(viewModel = viewModel)
                }
            }

            composable(Rotas.EXCLUSAO_DE_CONTA) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: ExclusaoDeContaViewModel = koinViewModel()
                    val estado by viewModel.estado.collectAsStateWithLifecycle()
                    // Sessão já limpa por `aoConcluir`; sai da árvore autenticada como o logout faz.
                    LaunchedEffect(estado.resultado) {
                        if (estado.resultado != null) irParaEntrada()
                    }
                    TelaExclusaoDeConta(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.CONTA_SUSPENSA,
                arguments = listOf(
                    navArgument("motivo") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("desde") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entrada ->
                val contexto = LocalContext.current
                TelaContaSuspensa(
                    emailSuporte = EnderecosOficiais.padrao.emailSuporte,
                    aoContatarSuporte = { email ->
                        try {
                            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$email")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            contexto.startActivity(intent)
                        } catch (_: Exception) { }
                    },
                    aoSair = {
                        armazenamentoDeSessao.limparSessao()
                        irParaEntrada()
                    },
                    motivo = entrada.arguments?.getString("motivo"),
                    desde = entrada.arguments?.getString("desde"),
                )
            }

            composable(
                route = Rotas.DENUNCIA,
                arguments = listOf(
                    navArgument("alvoTipo") { type = NavType.StringType },
                    navArgument("alvoId") { type = NavType.StringType },
                    navArgument("turnoId") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("chamadaId") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val alvoTipo = TipoDeAlvo.entries.firstOrNull { it.chave == entrada.arguments?.getString("alvoTipo") }
                    val alvoId = entrada.arguments?.getString("alvoId").orEmpty()
                    if (alvoTipo == null || alvoId.isEmpty()) {
                        // Rota montada à mão com um tipo fora do contrato: não há quem denunciar.
                        LaunchedEffect(Unit) { navController.popBackStack() }
                    } else {
                        val turnoId = entrada.arguments?.getString("turnoId")
                        val chamadaId = entrada.arguments?.getString("chamadaId")
                        val contexto = LocalContext.current
                        val viewModel: DenunciaViewModel = koinViewModel(
                            parameters = { parametersOf(alvoTipo, alvoId, turnoId, chamadaId) },
                        )
                        TelaDenuncia(
                            viewModel = viewModel,
                            aoFechar = { navController.popBackStack() },
                            aoLigar = { numero ->
                                try {
                                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$numero")).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    contexto.startActivity(intent)
                                } catch (_: Exception) { }
                            },
                        )
                    }
                }
            }

            composable(
                route = Rotas.EQUIPE,
                arguments = listOf(navArgument("estabelecimentoId") { type = NavType.StringType }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
                    val viewModel: EquipeDeConfiancaViewModel = koinViewModel(
                        parameters = { parametersOf(estabelecimentoId) },
                    )
                    TelaEquipeDeConfianca(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        aoChamarDeNovo = if (chamadaDiretaHabilitada) {
                            { profissional ->
                                navController.navigate(RotasChamadaCasa.chamar(estabelecimentoId, profissional.id))
                            }
                        } else {
                            null
                        },
                    )
                }
            }

            rotasDaChamadaDiretaCasa(navController, guardaBiometrico, buscaProfissionaisHabilitada, servicoMembros)
            rotasDaChamadaDiretaProfissional(navController, guardaBiometrico, buscaProfissionaisHabilitada)

            composable(Rotas.CADASTRO_ESTABELECIMENTO) {
                RotaProtegida(guardaBiometrico) {
                    val viewModel: CadastroEstabelecimentoViewModel = koinViewModel()
                    TelaCadastroEstabelecimento(
                        viewModel = viewModel,
                        // Recém-cadastrada, a casa segue direto para a primeira vaga; "Voltar" da
                        // publicação leva ao perfil, não de volta ao formulário já concluído.
                        aoConcluir = { criado ->
                            navController.navigate(Rotas.publicarVaga(criado.id)) {
                                popUpTo(Rotas.CADASTRO_ESTABELECIMENTO) { inclusive = true }
                            }
                        },
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.PUBLICAR_VAGA,
                arguments = listOf(navArgument("estabelecimentoId") { type = NavType.StringType }),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    RotaPublicarVaga(
                        estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty(),
                        servicoMembros = servicoMembros,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            composable(
                route = Rotas.MINHAS_VAGAS,
                arguments = listOf(
                    navArgument("estabelecimentoId") { type = NavType.StringType },
                    navArgument("nomeEstabelecimento") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("vagaRecemPublicadaId") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty()
                    val nomeEstabelecimento = entrada.arguments?.getString("nomeEstabelecimento")?.takeIf { it.isNotBlank() }
                    val vagaRecemPublicadaId = entrada.arguments?.getString("vagaRecemPublicadaId")?.takeIf { it.isNotBlank() }
                    val viewModel: MinhasVagasViewModel = koinViewModel(
                        parameters = { parametersOf(estabelecimentoId, nomeEstabelecimento, vagaRecemPublicadaId) },
                    )
                    TelaMinhasVagas(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                        aoVerCandidatos = { vagaId, posicoesAbertas, inicioDaVaga ->
                            navController.navigate(Rotas.candidatosDaVaga(vagaId, posicoesAbertas, inicioDaVaga))
                        },
                        aoPublicarVaga = { id -> navController.navigate(Rotas.publicarVaga(id)) },
                        aoAcompanharTurno = { vagaId, posicaoId ->
                            navController.navigate(Rotas.turnoDoContratante(estabelecimentoId, vagaId, posicaoId))
                        },
                    )
                }
            }

            composable(
                route = Rotas.TURNO_DO_CONTRATANTE,
                arguments = listOf(
                    navArgument("estabelecimentoId") { type = NavType.StringType },
                    navArgument("vagaId") { type = NavType.StringType },
                    navArgument("posicaoId") { type = NavType.StringType },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    RotaTurnoDoContratante(
                        estabelecimentoId = entrada.arguments?.getString("estabelecimentoId").orEmpty(),
                        vagaId = entrada.arguments?.getString("vagaId").orEmpty(),
                        posicaoId = entrada.arguments?.getString("posicaoId").orEmpty(),
                        buscarPainel = servicoVagas?.let { servico -> servico::painelEstabelecimento },
                        aoVoltar = { navController.popBackStack() },
                        checkinPorCodigoHabilitado = checkinPorCodigoHabilitado,
                        // C0-9: a casa denuncia a profissional pelo turno, como o iOS (`TelaTurnoDoContratante.swift:360`).
                        aoDenunciarProfissional = { profissionalId, turnoId ->
                            navController.navigate(Rotas.denuncia(TipoDeAlvo.PROFISSIONAL, profissionalId, turnoId = turnoId))
                        },
                    )
                }
            }

            composable(
                route = Rotas.CANDIDATOS_DA_VAGA,
                arguments = listOf(
                    navArgument("vagaId") { type = NavType.StringType },
                    navArgument("posicoesAbertas") { type = NavType.StringType; nullable = true; defaultValue = null },
                    navArgument("inicioDaVaga") { type = NavType.StringType; nullable = true; defaultValue = null },
                ),
            ) { entrada ->
                RotaProtegida(guardaBiometrico) {
                    val vagaId = entrada.arguments?.getString("vagaId").orEmpty()
                    // Valor que não é número, negativo ou data inválida vira "não informado": o ViewModel
                    // só perde o aviso da última posição e o prazo, nunca recebe lixo.
                    val posicoesAbertas = entrada.arguments?.getString("posicoesAbertas")?.toIntOrNull()?.takeIf { it >= 0 }
                    val inicioDaVaga = entrada.arguments?.getString("inicioDaVaga")?.let { runCatching { Instant.parse(it) }.getOrNull() }
                    val viewModel: CandidatosDaVagaViewModel = koinViewModel(
                        parameters = { parametersOf(vagaId, posicoesAbertas, inicioDaVaga) },
                    )
                    TelaCandidatosDaVaga(
                        viewModel = viewModel,
                        aoVoltar = { navController.popBackStack() },
                    )
                }
            }

            if (recursoSeloHabilitado) {
                composable(Rotas.SELO_CONFIANCA) {
                    RotaProtegida(guardaBiometrico) {
                        val viewModel: VerificacaoIdentidadeViewModel = koinViewModel()
                        TelaVerificacaoDocumento(
                            viewModel = viewModel,
                            aoVoltar = { navController.popBackStack() },
                        )
                    }
                }
            }

            composable(Rotas.AJUDA) {
                RotaProtegida(guardaBiometrico) {
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
            }

            composable(Rotas.LICENCAS) {
                RotaProtegida(guardaBiometrico) {
                    TelaLicencas(
                        aoVoltar = { navController.popBackStack() },
                    )
                }
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
