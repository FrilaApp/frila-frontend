package br.com.frila.app

import android.content.Context
import br.com.frila.app.conectividade.MonitorDeConectividadeAndroid
import br.com.frila.app.seguranca.ArmazenamentoDeSessaoKeystore
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
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
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
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltroSharedPreferences
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.MonitorizadorDeTurnosProximos
import br.com.frila.feature.turnos.OcorrenciaTurnoViewModel
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.dsl.module

/** Endpoint real do Supabase do Frila. Em produção isto vem de `BuildConfig`, não de literal. */
private const val SUPABASE_URL = "https://frila.supabase.co"
private const val SUPABASE_ANON_KEY = "TODO_INJETAR_VIA_BUILDCONFIG"

/** Usa Android Keystore em produção e mantém o grafo utilizável em testes JVM sem [Context]. */
val moduloSeguranca = module {
    single<ArmazenamentoDeSessao> {
        getOrNull<Context>()
            ?.let(::ArmazenamentoDeSessaoKeystore)
            ?: ArmazenamentoDeSessaoEmMemoria()
    }
    /** RN15 (cartão Cdv0sS5w): leitura do ambiente para VerificadorDeIntegridade. */
    single<LeitorDeAmbiente> {
        getOrNull<Context>()
            ?.let(::LeitorDeAmbienteAndroid)
            ?: LeitorDeAmbienteNulo()
    }
}

val moduloRede = module {
    /** RNF01 (cartão 9Q0sJIzW): fallback inerte (sempre CONECTADO) fora de um Context Android real. */
    single<MonitorDeConectividade> {
        getOrNull<Context>()
            ?.let(::MonitorDeConectividadeAndroid)
            ?: MonitorDeConectividadeFalso()
    }
    single {
        ClienteSupabase(
            baseUrl = SUPABASE_URL,
            apiKey = SUPABASE_ANON_KEY,
            armazenamentoDeSessao = get(),
            monitorDeConectividade = get(),
        )
    }
    single { ServicoAutenticacao(get()) }
    single { ServicoVagas(get()) }
    single { ServicoDispositivo(get()) }
    single { ServicoTurnos(get()) }
    single { ServicoPerfil(get()) }
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
    single<ArmazenamentoPreferenciasFiltro> {
        getOrNull<Context>()
            ?.let { ctx ->
                ArmazenamentoPreferenciasFiltroSharedPreferences(
                    ctx.getSharedPreferences("preferencias_filtros_vagas", Context.MODE_PRIVATE),
                )
            }
            ?: ArmazenamentoPreferenciasFiltroEmMemoria()
    }
    viewModel { EntradaViewModel(get()) }
    viewModel { (email: String) -> CodigoViewModel(email, get(), get()) }
    viewModel { CadastroViewModel() }
    viewModel { FeedVagasViewModel(get(), get(), get()) }
    viewModel { (vaga: VagaAbertaDto) -> DetalheVagaViewModel(vaga, get()) }
    single { MonitorizadorDeTurnosProximos(gerenciadorGeofencing = get(), preferenciasNotificacao = get()) }
    viewModel { MeusTurnosViewModel(get(), monitorizador = get()) }
    viewModel { (turnoId: String, coordenadaDaVaga: Coordenada?) ->
        CheckinViewModel(turnoId, coordenadaDaVaga, get(), get(), monitorizador = get())
    }
    viewModel { AvaliacaoViewModel(get()) }
    viewModel { PerfilViewModel(get(), get(), get(), preferenciasNotificacao = get()) }
    viewModel { (turnoId: String) -> OcorrenciaTurnoViewModel(turnoId, get()) }
}

val todosOsModulos = listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacao, moduloFeatures)
