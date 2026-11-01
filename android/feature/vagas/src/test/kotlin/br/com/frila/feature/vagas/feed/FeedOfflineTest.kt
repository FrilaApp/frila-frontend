package br.com.frila.feature.vagas.feed

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.hasAnyDescendant
import androidx.compose.ui.test.hasScrollAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.*
import io.mockk.mockk
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class FeedOfflineTest {
    @get:Rule val compose = createComposeRule()
    @get:Rule val temporarios = TemporaryFolder()
    private val aviso = "Exibindo vagas salvas. Disponibilidade não confirmada; conecte-se para verificar se ainda estão abertas."
    private val vaga = VagaAbertaDto(
        "vaga-teste", FuncaoDto("funcao", "Atendimento", "Salão"),
        PerfilPublicoDto("local", "estabelecimento", "Local sintético",
            reputacao = ReputacaoDto(0, 0, turnosConsiderados = 0, turnosRealizados = 0)),
        java.time.Instant.now().plusSeconds(3600).toString(), java.time.Instant.now().plusSeconds(7200).toString(), "Local de teste", "Região de teste",
        1.0, 12000, 1, InclusosDto(false, false, false), "selecao",
    )
    private fun semRede(): Nothing = throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "Teste")
    private fun localizacao(travada: Boolean = false) = object : ProvedorDeLocalizacao {
        override fun temPermissaoDeLocalizacao() = false
        override fun isGpsAtivado() = false
        override suspend fun obterCoordenadaAtual(): Coordenada? = if (travada) awaitCancellation() else null
    }
    private fun criarVm(repo: RepositorioVagas, escopo: CoroutineScope = CoroutineScope(Dispatchers.Default),
        gpsTravado: Boolean = false) = FeedVagasViewModel(
        mockk(relaxed = true), localizacao(gpsTravado), escopo = escopo, repositorioVagas = repo,
    )

    @Test fun `nova abertura offline le disco e exibe lista sem ficar carregando`() = runBlocking {
        val arquivo = File(temporarios.root, "vagas.json")
        RepositorioVagas(arquivo) { listOf(vaga) }.listar()
        val vm = criarVm(RepositorioVagas(arquivo) { semRede() })
        vm.carregar().join()
        assertEquals(StatusFeed.SUCESSO, vm.estado.value.status)
        assertEquals(listOf("vaga-teste"), vm.estado.value.vagas.map { it.id })
        assertTrue(vm.estado.value.emCache)
        assertEquals(vaga, vm.encontrarVagaPorId("vaga-teste"))
    }

    @Test fun `cache aparece antes de GPS responder e prazo permite fallback`() = runTest {
        val repo = RepositorioVagas(null) { listOf(vaga) }
        repo.listar()
        val vm = criarVm(repo, this, gpsTravado = true)
        val carga = vm.carregar()
        vm.estado.first { it.status == StatusFeed.SUCESSO }
        assertTrue(vm.estado.value.emCache)
        assertFalse(carga.isCompleted)
        advanceTimeBy(3_001)
        carga.join()
        assertFalse(vm.estado.value.emCache)
    }

    @Test fun `sem rede nem cache termina em erro explicito`() = runBlocking {
        val vm = criarVm(RepositorioVagas(null) { semRede() })
        vm.carregar().join()
        assertEquals(StatusFeed.ERRO, vm.estado.value.status)
        assertTrue(vm.estado.value.mensagemErro!!.contains("Sem conexão"))
    }

    @Test fun `indicador e vagas aparecem offline e swipe recupera dados online`() {
        val offline = AtomicBoolean(false)
        val chamadas = AtomicInteger(0)
        val repo = RepositorioVagas(null) {
            chamadas.incrementAndGet()
            if (offline.get()) semRede() else (0..11).map { indice ->
                vaga.copy(id = "vaga-$indice", estabelecimento = vaga.estabelecimento.copy(
                    nome = if (indice == 0) "Local sintético" else "Local de teste $indice"))
            }
        }
        runBlocking { repo.listar() }
        offline.set(true)
        val vm = criarVm(repo)
        runBlocking { vm.carregar().join() }
        compose.setContent { FrilaTheme { TelaFeedVagas(vm, {}) } }
        compose.onNodeWithText(aviso).assertIsDisplayed()
        compose.onNodeWithText("Vagas salvas").assertIsDisplayed()
        compose.onNodeWithText("Local sintético").assertIsDisplayed()
        offline.set(false)
        compose.onNode(hasScrollAction() and hasAnyDescendant(hasText("Local sintético"))).performTouchInput {
            swipeDown(startY = height * 0.1f, endY = height * 0.95f, durationMillis = 600)
        }
        compose.waitUntil(10_000) { chamadas.get() >= 3 && !vm.estado.value.emCache && !vm.estado.value.atualizando }
        compose.onNodeWithText(aviso).assertDoesNotExist()
        compose.onNodeWithText("Vagas abertas").assertIsDisplayed()
        compose.onNodeWithText("Local sintético").assertIsDisplayed()
    }
    @Test fun linceVagaEncerradaNaoApareceComoAbertaNoCache() = runBlocking {
        val expirada = vaga.copy(inicioEm = "2020-01-01T12:00:00Z", fimEm = "2020-01-01T18:00:00Z")
        assertTrue(java.time.Instant.parse(expirada.fimEm).isBefore(java.time.Instant.now()))
        val arquivo = File(temporarios.root, "expirada.json")
        RepositorioVagas(arquivo) { listOf(expirada) }.listar()
        val vm = criarVm(RepositorioVagas(arquivo) { semRede() })
        vm.carregar().join()
        assertTrue(vm.estado.value.emCache)
        assertTrue("Vaga encerrada ainda é exibida no feed de vagas abertas", vm.estado.value.vagas.isEmpty())
        assertNull(vm.encontrarVagaPorId(expirada.id))
    }


    @Test fun cacheExpiraNoFeedAbertoESaiDoDetalheSemNovaRequisicao() = runBlocking {
        // Relógio controlado com delay curto real: não avança o tempo virtual enquanto o disco usa IO.
        val instante = java.util.concurrent.atomic.AtomicReference(java.time.Instant.parse("2030-01-01T12:00:00Z"))
        val agora = { instante.get() }
        val encerrando = vaga.copy(fimEm = agora().plusMillis(20).toString())
        var offline = false
        val repo = RepositorioVagas(null, agora = agora) { if (offline) semRede() else listOf(encerrando) }
        repo.listar()
        offline = true
        val vm = FeedVagasViewModel(mockk(relaxed = true), localizacao(), escopo = CoroutineScope(Dispatchers.Default),
            repositorioVagas = repo, agora = agora)
        vm.carregar().join()
        assertEquals(1, vm.estado.value.vagas.size)
        instante.set(java.time.Instant.parse(encerrando.fimEm))
        kotlinx.coroutines.withTimeout(2_000) { vm.estado.first { it.vagas.isEmpty() } }
        assertNull(vm.encontrarVagaPorId(encerrando.id))
    }

    @Test fun invalidarLimpaVagasJaVisiveisENaoPermiteRepublicar() = runBlocking {
        val repo = RepositorioVagas(null) { listOf(vaga) }
        val vm = criarVm(repo)
        vm.carregar().join()
        assertEquals(1, vm.estado.value.vagas.size)
        repo.invalidar()
        assertTrue(vm.estado.value.vagas.isEmpty())
        assertNull(vm.encontrarVagaPorId(vaga.id))
        try { vm.carregar().join() } catch (_: kotlinx.coroutines.CancellationException) { }
        assertTrue(vm.estado.value.vagas.isEmpty())
    }

    @Test fun respostaOnlineRetiraVagaCanceladaDoFeedEDoDetalhe() = runBlocking {
        var resposta = listOf(vaga)
        val repo = RepositorioVagas(null) { resposta }
        val vm = criarVm(repo)
        vm.carregar().join()
        assertNotNull(vm.encontrarVagaPorId(vaga.id))
        resposta = emptyList()
        vm.atualizar().join()
        assertEquals(StatusFeed.VAZIO, vm.estado.value.status)
        assertNull(vm.encontrarVagaPorId(vaga.id))
        assertFalse(vm.estado.value.emCache)
        assertTrue(repo.obterCache()!!.vagas.isEmpty())
    }

}
