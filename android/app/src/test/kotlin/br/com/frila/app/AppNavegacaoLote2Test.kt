package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CandidaturaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.rede.VagaDto
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.conta.ContaSuspensaViewModel
import br.com.frila.feature.conta.ContestarDespachoViewModel
import br.com.frila.feature.conta.TextosContestarDespacho
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.equipe.IncluirNaEquipeViewModel
import br.com.frila.feature.equipe.TextosEquipe
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.suporte.BloqueiosViewModel
import br.com.frila.feature.suporte.TextosBloqueios
import br.com.frila.feature.turnos.EstadoMeusTurnos
import br.com.frila.feature.turnos.ItemTurno
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.StatusMeusTurnos
import br.com.frila.feature.turnos.TextosACaminho
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.vagas.candidaturas.MinhasCandidaturasViewModel
import br.com.frila.feature.vagas.candidaturas.RetirarCandidaturaViewModel
import br.com.frila.feature.vagas.candidaturas.TextosCandidaturas
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import br.com.frila.feature.vagas.painel.CancelarVagaViewModel
import br.com.frila.feature.vagas.painel.EstadoMinhasVagas
import br.com.frila.feature.vagas.painel.ItemMinhaVaga
import br.com.frila.feature.vagas.painel.ListaMinhasVagas
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.vagas.painel.RepublicarPosicoesRestantesViewModel
import br.com.frila.feature.vagas.painel.RepublicarVagaViewModel
import br.com.frila.feature.vagas.painel.SecaoMinhasVagas
import br.com.frila.feature.vagas.painel.TextosCancelarVaga
import br.com.frila.feature.vagas.painel.TextosRepublicarPosicoesRestantes
import br.com.frila.feature.vagas.painel.TextosRepublicarVaga
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * L2-8: as telas do Lote 2 ligadas na navegação. Cada teste chega à tela pelo app (rota, entrada ou botão) e confere que o ViewModel
 * recebeu o que a rota sabe. As telas são PROVISÓRIAS; aqui só se prova a fiação.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoLote2Test {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController

    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    // O que as rotas entregaram aos ViewModels.
    private val canceladas = mutableListOf<Pair<String, Instant?>>()
    private val republicadas = mutableListOf<Triple<String, Boolean, Duration>>()
    private val restantes = mutableListOf<Pair<String, Int>>()
    private val aberturas = mutableListOf<String>()
    private val detalhes = mutableListOf<Pair<String, VagaDto?>>()
    private val retiradas = mutableListOf<String>()
    private val incluidos = mutableListOf<Pair<String, String>>()
    private var reativar: (() -> Unit)? = null
    private var bloqueiosLidos = 0
    private var candidaturasLidas = 0

    private var detalheDoServidor: () -> VagaDto = { vagaDoServidor("vaga-9") }
    private var situacao = SituacaoDaContaDto(
        estado = "suspensa",
        suspensao = SuspensaoDaContaDto(motivo = "Assédio confirmado", desde = "2026-11-09T15:00:00Z"),
    )

    private val agora = Instant.now()

    private fun turnoConfirmado(inicio: Instant) = ItemTurno(
        turnoId = "t1", posicaoId = "p1", inicio = inicio, fim = inicio.plusSeconds(4 * 3_600), funcaoNome = "Garçom",
        estabelecimentoNome = "Bar do Zé", dataHorarioFormatado = "hoje", valorFormatado = "R$ 160,00", estado = "confirmada",
    )

    private val meusTurnos = mockk<MeusTurnosViewModel>(relaxed = true).also {
        every { it.estado } returns MutableStateFlow(
            EstadoMeusTurnos(status = StatusMeusTurnos.SUCESSO, agendados = listOf(turnoConfirmado(Instant.now().plusSeconds(3_600)))),
        )
    }

    private fun itemDaVaga(
        podeCancelar: Boolean = false,
        podeRepublicar: Boolean = false,
        republicavelEmUrgencia: Int = 0,
        selecao: Boolean = true,
    ) = ItemMinhaVaga(
        id = "v1", funcao = "Garçom", local = "SQN 108", inicio = agora.plusSeconds(2 * 86_400), fim = agora.plusSeconds(2 * 86_400 + 6 * 3_600),
        valorCentavos = 16_000, selecao = selecao, oculta = false, alertaVagaVazia = false, candidatosPendentes = 0, totalPosicoes = 3,
        confirmadas = 1, posicoesAbertas = 2, emAtraso = 0, secao = SecaoMinhasVagas.PROXIMAS, recemPublicada = false,
        podeVerCandidatos = false, comecaEm = null, podeCancelar = podeCancelar, podeRepublicar = podeRepublicar,
        republicavelEmUrgencia = republicavelEmUrgencia,
    )

    private var itensDeMinhasVagas = listOf(itemDaVaga())

    private fun candidatura(estado: String = "pendente") = CandidaturaDto(
        id = "c1", vaga = VagaResumoDto("v7", "Barman", "SQN 108", "Asa Norte", "2026-12-01T21:00:00Z", "2026-12-02T03:00:00Z", 16_000),
        estado = estado, criadaEm = "2026-11-17T12:00:00Z",
    )

    private fun painelComTurno(verificacao: String) = PainelDto(
        estabelecimentoId = "est-1", checkinsPendentes = emptyList(),
        vagas = listOf(
            VagaNoPainelDto(
                vaga = VagaResumoDto("v1", "Garçom", "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
                modo = "urgencia", estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = 0,
                posicoes = listOf(
                    PosicaoNoPainelDto(
                        id = "p1", estado = "confirmada", turnoId = "t1", verificacao = verificacao, emAtraso = false,
                        checkinEm = "2026-11-12T21:02:00Z", checkinTipo = "manual",
                        profissional = PerfilPublicoDto("pr1", "profissional", "Ana", reputacao = ReputacaoDto(1, 1, null, 1, 1)),
                    ),
                ),
            ),
        ),
    )

    private fun contratanteCom(id: String): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } returns listOf(EstabelecimentoDaContaDto(id = id, nome = "Bar $id", papel = "administrador"))
    }

    private fun profissional(): ServicoMembros = mockk {
        coEvery { listarMeusEstabelecimentos() } throws ErroDaApi(CodigoErroAPI.PERFIL_INCOMPATIVEL, "perfil_incompativel", null, "x")
    }

    private fun servicoDoPainel(verificacao: String): ServicoVagas = mockk {
        coEvery { painelEstabelecimento(any(), any(), any()) } returns Result.success(painelComTurno(verificacao))
    }

    private fun montar(inicio: String, servicoMembros: ServicoMembros? = null, servicoVagas: ServicoVagas? = null) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO)) }
        val minhasVagas = mockk<MinhasVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoMinhasVagas(lista = ListaMinhasVagas.Sucesso(itensDeMinhasVagas)))
            every { nomeEstabelecimento } returns "Bar est-1"
        }
        val escopo = CoroutineScope(Dispatchers.Unconfined)
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { feed }
                        viewModel { meusTurnos }
                        viewModel { (turnoId: String, ponto: Coordenada?) ->
                            CheckinViewModel(turnoId, ponto, mockk(relaxed = true), mockk(relaxed = true))
                        }
                        viewModel { (_: String, _: String?, _: String?) -> minhasVagas }
                        viewModel { (vagaId: String, inicioDaVaga: Instant?) ->
                            canceladas += vagaId to inicioDaVaga
                            CancelarVagaViewModel(vagaId, inicioDaVaga, cancelar = { _, _ -> error("o teste não cancela") }, escopo = escopo)
                        }
                        viewModel { (vagaId: String, selecao: Boolean, duracao: Duration) ->
                            republicadas += Triple(vagaId, selecao, duracao)
                            RepublicarVagaViewModel(vagaId, selecao, duracao, republicar = { _, _, _, _ -> error("o teste não republica") }, escopo = escopo)
                        }
                        viewModel { (vagaId: String, posicoes: Int, _: (String) -> Unit, _: () -> Unit) ->
                            restantes += vagaId to posicoes
                            RepublicarPosicoesRestantesViewModel(vagaId, posicoes, republicar = { _, _ -> error("o teste não republica") }, escopo = escopo)
                        }
                        viewModel { (vagaId: String) ->
                            aberturas += vagaId
                            AberturaDeVagaViewModel(vagaId, buscarDetalhe = { detalheDoServidor() }, escopo = escopo)
                        }
                        viewModel { params ->
                            val vaga = params.get<VagaAbertaDto>()
                            val detalhe = params.getOrNull<VagaDto>()
                            detalhes += vaga.id to detalhe
                            DetalheVagaViewModel(vaga, mockk<ServicoVagas>(relaxed = true), detalhe = detalhe, escopo = escopo)
                        }
                        viewModel {
                            MinhasCandidaturasViewModel(buscar = { candidaturasLidas++; listOf(candidatura()) }, escopo = escopo)
                        }
                        viewModel { (candidaturaId: String, aoRetirar: () -> Unit) ->
                            retiradas += candidaturaId
                            RetirarCandidaturaViewModel(
                                candidaturaId, retirar = { error("o teste não retira") }, minhasCandidaturas = { listOf(candidatura()) },
                                aoRetirar = aoRetirar, escopo = escopo,
                            )
                        }
                        viewModel {
                            BloqueiosViewModel(listar = { bloqueiosLidos++; emptyList() }, desfazer = { _, _ -> error("o teste não desbloqueia") }, escopo = escopo)
                        }
                        viewModel { ContestarDespachoViewModel(pedirRevisao = { error("o teste não contesta") }, escopo = escopo) }
                        viewModel { (aoReativar: () -> Unit) ->
                            reativar = aoReativar
                            ContaSuspensaViewModel(
                                buscarSituacao = { situacao }, contestar = { error("o teste não contesta") },
                                aoReativar = aoReativar, escopo = escopo,
                            )
                        }
                        viewModel { (estabelecimentoId: String, profissionalId: String) ->
                            incluidos += estabelecimentoId to profissionalId
                            IncluirNaEquipeViewModel(
                                estabelecimentoId, profissionalId, listar = { emptyList() },
                                incluirMembro = { _, _ -> error("o teste não inclui") }, escopo = escopo,
                            )
                        }
                        viewModel { (contexto: ContextoDoTurnoContratante) ->
                            AcompanhamentoContratanteViewModel(contexto = contexto, confirmar = { error("x") }, escopo = escopo)
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    servicoMembros = servicoMembros,
                    servicoVagas = servicoVagas,
                )
            }
        }
        rule.runOnIdle { nav.navigate(inicio) }
    }

    private fun rotaAtual() = nav.currentDestination?.route

    private fun esperarTexto(texto: String, substring: Boolean = false) {
        rule.waitUntil(5_000) { rule.onAllNodesWithText(texto, substring = substring).fetchSemanticsNodes().isNotEmpty() }
    }

    private fun esperarTag(tag: String) {
        rule.waitUntil(5_000) { rule.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty() }
    }

    // ---- 1. Estou a caminho (L2-1) ----

    @Test
    fun `em Meus turnos o turno confirmado dentro da janela mostra Estou a caminho e o toque chama o ViewModel`() {
        montar(Rotas.MEUS_TURNOS)

        esperarTexto(TextosACaminho.BOTAO)
        rule.onNodeWithText(TextosACaminho.BOTAO).performScrollTo().performClick()

        verify { meusTurnos.avisarACaminho(match { it.turnoId == "t1" }) }
    }

    @Test
    fun `no aviso do turno (frila meus_turnos id) o Estou a caminho tambem esta ligado`() {
        montar(Rotas.turnoAviso("t1"))

        esperarTexto(TextosACaminho.BOTAO)
        rule.onNodeWithText(TextosACaminho.BOTAO).performScrollTo().performClick()

        verify { meusTurnos.avisarACaminho(match { it.turnoId == "t1" }) }
    }

    // ---- 2. Reabrir vaga e 6. Incluir na equipe, no turno da casa ----

    @Test
    fun `no turno da casa com a presenca verificada o bloco Incluir na equipe aparece, para o profissional do turno`() {
        montar(Rotas.turnoDoContratante("est-1", "v1", "p1"), servicoVagas = servicoDoPainel("verificado"))

        esperarTexto(TextosEquipe.INCLUIR)

        assertEquals(listOf("est-1" to "pr1"), incluidos)
    }

    @Test
    fun `no turno da casa sem a presenca verificada nao se oferece Incluir na equipe`() {
        montar(Rotas.turnoDoContratante("est-1", "v1", "p1"), servicoVagas = servicoDoPainel("pendente"))

        esperarTexto("Ana")

        rule.onAllNodesWithText(TextosEquipe.INCLUIR).assertCountEquals(0)
        assertTrue(incluidos.isEmpty())
    }

    // ---- 3. Minhas vagas da casa: cancelar, republicar, restantes ----

    @Test
    fun `Cancelar vaga em Minhas vagas abre a tela de cancelamento com a vaga e o inicio dela`() {
        itensDeMinhasVagas = listOf(itemDaVaga(podeCancelar = true))
        montar(Rotas.minhasVagas("est-1", "Bar est-1"))

        esperarTexto(TextosCancelarVaga.TITULO)
        rule.onAllNodesWithText(TextosCancelarVaga.TITULO)[0].performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.CANCELAR_VAGA, rotaAtual())
            assertEquals("v1", canceladas.single().first)
            assertEquals(itensDeMinhasVagas.single().inicio, canceladas.single().second)
        }
    }

    @Test
    fun `Republicar vaga em Minhas vagas abre a tela com a vaga, o modo e a duracao da vaga de origem`() {
        itensDeMinhasVagas = listOf(itemDaVaga(podeRepublicar = true, selecao = true))
        montar(Rotas.minhasVagas("est-1", "Bar est-1"))

        esperarTexto(TextosRepublicarVaga.TITULO)
        rule.onAllNodesWithText(TextosRepublicarVaga.TITULO)[0].performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.REPUBLICAR_VAGA, rotaAtual())
            assertEquals(Triple("v1", true, Duration.ofHours(6)), republicadas.single())
        }
    }

    @Test
    fun `Republicar posicoes restantes abre a confirmacao na propria lista, com a quantidade da vaga`() {
        itensDeMinhasVagas = listOf(itemDaVaga(republicavelEmUrgencia = 2))
        montar(Rotas.minhasVagas("est-1", "Bar est-1"))

        val botao = TextosRepublicarPosicoesRestantes.botao(2)
        esperarTexto(botao)
        rule.onNodeWithText(botao).performScrollTo().performClick()

        esperarTexto(TextosRepublicarPosicoesRestantes.CONFIRMACAO_TITULO)
        rule.runOnIdle {
            assertEquals(Rotas.MINHAS_VAGAS, rotaAtual())
            assertEquals(listOf("v1" to 2), restantes)
        }
    }

    // ---- 4. A vaga abre pelo id; minhas candidaturas e retirar ----

    @Test
    fun `RN - o voltar do detalhe da vaga devolve a tela de onde a pessoa veio`() {
        montar(Rotas.detalhe("vaga-9"))
        esperarTexto("Chegar 15 minutos antes", substring = true)
        var rotaDeBaixo: String? = null
        rule.runOnIdle { rotaDeBaixo = nav.previousBackStackEntry?.destination?.route }
        assertNotNull("o teste precisa de uma tela embaixo do detalhe", rotaDeBaixo)

        rule.onNodeWithContentDescription("Voltar").performClick()

        rule.runOnIdle { assertEquals(rotaDeBaixo, rotaAtual()) }
    }

    @Test
    fun `RN - o voltar do detalhe aberto por link, sem tela embaixo, leva as vagas em vez de esvaziar a pilha`() {
        montar(Rotas.FEED)
        // Como um link que abre o app direto na vaga: o detalhe é a única tela da pilha.
        rule.runOnIdle { nav.navigate(Rotas.detalhe("vaga-9")) { popUpTo(0) { inclusive = true } } }
        esperarTexto("Chegar 15 minutos antes", substring = true)
        rule.runOnIdle { assertNull(nav.previousBackStackEntry) }

        rule.onNodeWithContentDescription("Voltar").performClick()

        rule.runOnIdle {
            assertEquals(Rotas.FEED, rotaAtual())
            assertNull("o detalhe não fica embaixo das vagas", nav.previousBackStackEntry)
        }
    }

    @Test
    fun `a vaga aberta pelo id, sem passar pelo feed, e lida do servidor e mostra o que so o servidor sabe`() {
        montar(Rotas.detalhe("vaga-9"))

        esperarTexto("Chegar 15 minutos antes", substring = true) // `observacoes` só vem no detalhe do servidor

        rule.runOnIdle {
            assertEquals(listOf("vaga-9"), aberturas)
            assertEquals("vaga-9", detalhes.single().first)
            assertEquals(vagaDoServidor("vaga-9"), detalhes.single().second)
        }
    }

    @Test
    fun `a vaga que o servidor nao conhece (404) abre como nao encontrada, nao como erro`() {
        detalheDoServidor = { throw ErroDaApi(CodigoErroAPI.NAO_ENCONTRADO, "nao_encontrado", null, "x") }
        montar(Rotas.detalhe("vaga-sumiu"))

        rule.waitUntil(5_000) { aberturas.isNotEmpty() }
        rule.runOnIdle { assertTrue(detalhes.isEmpty()) }
    }

    @Test
    fun `no feed a aba Candidaturas abre Minhas candidaturas e Retirar abre a pergunta`() {
        montar(Rotas.FEED)

        esperarTexto(TextosCandidaturas.TITULO)
        rule.onNodeWithText(TextosCandidaturas.TITULO).performClick()
        esperarTexto(TextosCandidaturas.RETIRAR)
        rule.onNodeWithText(TextosCandidaturas.RETIRAR).performScrollTo().performClick()

        esperarTexto(TextosCandidaturas.PERGUNTA_DA_RETIRADA)
        rule.runOnIdle {
            assertEquals(Rotas.MINHAS_CANDIDATURAS, rotaAtual())
            assertEquals(listOf("c1"), retiradas)
            assertTrue(candidaturasLidas >= 1)
        }
    }

    // ---- 5. Conta suspensa e contestar despacho ----

    @Test
    fun `a conta suspensa mostra o motivo e a data lidos do servidor, e reativar reavalia a abertura`() {
        montar(Rotas.contaSuspensa())

        esperarTexto("Assédio confirmado")
        rule.onAllNodesWithText("09/11/2026", substring = true)[0].assertExists()

        rule.runOnUiThread { reativar!!.invoke() }
        rule.waitUntil(5_000) { rotaAtual() != Rotas.CONTA_SUSPENSA }
        assertNotEquals(Rotas.CONTA_SUSPENSA, rotaAtual())
    }

    @Test
    fun `no perfil do profissional a entrada de contestar o despacho abre a tela, e a casa nao a ve`() {
        montar(Rotas.PERFIL, servicoMembros = profissional())
        esperarTag(ENTRADA_CONTESTAR_DESPACHO)
        rule.onNodeWithTag(ENTRADA_CONTESTAR_DESPACHO).performClick()

        esperarTexto(TextosContestarDespacho.EXPLICACAO)
        assertEquals(Rotas.CONTESTAR_DESPACHO, rotaAtual())
    }

    @Test
    fun `o perfil da casa nao mostra contestar despacho`() {
        montar(Rotas.PERFIL, servicoMembros = contratanteCom("est-1"))
        esperarTag("perfil-minhas-vagas") // as casas já carregaram: a conta é de contratante
        esperarTag(ENTRADA_BLOQUEIOS)

        rule.onAllNodesWithTag(ENTRADA_CONTESTAR_DESPACHO).assertCountEquals(0)
    }

    // ---- 6. Pessoas e locais bloqueados ----

    @Test
    fun `no perfil a entrada Pessoas e locais bloqueados abre a lista e le os bloqueios`() {
        montar(Rotas.PERFIL, servicoMembros = profissional())
        esperarTag(ENTRADA_BLOQUEIOS)
        rule.onNodeWithTag(ENTRADA_BLOQUEIOS).performClick()

        esperarTexto(TextosBloqueios.EXPLICACAO)
        rule.runOnIdle {
            assertEquals(Rotas.BLOQUEIOS, rotaAtual())
            assertTrue(bloqueiosLidos >= 1)
        }
    }

    @Test
    fun `a casa tambem tem a entrada de bloqueios no perfil`() {
        montar(Rotas.PERFIL, servicoMembros = contratanteCom("est-1"))

        esperarTag(ENTRADA_BLOQUEIOS)
    }
}
