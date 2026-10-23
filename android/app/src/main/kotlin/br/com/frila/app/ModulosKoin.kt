package br.com.frila.app

import android.content.Context
import br.com.frila.app.seguranca.ArmazenamentoDeSessaoKeystore
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacaoFused
import br.com.frila.core.notificacoes.ProcessadorDePush
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
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
}

val moduloRede = module {
    single {
        ClienteSupabase(
            baseUrl = SUPABASE_URL,
            apiKey = SUPABASE_ANON_KEY,
            armazenamentoDeSessao = get(),
        )
    }
    single { ServicoAutenticacao(get()) }
    single { ServicoVagas(get()) }
    single { ServicoDispositivo(get()) }
    single { ServicoTurnos(get()) }
    single { ServicoPerfil(get()) }
}

val moduloNotificacoes = module {
    single { ProcessadorDePush(get()) }
}

/** Leitura de localização sob demanda para o check-in presencial (RF13/RN06/RN22). */
val moduloLocalizacao = module {
    single<ProvedorDeLocalizacao> { ProvedorDeLocalizacaoFused(get()) }
}

val moduloFeatures = module {
    viewModel { EntradaViewModel(get()) }
    viewModel { (email: String) -> CodigoViewModel(email, get(), get()) }
    viewModel { CadastroViewModel() }
    viewModel { FeedVagasViewModel(get()) }
    viewModel { (vaga: VagaAbertaDto) -> DetalheVagaViewModel(vaga, get()) }
    viewModel { MeusTurnosViewModel(get()) }
    viewModel { (turnoId: String, coordenadaDaVaga: Coordenada?) -> CheckinViewModel(turnoId, coordenadaDaVaga, get(), get()) }
    viewModel { AvaliacaoViewModel(get()) }
    viewModel { PerfilViewModel(get(), get()) }
}

val todosOsModulos = listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacao, moduloFeatures)
