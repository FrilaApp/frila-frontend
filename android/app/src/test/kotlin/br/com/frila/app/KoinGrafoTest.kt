package br.com.frila.app

import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacao
import br.com.frila.core.notificacoes.ProcessadorDePush
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.rede.RepositorioVagas
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoConfianca
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoMembros
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
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.VerificacaoIdentidadeViewModel
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import io.mockk.mockk
import kotlinx.coroutines.launch
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertInstanceOf
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertSame
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get
import kotlin.reflect.full.memberProperties
import kotlin.reflect.jvm.isAccessible

/**
 * Prova que o grafo Koin monta sem faltar nenhuma dependência — cada `get<T>()` que falhasse
 * aqui falharia exatamente do mesmo jeito em produção, na primeira tela que precisasse de T.
 *
 * Roda sem `androidContext()`, de propósito (ver comentário em [moduloSeguranca]): isso prova
 * que `ArmazenamentoDeSessao`/`ArmazenamentoPreferenciasFiltro` continuam utilizáveis em JVM puro,
 * sem `Context`. `moduloLocalizacao` é o único módulo que exige um `Context` Android de verdade
 * (via `ProvedorDeLocalizacaoFused`), então aqui ele é substituído por [moduloLocalizacaoFalso],
 * que resolve `ProvedorDeLocalizacao` sem precisar de `Context`.
 */
private val moduloLocalizacaoFalso = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

class KoinGrafoTest : KoinTest {

