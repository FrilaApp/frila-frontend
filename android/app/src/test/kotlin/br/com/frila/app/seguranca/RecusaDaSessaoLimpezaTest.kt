package br.com.frila.app.seguranca

import android.app.Application
import br.com.frila.app.CacheVagasDaSessao
import br.com.frila.app.SessaoComCacheVagas
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.io.File
import java.nio.file.Files
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * #793 / PDr6NCVp: o refresh recusado pelo Auth (401 na chamada, 400 `invalid_grant` na renovação) tem de deixar o aparelho
 * como o Sair manual deixa. A fiação é a da produção (`ModulosKoin`): o cliente recebe o `SessaoComCacheVagas` e avisa a recusa
 * ao [CoordenadorDeLogout], que tem os mesmos diretórios, escopo da sessão e gestor do cliente. Antes da correção, depois da
 * recusa sobravam o cache de imagens, as fotos de ocorrência e os temporários, o escopo da sessão seguia vivo e o cliente era o
 * mesmo.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class RecusaDaSessaoLimpezaTest {

    private val sessao = Sessao("access-antigo", "refresh-antigo", "bearer", 3_600L, vinculoId = "v1")

    private class Aparelho(
        val raiz: File,
        val armazenamento: ArmazenamentoDeSessao,
        val coordenador: CoordenadorDeLogout,
        val gestor: GestorClienteKtor,
        val trabalhoDaSessao: Job,
    ) {
        val cache: File get() = raiz.resolve("cache")
        val arquivos: File get() = raiz.resolve("files")
        val semBackup: File get() = raiz.resolve("nobackup")

        /** Os caminhos que ainda existem, relativos à raiz, em ordem. */
        fun oQueSobrou(): List<String> =
            raiz.walkTopDown().filter { it.isFile }.map { it.relativeTo(raiz).path }.sorted().toList()
    }

    private fun montar(): Aparelho {
        val raiz = Files.createTempDirectory("aparelho").toFile()
        val cache = raiz.resolve("cache").apply { mkdirs() }
        val arquivos = raiz.resolve("files").apply { mkdirs() }
        val semBackup = raiz.resolve("nobackup").apply { mkdirs() }
        // O que é da conta: cache de imagem e de fotos de ocorrência, avatar, temporário, cache de vagas.
        cache.resolve("image_cache/foto-da-casa.png").apply { parentFile!!.mkdirs() }.writeText("png")
        cache.resolve("ocorrencia_t1.jpg").writeText("jpg")
        arquivos.resolve("avatar_perfil_1.jpg").writeText("jpg")
        arquivos.resolve("recorte.tmp").writeText("tmp")
        semBackup.resolve("vagas/cache.json").apply { parentFile!!.mkdirs() }.writeText("[]")
        // O que é do aparelho e fica: as preferências.
        arquivos.resolve("datastore/preferencias.preferences_pb").apply { parentFile!!.mkdirs() }.writeText("prefs")

        val armazenamento = SessaoComCacheVagas(
            ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao) },
            CacheVagasDaSessao(semBackup, diretorioDosAvatares = arquivos),
        )
        val escopoDaSessao = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val trabalho = escopoDaSessao.launch { awaitCancellation() }
        lateinit var coordenador: CoordenadorDeLogout
        val gestor = GestorClienteKtor {
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                armazenamentoDeSessao = armazenamento,
                aoRecusarSessao = { coordenador.encerrarAposRecusa() },
                engine = MockEngine { requisicao ->
                    if (requisicao.url.encodedPath == "/auth/v1/token") {
                        respond("""{"error":"invalid_grant","error_description":"Invalid Refresh Token"}""", HttpStatusCode.BadRequest)
                    } else {
                        respond("""{"code":"PGRST301","message":"JWT expired"}""", HttpStatusCode.Unauthorized, headersOf(HttpHeaders.WWWAuthenticate, "Bearer"))
                    }
                },
            )
        }
        coordenador = CoordenadorDeLogout(armazenamento, cache, arquivos, escopoDaSessao, gestor)
        return Aparelho(raiz, armazenamento, coordenador, gestor, trabalho)
    }

    private fun recusarORefresh(aparelho: Aparelho) = runBlocking {
        val cliente = aparelho.gestor.clienteAtual
        val resposta = cliente.http.get(cliente.urlRpc("minha_conta"))
        assertEquals("a chamada volta 401 para quem chamou", HttpStatusCode.Unauthorized, resposta.status)
    }

    private data class Estado(val sessao: Sessao?, val arquivos: List<String>, val trabalhoCancelado: Boolean, val clienteRecriado: Boolean)

    private fun estadoDepois(aparelho: Aparelho, clienteAntes: ClienteSupabase) = Estado(
        sessao = aparelho.armazenamento.obterSessao(),
        arquivos = aparelho.oQueSobrou(),
        trabalhoCancelado = aparelho.trabalhoDaSessao.isCancelled,
        clienteRecriado = aparelho.gestor.clienteAtual !== clienteAntes,
    )

    @Test
    fun `refresh recusado deixa o aparelho como o Sair manual`() {
        val pelaRecusa = montar()
        val clienteDaRecusa = pelaRecusa.gestor.clienteAtual
        recusarORefresh(pelaRecusa)
        val depoisDaRecusa = estadoDepois(pelaRecusa, clienteDaRecusa)

        val peloSair = montar()
        val clienteDoSair = peloSair.gestor.clienteAtual
        peloSair.coordenador.limparSessao()
        val depoisDoSair = estadoDepois(peloSair, clienteDoSair)

        assertEquals(depoisDoSair, depoisDaRecusa)
        assertEquals(listOf("files/datastore/preferencias.preferences_pb"), depoisDaRecusa.arquivos)
    }
}
