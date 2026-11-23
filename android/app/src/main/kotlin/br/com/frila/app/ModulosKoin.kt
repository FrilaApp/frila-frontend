package br.com.frila.app

import android.content.Context
import android.util.Log
import br.com.frila.app.conectividade.MonitorDeConectividadeAndroid
import br.com.frila.app.falhas.ColetaDeFalhas
import br.com.frila.app.falhas.DestinoCrashlytics
import br.com.frila.app.falhas.DestinoDeFalhas
import br.com.frila.app.falhas.FalhasDoFirebase
import br.com.frila.app.falhas.FalhasDoFirebaseReal
import br.com.frila.app.falhas.GerenciadorConsentimentoCrashlytics
import br.com.frila.app.falhas.GerenciadorConsentimentoCrashlyticsReal
import br.com.frila.app.falhas.TelemetriaDeFalhas
import br.com.frila.app.seguranca.ArmazenamentoDeSessaoKeystore
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.app.seguranca.LeitorDeAmbienteAndroid
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.localizacao.GeocodificadorDfOffline
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacaoFused
import br.com.frila.core.localizacao.RemovedorDeGeofencesAntigos
import br.com.frila.core.localizacao.RemovedorDeGeofencesAntigosDoPlayServices
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacao
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoEmMemoria
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoSharedPrefs
import br.com.frila.core.notificacoes.ProcessadorDePush
import br.com.frila.core.notificacoes.RegistradorDeDispositivo
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.FilaDeTelemetria
import br.com.frila.core.rede.RegistradorDeTelemetria
import br.com.frila.core.rede.ServicoTelemetria
import br.com.frila.core.rede.contaDaSessaoParaTelemetria
import kotlinx.coroutines.cancel
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoChamadaDireta
import br.com.frila.core.rede.ServicoConfianca
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.rede.RegistroDeErroDaApi
import br.com.frila.core.rede.ServicoMidia
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVerificacaoIdentidade
import br.com.frila.core.rede.RepositorioVerificacaoIdentidade
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.RepositorioVagas
import br.com.frila.core.rede.SincronizadorDeAcoes
import br.com.frila.core.rede.TipoAcaoPendente
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.rede.VagaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.LeitorDeAmbiente
import br.com.frila.core.seguranca.LeitorDeAmbienteNulo
import br.com.frila.feature.conta.ContaSuspensaViewModel
import br.com.frila.feature.conta.ContestarDespachoViewModel
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.vagas.candidaturas.MinhasCandidaturasViewModel
import br.com.frila.feature.vagas.candidaturas.RetirarCandidaturaViewModel
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltro
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltroEmMemoria
import br.com.frila.feature.vagas.feed.ArmazenamentoPreferenciasFiltroDataStore
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.painel.CancelarVagaViewModel
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.vagas.painel.RepublicarPosicoesRestantesViewModel
import br.com.frila.feature.vagas.painel.RepublicarVagaViewModel
import br.com.frila.feature.chamadas.profissional.ChamadaRecebidaViewModel
import br.com.frila.feature.chamadas.profissional.EditarServicosViewModel
import br.com.frila.feature.chamadas.profissional.PreferenciasChamadaViewModel
import br.com.frila.feature.chamadas.profissional.ServicoDeEspecialidades
import br.com.frila.feature.chamadas.casa.AcompanharChamadasViewModel
import br.com.frila.feature.chamadas.casa.BuscaDeProfissionaisViewModel
import br.com.frila.feature.chamadas.casa.ChamadaDiretaViewModel
import br.com.frila.feature.chamadas.casa.PerfilPublicoViewModel
import br.com.frila.feature.chamadas.casa.ServicoDeRegioes
import br.com.frila.feature.equipe.EquipeDeConfiancaViewModel
import br.com.frila.feature.equipe.casa.EquipeDaCasaViewModel
import br.com.frila.feature.equipe.casa.TenhoUmConviteViewModel
import br.com.frila.feature.equipe.casa.TrocarDeCasaViewModel
import br.com.frila.feature.equipe.IncluirNaEquipeViewModel
import br.com.frila.feature.estabelecimento.CadastroEstabelecimentoViewModel
import br.com.frila.feature.vagas.candidatos.CandidatosDaVagaViewModel
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.escala.EscalaDeEventoViewModel
import br.com.frila.feature.vagas.publicacao.PublicarVagaViewModel
import br.com.frila.feature.perfil.ApresentacaoERegioesViewModel
import br.com.frila.feature.perfil.EnderecosOficiais
import br.com.frila.feature.perfil.OpcaoDePontoBase
import br.com.frila.feature.perfil.PontoBaseViewModel
import br.com.frila.feature.perfil.FuncoesEHorariosViewModel
import br.com.frila.feature.perfil.HistoricoDeTurnosViewModel
import br.com.frila.feature.perfil.PorQueReceboVagasViewModel
import br.com.frila.feature.perfil.ConferidorDeRostoDaFoto
import br.com.frila.feature.perfil.ConferidorDeRostoDoAndroid
import br.com.frila.feature.perfil.FluxoDaFotoDePerfil
import br.com.frila.feature.perfil.FotoDePerfilViewModel
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.PreparadorDeJpegDoAparelho
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.suporte.BloqueiosViewModel
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.MedidorDeDistancia
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.OcorrenciaTurnoViewModel
import br.com.frila.feature.turnos.ValidacaoDoCodigoViewModel
import br.com.frila.feature.turnos.contratante.CodigoDaCasaViewModel
import java.time.Duration
import java.time.Instant
import org.koin.androidx.viewmodel.dsl.viewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import org.koin.core.qualifier.named
import org.koin.dsl.onClose
import org.koin.dsl.module

