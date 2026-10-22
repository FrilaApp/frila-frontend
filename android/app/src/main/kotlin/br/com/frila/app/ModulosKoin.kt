package br.com.frila.app

import br.com.frila.core.notificacoes.ProcessadorDePush
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ProvedorDeToken
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoDispositivo
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
import br.com.frila.feature.turnos.MeusTurnosViewModel
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.dsl.module

/** Endpoint real do Supabase do Frila. Em produção isto vem de `BuildConfig`, não de literal. */
private const val SUPABASE_URL = "https://frila.supabase.co"
private const val SUPABASE_ANON_KEY = "TODO_INJETAR_VIA_BUILDCONFIG"

/**
 * `:core:seguranca` ainda não tem a implementação de produção (Android Keystore +
 * `EncryptedSharedPreferences`, ver `docs/android/04-seguranca-e-sessao.md`) — só o
 * `ArmazenamentoDeSessaoEmMemoria` usado nos testes. Esta vinculação é o único lugar que
 * precisa trocar quando esse módulo chegar; o resto do grafo já depende só da interface.
 */
val moduloSeguranca = module {
    single<ArmazenamentoDeSessao> { ArmazenamentoDeSessaoEmMemoria() }
}

val moduloRede = module {
    single {
        ClienteSupabase(
            baseUrl = SUPABASE_URL,
            apiKey = SUPABASE_ANON_KEY,
            provedorDeToken = ProvedorDeToken { get<ArmazenamentoDeSessao>().obterSessao()?.accessToken },
        )
    }
    single { ServicoAutenticacao(get()) }
    single { ServicoVagas(get()) }
    single { ServicoDispositivo(get()) }
    single { ServicoTurnos(get()) }
}

val moduloNotificacoes = module {
    single { ProcessadorDePush(get()) }
}

val moduloFeatures = module {
    viewModel { EntradaViewModel(get()) }
    viewModel { (email: String) -> CodigoViewModel(email, get(), get()) }
    viewModel { CadastroViewModel() }
    viewModel { FeedVagasViewModel(get()) }
    viewModel { (vaga: VagaAbertaDto) -> DetalheVagaViewModel(vaga, get()) }
    viewModel { MeusTurnosViewModel(get()) }
}

val todosOsModulos = listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloFeatures)