    private val modulosDeTeste =
        listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoFalso, moduloFeatures, moduloDestinoDaConta)

    private val vagaDeTeste = VagaAbertaDto(
        id = "vaga-1",
        funcao = FuncaoDto(id = "f1", nome = "garçom", categoria = "Salão"),
        estabelecimento = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = "Bar do Zé",
            reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
        ),
        inicioEm = "2026-11-01T21:00:00Z",
        fimEm = "2026-11-02T03:00:00Z",
        local = "SQN 108",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 1.0,
        valorCentavos = 16_000,
        posicoesAbertas = 1,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
        modo = "selecao",
    )

    @AfterEach
    fun depoisDeCada() {
        stopKoin()
    }

    @Test
    fun `grafo resolve todas as dependencias de rede, seguranca, notificacoes e features`() {
        startKoin { modules(modulosDeTeste) }

        assertInstanceOf(ArmazenamentoDeSessaoEmMemoria::class.java, (get<ArmazenamentoDeSessao>() as SessaoComCacheVagas).origem)
        assertInstanceOf(LeitorDeAmbienteNulo::class.java, get<LeitorDeAmbiente>())
        assertInstanceOf(MonitorDeConectividadeFalso::class.java, get<MonitorDeConectividade>())
        assertNotNull(get<CoordenadorDeLogout>())
        assertNotNull(get<GestorClienteKtor>())
        assertNotNull(get<ClienteSupabase>())
        assertNotNull(get<ServicoAutenticacao>())
        assertNotNull(get<ServicoVagas>())
        assertNotNull(get<ServicoDispositivo>())
        assertNotNull(get<ProcessadorDePush>())
        // HaRJJ0L0: as rotas e o serviço de push usam getOrNull/inject; sem este registro a atualização automática some sem crash nem log.
        assertNotNull(get<AtualizacaoAutomatica>())

        assertNotNull(get<EntradaViewModel>())
        assertNotNull(get<CadastroViewModel>())
        val feed = get<FeedVagasViewModel>()
        val propriedadeCache = FeedVagasViewModel::class.memberProperties.single { it.name == "repositorioVagas" }
        propriedadeCache.isAccessible = true
        assertInstanceOf(RepositorioVagas::class.java, propriedadeCache.get(feed))
        assertNotNull(get<PerfilViewModel>())
        assertNotNull(get<VerificacaoIdentidadeViewModel>())
        assertNotNull(get<MeusTurnosViewModel>())
        assertNotNull(get<CodigoViewModel> { parametersOf("profissional@exemplo.com") })
        assertNotNull(get<DetalheVagaViewModel> { parametersOf(vagaDeTeste) })
        assertNotNull(get<CheckinViewModel> { parametersOf("turno-1", null) })
    }

    /** qmheBhAK: o repositório do feed recebe a página seguinte; sem ela o feed iria direto ao serviço e perderia a guarda da sessão. */
    @Test
    fun `o repositorio do feed do grafo pagina pela rede`() {
        startKoin { modules(modulosDeTeste) }

        val campo = RepositorioVagas::class.java.getDeclaredField("buscarPaginaNaRede").apply { isAccessible = true }
        assertNotNull(campo.get(get<RepositorioVagas>()))
    }

    @Test
    fun `ClienteSupabase e um singleton compartilhado entre os servicos`() {
        startKoin { modules(modulosDeTeste) }

        val primeiraResolucao = get<ClienteSupabase>()
        val segundaResolucao = get<ClienteSupabase>()

        assertNotNull(primeiraResolucao)
        assertSame(primeiraResolucao, segundaResolucao)
    }

    @Test
    fun `servicos de rede leem o cliente vigente depois do logout recriar o cliente`() {
        startKoin { modules(modulosDeTeste) }
        val gestor = get<GestorClienteKtor>()
        val servicos = listOf(
            get<ServicoAutenticacao>(), get<ServicoVagas>(), get<ServicoDispositivo>(),
            get<ServicoTurnos>(), get<ServicoPerfil>(), get<ServicoConfianca>(), get<ServicoMembros>(),
        )
        val antigo = gestor.clienteAtual

        get<CoordenadorDeLogout>().deslogar()

        assertTrue(antigo.estaFechado)
        val vigente = gestor.clienteAtual
        servicos.forEach { servico ->
            val propriedade = servico::class.memberProperties.single { it.name == "cliente" }
            propriedade.isAccessible = true
            val usado = propriedade.getter.call(servico)
            assertSame(vigente, usado, "${servico::class.simpleName} reteve cliente fechado")
        }
        assertSame(vigente, get<ClienteSupabase>())
    }

    @Test
    fun `logout em producao cancela corrotinas do escopo da sessao registrado no Koin`() = kotlinx.coroutines.runBlocking {
        startKoin { modules(modulosDeTeste) }
        val escopo = get<kotlinx.coroutines.CoroutineScope>(org.koin.core.qualifier.named(ESCOPO_DA_SESSAO))
        val job = escopo.launch { kotlinx.coroutines.delay(60_000) }

        val resultado = get<CoordenadorDeLogout>().deslogar()

        assertTrue(resultado.corrotinasCanceladas)
        job.join()
        assertTrue(job.isCancelled)
    }

    @Test
    fun `GerenciadorPreferenciasNotificacao e o mesmo singleton para PerfilViewModel e ProcessadorDePush`() {
        // MEDIDO (Shisui, PR #596, bloqueante): PerfilViewModel estava registrado com 3
        // argumentos no Koin, caindo no default GerenciadorPreferenciasNotificacaoEmMemoria()
        // criado dentro do ViewModel — uma instância DIFERENTE da que ProcessadorDePush recebia
        // do grafo. Desligar o switch na tela nunca chegava ao push real nem persistia.
        startKoin { modules(modulosDeTeste) }

        val doGrafo = get<GerenciadorPreferenciasNotificacao>()
        val viewModel = get<PerfilViewModel>()

        viewModel.definirNotificacaoAtivada(GerenciadorDeCanais.CANAL_TURNOS, false)

        assertFalse(doGrafo.estaAtivado(GerenciadorDeCanais.CANAL_TURNOS)) {
            "PerfilViewModel e o grafo Koin devem compartilhar a MESMA instância de " +
                "GerenciadorPreferenciasNotificacao — senão o switch na tela nunca silencia o push real."
        }

        val processador = get<ProcessadorDePush>()
        val resultado = processador.processar(mapOf("tipo" to "checkin"))
        assertTrue(resultado.silenciada) {
            "ProcessadorDePush deveria ver o canal_turnos desativado pelo mesmo gerenciador usado no PerfilViewModel."
        }
    }

    @Test
    fun `PerfilViewModel recebe o ServicoConta do grafo`() {
        // C0-4b: sem ele o perfil cai no padrão nulo do construtor e a conta de casa volta a "Não encontramos
        // seu perfil." (a mesma classe de bug do #596: um padrão do construtor no lugar da instância do grafo).
        startKoin { modules(modulosDeTeste) }

        assertSame(get<ServicoConta>(), propriedadePrivada(get<PerfilViewModel>(), "servicoConta"))
    }

    @Test
    fun `ServicoConta resolve so com moduloRede`() {
        startKoin { modules(moduloSeguranca, moduloRede) }

        assertNotNull(get<ServicoConta>())
    }

    @Test
    fun `o grafo carrega sem sobrescrever nenhuma definicao`() {
        // Uma definição repetida em dois módulos passa despercebida com o padrão do Koin (a última vence).
        startKoin {
            allowOverride(false)
            modules(modulosDeTeste)
        }

        assertNotNull(get<ServicoConta>())
    }

    private fun propriedadePrivada(instancia: Any, nome: String): Any? =
        instancia::class.memberProperties
            .first { it.name == nome }
            .apply { isAccessible = true }
            .call(instancia)
}