/** URL e chave publicável do Supabase, do `BuildConfig` (par DEV no debug, PROD no release; ver app/build.gradle.kts). */
private val configuracaoSupabase = ConfiguracaoSupabase.doBuildConfig()

/** Qualificador do [CoroutineScope] cujos filhos o logout cancela. */
const val ESCOPO_DA_SESSAO = "escopoDaSessao"

/** Usa Android Keystore em produção e mantém o grafo utilizável em testes JVM sem [Context]. */
val moduloSeguranca = module {
    single { FilaDeTelemetria(getOrNull<Context>()?.noBackupFilesDir?.resolve("telemetria/eventos.json")) }
    single {
        val fila = get<FilaDeTelemetria>()
        CacheVagasDaSessao(getOrNull<Context>()?.noBackupFilesDir, limparTelemetria = fila::limpar)
    }
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
            // C0-10: o Sair pede remover_dispositivo depois da limpeza local; falha só vira log, sem token nem sessão.
            servicoDispositivo = getOrNull(),
            provedorDeTokenFcm = { lerTokenDoFcm() },
            escopoDaRemocao = CoroutineScope(SupervisorJob() + Dispatchers.IO),
            registrarFalha = { motivo -> Log.w("FrilaPush", motivo) },
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
    /**
     * L1-7d / Parecer P-059: telemetria de falhas (Crashlytics). A coleta sai DESLIGADA no manifesto (LGPD art. 33, VIII);
     * só é ativada se houver consentimento explícito e específico para a versão atual do texto (1.8).
     * Só código, rota e duração; nunca identificador de usuário nem dados pessoais.
     */
    single<FalhasDoFirebase> {
        getOrNull<Context>()?.let(::FalhasDoFirebaseReal) ?: object : FalhasDoFirebase {
            override val configurado: Boolean = false
            override fun apagarRelatoriosPendentes() {}
            override fun definirColetaAtiva(ativa: Boolean) {}
        }
    }
    single<GerenciadorConsentimentoCrashlytics> {
        getOrNull<Context>()?.let { contexto ->
            GerenciadorConsentimentoCrashlyticsReal(contexto, firebase = get())
        } ?: object : GerenciadorConsentimentoCrashlytics {
            override fun coletaAtiva(): Boolean = false
            override fun precisaPerguntar(): Boolean = false
            override fun definirConsentimento(concedido: Boolean) {}
        }
    }
    single {
        val consentimento = getOrNull<GerenciadorConsentimentoCrashlytics>()
        TelemetriaDeFalhas(
            leitorColetaLigada = { consentimento?.coletaAtiva() ?: false },
            destino = getOrNull<DestinoDeFalhas>() ?: DestinoCrashlytics(),
        )
    }
    /** Cartão 101: gestor de ciclo de vida do cliente Ktor para recriação limpa após logout. */
    single {
        // Debug compilado sem o par DEV: o app sobe, mas diz no log por que não alcança o servidor (sem valores).
        configuracaoSupabase.problema?.let { Log.w("FRILA_CONFIG", "Supabase sem configuração que sirva: $it") }
        GestorClienteKtor {
            ClienteSupabase(
                baseUrl = configuracaoSupabase.url,
                apiKey = configuracaoSupabase.chavePublicavel,
                armazenamentoDeSessao = get(),
                monitorDeConectividade = get(),
                registroDeErros = get<TelemetriaDeFalhas>().let { telemetria -> RegistroDeErroDaApi(telemetria::registrarErroDaApi) },
            )
        }
    }
    /** Sem cache: o cliente muda a cada `GestorClienteKtor.recriar()` (logout). */
    factory { get<GestorClienteKtor>().clienteAtual }
    /** Serviços singleton, mas leem o cliente vigente do gestor a cada chamada. */
    single { ServicoAutenticacao { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoConta { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoTelemetria { get<GestorClienteKtor>().clienteAtual } }
    single(named("escopoDaTelemetria")) { CoroutineScope(SupervisorJob() + Dispatchers.IO) } onClose { it?.cancel() }
    single {
        val armazenamento = get<ArmazenamentoDeSessao>()
        val conta = get<ServicoConta>()
        RegistradorDeTelemetria(
            enviar = get<ServicoTelemetria>()::registrarEvento,
            fila = get(),
            contaLocal = { contaDaSessaoParaTelemetria(armazenamento.obterSessao()) },
            consultarConta = { conta.minhaConta().id },
            escopo = get(named("escopoDaTelemetria")),
        )
    }
    single { ServicoVagas { get<GestorClienteKtor>().clienteAtual } }
    factory {
        val servico = get<ServicoVagas>()
        val armazenamento = get<ArmazenamentoDeSessao>()
        get<CacheVagasDaSessao>().criar(armazenamento) { servico.listarVagasAbertas() }
    }
    single { ServicoDispositivo { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoTurnos { get<GestorClienteKtor>().clienteAtual } }
    /**
     * A6.1: fila das ações sem rede (limpa com o cache da sessão) e o reenvio, com um envio por tipo. Enfileiram: o
     * check-in e o check-out (A6.2); as fatias seguintes (avaliação, cancelamentos, publicação) enfileiram o seu tipo.
     */
    single { get<CacheVagasDaSessao>().filaDeAcoes }
    /** O reenvio da fila vive o app todo (o logout cancela só o escopo da sessão): reenvia a cada vez que a rede volta. */
    single(named("escopoDaFilaDeAcoes")) { CoroutineScope(SupervisorJob() + Dispatchers.IO) } onClose { it?.cancel() }
    single {
        val turnos = get<ServicoTurnos>()
        val vagas = get<ServicoVagas>()
        val conta = get<ServicoConta>()
        SincronizadorDeAcoes(
            fila = get(),
            contaAtual = { conta.minhaConta().id },
            envios = mapOf(
                TipoAcaoPendente.CHECKIN to { a -> turnos.fazerCheckin(checkNotNull(a.turnoId), a.distanciaMetros, a.instanteDoToque); Unit },
                TipoAcaoPendente.CHECKOUT to { a -> turnos.fazerCheckout(checkNotNull(a.turnoId), a.distanciaMetros, a.instanteDoToque); Unit },
                TipoAcaoPendente.AVALIACAO to { a -> turnos.avaliarTurno(checkNotNull(a.turnoId), checkNotNull(a.resposta)); Unit },
                TipoAcaoPendente.PUBLICACAO_VAGA to { a -> vagas.publicarVaga(checkNotNull(a.publicacao)); Unit },
                TipoAcaoPendente.REPUBLICACAO_VAGA to { a ->
                    val r = checkNotNull(a.republicacao)
                    vagas.republicarVaga(r.vagaId, instanteDoServidor(r.inicioEm), instanteDoServidor(r.fimEm), a.chave)
                    Unit
                },
                TipoAcaoPendente.CANCELAMENTO_POSICAO to { a -> turnos.cancelarPosicao(checkNotNull(a.alvoId), checkNotNull(a.motivo)); Unit },
                TipoAcaoPendente.CANCELAMENTO_VAGA to { a -> vagas.cancelarVaga(checkNotNull(a.alvoId), checkNotNull(a.motivo)); Unit },
            ),
        )
    }
    single { ServicoPerfil { get<GestorClienteKtor>().clienteAtual } }
    /** Foto de perfil (contrato 0.2.54): pedir o envio, PUT na URL assinada, confirmar, remover e listar. */
    single { ServicoMidia { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoVerificacaoIdentidade { get<GestorClienteKtor>().clienteAtual } }
    single { RepositorioVerificacaoIdentidade(get()) }
    /** Denúncia, bloqueio e equipe de confiança (RF26/RF18); membros do estabelecimento (RF21). */
    single { ServicoConfianca { get<GestorClienteKtor>().clienteAtual } }
    single { ServicoMembros { get<GestorClienteKtor>().clienteAtual } }
    /** Chamada direta e busca (contrato 0.2.88): as 11 RPCs; compartilhado pelos dois lados (profissional e casa). */
    single { ServicoChamadaDireta { get<GestorClienteKtor>().clienteAtual } }
    /** Especialidades ativas por função, para o profissional marcar nos serviços (RN44). */
    single { ServicoDeEspecialidades { get<GestorClienteKtor>().clienteAtual } }
    /** Regiões Administrativas ativas, para o filtro da busca de profissionais. */
    single { ServicoDeRegioes { get<GestorClienteKtor>().clienteAtual } }
}

val moduloNotificacoes = module {
    single<GerenciadorPreferenciasNotificacao> {
        getOrNull<Context>()
            ?.let(::GerenciadorPreferenciasNotificacaoSharedPrefs)
            ?: GerenciadorPreferenciasNotificacaoEmMemoria()
    }
    single { ProcessadorDePush(get(), get()) }
    // C0-10: o registro do aparelho numa função só (abrir com sessão, depois de entrar e onNewToken), com versao_app.
    // Falha do registro (rede, servidor, token) só vira log, com o motivo e sem token nem sessão.
    single {
        RegistradorDeDispositivo(
            get(), get(), versaoApp = BuildConfig.VERSION_NAME, registrarFalha = { motivo -> Log.w("FrilaPush", motivo) },
        ) { lerTokenDoFcm() }
    }
}

/**
 * Leitura de localização sob demanda, só no toque de marcar presença e saída (RF13/RN06/RN22). Nada lê a posição fora
 * do toque: não há geofence nem leitura ao abrir a lista de vagas.
 */
val moduloLocalizacao = module {
    single<ProvedorDeLocalizacao> { ProvedorDeLocalizacaoFused(get()) }
    /** Só desfaz o que uma versão anterior registrou; sem `Context` (testes) não há Play Services e nada a remover. */
    single<RemovedorDeGeofencesAntigos> {
        getOrNull<Context>()?.let { RemovedorDeGeofencesAntigosDoPlayServices(it) } ?: RemovedorDeGeofencesAntigos { }
    }
    single {
        val turnos = get<ServicoTurnos>()
        LimpezaDeGeofencesAntigos(
            temSessao = get<ArmazenamentoDeSessao>()::estaAutenticado,
            idsDosTurnos = { turnos.listarMeusTurnos().map { it.id } },
            remover = get<RemovedorDeGeofencesAntigos>()::remover,
        )
    }
}

val moduloFeatures = module {
    single { PreferenciasAndroid(get()) } onClose { it?.close() }
    single { PreferenciasAparencia(get<PreferenciasAndroid>().dados) }
    single<ArmazenamentoPreferenciasFiltro> {
        getOrNull<Context>()
            ?.let { _ ->
                ArmazenamentoPreferenciasFiltroDataStore(get<PreferenciasAndroid>().dados)
            }
            ?: ArmazenamentoPreferenciasFiltroEmMemoria()
    }
    viewModel { EntradaViewModel(get(), permitirDominioDeTeste = BuildConfig.DEBUG) }
    viewModel { (email: String) ->
        CodigoViewModel(
            email, get(), get(),
            aoEntrar = { get<RegistradorDeDispositivo>().registrarEmSegundoPlano() },
            permitirDominioDeTeste = BuildConfig.DEBUG,
        )
    }
    viewModel { CadastroViewModel(get(), registrarEvento = get<RegistradorDeTelemetria>()::disparar) }
    viewModel { FeedVagasViewModel(get(), get(), repositorioVagas = get(), registrarEvento = get<RegistradorDeTelemetria>()::disparar) }
    /** L2-4: a vaga da lista; aberta pelo id (link, aviso), vem também o detalhe lido do servidor (segundo parâmetro, opcional). */
    viewModel { params -> DetalheVagaViewModel(params.get<VagaAbertaDto>(), get(), detalhe = params.getOrNull<VagaDto>(), registrarEvento = get<RegistradorDeTelemetria>()::disparar) }
    viewModel { MeusTurnosViewModel(get()) }
    viewModel { (turnoId: String, coordenadaDaVaga: Coordenada?) ->
        val armazenamento = get<ArmazenamentoDeSessao>()
        CheckinViewModel(
            turnoId, coordenadaDaVaga, get(), get(),
            registrarEvento = get<RegistradorDeTelemetria>()::disparar,
            filaDeAcoes = get(),
            contaAtual = { contaDaSessaoParaTelemetria(armazenamento.obterSessao()) },
        )
    }
    viewModel { AvaliacaoViewModel(get(), registrarEvento = get<RegistradorDeTelemetria>()::disparar) }
    /** #789: o "Sair" e a exclusão do perfil passam pelo coordenador, que fecha o cliente Ktor da conta que saiu. */
    viewModel { PerfilViewModel(get(), get(), get<CoordenadorDeLogout>(), preferenciasNotificacao = get(), servicoConta = get(), exportarMeusDados = get<ServicoConta>()::exportarMeusDados) }
    viewModel { VerificacaoIdentidadeViewModel(get()) }
    viewModel { (turnoId: String) -> OcorrenciaTurnoViewModel(turnoId, get()) }
    /**
     * Exclusão de conta (RF25, UC16): só depois do sucesso do servidor a sessão local é limpa; uma
     * recusa (`409 administrador_unico`) deixa a conta de pé e a sessão valendo.
     */
    viewModel {
        val servicoPerfil = get<ServicoPerfil>()
        val coordenadorDeLogout = get<CoordenadorDeLogout>()
        ExclusaoDeContaViewModel(
            excluir = { servicoPerfil.excluirConta() },
            aoConcluir = { coordenadorDeLogout.limparSessao() },
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
     * Equipe da casa (RF21): lista, convite por link, remover e tornar administrador. O link do convite sai da origem da web
     * dos endereços oficiais; o papel de quem abriu a tela vem da rota (lido de `meus_estabelecimentos`).
     */
    viewModel { (estabelecimentoId: String, papel: PapelMembro?) ->
        val membros = get<ServicoMembros>()
        EquipeDaCasaViewModel(
            estabelecimentoId = estabelecimentoId,
            papel = papel,
            listar = membros::listarMembrosDaCasa,
            convidar = membros::convidarMembro,
            remover = membros::removerMembro,
            transferir = membros::transferirAdministracao,
            // A web do MESMO ambiente do app: o debug (Supabase DEV) abre a web DEV, o release abre a web Prod.
            montarLink = { token -> EnderecosOficiais.padrao.copy(origemDaWeb = OrigemDaWeb.doAmbiente()).linkDoConvite(token) },
        )
    }
    /** "Tenho um convite": cola o link ou o código e aceita (`aceitar_convite_membro`). */
    viewModel { TenhoUmConviteViewModel(aceitar = get<ServicoMembros>()::aceitarConviteMembro) }
    /** Trocar de casa: `meus_estabelecimentos`, sem RPC própria. */
    viewModel { TrocarDeCasaViewModel(listar = get<ServicoMembros>()::listarMeusEstabelecimentos) }
    /** Escala de evento (RF19, `publicar_escala`): o mesmo estabelecimento lido da publicação de vaga, com a chave única da escala. */
    viewModel { (estabelecimento: EstabelecimentoDaVaga) ->
        val vagas = get<ServicoVagas>()
        EscalaDeEventoViewModel(
            estabelecimento = estabelecimento,
            buscarFuncoes = vagas::listarFuncoes,
            enviarEscala = vagas::publicarEscala,
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
        // L2-2: `reabrir` liga o botão "Reabrir vaga" (a tela a pergunta antes: reabrir registra a falta e não tem volta).
        AcompanhamentoContratanteViewModel(
            contexto = contexto,
            confirmar = turnos::confirmarCheckinManual,
            reabrir = turnos::reabrirPorAtraso,
        )
    }
    /**
     * Lado da casa na chamada direta (UC de contratação direta, 0.2.88). As chaves `chamada_direta` e
     * `busca_profissionais` vêm da configuração do app, lida a cada abertura da folha ou da busca.
     */
    viewModel { (id: String) ->
        PerfilPublicoViewModel(id = id, buscar = get<ServicoChamadaDireta>()::perfilPublico)
    }
    viewModel { (profissionalId: String, estabelecimentoId: String, regiaoId: Int?) ->
        val chamadas = get<ServicoChamadaDireta>()
        val membros = get<ServicoMembros>()
        val vagas = get<ServicoVagas>()
        val gestor = get<GestorClienteKtor>()
        ChamadaDiretaViewModel(
            profissionalId = profissionalId,
            estabelecimentoId = estabelecimentoId,
            recursoHabilitado = { consultarConfiguracaoDoApp(gestor.clienteAtual).recursos.chamadaDireta },
            buscarCasa = membros::meuEstabelecimento,
            buscarFuncoes = vagas::listarFuncoes,
            chamar = chamadas::chamarProfissional,
            regiaoId = regiaoId,
        )
    }
    viewModel { (vagaId: String) ->
        val chamadas = get<ServicoChamadaDireta>()
        AcompanharChamadasViewModel(
            vagaId = vagaId,
            listar = chamadas::minhasChamadas,
            cancelarChamada = chamadas::cancelarChamada,
            publicarAPartirDaChamada = chamadas::publicarAPartirDaChamada,
        )
    }
    /** Busca de profissionais (tela PROVISÓRIA até o high-fi do Fabrício), atrás da chave `busca_profissionais`. */
    viewModel { (estabelecimentoId: String) ->
        val chamadas = get<ServicoChamadaDireta>()
        val gestor = get<GestorClienteKtor>()
        BuscaDeProfissionaisViewModel(
            estabelecimentoId = estabelecimentoId,
            recursoHabilitado = { consultarConfiguracaoDoApp(gestor.clienteAtual).recursos.buscaProfissionais },
            buscarProfissionais = chamadas::buscarProfissionais,
            chamarProfissional = chamadas::chamarProfissional,
            aceitarTermos = chamadas::aceitarTermos,
            // 0.2.95: os termos da vaga do 409 trabalho_ja_aberto, como a casa os lê (seguindo o cursor).
            minhasChamadas = { estado, cursor -> chamadas.minhasChamadas(estado = estado, cursor = cursor) },
            detalheChamada = chamadas::detalheChamada,
            listarFuncoes = get<ServicoVagas>()::listarFuncoes,
            listarRegioes = get<ServicoDeRegioes>()::regioesAtivas,
            buscarCasa = get<ServicoMembros>()::meuEstabelecimento,
        )
    }
    /**
     * Apresentação e regiões do profissional (L1-2): `meu_perfil_detalhado`, as regiões ativas e as duas gravações. As quatro operações chegam por
     * função ao ViewModel; a rota é do `AppNavegacao`.
     */
    viewModel {
        val perfil = get<ServicoPerfil>()
        val chamadas = get<ServicoChamadaDireta>()
        ApresentacaoERegioesViewModel(
            carregarPerfil = chamadas::meuPerfilDetalhado,
            carregarRegioes = perfil::regioesAdministrativas,
            salvarApresentacao = perfil::atualizarApresentacaoProfissional,
            salvarRegioes = perfil::definirRegioesAtendidas,
        )
    }
    /**
     * Ponto base (tela provisória): a pessoa escolhe uma das regiões administrativas do DF, que já estão no app, e o centro dela vira o ponto
     * base. Nada lê a posição do aparelho nem consulta serviço de endereço.
     */
    viewModel {
        val perfil = get<ServicoPerfil>()
        PontoBaseViewModel(
            opcoes = GeocodificadorDfOffline.REGIOES_ADMINISTRATIVAS.map { OpcaoDePontoBase(it.nome, it.centroide) },
            carregarPerfil = perfil::obterMeuPerfilProfissional,
            carregarFuncoes = get<ServicoVagas>()::listarFuncoes,
            criarPerfil = perfil::criarPerfilProfissional,
            atualizarPerfil = perfil::atualizarPerfilProfissional,
        )
    }
    /**
     * Funções e horários (Item #17 da Paridade, Lote B): o profissional vê e edita as funções exercidas
     * e a grade semanal de disponibilidade (7 dias, início e fim).
     */
    viewModel {
        val perfil = get<ServicoPerfil>()
        FuncoesEHorariosViewModel(
            carregarPerfil = perfil::obterMeuPerfilProfissional,
            carregarFuncoes = get<ServicoVagas>()::listarFuncoes,
            criarPerfil = perfil::criarPerfilProfissional,
            atualizarPerfil = perfil::atualizarPerfilProfissional,
        )
    }
    /**
     * Histórico de turnos e extrato (Item #32 da Paridade, Lote C).
     */
    viewModel {
        HistoricoDeTurnosViewModel(
            servicoTurnos = get<ServicoTurnos>(),
        )
    }
    /**
     * Por que recebo vagas (Item #34 da Paridade, Lote C): transparência dos critérios de notificação
     * e acompanhamento de revisão do despacho.
     */
    viewModel {
        val conta = get<ServicoConta>()
        PorQueReceboVagasViewModel(carregarCriterios = conta::criteriosDeNotificacao)
    }
    /**
     * Foto de perfil (L1-3): o detector e o preparo do JPEG são do aparelho (sem rede); só o envio fala com o servidor. O `Context` só é pedido
     * na hora de preparar a foto, para o grafo montar também onde não há `Context` (testes).
     */
    single<ConferidorDeRostoDaFoto> { ConferidorDeRostoDoAndroid() }
    single<PreparadorDaFotoDePerfil> {
        val escopo = this
        PreparadorDaFotoDePerfil { referencia -> PreparadorDeJpegDoAparelho(escopo.get<Context>()).preparar(referencia) }
    }
    viewModel {
        val fluxo = FluxoDaFotoDePerfil(get<ConferidorDeRostoDaFoto>(), get<ServicoMidia>())
        val preparador = get<PreparadorDaFotoDePerfil>()
        FotoDePerfilViewModel(prepararJpeg = preparador::preparar, enviar = fluxo::enviar)
    }
    /**
     * Código de chegada (L1-4b): o profissional digita o código que a casa mostra. A distância é medida no toque, até o ponto da vaga (só ela sai,
     * nunca a coordenada); `aoPresencaVerificada` avisa a tela para reler o turno.
     */
    viewModel { (turnoId: String, coordenadaDaVaga: Coordenada?, aoPresencaVerificada: (() -> Unit)?) ->
        val turnos = get<ServicoTurnos>()
        val localizacao = get<ProvedorDeLocalizacao>()
        ValidacaoDoCodigoViewModel(
            turnoId = turnoId,
            validar = turnos::validarCodigoCheckin,
            medirDistancia = { MedidorDeDistancia(localizacao, coordenadaDaVaga).medir() },
            aoPresencaVerificada = aoPresencaVerificada,
        )
    }
    /** Código de chegada, lado da casa (L1-5): `gerar_codigo_checkin`; `aoConfirmar` avisa a tela quando a presença foi verificada. */
    viewModel { (turnoId: String, aoConfirmar: (() -> Unit)?) ->
        CodigoDaCasaViewModel(turnoId = turnoId, gerar = get<ServicoTurnos>()::gerarCodigoCheckin, aoConfirmar = aoConfirmar)
    }
    /**
     * Lote 2 do Android (L2-8): as telas provisórias ligadas. Cada ViewModel recebe a chamada do serviço por função; os parâmetros vêm da rota.
     * L2-3: a casa cancela a vaga inteira e a republica (inteira ou só as posições que a seleção deixou vazias).
     */
    viewModel { (vagaId: String, inicioDaVaga: Instant?) ->
        CancelarVagaViewModel(vagaId = vagaId, inicioDaVaga = inicioDaVaga, cancelar = get<ServicoVagas>()::cancelarVaga)
    }
    viewModel { (vagaId: String, selecao: Boolean, duracaoOriginal: Duration) ->
        RepublicarVagaViewModel(vagaId = vagaId, selecao = selecao, duracaoOriginal = duracaoOriginal, republicar = get<ServicoVagas>()::republicarVaga)
    }
    viewModel { (vagaId: String, posicoesRestantes: Int, aoRepublicar: (String) -> Unit, aoMudarOPainel: () -> Unit) ->
        RepublicarPosicoesRestantesViewModel(
            vagaId = vagaId,
            posicoesRestantes = posicoesRestantes,
            republicar = get<ServicoVagas>()::republicarPosicoesRestantes,
            aoRepublicar = aoRepublicar,
            aoMudarOPainel = aoMudarOPainel,
        )
    }
    /** L2-4: a vaga aberta pelo id (`detalhe_vaga`); as candidaturas da conta e a retirada de uma (`aoRetirar` avisa a lista). */
    viewModel { (vagaId: String) -> AberturaDeVagaViewModel(vagaId = vagaId, buscarDetalhe = get<ServicoVagas>()::detalheVaga) }
    viewModel {
        val vagas = get<ServicoVagas>()
        MinhasCandidaturasViewModel(buscar = { vagas.minhasCandidaturas() })
    }
    viewModel { (candidaturaId: String, aoRetirar: () -> Unit) ->
        val vagas = get<ServicoVagas>()
        RetirarCandidaturaViewModel(
            candidaturaId = candidaturaId,
            retirar = vagas::retirarCandidatura,
            minhasCandidaturas = { vagas.minhasCandidaturas() },
            aoRetirar = aoRetirar,
            registrarEvento = get<RegistradorDeTelemetria>()::disparar,
        )
    }
    /** L2-5: a situação da conta e a contestação da suspensão (`aoReativar` reavalia a abertura); o pedido de revisão do despacho. */
    viewModel { (aoReativar: () -> Unit) ->
        val conta = get<ServicoConta>()
        ContaSuspensaViewModel(buscarSituacao = conta::situacaoDaConta, contestar = conta::contestarSuspensao, aoReativar = aoReativar)
    }
    viewModel { ContestarDespachoViewModel(pedirRevisao = get<ServicoConta>()::pedirRevisaoDespacho) }
    /** L2-6: bloqueios da conta (listar e desfazer) e "Incluir na equipe" do profissional que cumpriu turno. */
    viewModel {
        val confianca = get<ServicoConfianca>()
        BloqueiosViewModel(listar = confianca::listarBloqueios, desfazer = confianca::desbloquear)
    }
    viewModel { (estabelecimentoId: String, profissionalId: String) ->
        val confianca = get<ServicoConfianca>()
        IncluirNaEquipeViewModel(
            estabelecimentoId = estabelecimentoId,
            profissionalId = profissionalId,
            listar = confianca::equipeDeConfianca,
            incluirMembro = confianca::incluirNaEquipe,
        )
    }
    /** Chamada direta, lado do profissional (contrato 0.2.88): serviços com preço, preferências e chamada recebida. */
    viewModel {
        val chamadas = get<ServicoChamadaDireta>()
        val especialidades = get<ServicoDeEspecialidades>()
        EditarServicosViewModel(
            carregarPerfil = chamadas::meuPerfilDetalhado,
            listarEspecialidades = especialidades::especialidadesDaFuncao,
            definir = chamadas::definirServicos,
        )
    }
    viewModel {
        val chamadas = get<ServicoChamadaDireta>()
        PreferenciasChamadaViewModel(
            carregarPerfil = chamadas::meuPerfilDetalhado,
            definirPreferencias = chamadas::definirPreferenciaChamadas,
        )
    }
    viewModel { (chamadaId: String) ->
        val chamadas = get<ServicoChamadaDireta>()
        ChamadaRecebidaViewModel(
            chamadaId = chamadaId,
            detalhar = chamadas::detalheChamada,
            responder = chamadas::responderChamada,
        )
    }
}

val todosOsModulos = listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacao, moduloFeatures, moduloDestinoDaConta)
