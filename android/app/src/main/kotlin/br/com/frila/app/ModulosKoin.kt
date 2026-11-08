package br.com.frila.app

import android.content.Context
import br.com.frila.app.conectividade.MonitorDeConectividadeAndroid
import br.com.frila.app.seguranca.ArmazenamentoDeSessaoKeystore
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.app.seguranca.LeitorDeAmbienteAndroid
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.localizacao.GerenciadorGeofencingTurnosNulo
import br.com.frila.core.localizacao.GerenciadorGeofencingTurnosReal
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacaoFused
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacao
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoEmMemoria
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoSharedPrefs
import br.com.frila.core.notificacoes.ProcessadorDePush
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVerificacaoIdentidade
import br.com.frila.core.rede.RepositorioVerificacaoIdentidade
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.RepositorioVagas
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.LeitorDeAmbiente
import br.com.frila.core.seguranca.LeitorDeAmbienteNulo
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltro
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltroEmMemoria
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltroDataStore
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.MonitorizadorDeTurnosProximos
import br.com.frila.feature.turnos.OcorrenciaTurnoViewModel
import org.koin.androidx.viewmodel.dsl.viewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.koin.core.qualifier.named
import org.koin.dsl.onClose
import org.koin.dsl.module

/** Endpoint real do Supabase do Frila. Em produção isto vem de `BuildConfig`, não de literal. */
private const val SUPABASE_URL = "https://frila.supabase.co"
private const val SUPABASE_ANON_KEY = "TODO_INJETAR_VIA_BUILDCONFIG"

/** Qualificador do [CoroutineScope] cujos filhos o logout cancela. */
const val ESCOPO_DA_SESSAO = "escopoDaSessao"

/** Usa Android Keystore em produção e mantém o grafo utilizável em testes JVM sem [Context]. */
val moduloSeguranca = module {
    single { CacheVagasDaSessao(getOrNull<Context>()?.noBackupFilesDir) }
    single<ArmazenamentoDeSessao> {
        val origem = getOrNull<Context>()?.let(::ArmazenamentoDeSessaoKeystore)
            ?: ArmazenamentoDeSessaoEmMemoria()
        SessaoComCacheVagas(origem, get())
    }
    /** RN15 (cartão Cdv0sS5w): leitura do ambiente para VerificadorDeIntegridade. */
    single<LeitorDeAmbiente> {
        getOrNull<Context>()
            ?.let(::LeitorDeAmbienteAndroid)
            ?: LeitorDeAmbienteNulo()
    }
    /** Cartão 101: escopo das corrotinas de sessão; o logout cancela os filhos, não o escopo. */
    single(named(ESCOPO_DA_SESSAO)) { CoroutineScope(SupervisorJob() + Dispatchers.Default) }
    /** Cartão 101: coordenador central de logout com limpeza segura de dados. */
    single {
        CoordenadorDeLogout(
            armazenamentoDeSessao = get(),
            diretorioCache = getOrNull<Context>()?.cacheDir,
            diretorioArquivos = getOrNull<Context>()?.filesDir,
            escopoDeCorrotinas = get(named(ESCOPO_DA_SESSAO)),
            gestorClienteKtor = getOrNull(),
        )
    }
}

val moduloRede = module {
    /** RNF01 (cartão 9Q0sJIzW): fallback inerte (sempre CONECTADO) fora de um Context Android real. */
    single<MonitorDeConectividade> {
        getOrNull<Context>()
            ?.let(::MonitorDeConectividadeAndroid)
            ?: MonitorDeConectividadeFalso()
    }
    /** Cartão 101: gestor de ciclo de vida do cliente Ktor para recriação limpa após logout. */
    single {
        GestorClienteKtor {
            ClienteSupabase(
                baseUrl = SUPABASE_URL,
                apiKey = SUPABASE_ANON_KEY,
                armazenamentoDeSessao = get(),
                monitorDeConectividade = get(),
            )
        }
    }
    /** Sem cache: o cliente muda a cada `GestorClienteKtor.recriar()` (logout). */
    factory { get<GestorClienteKtor>().clienteAtual }
    /** Serviços singleton, mas leem o cliente vigente do gestor a cada chamada. */
    single { ServicoAutenticacao { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoVagas { get<GestorClienteKtor>().clienteAtual } }
    factory {
        val servico = get<ServicoVagas>()
        val armazenamento = get<ArmazenamentoDeSessao>()
        get<CacheVagasDaSessao>().criar(armazenamento) { coordenada -> servico.listarVagasAbertas(coordenada) }
    }
    single { ServicoDispositivo { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoTurnos { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoPerfil { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoVerificacaoIdentidade { get<GestorClienteKtor>().clienteAtual } }
    single { RepositorioVerificacaoIdentidade(get()) }
}

val moduloNotificacoes = module {
    single<GerenciadorPreferenciasNotificacao> {
        getOrNull<Context>()
            ?.let(::GerenciadorPreferenciasNotificacaoSharedPrefs)
            ?: GerenciadorPreferenciasNotificacaoEmMemoria()
    }
    single { ProcessadorDePush(get(), get()) }
}

/**
 * Leitura de localização sob demanda para o check-in presencial (RF13/RN06/RN22), e geofencing
 * passivo de aproximação de turno (RN06/RNF04, cartão Uu04zAt4).
 */
val moduloLocalizacao = module {
    single<ProvedorDeLocalizacao> { ProvedorDeLocalizacaoFused(get()) }
    single<GerenciadorGeofencingTurnos> {
        getOrNull<Context>()
            ?.let(::GerenciadorGeofencingTurnosReal)
            ?: GerenciadorGeofencingTurnosNulo()
    }
}

val moduloFeatures = module {
    single { PreferenciasAndroid(get()) } onClose { it?.close() }
    single<ArmazenamentoPreferenciasFiltro> {
        getOrNull<Context>()
            ?.let { _ ->
                ArmazenamentoPreferenciasFiltroDataStore(get<PreferenciasAndroid>().dados)
            }
            ?: ArmazenamentoPreferenciasFiltroEmMemoria()
    }
    viewModel { EntradaViewModel(get()) }
    viewModel { (email: String) -> CodigoViewModel(email, get(), get()) }
    viewModel { CadastroViewModel() }
    viewModel { FeedVagasViewModel(get(), get(), get(), repositorioVagas = get()) }
    viewModel { (vaga: VagaAbertaDto) -> DetalheVagaViewModel(vaga, get()) }
    single { MonitorizadorDeTurnosProximos(gerenciadorGeofencing = get(), preferenciasNotificacao = get()) }
    viewModel { MeusTurnosViewModel(get(), monitorizador = get()) }
    viewModel { (turnoId: String, coordenadaDaVaga: Coordenada?) ->
        CheckinViewModel(turnoId, coordenadaDaVaga, get(), get(), monitorizador = get())
    }
    viewModel { AvaliacaoViewModel(get()) }
    viewModel { PerfilViewModel(get(), get(), get(), preferenciasNotificacao = get()) }
    viewModel { VerificacaoIdentidadeViewModel(get()) }
    viewModel { (turnoId: String) -> OcorrenciaTurnoViewModel(turnoId, get()) }
}

val todosOsModulos = listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacao, moduloFeatures)
