package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import io.mockk.every
import io.mockk.mockk
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

private const val MENSAGEM_OFFLINE = "Sem conexão com a internet. Verifique sua rede."

private fun armazenamentoSemSessao(): ArmazenamentoDeSessao {
    val armazenamento = mockk<ArmazenamentoDeSessao>()
    every { armazenamento.estaAutenticado() } returns false
    // AppNavegacao constrói o GuardaBiometrico incondicionalmente, não só no ramo autenticado.
    every { armazenamento.isBiometriaAtivada() } returns false
    return armazenamento
}

/**
 * RNF01 (ressalva do Shisui, PR #604): prova que o banner de conectividade está de verdade
 * amarrado em [AppNavegacao] — não só no composable isolado [BannerDeConectividade] — para
 * matar os mutantes de "banner removido" e "status fixo".
 *
 * `KoinApplication(application = { modules(...) })` em vez de `startKoin`/`stopKoin` globais:
 * o `GlobalContext` do Koin é um singleton de JVM — MEDIDO: dois `@Test` usando `startKoin`/
 * `stopKoin` globais nesta suíte produziam `ClosedScopeException` de forma não-determinística
 * (ora na primeira classe, ora na segunda), porque o `Test` do Gradle reusa a mesma JVM para
 * várias classes de teste. `KoinApplication` cria uma instância de Koin isolada por composição,
 * via `CompositionLocal`, sem tocar o `GlobalContext` — elimina a interferência entre testes.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoWiringTest {

    @get:Rule
    val rule = createComposeRule()

    private fun conteudoDeTeste(monitorDeConectividade: MonitorDeConectividadeFalso) {
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        viewModel { EntradaViewModel(get()) }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamentoSemSessao(),
                    monitorDeConectividade = monitorDeConectividade,
                )
            }
        }
    }

    @Test
    fun `banner aparece quando AppNavegacao recebe monitor SEM_CONEXAO`() {
        conteudoDeTeste(MonitorDeConectividadeFalso(StatusConectividade.SEM_CONEXAO))

        rule.onNodeWithText(MENSAGEM_OFFLINE).assertExists()
    }

    @Test
    fun `banner nao aparece quando AppNavegacao recebe monitor CONECTADO`() {
        conteudoDeTeste(MonitorDeConectividadeFalso(StatusConectividade.CONECTADO))

        rule.onNodeWithText(MENSAGEM_OFFLINE).assertDoesNotExist()
    }
}
