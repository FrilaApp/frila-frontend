package br.com.frila.app

import android.app.Application
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.compose.LocalLifecycleOwner
import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import br.com.frila.core.dominio.regra.ListaAtualizavel
import java.io.File
import java.time.Duration
import java.time.Instant
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * HaRJJ0L0, fatia 2: a lista relê quando o app volta do segundo plano (a tela volta a `RESUMED`) depois de 30 s, não antes, e quando
 * chega um push da conta com a lista na tela. O ciclo de vida e o relógio são conduzidos pelo teste.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AtualizacaoAutomaticaDaListaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val agora = AtomicReference(Instant.parse("2026-11-27T12:00:00Z"))
    private var releituras = 0
    private var travada: kotlinx.coroutines.CompletableDeferred<Unit>? = null

    private val dono = object : LifecycleOwner {
        val registro = LifecycleRegistry.createUnsafe(this)
        override val lifecycle: Lifecycle get() = registro
    }

    private fun montar(conta: String? = "vinculo-1"): AtualizacaoAutomatica {
        val atualizacao = AtualizacaoAutomatica(
            sessao = { conta },
            relogio = { agora.get() },
            esperar = { duracao -> agora.updateAndGet { it.plus(duracao) } },
        )
        rule.runOnUiThread { dono.registro.currentState = Lifecycle.State.RESUMED }
        rule.setContent {
            CompositionLocalProvider(LocalLifecycleOwner provides dono) {
                AtualizacaoAutomaticaDaLista(ListaAtualizavel.VAGAS, atualizacao) { releituras++; travada?.await() }
            }
        }
        rule.waitForIdle()
        return atualizacao
    }

    private fun estado(novo: Lifecycle.State) {
        rule.runOnUiThread { dono.registro.currentState = novo }
        rule.waitForIdle()
    }

    private fun passar(segundos: Long) = agora.updateAndGet { it.plusSeconds(segundos) }

    @Test
    fun `a primeira vez que a tela fica ativa e a carga da propria tela e nao relê`() {
        montar()
        assertEquals(0, releituras)
    }

    @Test
    fun `voltar do segundo plano depois de 30 s rele, e antes de 30 s nao`() {
        montar()
        estado(Lifecycle.State.STARTED)
        passar(10)
        estado(Lifecycle.State.RESUMED)
        assertEquals("antes de 30 s não relê", 0, releituras)

        estado(Lifecycle.State.STARTED)
        passar(25)
        estado(Lifecycle.State.RESUMED)
        assertEquals("35 s depois da carga relê", 1, releituras)

        estado(Lifecycle.State.STARTED)
        passar(5)
        estado(Lifecycle.State.RESUMED)
        assertEquals("5 s depois da releitura não relê de novo", 1, releituras)
    }

    @Test
    fun `um push da conta rele a lista aberta mesmo dentro dos 30 s, esperando os 3 s da ultima`() {
        val atualizacao = montar()
        passar(5)
        atualizacao.avisoChegou()
        rule.waitForIdle()
        assertEquals(1, releituras)
    }

    @Test
    fun `um push com a lista escondida nao rele na hora, e a volta atende o aviso`() {
        val atualizacao = montar()
        estado(Lifecycle.State.STARTED)
        atualizacao.avisoChegou()
        rule.waitForIdle()
        assertEquals("escondida: nada", 0, releituras)
        passar(10)
        estado(Lifecycle.State.RESUMED)
        assertEquals("ao voltar atende o aviso, dentro do intervalo", 1, releituras)
    }

    @Test
    fun `sair da tela com a releitura em voo cancela e libera a vez da lista`() {
        val atualizacao = montar()
        travada = kotlinx.coroutines.CompletableDeferred()
        estado(Lifecycle.State.STARTED)
        passar(31)
        estado(Lifecycle.State.RESUMED)
        assertEquals("a releitura começou e está travada", 1, releituras)
        assertEquals(true, atualizacao.emVoo(ListaAtualizavel.VAGAS))

        estado(Lifecycle.State.STARTED)
        assertEquals("sair da tela libera a vez", false, atualizacao.emVoo(ListaAtualizavel.VAGAS))
    }

    @Test
    fun `sem conta nada e relido`() {
        val atualizacao = montar(conta = null)
        estado(Lifecycle.State.STARTED)
        passar(60)
        estado(Lifecycle.State.RESUMED)
        atualizacao.avisoChegou()
        rule.waitForIdle()
        assertEquals(0, releituras)
    }

    @Test
    fun `o intervalo curto do push espera o que falta e relê uma vez`() {
        val atualizacao = montar()
        // A carga da tela foi há 1 s: o push passa dos 30 s mas espera os 3 s.
        passar(1)
        atualizacao.avisoChegou()
        rule.waitForIdle()
        assertEquals(1, releituras)
        assertEquals("a espera avançou o relógio até os 3 s", Duration.ofSeconds(3), Duration.between(Instant.parse("2026-11-27T12:00:00Z"), agora.get()))
    }

    private fun fonte(relativo: String): String =
        listOf(File(relativo), File("app/$relativo"), File("../$relativo")).first { it.exists() }.readText()

    @Test
    fun `as rotas do feed e de Meus turnos ligam a atualizacao automatica, com a releitura em silencio de cada uma`() {
        val navegacao = fonte("src/main/kotlin/br/com/frila/app/AppNavegacao.kt")
        assertEquals(
            "o feed relê em silêncio",
            true,
            navegacao.contains("AtualizacaoAutomaticaDaLista(ListaAtualizavel.VAGAS, atualizacao) { viewModel.atualizarEmSilencio().join() }"),
        )
        assertEquals(
            "Meus turnos relê sem piscar",
            true,
            navegacao.contains("AtualizacaoAutomaticaDaLista(ListaAtualizavel.MEUS_TURNOS, atualizacao) { viewModel.atualizarSemPiscar().join() }"),
        )
    }

    @Test
    fun `o servico de push sinaliza as listas e o Koin registra o ponto central`() {
        val servico = fonte("../core/notificacoes/src/main/kotlin/br/com/frila/core/notificacoes/FrilaFirebaseMessagingService.kt")
        assertEquals(true, servico.contains("AvisoParaAtualizacao.sinalizar(notificacao, atualizacaoAutomatica)"))
        val koin = fonte("src/main/kotlin/br/com/frila/app/ModulosKoin.kt")
        assertEquals(true, koin.contains("single { AtualizacaoAutomatica(sessao = { get<ArmazenamentoDeSessao>().obterSessao()?.vinculoId }) }"))
    }

    @Test
    fun `as seis listas respeitam os 30 s, o push e a saida da tela, cada uma com a propria vez`() {
        val atualizacao = AtualizacaoAutomatica(
            sessao = { "vinculo-1" },
            relogio = { agora.get() },
            esperar = { duracao -> agora.updateAndGet { it.plus(duracao) } },
        )
        val contagem = ListaAtualizavel.entries.associateWith { 0 }.toMutableMap()
        rule.runOnUiThread { dono.registro.currentState = Lifecycle.State.RESUMED }
        rule.setContent {
            CompositionLocalProvider(LocalLifecycleOwner provides dono) {
                ListaAtualizavel.entries.forEach { lista ->
                    AtualizacaoAutomaticaDaLista(lista, atualizacao) { contagem[lista] = contagem.getValue(lista) + 1 }
                }
            }
        }
        rule.waitForIdle()
        assertEquals("a primeira ativação é a carga de cada tela", ListaAtualizavel.entries.associateWith { 0 }, contagem)

        estado(Lifecycle.State.STARTED)
        passar(10)
        estado(Lifecycle.State.RESUMED)
        assertEquals("antes de 30 s nenhuma relê", ListaAtualizavel.entries.associateWith { 0 }, contagem)

        estado(Lifecycle.State.STARTED)
        passar(25)
        estado(Lifecycle.State.RESUMED)
        assertEquals("depois de 30 s todas relêem uma vez", ListaAtualizavel.entries.associateWith { 1 }, contagem)

        passar(5)
        atualizacao.avisoChegou()
        rule.waitForIdle()
        assertEquals("o push relê todas", ListaAtualizavel.entries.associateWith { 2 }, contagem)
    }

    @Test
    fun `no modo NUNCA a primeira ativacao nao conta como carga, e so a volta do segundo plano e o push relêem`() {
        val atualizacao = AtualizacaoAutomatica(
            sessao = { "vinculo-1" },
            relogio = { agora.get() },
            esperar = { duracao -> agora.updateAndGet { it.plus(duracao) } },
        )
        rule.runOnUiThread { dono.registro.currentState = Lifecycle.State.RESUMED }
        rule.setContent {
            CompositionLocalProvider(LocalLifecycleOwner provides dono) {
                AtualizacaoAutomaticaDaLista(ListaAtualizavel.EQUIPE_DE_CONFIANCA, atualizacao, AtualizacaoAoAparecer.NUNCA) { releituras++ }
            }
        }
        rule.waitForIdle()
        assertEquals("a primeira ativação não relê", 0, releituras)

        // Sem carga registrada, não há intervalo a respeitar: a volta do segundo plano relê, mesmo 10 s depois.
        estado(Lifecycle.State.STARTED)
        passar(10)
        estado(Lifecycle.State.RESUMED)
        assertEquals(1, releituras)
    }

    @Test
    fun `as quatro rotas restantes ligam a atualizacao automatica, cada uma com a sua releitura em silencio`() {
        val navegacao = fonte("src/main/kotlin/br/com/frila/app/AppNavegacao.kt")
        listOf(
            "AtualizacaoAutomaticaDaLista(ListaAtualizavel.MINHAS_CANDIDATURAS, atualizacao) { viewModel.atualizarEmSilencio().join() }",
            "AtualizacaoAutomaticaDaLista(ListaAtualizavel.MINHAS_VAGAS, atualizacao) { viewModel.atualizarEmSilencio().join() }",
            "AtualizacaoAutomaticaDaLista(ListaAtualizavel.EQUIPE_DE_CONFIANCA, atualizacao, AtualizacaoAoAparecer.NUNCA) {",
        ).forEach { assertEquals(it, true, navegacao.contains(it)) }
        val contratante = fonte("src/main/kotlin/br/com/frila/app/ContratanteNavegacao.kt")
        assertEquals(true, contratante.contains("AtualizacaoAutomaticaDaLista(ListaAtualizavel.TURNO_DO_CONTRATANTE, atualizacao) {"))
        assertEquals("a falha deixa o turno na tela", true, contratante.contains("if (novo is EstadoDoTurnoDaRota.Pronto) estado = novo"))
    }
}
