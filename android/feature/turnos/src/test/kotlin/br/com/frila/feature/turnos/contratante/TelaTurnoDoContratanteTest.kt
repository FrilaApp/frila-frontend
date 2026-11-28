package br.com.frila.feature.turnos.contratante

import android.view.View
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.runtime.mutableStateOf
import androidx.core.graphics.Insets
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.MotivoDeCancelamentoDaCasa
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class TelaTurnoDoContratanteTest {

    @get:Rule
    val rule = createComposeRule()

    @Test fun `cancelar posicao tem alvo minimo chama pedido e mostra aviso sem abrir dialogo`() {
        var pedidos = 0
        val aviso = "Sem conexão. O cancelamento será enviado quando a internet voltar."
        val inicial = estado().let { it.copy(
            contexto = it.contexto.copy(posicaoId = "posicao", estadoDaPosicao = "confirmada"),
            cancelamentoDisponivel = true, agora = { Instant.EPOCH }, avisoDoCancelamento = aviso,
        ) }
        rule.setContent { FrilaTheme {
            ConteudoTurnoDoContratante(inicial, AcoesTurnoDoContratante(aoPedirCancelamento = { pedidos++ }))
        } }
        rule.onNodeWithText("Cancelar posição").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        rule.runOnIdle { assertEquals(1, pedidos) }
        assertEquals(0, contar("Motivo"))
        rule.onNodeWithText(aviso).assertIsDisplayed()
    }

    @Test fun `posicao nao confirmada ou na fila esconde cancelamento`() {
        val inicial = estado().let { it.copy(
            contexto = it.contexto.copy(posicaoId = "posicao", estadoDaPosicao = "aberta"),
            cancelamentoDisponivel = true, agora = { Instant.EPOCH },
        ) }
        val tela = mutableStateOf(inicial)
        rule.setContent { FrilaTheme { ConteudoTurnoDoContratante(tela.value, AcoesTurnoDoContratante()) } }
        assertEquals(0, contar("Cancelar posição"))
        rule.runOnIdle { tela.value = inicial.copy(
            contexto = inicial.contexto.copy(estadoDaPosicao = "confirmada"), cancelamentoNaFila = true,
        ) }
        assertEquals(0, contar("Cancelar posição"))
    }

    private val ana = PerfilPublicoDto("p1", "profissional", "Ana", listOf("garçom", "barman"), ReputacaoDto(1, 1, null, 1, 1))

    private fun estado(
        verificacao: String? = null,
        checkinTipo: String? = null,
        checkinEm: Instant? = null,
        aCaminhoEm: Instant? = null,
        emAtraso: Boolean = false,
        profissional: PerfilPublicoDto? = ana,
        enviando: Boolean = false,
        aviso: AvisoDaConfirmacao? = null,
        fim: String = "2026-11-13T03:00:00Z",
    ) = EstadoTurnoDoContratante(
        contexto = ContextoDoTurnoContratante(
            turnoId = "t1", funcao = "Garçom", local = "SQN 108", inicio = Instant.parse("2026-11-12T21:00:00Z"),
            fim = Instant.parse(fim), profissional = profissional, aCaminhoEm = aCaminhoEm, checkinEm = checkinEm,
            checkinTipo = checkinTipo, verificacao = verificacao, emAtraso = emAtraso,
        ),
        enviando = enviando,
        aviso = aviso,
    )

    private class Chamadas {
        var confirmou = 0
        var voltou = 0
    }

    private fun montar(estado: EstadoTurnoDoContratante, chamadas: Chamadas = Chamadas()): Chamadas {
        rule.setContent {
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estado = estado,
                    acoes = AcoesTurnoDoContratante(aoConfirmarPresenca = { chamadas.confirmou++ }, aoVoltar = { chamadas.voltou++ }),
                )
            }
        }
        return chamadas
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `mostra funcao, horario no fuso de Brasilia, local e o cartao do profissional`() {
        montar(estado())

        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText("12/11/2026 18:00 – 13/11/2026 00:00").assertIsDisplayed()
        rule.onNodeWithText("SQN 108").assertIsDisplayed()
        rule.onNodeWithText("Ana").assertIsDisplayed()
        rule.onNodeWithText("Funções: garçom, barman").assertIsDisplayed()
    }

    @Test
    fun `horario de um dia so fica numa linha`() {
        montar(estado(fim = "2026-11-13T00:00:00Z"))

        rule.onNodeWithText("12/11/2026, 18:00 – 21:00").assertIsDisplayed()
    }

    @Test
    fun `sem profissional confirmado a posicao diz isso`() {
        montar(estado(profissional = null))

        rule.onNodeWithText(TextosTurnoDoContratante.SEM_PROFISSIONAL).assertIsDisplayed()
    }

    @Test
    fun `aguardando mostra so o texto, sem botao`() {
        montar(estado())

        rule.onNodeWithText(TextosTurnoDoContratante.AGUARDANDO).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
    }

    @Test
    fun `a caminho mostra o horario do aviso`() {
        montar(estado(aCaminhoEm = Instant.parse("2026-11-12T20:40:00Z")))

        rule.onNodeWithText("Ana está a caminho desde as 17:40.").assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
    }

    @Test
    fun `atraso mostra o alerta e nao oferece confirmar`() {
        montar(estado(emAtraso = true))

        rule.onNodeWithText(TextosTurnoDoContratante.EM_ATRASO).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
    }

    @Test
    fun `check-in manual pendente mostra a hora e o botao confirmar presenca com alvo minimo`() {
        val chamadas = montar(estado(verificacao = "pendente", checkinTipo = "manual", checkinEm = Instant.parse("2026-11-12T21:02:00Z")))

        rule.onNodeWithText("Ana fez o check-in às 18:02. Confirme a presença para ela contar.").assertIsDisplayed()
        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA)
            .assertIsEnabled()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, chamadas.confirmou)
    }

    @Test
    fun `check-in pendente sem a hora usa o texto sem hora`() {
        montar(estado(verificacao = "pendente", checkinTipo = "manual"))

        rule.onNodeWithText("Ana fez o check-in. Confirme a presença para ela contar.").assertIsDisplayed()
    }

    @Test
    fun `enquanto confirma o botao mostra confirmando e fica desabilitado`() {
        montar(estado(verificacao = "pendente", checkinTipo = "manual", enviando = true))

        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMANDO).assertIsNotEnabled()
    }

    @Test
    fun `presenca verificada mostra o selo e nao oferece confirmar`() {
        montar(estado(verificacao = "verificado", checkinTipo = "manual"))

        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
    }

    @Test
    fun `presenca nao verificada e dita em texto`() {
        montar(estado(verificacao = "nao_verificado", checkinTipo = "geolocalizado"))

        rule.onNodeWithText(TextosTurnoDoContratante.NAO_VERIFICADA).assertIsDisplayed()
    }

    @Test
    fun `aviso de erro e de sucesso da confirmacao sao mostrados`() {
        montar(estado(verificacao = "pendente", checkinTipo = "manual", aviso = AvisoDaConfirmacao.SEM_REDE))
        rule.onNodeWithText(TextosTurnoDoContratante.ERRO_SEM_REDE).assertIsDisplayed()
    }

    @Test
    fun `aviso de presenca confirmada aparece junto ao selo`() {
        montar(estado(verificacao = "verificado", checkinTipo = "manual", aviso = AvisoDaConfirmacao.CONFIRMADA_AGORA))

        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMADA_AGORA).assertIsDisplayed()
        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertIsDisplayed()
    }

    @Test
    fun `voltar chama o callback`() {
        val chamadas = montar(estado())

        rule.onNodeWithContentDescription(TextosTurnoDoContratante.ROTULO_VOLTAR).performClick()

        assertEquals(1, chamadas.voltou)
    }

    @Test
    fun `C0-9 - Denunciar leva o id do profissional e o do turno, com rotulo e alvo de toque como o iOS`() {
        val denuncias = mutableListOf<Pair<String, String>>()
        rule.setContent {
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estado = estado(),
                    acoes = AcoesTurnoDoContratante(aoDenunciarProfissional = { profissional, turno -> denuncias += profissional to turno }),
                )
            }
        }

        rule.onNodeWithContentDescription("Denunciar Ana").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(listOf("p1" to "t1"), denuncias)
    }

    @Test
    fun `C0-9 - posicao sem profissional confirmado nao tem quem denunciar`() {
        rule.setContent {
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estado = estado(profissional = null),
                    acoes = AcoesTurnoDoContratante(aoDenunciarProfissional = { _, _ -> error("não há quem denunciar") }),
                )
            }
        }

        rule.onNodeWithText(TextosTurnoDoContratante.SEM_PROFISSIONAL).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.DENUNCIAR))
    }

    @Test
    fun `a tela ligada ao ViewModel confirma a presenca pelo servico e passa a mostrar o selo`() {
        val chamados = mutableListOf<String>()
        val vm = AcompanhamentoContratanteViewModel(
            contexto = estado(verificacao = "pendente", checkinTipo = "manual").contexto,
            confirmar = { id ->
                chamados += id
                Result.success(br.com.frila.core.rede.ResultadoRegistroDto(id, "manual", "verificado", "2026-11-12T21:05:00Z"))
            },
            escopo = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined),
        )
        var voltou = 0
        rule.setContent { FrilaTheme { TelaTurnoDoContratante(viewModel = vm, aoVoltar = { voltou++ }) } }

        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).performClick()
        rule.onNodeWithContentDescription(TextosTurnoDoContratante.ROTULO_VOLTAR).performClick()

        assertEquals(listOf("t1"), chamados)
        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
        assertEquals(1, voltou)
    }

    // ── A folha de motivos da casa (Vmfnk4gQ) ─────────────────────────────────────────────────────────────────────────

    private fun estadoComFolha(motivo: MotivoDeCancelamentoDaCasa? = null, detalhes: String = "") = estado().let {
        it.copy(
            contexto = it.contexto.copy(posicaoId = "posicao", estadoDaPosicao = "confirmada"),
            cancelamentoDisponivel = true, agora = { Instant.EPOCH },
            pedindoCancelamento = true, motivoDoCancelamento = motivo, detalhesDoCancelamento = detalhes,
        )
    }

    private class Escolhas {
        val motivos = mutableListOf<MotivoDeCancelamentoDaCasa>()
        var confirmou = 0
        var desistiu = 0
    }

    private fun montarFolha(estado: EstadoTurnoDoContratante): Escolhas {
        val escolhas = Escolhas()
        rule.setContent { FrilaTheme {
            ConteudoTurnoDoContratante(estado, AcoesTurnoDoContratante(
                aoEscolherMotivoDoCancelamento = { escolhas.motivos += it },
                aoConfirmarCancelamento = { escolhas.confirmou++ },
                aoDesistir = { escolhas.desistiu++ },
            ))
        } }
        return escolhas
    }

    @Test
    fun `a folha lista os motivos da casa e escolher um chama a acao com ele`() {
        val escolhas = montarFolha(estadoComFolha())

        MotivoDeCancelamentoDaCasa.entries.forEach { rule.onNodeWithText(it.texto).assertIsDisplayed() }
        rule.onNodeWithText("Movimento menor que o esperado").performClick()

        rule.runOnIdle { assertEquals(listOf(MotivoDeCancelamentoDaCasa.MOVIMENTO_MENOR), escolhas.motivos) }
    }

    @Test
    fun `sem motivo escolhido o confirmar fica desabilitado, com motivo fica habilitado e confirma`() {
        val sem = montarFolha(estadoComFolha())
        rule.onNodeWithText("Confirmar cancelamento").assertIsNotEnabled()
        rule.runOnIdle { assertEquals(0, sem.confirmou) }
    }

    @Test
    fun `com um motivo o confirmar habilita e chama a acao`() {
        val escolhas = montarFolha(estadoComFolha(motivo = MotivoDeCancelamentoDaCasa.MOVIMENTO_MENOR))
        rule.onNodeWithText("Confirmar cancelamento").assertIsEnabled().performClick()
        rule.runOnIdle { assertEquals(1, escolhas.confirmou) }
    }

    @Test
    fun `Outro motivo pede o detalhe e fica travado sem ele`() {
        montarFolha(estadoComFolha(motivo = MotivoDeCancelamentoDaCasa.OUTRO))

        rule.onNodeWithText("Descreva o motivo (pelo menos 3 caracteres)").assertExists()
        rule.onNodeWithText("Confirmar cancelamento").assertIsNotEnabled()
    }

    @Test
    fun `Outro motivo com o detalhe habilita o confirmar`() {
        montarFolha(estadoComFolha(motivo = MotivoDeCancelamentoDaCasa.OUTRO, detalhes = "Fechamos mais cedo"))
        rule.onNodeWithText("Confirmar cancelamento").assertIsEnabled()
    }

    @Test
    fun `os outros motivos tem o detalhe opcional`() {
        montarFolha(estadoComFolha(motivo = MotivoDeCancelamentoDaCasa.PROBLEMA_NO_LOCAL))
        rule.onNodeWithText("Quer explicar melhor? (opcional)").assertExists()
    }

    @Test
    fun `Voltar desiste da folha`() {
        val escolhas = montarFolha(estadoComFolha())
        rule.onNodeWithText("Voltar").performClick()
        rule.runOnIdle { assertEquals(1, escolhas.desistiu) }
    }

    @Test
    @Config(sdk = [35], qualifiers = "w360dp-h480dp")
    fun `em janela pequena com Outro motivo escolhido, Confirmar cancelamento e Voltar ficam visiveis sem rolar`() {
        montarFolha(estadoComFolha(motivo = MotivoDeCancelamentoDaCasa.OUTRO))

        rule.onNodeWithText(TextosCancelarPosicao.CONFIRMAR).assertIsDisplayed()
        rule.onNodeWithText(TextosCancelarPosicao.VOLTAR).assertIsDisplayed()
    }

    @Test
    fun `a folha recua o titulo abaixo da barra de status`() {
        lateinit var view: View
        rule.setContent {
            view = LocalView.current
            FrilaTheme {
                ConteudoTurnoDoContratante(estadoComFolha(), AcoesTurnoDoContratante())
            }
        }

        val recuoPx = 48
        rule.runOnUiThread {
            val insets = WindowInsetsCompat.Builder()
                .setInsets(WindowInsetsCompat.Type.statusBars(), Insets.of(0, recuoPx, 0, 0))
                .build()
            ViewCompat.dispatchApplyWindowInsets(view, insets)
        }
        rule.waitForIdle()

        val topoTitulo = rule.onNodeWithText(TextosCancelarPosicao.TITULO).getUnclippedBoundsInRoot().top
        val recuoDp = with(rule.density) { recuoPx.toDp() }
        assertTrue("Esperado topo do título ($topoTitulo) >= recuo ($recuoDp)", topoTitulo >= recuoDp)
    }

    @Test
    @Config(sdk = [35], qualifiers = "w360dp-h640dp")
    fun `com teclado aberto, os botoes do rodape sobem e o campo de detalhe continua acima do rodape`() {
        lateinit var view: View
        rule.setContent {
            view = LocalView.current
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estadoComFolha(motivo = MotivoDeCancelamentoDaCasa.OUTRO)
                        .copy(avisoDoCancelamento = "Erro de teste junto ao botão"),
                    AcoesTurnoDoContratante(),
                )
            }
        }

        val tecladoPx = 240
        rule.runOnUiThread {
            val insets = WindowInsetsCompat.Builder()
                .setInsets(WindowInsetsCompat.Type.ime(), Insets.of(0, 0, 0, tecladoPx))
                .build()
            ViewCompat.dispatchApplyWindowInsets(view, insets)
        }
        rule.waitForIdle()

        val raiz = rule.onRoot().getUnclippedBoundsInRoot()
        val tecladoDp = with(rule.density) { tecladoPx.toDp() }
        val voltar = rule.onNodeWithText(TextosCancelarPosicao.VOLTAR).assertIsDisplayed()
        val confirmar = rule.onNodeWithText(TextosCancelarPosicao.CONFIRMAR).assertIsDisplayed()
        rule.onNodeWithText("Erro de teste junto ao botão").assertIsDisplayed()
        val detalhe = rule.onNodeWithText(TextosCancelarPosicao.DETALHES_OBRIGATORIOS)
            .performScrollTo()
            .assertIsDisplayed()

        assertTrue(
            "Voltar (${voltar.getUnclippedBoundsInRoot().bottom}) deveria subir acima do teclado (${raiz.bottom - tecladoDp})",
            voltar.getUnclippedBoundsInRoot().bottom <= raiz.bottom - tecladoDp,
        )
        assertTrue(
            "Campo do detalhe (${detalhe.getUnclippedBoundsInRoot().bottom}) deveria ficar acima do confirmar (${confirmar.getUnclippedBoundsInRoot().top})",
            detalhe.getUnclippedBoundsInRoot().bottom <= confirmar.getUnclippedBoundsInRoot().top,
        )
    }

    @Test
    fun `de ponta a ponta com o ViewModel real - escolher o motivo na folha e confirmar manda o texto do motivo`() {
        val enviados = mutableListOf<Pair<String, String>>()
        val viewModel = AcompanhamentoContratanteViewModel(
            contexto = estado().contexto.copy(posicaoId = "posicao", estadoDaPosicao = "confirmada"),
            confirmar = { error("não confirma") },
            escopo = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined),
            cancelar = { posicao, motivo ->
                enviados += posicao to motivo
                br.com.frila.core.dominio.modelo.ResultadoCancelamento("posicao", true, false)
            },
            relogio = { Instant.EPOCH },
        )
        rule.setContent { FrilaTheme { TelaTurnoDoContratante(viewModel = viewModel, aoVoltar = {}) } }

        rule.onNodeWithText("Cancelar posição").performClick()
        rule.onNodeWithText("Confirmar cancelamento").assertIsNotEnabled()
        rule.onNodeWithText("Movimento menor que o esperado").performClick()
        rule.onNodeWithText("Confirmar cancelamento").assertIsEnabled().performClick()
        rule.waitForIdle()

        assertEquals(listOf("posicao" to "Movimento menor que o esperado"), enviados)
    }

    // ── Turno já avaliado pela casa (QBAAgKth) ────────────────────────────────────────────────────────────────────────

    private fun montarAvaliacao(estado: EstadoTurnoDoContratante, avaliou: MutableList<String> = mutableListOf()): MutableList<String> {
        rule.setContent {
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estado = estado,
                    acoes = AcoesTurnoDoContratante(aoConfirmarPresenca = {}, aoVoltar = {}, aoAvaliarTurno = { avaliou += it }),
                )
            }
        }
        return avaliou
    }

    @Test
    fun `presenca verificada sem avaliacao oferece Avaliar turno e nao diz que avaliou`() {
        val avaliou = montarAvaliacao(estado(verificacao = "verificado", checkinTipo = "manual"))

        rule.onNodeWithText("Avaliar turno").performClick()
        assertEquals(listOf("t1"), avaliou)
        assertEquals(0, contar("Turno avaliado"))
        assertEquals(0, contar("Ver avaliação"))
    }

    @Test
    fun `turno ja avaliado mostra a resposta e Ver avaliacao no lugar de Avaliar turno`() {
        val avaliou = montarAvaliacao(estado(verificacao = "verificado", checkinTipo = "manual").copy(avaliacaoDoServidor = true))

        rule.onNodeWithText("Turno avaliado · Resposta: Sim").assertIsDisplayed()
        assertEquals("o convite some", 0, contar("Avaliar turno"))
        assertEquals(0, contar("Como foi sua experiência no turno?"))
        rule.onNodeWithText("Ver avaliação").performClick()
        assertEquals("Ver avaliação abre a mesma tela de avaliação", listOf("t1"), avaliou)
    }

    @Test
    fun `a resposta Nao e a avaliacao so na fila sem resposta do servidor tambem aparecem`() {
        montarAvaliacao(estado(verificacao = "verificado", checkinTipo = "manual").copy(avaliacaoNaFila = false))
        rule.onNodeWithText("Turno avaliado · Resposta: Não").assertIsDisplayed()
    }

    @Test
    fun `avaliado sem presenca verificada nao mostra o cartao`() {
        montarAvaliacao(estado(verificacao = "pendente", checkinTipo = "manual").copy(avaliacaoDoServidor = true))
        assertEquals(0, contar("Ver avaliação"))
        assertEquals(0, contar("Avaliar turno"))
    }

    // ── O efeito do cancelamento (Vmfnk4gQ, fatia 2) ──────────────────────────────────────────────────────────────────

    private fun efeitoNaFolha(agoraDoTurno: Instant, inicio: Instant?): String {
        val base = estadoComFolha()
        montarFolha(base.copy(contexto = base.contexto.copy(inicio = inicio), agora = { agoraDoTurno }))
        return rule.onNodeWithTag("efeito-do-cancelamento").fetchSemanticsNode().config
            .let { androidx.compose.ui.semantics.SemanticsProperties.Text.let { chave -> it[chave].joinToString("") { t -> t.text } } }
    }

    @Test
    fun `a folha antes do inicio diz que a posicao volta a ser oferecida`() {
        val agora = Instant.parse("2026-11-12T16:00:00Z")
        val texto = efeitoNaFolha(agora, inicio = Instant.parse("2026-11-12T21:00:00Z"))
        assertEquals(
            "Faltam 5 h para o início. A posição volta a ser oferecida a outros profissionais, e quem estava confirmado será avisado. " +
                "Não conta como falta para o profissional.",
            texto,
        )
    }

    @Test
    fun `a folha depois do inicio diz que nao reabre e o turno fica descoberto`() {
        val agora = Instant.parse("2026-11-12T22:00:00Z")
        val texto = efeitoNaFolha(agora, inicio = Instant.parse("2026-11-12T21:00:00Z"))
        assertEquals(
            "O turno já começou. A posição não será reaberta: o turno fica descoberto, e quem estava confirmado será avisado. " +
                "Não conta como falta para o profissional.",
            texto,
        )
    }

    // ── A avaliação só libera depois do fim previsto (rWpiTL8g) ───────────────────────────────────────────────────────

    /** 23:30 em UTC são 20:30 em São Paulo: a hora do aviso tem de sair no fuso do Frila. */
    private val fimDoTurno = Instant.parse("2026-11-12T23:30:00Z")

    private fun verificadoComRelogio(agora: () -> Instant) =
        estado(verificacao = "verificado", checkinTipo = "manual", fim = fimDoTurno.toString()).copy(agora = agora)

    @Test
    fun `antes do fim mostra quando a avaliacao libera, na hora de Sao Paulo, e nao oferece Avaliar turno`() {
        val avaliou = montarAvaliacao(verificadoComRelogio { fimDoTurno.minusSeconds(3_600) })

        rule.onNodeWithText("A avaliação libera às 20:30").assertIsDisplayed()
        assertEquals(0, contar("Avaliar turno"))
        assertEquals(0, contar("Como foi sua experiência no turno?"))
        assertEquals(emptyList<String>(), avaliou)
    }

    private fun verificarQueOfereceAvaliar(agora: Instant) {
        val avaliou = montarAvaliacao(verificadoComRelogio { agora })
        rule.onNodeWithText("Avaliar turno").performClick()
        assertEquals(listOf("t1"), avaliou)
        assertEquals(0, rule.onAllNodesWithTag("aviso-avaliacao-libera").fetchSemanticsNodes().size)
    }

    @Test
    fun `no fim previsto ja oferece Avaliar turno, sem o aviso`() = verificarQueOfereceAvaliar(fimDoTurno)

    @Test
    fun `depois do fim oferece Avaliar turno, sem o aviso`() = verificarQueOfereceAvaliar(fimDoTurno.plusSeconds(60))

    @Test
    fun `com a tela aberta, o aviso da lugar ao botao quando o fim passa`() {
        rule.mainClock.autoAdvance = false
        var agora = fimDoTurno.minusSeconds(600)
        montarAvaliacao(verificadoComRelogio { agora })
        rule.mainClock.advanceTimeByFrame()
        rule.onNodeWithText("A avaliação libera às 20:30").assertExists()
        assertEquals(0, contar("Avaliar turno"))

        agora = fimDoTurno.plusSeconds(1)
        rule.mainClock.advanceTimeBy(601_000)
        rule.mainClock.advanceTimeByFrame()

        rule.onNodeWithText("Avaliar turno").assertExists()
        assertEquals(0, rule.onAllNodesWithTag("aviso-avaliacao-libera").fetchSemanticsNodes().size)
    }

    private fun verificarCancelada(agora: Instant) {
        val base = verificadoComRelogio { agora }
        montarAvaliacao(base.copy(contexto = base.contexto.copy(estadoDaPosicao = "cancelada")))
        assertEquals(0, contar("Avaliar turno"))
        assertEquals(0, rule.onAllNodesWithTag("aviso-avaliacao-libera").fetchSemanticsNodes().size)
    }

    @Test
    fun `posicao cancelada antes do fim nao mostra o aviso`() = verificarCancelada(fimDoTurno.minusSeconds(3_600))

    @Test
    fun `posicao cancelada depois do fim nao oferece a avaliacao`() = verificarCancelada(fimDoTurno.plusSeconds(60))
}
