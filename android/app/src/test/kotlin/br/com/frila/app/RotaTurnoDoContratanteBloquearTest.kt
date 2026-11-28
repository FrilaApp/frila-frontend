package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.dominio.modelo.AlvoBloqueado
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.MembroDaEquipeDto
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoConfianca
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.feature.equipe.IncluirNaEquipeViewModel
import br.com.frila.feature.equipe.TextosEquipe
import br.com.frila.feature.suporte.BloqueioDeAlvoViewModel
import br.com.frila.feature.suporte.TextosSuporte
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.contratante.TextosTurnoDoContratante
import io.mockk.mockk
import java.time.Instant
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * 0P4RwnNi: o turno visto pela casa oferece "Bloquear" avulso do profissional, ao lado de "Denunciar", como o iOS
 * (`TelaTurnoDoContratante.swift`, `segurancaDoProfissional`). O alvo é o `id` do perfil público (RN10); bloqueado, a tela diz uma vez
 * só "Você bloqueou este profissional"; a posição reatribuída a outro profissional não herda o bloqueio do anterior.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class RotaTurnoDoContratanteBloquearTest {

    // Sem ele, o build release não tem a ComponentActivity do createComposeRule no manifesto (como nos outros testes do :app).
    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val bloqueios = BloqueiosDaSessao()
    private val pedidosDeBloqueio = CopyOnWriteArrayList<Pair<String, String>>()
    private val denuncias = CopyOnWriteArrayList<Pair<String, String>>()
    private val agora = AtomicReference(Instant.parse("2026-11-12T22:00:00Z"))
    private val atualizacao = AtualizacaoAutomatica(
        sessao = { "vinculo-1" },
        relogio = { agora.get() },
        esperar = { duracao -> agora.updateAndGet { it.plus(duracao) } },
    )

    private fun perfil(id: String, nome: String) =
        PerfilPublicoDto(id, "profissional", nome, reputacao = ReputacaoDto(1, 1, null, 1, 1))

    private val ana = perfil("pr1", "Ana")
    private val bia = perfil("pr2", "Bia")

    /** O profissional que o painel devolve na posição p1: trocá-lo e reler é a posição reatribuída. */
    private val naPosicao = AtomicReference(ana)

    private fun painel() = PainelDto(
        estabelecimentoId = "est-1",
        checkinsPendentes = emptyList(),
        vagas = listOf(
            VagaNoPainelDto(
                vaga = VagaResumoDto("v1", "Garçom", "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
                modo = "urgencia", estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = 0,
                posicoes = listOf(
                    PosicaoNoPainelDto(
                        id = "p1", estado = "confirmada", turnoId = "t1", verificacao = "verificado", emAtraso = false,
                        checkinEm = "2026-11-12T21:02:00Z", checkinTipo = "manual", profissional = naPosicao.get(),
                    ),
                ),
            ),
        ),
    )

    private fun montar(comServicoDeConfianca: Boolean = true) {
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single { bloqueios }
                        single { atualizacao }
                        if (comServicoDeConfianca) single { mockk<ServicoConfianca>() }
                        viewModel { (contexto: ContextoDoTurnoContratante) ->
                            AcompanhamentoContratanteViewModel(
                                contexto = contexto, confirmar = { error("nao confirma") }, escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (estabelecimentoId: String, profissionalId: String) ->
                            IncluirNaEquipeViewModel(
                                estabelecimentoId = estabelecimentoId, profissionalId = profissionalId,
                                listar = { emptyList() },
                                incluirMembro = { e, p -> MembroDaEquipeDto(e, p) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        // Como o ModulosKoin: o alvo entra no conjunto da sessão só depois de o servidor confirmar.
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String) ->
                            BloqueioDeAlvoViewModel(
                                alvoTipo = alvoTipo,
                                alvoId = alvoId,
                                bloquear = { tipo, id ->
                                    bloqueios.registrandoAposSucesso(tipo, id) {
                                        pedidosDeBloqueio += tipo to id
                                        BloqueioDto(tipo, id, "2026-11-12T22:00:00Z")
                                    }
                                },
                                bloqueios = bloqueios,
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                    },
                )
            }) {
                RotaTurnoDoContratante(
                    estabelecimentoId = "est-1",
                    vagaId = "v1",
                    posicaoId = "p1",
                    buscarPainel = { _, _, _ -> Result.success(painel()) },
                    aoVoltar = {},
                    aoDenunciarProfissional = { profissionalId, turnoId -> denuncias += profissionalId to turnoId },
                )
            }
        }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Garçom").fetchSemanticsNodes().isNotEmpty() }
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size
    private fun existeTag(tag: String) = rule.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()

    private fun bloquear() {
        rule.onNodeWithTag("turno-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()
        rule.waitUntil(5_000) { existeTag("turno-bloqueado") }
    }

    @Test
    fun `Bloquear confirma e bloqueia o perfil publico do profissional, e a tela diz uma vez so que bloqueou`() {
        montar()
        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosEquipe.INCLUIR).fetchSemanticsNodes().isNotEmpty() }

        bloquear()

        assertEquals(listOf("profissional" to "pr1"), pedidosDeBloqueio.toList())
        rule.onNodeWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).performScrollTo().assertIsDisplayed()
        assertEquals(1, contar(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL))
        assertEquals(false, existeTag("turno-bloquear"))
        // D-14, do #1246: bloqueado, não se inclui na equipe.
        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosEquipe.INCLUIR).fetchSemanticsNodes().isEmpty() }
    }

    @Test
    fun `ja bloqueado na sessao, a tela diz uma vez so que bloqueou e nao oferece Bloquear`() {
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "pr1"))
        montar()

        rule.onNodeWithText(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL).performScrollTo().assertIsDisplayed()
        assertEquals(1, contar(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL))
        assertEquals(false, existeTag("turno-bloquear"))
        assertEquals(emptyList<Pair<String, String>>(), pedidosDeBloqueio.toList())
    }

    @Test
    fun `Denunciar fica uma so vez e leva o perfil e o turno`() {
        montar()

        assertEquals(1, contar(TextosSuporte.TITULO))
        rule.onNodeWithTag("turno-denunciar").performScrollTo().performClick()

        assertEquals(listOf("pr1" to "t1"), denuncias.toList())
    }

    @Test
    fun `a posicao reatribuida a outro profissional nao herda o bloqueio do anterior`() {
        montar()
        bloquear()

        naPosicao.set(bia)
        rule.runOnIdle { atualizacao.avisoChegou() }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Bia", substring = true).fetchSemanticsNodes().isNotEmpty() }

        rule.waitUntil(5_000) { existeTag("turno-bloquear") }
        assertEquals(0, contar(TextosTurnoDoContratante.VOCE_BLOQUEOU_PROFISSIONAL))
        rule.onNodeWithTag("turno-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()
        rule.waitUntil(5_000) { pedidosDeBloqueio.size == 2 }
        assertEquals(listOf("profissional" to "pr1", "profissional" to "pr2"), pedidosDeBloqueio.toList())
    }

    @Test
    fun `sem o servico de confianca no grafo, a tela segue so com Denunciar, como antes`() {
        montar(comServicoDeConfianca = false)

        rule.onNodeWithText(TextosTurnoDoContratante.DENUNCIAR).performScrollTo().assertIsDisplayed()
        assertEquals(1, contar(TextosTurnoDoContratante.DENUNCIAR))
        assertEquals(false, existeTag("turno-bloquear"))
    }
}
