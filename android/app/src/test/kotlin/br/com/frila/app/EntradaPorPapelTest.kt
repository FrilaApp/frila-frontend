package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.ComposeTimeoutException
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.codigo.CodigoViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import androidx.compose.ui.test.performScrollTo
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
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
 * Issues #782 e #783 (QA Android no dev, 16/11/2026): o app Android não olha o servidor para saber
 * quem é a conta, então (#782) conta que já existe cai em "Complete seu cadastro" depois do código e
 * (#783) a casa (contratante) abre o feed do profissional (`/rpc/vagas_abertas`), que o contrato
 * recusa com `422 perfil_incompativel`.
 *
 * O servidor aqui é um [MockEngine] que responde como o contrato (`iOS/Contrato/openapi.yaml`):
 * `minha_conta` 200 (ou 404 sem conta), `vagas_abertas` e `meu_perfil_profissional` com
 * `422 perfil_incompativel` para contratante, `meus_estabelecimentos` com `422 perfil_incompativel`
 * para profissional. As rotas vêm do grafo real ([AppNavegacao]); só os ViewModels de tela são
 * montados à mão. O destino da conta é decidido pelo servidor, como no iOS (`DestinoDaConta.avaliar`).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class EntradaPorPapelTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createAndroidComposeRule<ComponentActivity>()

    private lateinit var nav: NavHostController

    private enum class Papel { PROFISSIONAL, CONTRATANTE, CONTRATANTE_SEM_CASA, SEM_CONTA, SESSAO_VENCIDA }

    private val sessao = ArmazenamentoDeSessaoEmMemoria()

    /** Caminhos pedidos ao "servidor", na ordem. */
    private val chamadas = CopyOnWriteArrayList<String>()

    private val usuario = """{"id":"11111111-1111-4111-8111-111111111111","perfil":"%s","nome":"Conta Teste","telefone":"61999990000","email":"conta@exemplo.com","nascimento":"1990-01-01","estado":"ativa"}"""
    private val perfilProfissional = """{"id":"22222222-2222-4222-8222-222222222222","usuario_id":"11111111-1111-4111-8111-111111111111","funcoes":[],"disponibilidades":[],"reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}"""
    private val casa = """[{"id":"33333333-3333-4333-8333-333333333333","nome":"Bar Teste","papel":"administrador"}]"""

    private fun erro(codigo: String, status: HttpStatusCode) =
        """{"code":"$codigo","message":"$codigo","details":null}""" to status

    private fun servidor(papel: Papel) = MockEngine { requisicao ->
        val caminho = requisicao.url.encodedPath
        chamadas += caminho
        val (corpo, status) = when {
            caminho == "/auth/v1/verify" ->
                """{"access_token":"tok","refresh_token":"ref","token_type":"bearer","expires_in":3600}""" to HttpStatusCode.OK
            caminho.endsWith("/rpc/minha_conta") -> when (papel) {
                Papel.SEM_CONTA -> erro("nao_encontrado", HttpStatusCode.NotFound)
                Papel.SESSAO_VENCIDA -> erro("nao_autenticado", HttpStatusCode.Unauthorized)
                Papel.PROFISSIONAL -> usuario.format("profissional") to HttpStatusCode.OK
                Papel.CONTRATANTE, Papel.CONTRATANTE_SEM_CASA -> usuario.format("contratante") to HttpStatusCode.OK
            }
            caminho.endsWith("/rpc/situacao_da_conta") -> """{"estado":"ativa"}""" to HttpStatusCode.OK
            caminho.endsWith("/rpc/meu_perfil_profissional") -> when (papel) {
                Papel.PROFISSIONAL -> perfilProfissional to HttpStatusCode.OK
                Papel.CONTRATANTE, Papel.CONTRATANTE_SEM_CASA -> erro("perfil_incompativel", HttpStatusCode.UnprocessableEntity)
                else -> erro("nao_encontrado", HttpStatusCode.NotFound)
            }
            caminho.endsWith("/rpc/meus_estabelecimentos") -> when (papel) {
                Papel.CONTRATANTE -> casa to HttpStatusCode.OK
                Papel.CONTRATANTE_SEM_CASA -> "[]" to HttpStatusCode.OK
                else -> erro("perfil_incompativel", HttpStatusCode.UnprocessableEntity)
            }
            caminho.endsWith("/rpc/vagas_abertas") -> when (papel) {
                Papel.PROFISSIONAL -> "[]" to HttpStatusCode.OK
                // Contrato (`/rpc/vagas_abertas`): "conta de contratante recebe `422 perfil_incompativel`".
                else -> erro("perfil_incompativel", HttpStatusCode.UnprocessableEntity)
            }
            else -> erro("nao_encontrado", HttpStatusCode.NotFound)
        }
        respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
    }

    private val semLocalizacao = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = null
        override fun temPermissaoDeLocalizacao() = false
        override fun isGpsAtivado() = false
    }

    private fun montar(papel: Papel, comSessaoGuardada: Boolean) {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = servidor(papel))
        if (comSessaoGuardada) sessao.salvarSessao(Sessao("tok", "ref", "bearer", 3600))
        val servicoMembros = ServicoMembros(cliente)
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<br.com.frila.core.seguranca.ArmazenamentoDeSessao> { sessao }
                        single { ServicoVagas(cliente) }
                        single { ServicoPerfil(cliente) }
                        single { servicoMembros }
                        single {
                            val conta = ServicoConta(cliente)
                            val perfil = ServicoPerfil(cliente)
                            AvaliadorDeDestino(
                                descobrir = {
                                    avaliarDestinoDaConta(conta::minhaConta, perfil::obterMeuPerfilProfissional, servicoMembros::listarMeusEstabelecimentos)
                                },
                                guardado = DestinoGuardadoEmMemoria(),
                                // Este cliente não renova o token: o 401 do servidor já é a recusa (o caso da sessão vencida).
                                sessaoGuardada = { false },
                            )
                        }
                        viewModel { EntradaViewModel(ServicoAutenticacao(cliente), CoroutineScope(Dispatchers.Default)) }
                        viewModel { (email: String) ->
                            CodigoViewModel(email, ServicoAutenticacao(cliente), sessao, CoroutineScope(Dispatchers.Default))
                        }
                        viewModel { CadastroViewModel() }
                        viewModel { perfil }
                        viewModel {
                            br.com.frila.feature.estabelecimento.CadastroEstabelecimentoViewModel(
                                cadastrar = { error("o teste de navegação não cadastra") },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { FeedVagasViewModel(ServicoVagas(cliente), semLocalizacao) }
                        viewModel { br.com.frila.feature.turnos.MeusTurnosViewModel(br.com.frila.core.rede.ServicoTurnos { cliente }) }
                        viewModel { (id: String, nome: String?, recente: String?) ->
                            MinhasVagasViewModel(
                                estabelecimentoId = id,
                                nomeEstabelecimento = nome,
                                vagaRecemPublicadaId = recente,
                                buscarPainel = { estabelecimentoId, _, _ -> Result.success(PainelDto(estabelecimentoId, emptyList(), emptyList())) },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
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
                )
            }
        }
    }

    private fun rotaAtual(): String? {
        var rota: String? = null
        rule.runOnIdle { rota = nav.currentDestination?.route }
        return rota
    }

    /** Espera até [prazoMs] pela condição; devolve se ela ficou verdadeira (sem lançar). */
    private fun aguardar(prazoMs: Long = 4_000, condicao: () -> Boolean): Boolean =
        try {
            // runOnIdle roda a fila da thread principal: sem isso o ViewModel do feed só dispara quando outra coisa a esvazia.
            rule.waitUntil(prazoMs) { rule.runOnIdle { }; condicao() }
            true
        } catch (_: ComposeTimeoutException) {
            false
        }

    /** Entra pela tela de código, como a pessoa faz, e espera o app sair dela. */
    private fun entrarComCodigo(): String? {
        rule.runOnIdle { nav.navigate(Rotas.codigo("conta@exemplo.com")) }
        // Completar os 6 dígitos confirma sozinho (como o iOS): sem toque em "Confirmar código".
        rule.onNodeWithText("Código de 6 dígitos").performTextInput("123456")
        aguardar { rotaAtual() != Rotas.CODIGO && rotaAtual() != Rotas.ABERTURA }
        // Dá tempo de uma decisão que dependa do servidor terminar de rotear.
        aguardar(1_500) { rotaAtual() !in listOf(Rotas.CADASTRO, Rotas.CODIGO, Rotas.ABERTURA) }
        return rotaAtual()
    }

    // ───────────────────────── #782: depois do código ─────────────────────────

    @Test
    fun `controle - conta sem cadastro no servidor continua indo para o cadastro`() {
        montar(Papel.SEM_CONTA, comSessaoGuardada = false)

        val rota = entrarComCodigo()

        assertEquals(Rotas.CADASTRO, rota)
    }

    @Test
    fun `782 - profissional que ja tem conta nao cai em Complete seu cadastro depois do codigo`() {
        montar(Papel.PROFISSIONAL, comSessaoGuardada = false)

        val rota = entrarComCodigo()

        assertTrue(
            "o app nunca perguntou ao servidor se a conta existe (chamadas: $chamadas)",
            chamadas.any { it.endsWith("/rpc/minha_conta") },
        )
        assertNotEquals("conta existente caiu no cadastro local", Rotas.CADASTRO, rota)
        assertEquals(Rotas.FEED, rota)
    }

    @Test
    fun `782 - casa que ja tem conta nao cai em Complete seu cadastro depois do codigo`() {
        montar(Papel.CONTRATANTE, comSessaoGuardada = false)

        val rota = entrarComCodigo()

        assertNotEquals("conta existente caiu no cadastro local", Rotas.CADASTRO, rota)
        assertEquals("a casa abre Minhas vagas", Rotas.MINHAS_VAGAS, rota)
        assertFalse(
            "a casa nunca pede o feed do profissional (chamadas: $chamadas)",
            chamadas.any { it.endsWith("/rpc/vagas_abertas") },
        )
    }

    // ───────────────────── #783: tela inicial por papel ─────────────────────

    @Test
    fun `783 - casa com sessao guardada abre a tela da casa e nao o feed do profissional`() {
        montar(Papel.CONTRATANTE, comSessaoGuardada = true)

        // rotaInicial(): sessão válida sem biometria abre FEED para qualquer papel.
        aguardar(8_000) { chamadas.any { it.endsWith("/rpc/vagas_abertas") } || rotaAtual() == Rotas.MINHAS_VAGAS }

        assertFalse(
            "a casa pediu /rpc/vagas_abertas e recebeu 422 perfil_incompativel (chamadas: $chamadas)",
            chamadas.any { it.endsWith("/rpc/vagas_abertas") },
        )
        assertEquals(Rotas.MINHAS_VAGAS, rotaAtual())
    }

    @Test
    fun `controle - profissional com sessao guardada abre o feed e le as vagas`() {
        montar(Papel.PROFISSIONAL, comSessaoGuardada = true)

        val leu = aguardar(8_000) { chamadas.any { it.endsWith("/rpc/vagas_abertas") } }

        assertTrue("o feed do profissional deveria ler as vagas (rota: ${rotaAtual()}, chamadas: $chamadas)", leu)
        assertEquals(Rotas.FEED, rotaAtual())
    }

    @Test
    fun `C0-9 - do feed da profissional chega-se a Meus turnos`() {
        montar(Papel.PROFISSIONAL, comSessaoGuardada = true)
        aguardar(8_000) { rotaAtual() == Rotas.FEED && chamadas.any { it.endsWith("/rpc/vagas_abertas") } }

        rule.onNodeWithText("Meus turnos").performClick()

        assertTrue("o botão do feed não levou a Meus turnos (rota: ${rotaAtual()})", aguardar { rotaAtual() == Rotas.MEUS_TURNOS })
        assertEquals("Meus turnos abre por cima do feed", Rotas.FEED, rotaAbaixo())
    }

    // ───────────────── Revisão do #785: a casa nunca fica presa na tela inicial ─────────────────

    /** Rota imediatamente abaixo da atual na pilha (nulo se a atual é a raiz). */
    private fun rotaAbaixo(): String? {
        var rota: String? = null
        rule.runOnIdle { rota = nav.previousBackStackEntry?.destination?.route }
        return rota
    }

    private fun voltarDoSistema() {
        rule.runOnUiThread { rule.activity.onBackPressedDispatcher.onBackPressed() }
        rule.waitForIdle()
    }

    @Test
    fun `casa com sessao guardada alcanca o Perfil e o Sair a partir de Minhas vagas`() {
        montar(Papel.CONTRATANTE, comSessaoGuardada = true)
        aguardar(8_000) { rotaAtual() == Rotas.MINHAS_VAGAS }

        assertEquals(Rotas.MINHAS_VAGAS, rotaAtual())
        assertEquals("o Perfil (Sair, Equipe) fica embaixo da tela inicial da casa", Rotas.PERFIL, rotaAbaixo())

        // A seta de Minhas vagas leva ao Perfil, nunca a uma pilha vazia.
        rule.runOnUiThread { nav.popBackStack() }
        rule.waitForIdle()
        assertEquals(Rotas.PERFIL, rotaAtual())

        rule.onNodeWithText("Sair da conta").performScrollTo().performClick()
        rule.waitForIdle()
        assertEquals(Rotas.ENTRADA, rotaAtual())
    }

    @Test
    fun `casa com sessao guardada Voltar na raiz sai do app em vez de deixar tela em branco`() {
        montar(Papel.CONTRATANTE, comSessaoGuardada = true)
        aguardar(8_000) { rotaAtual() == Rotas.MINHAS_VAGAS }

        voltarDoSistema() // Minhas vagas -> Perfil
        assertEquals(Rotas.PERFIL, rotaAtual())
        assertFalse("ainda há tela para voltar", rule.activity.isFinishing)

        voltarDoSistema() // Perfil é a raiz: sai do app
        assertTrue("Voltar na raiz deve sair do app", rule.activity.isFinishing)
        assertEquals("a pilha nunca fica vazia", Rotas.PERFIL, rotaAtual())
    }

    @Test
    fun `casa sem estabelecimento abre o cadastro com o Perfil embaixo e Voltar nao esvazia a pilha`() {
        montar(Papel.CONTRATANTE_SEM_CASA, comSessaoGuardada = true)
        aguardar(8_000) { rotaAtual() == Rotas.CADASTRO_ESTABELECIMENTO }

        assertEquals(Rotas.CADASTRO_ESTABELECIMENTO, rotaAtual())
        assertEquals(Rotas.PERFIL, rotaAbaixo())

        voltarDoSistema()
        assertEquals(Rotas.PERFIL, rotaAtual())
        rule.onNodeWithText("Sair da conta").performScrollTo().assertExists()
    }

    // ───────────────── Revisão do #785: sessão vencida na abertura ─────────────────

    @Test
    fun `401 na abertura limpa a sessao e leva a Entrada em vez de ficar em Tentar novamente`() {
        montar(Papel.SESSAO_VENCIDA, comSessaoGuardada = true)

        val foiParaEntrada = aguardar(8_000) { rotaAtual() == Rotas.ENTRADA }

        assertTrue("sessão vencida prendeu a pessoa na abertura (rota: ${rotaAtual()})", foiParaEntrada)
        assertFalse("a sessão vencida deve ser limpa como no logout", sessao.estaAutenticado())
        rule.onNodeWithText("Bem-vindo ao Frila").assertExists()
    }
}

/** Destino guardado só em memória, para o teste não depender de arquivo nem de JWT. */
internal class DestinoGuardadoEmMemoria : DestinoGuardado {
    private var atual: DestinoDaConta? = null
    override fun obter() = atual
    override fun salvar(destino: DestinoDaConta) { atual = destino }
    override fun limpar() { atual = null }
}
