package br.com.frila.app

import android.content.Context
import br.com.frila.app.conectividade.MonitorDeConectividadeAndroid
import br.com.frila.app.seguranca.ArmazenamentoDeSessaoKeystore
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.app.seguranca.LeitorDeAmbienteAndroid
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.TipoDeAlvo
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
import br.com.frila.core.rede.ServicoConfianca
import br.com.frila.core.rede.ServicoMembros
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
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltro
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltroEmMemoria
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltroDataStore
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.equipe.EquipeDeConfiancaViewModel
import br.com.frila.feature.estabelecimento.CadastroEstabelecimentoViewModel
import br.com.frila.feature.vagas.candidatos.CandidatosDaVagaViewModel
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.PublicarVagaViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.MonitorizadorDeTurnosProximos
import br.com.frila.feature.turnos.OcorrenciaTurnoViewModel
import java.time.Instant
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
    /** Denúncia, bloqueio e equipe de confiança (RF26/RF18); membros do estabelecimento (RF21). */
    single { ServicoConfianca { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoMembros { get<GestorClienteKtor>().clienteAtual } }
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
    /**
     * Exclusão de conta (RF25, UC16): só depois do sucesso do servidor a sessão local é limpa; uma
     * recusa (`409 administrador_unico`) deixa a conta de pé e a sessão valendo.
     */
    viewModel {
        val servicoPerfil = get<ServicoPerfil>()
        val armazenamentoDeSessao = get<ArmazenamentoDeSessao>()
        ExclusaoDeContaViewModel(
            excluir = { servicoPerfil.excluirConta() },
            aoConcluir = { armazenamentoDeSessao.limparSessao() },
        )
    }
    viewModel { (alvoTipo: TipoDeAlvo, alvoId: String, turnoId: String?, chamadaId: String?) ->
        val confianca = get<ServicoConfianca>()
        DenunciaViewModel(
            alvoTipo = alvoTipo,
            alvoId = alvoId,
            denunciar = confianca::denunciar,
            bloquear = confianca::bloquear,
            turnoId = turnoId,
            chamadaId = chamadaId,
        )
    }
    viewModel { (estabelecimentoId: String) ->
        val confianca = get<ServicoConfianca>()
        EquipeDeConfiancaViewModel(
            estabelecimentoId = estabelecimentoId,
            listar = confianca::equipeDeConfianca,
            removerMembro = confianca::removerDaEquipe,
            sair = confianca::sairDaEquipe,
        )
    }
    /** Cadastro do estabelecimento do contratante (RF02, UC10). */
    viewModel {
        val membros = get<ServicoMembros>()
        CadastroEstabelecimentoViewModel(cadastrar = membros::cadastrarEstabelecimento)
    }
    /**
     * Publicação de vaga (RF04, UC01). A rota só traz o id da casa; endereço, Região Administrativa e
     * ponto vêm de `meu_estabelecimento`, lidos antes de criar o ViewModel, que recebe o conjunto pronto.
     */
    viewModel { (estabelecimento: EstabelecimentoDaVaga) ->
        val vagas = get<ServicoVagas>()
        PublicarVagaViewModel(
            estabelecimento = estabelecimento,
            buscarFuncoes = vagas::listarFuncoes,
            enviarVaga = vagas::publicarVaga,
        )
    }
    /**
     * Candidatos de uma vaga em seleção e a escolha (RF09, UC04). `posicoesAbertas` e `inicioDaVaga` vêm
     * da tela de origem, que conhece a vaga; nulos escondem o aviso da última posição e o prazo de escolha.
     */
    viewModel { (vagaId: String, posicoesAbertas: Int?, inicioDaVaga: Instant?) ->
        val vagas = get<ServicoVagas>()
        CandidatosDaVagaViewModel(
            vagaId = vagaId,
            buscar = vagas::candidatosDaVaga,
            escolher = vagas::escolherCandidato,
            posicoesAbertas = posicoesAbertas,
            inicioDaVaga = inicioDaVaga,
        )
    }
    /**
     * Minhas vagas do contratante (RF20, UC07): o painel do estabelecimento da rota. `nomeEstabelecimento`
     * e `vagaRecemPublicadaId` são opcionais: sem eles a tela não mostra o nome nem destaca uma vaga.
     */
    viewModel { (estabelecimentoId: String, nomeEstabelecimento: String?, vagaRecemPublicadaId: String?) ->
        val vagas = get<ServicoVagas>()
        MinhasVagasViewModel(
            estabelecimentoId = estabelecimentoId,
            nomeEstabelecimento = nomeEstabelecimento,
            vagaRecemPublicadaId = vagaRecemPublicadaId,
            buscarPainel = vagas::painelEstabelecimento,
        )
    }
    /**
     * Acompanhamento do turno pela casa e confirmação do check-in manual (RF13, UC05, UC07). O contexto
     * (vaga, profissional, check-in) vem pronto da rota, que o lê do painel antes de criar o ViewModel.
     */
    viewModel { (contexto: ContextoDoTurnoContratante) ->
        val turnos = get<ServicoTurnos>()
        AcompanhamentoContratanteViewModel(contexto = contexto, confirmar = turnos::confirmarCheckinManual)
    }
}

val todosOsModulos = listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacao, moduloFeatures)
