package br.com.frila.app

import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ServicoConfianca
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.suporte.BloqueioDeAlvoViewModel
import br.com.frila.feature.suporte.BloqueiosViewModel
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.suporte.EstadoBloqueios
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import java.util.Base64
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

private val moduloLocalizacaoDoGrafoDosBloqueios = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

/**
 * I1PonzKJ, fatia 1: o grafo real liga os três escritores do bloqueio (denúncia, bloqueio avulso, desbloqueio) ao conjunto da
 * sessão, só depois de o servidor confirmar, e o ponto único de limpeza o esvazia no logout, na troca de conta e na expiração.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoBloqueiosDaSessaoTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val caminhos = CopyOnWriteArrayList<String>()
    private var servidorRecusa = false

    private val casa = "casa-1"

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val cliente = clienteSupabaseDeTeste(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                val caminho = request.url.encodedPath
                caminhos += caminho
                when {
                    servidorRecusa && (caminho.endsWith("rpc/bloquear") || caminho.endsWith("rpc/desbloquear")) ->
                        respond("""{"code":"erro","message":"x"}""", HttpStatusCode.InternalServerError, json)
                    caminho.endsWith("rpc/bloquear") || caminho.endsWith("rpc/desbloquear") ->
                        respond("""{"alvo_tipo":"estabelecimento","alvo_id":"$casa","criado_em":"2026-11-10T12:00:00Z"}""", HttpStatusCode.OK, json)
                    caminho.endsWith("rpc/listar_bloqueios") ->
                        respond("""[{"alvo_tipo":"estabelecimento","alvo_id":"$casa","nome":"Bar do Zé","criado_em":"2026-11-10T12:00:00Z"}]""", HttpStatusCode.OK, json)
                    else -> respond("{}", HttpStatusCode.OK, json)
                }
            },
        )
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoGrafoDosBloqueios, moduloFeatures) +
                    module { single { ServicoConfianca(cliente) } },
            )
        }
    }

    @AfterEach
    fun depois() {
        encerrarOsClientesDoTeste()
        stopKoin()
        Dispatchers.resetMain()
    }

    private fun esperar(condicao: () -> Boolean) {
        val limite = System.currentTimeMillis() + 5_000
        while (!condicao() && System.currentTimeMillis() < limite) Thread.sleep(20)
    }

    private fun avulso() = get<BloqueioDeAlvoViewModel> { parametersOf(TipoDeAlvo.ESTABELECIMENTO, casa) }

    private fun sessaoDe(pessoa: String): Sessao {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"$pessoa\"}".toByteArray())
        return Sessao("cabecalho.$corpo.assinatura-sintetica", "renovacao-teste", "bearer", 60, null)
    }

    private fun bloquearPeloAvulso() {
        val vm = avulso()
        vm.abrirDialogo()
        vm.confirmar()
        esperar { vm.estado.value.bloqueado }
    }

    @Test
    fun `bloquear pelo bloqueio avulso registra o alvo na sessao, e a tela nova do mesmo alvo ja nasce bloqueada`() {
        val sessao = get<BloqueiosDaSessao>()

        bloquearPeloAvulso()

        assertTrue(sessao.contem(TipoDeAlvo.ESTABELECIMENTO, casa))
        assertTrue(avulso().estado.value.bloqueado, "ao sair e voltar, o bloqueado nao pode reaparecer")
    }

    @Test
    fun `se o servidor recusa o bloqueio, nada e registrado e a tela nova nao nasce bloqueada`() {
        servidorRecusa = true
        val sessao = get<BloqueiosDaSessao>()
        val vm = avulso()

        vm.abrirDialogo()
        vm.confirmar()
        esperar { vm.estado.value.erro != null }

        assertTrue(vm.estado.value.erro != null, "esperava o erro do bloqueio")
        assertFalse(vm.estado.value.bloqueado)
        assertTrue(sessao.alvos.value.isEmpty())
        assertFalse(avulso().estado.value.bloqueado)
    }

    @Test
    fun `bloquear pela denuncia tambem registra o alvo na sessao`() {
        val sessao = get<BloqueiosDaSessao>()
        val vm = get<DenunciaViewModel> { parametersOf(TipoDeAlvo.ESTABELECIMENTO, casa, null, null, null) }

        vm.abrirDialogoBloqueio()
        vm.confirmarBloqueio()
        esperar { vm.estado.value.bloqueado }

        assertTrue(sessao.contem(TipoDeAlvo.ESTABELECIMENTO, casa))
        assertTrue(get<DenunciaViewModel> { parametersOf(TipoDeAlvo.ESTABELECIMENTO, casa, null, null, null) }.estado.value.bloqueado)
    }

    @Test
    fun `desbloquear pela lista remove o alvo da sessao, e se o servidor recusa ele continua bloqueado`() {
        val sessao = get<BloqueiosDaSessao>()
        bloquearPeloAvulso()
        val lista = get<BloqueiosViewModel>()
        lista.carregar()
        esperar { lista.estado.value.estado is EstadoBloqueios.Conteudo }
        val item = (lista.estado.value.estado as EstadoBloqueios.Conteudo).itens.single()

        servidorRecusa = true
        lista.desbloquear(item)
        esperar { lista.estado.value.mensagemErro != null }
        assertTrue(sessao.contem(TipoDeAlvo.ESTABELECIMENTO, casa), "a falha do desbloqueio nao pode soltar o bloqueado")

        servidorRecusa = false
        lista.desbloquear(item)
        esperar { !sessao.contem(TipoDeAlvo.ESTABELECIMENTO, casa) }
        assertFalse(sessao.contem(TipoDeAlvo.ESTABELECIMENTO, casa))
    }

    @Test
    fun `o logout esvazia os bloqueados da sessao pelo ponto unico de limpeza`() {
        val sessao = get<BloqueiosDaSessao>()
        bloquearPeloAvulso()
        assertEquals(1, sessao.alvos.value.size)

        get<ArmazenamentoDeSessao>().limparSessao()

        assertTrue(sessao.alvos.value.isEmpty())
    }

    @Test
    fun `a troca de conta esvazia os bloqueados, e o refresh da mesma conta nao`() {
        val armazenamento = get<ArmazenamentoDeSessao>()
        val sessao = get<BloqueiosDaSessao>()
        armazenamento.salvarSessao(sessaoDe("pessoa-a"))
        bloquearPeloAvulso()

        armazenamento.salvarSessao(sessaoDe("pessoa-a"))
        assertEquals(1, sessao.alvos.value.size, "o refresh da mesma conta preserva")

        armazenamento.salvarSessao(sessaoDe("pessoa-b"))
        assertTrue(sessao.alvos.value.isEmpty(), "outra conta nao herda os bloqueios da anterior")
    }

    @Test
    fun `a expiracao da sessao esvazia os bloqueados`() {
        val sessao = get<BloqueiosDaSessao>()
        bloquearPeloAvulso()

        get<CacheVagasDaSessao>().limpar()

        assertTrue(sessao.alvos.value.isEmpty())
    }
}
