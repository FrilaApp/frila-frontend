package br.com.frila.app

import br.com.frila.core.notificacoes.ProcessadorDePush
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import io.mockk.mockk
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertInstanceOf
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

/**
 * Prova que o grafo Koin monta sem faltar nenhuma dependência — cada `get<T>()` que falhasse
 * aqui falharia exatamente do mesmo jeito em produção, na primeira tela que precisasse de T.
 *
 * Roda sem `androidContext()`, de propósito (ver comentário em [moduloSeguranca]): isso prova
 * que `ArmazenamentoDeSessao`/`ArmazenamentoPreferenciasFiltro` continuam utilizáveis em JVM puro,
 * sem `Context`. `moduloLocalizacao` é o único módulo que exige um `Context` Android de verdade
 * (via `ProvedorDeLocalizacaoFused`), então aqui ele é substituído por [moduloLocalizacaoFalso],
 * que resolve `ProvedorDeLocalizacao` sem precisar de `Context` — preserva o resto do grafo
 * exatamente como era antes do RF05/RN02 (filtro por raio GPS) acrescentar essa dependência.
 */
private val moduloLocalizacaoFalso = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

class KoinGrafoTest : KoinTest {

    private val modulosDeTeste = listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoFalso, moduloFeatures)

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

        assertInstanceOf(ArmazenamentoDeSessaoEmMemoria::class.java, get<ArmazenamentoDeSessao>())
        assertNotNull(get<ClienteSupabase>())
        assertNotNull(get<ServicoAutenticacao>())
        assertNotNull(get<ServicoVagas>())
        assertNotNull(get<ServicoDispositivo>())
        assertNotNull(get<ProcessadorDePush>())

        assertNotNull(get<EntradaViewModel>())
        assertNotNull(get<CadastroViewModel>())
        assertNotNull(get<FeedVagasViewModel>())
        assertNotNull(get<CodigoViewModel> { parametersOf("profissional@exemplo.com") })
        assertNotNull(get<DetalheVagaViewModel> { parametersOf(vagaDeTeste) })
    }

    @Test
    fun `ClienteSupabase e um singleton compartilhado entre os servicos`() {
        startKoin { modules(modulosDeTeste) }

        val primeiraResolucao = get<ClienteSupabase>()
        val segundaResolucao = get<ClienteSupabase>()

        assertNotNull(primeiraResolucao)
        org.junit.jupiter.api.Assertions.assertSame(primeiraResolucao, segundaResolucao)
    }
}
