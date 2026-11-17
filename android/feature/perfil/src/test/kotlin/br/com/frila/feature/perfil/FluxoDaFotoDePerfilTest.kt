package br.com.frila.feature.perfil

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoMidia
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * L1-3a (decisão do O2, 17/11): o detector do Android é mais fraco que o Vision do iOS; por isso "sem rosto" só **avisa** e a pessoa pode enviar mesmo assim
 * (a moderação do servidor decide). Mais de um rosto e análise indisponível continuam barrando. Aqui o servidor é falso e conta o que chegou a ele.
 */
class FluxoDaFotoDePerfilTest {

    private val foto = byteArrayOf(1, 2, 3, 4)
    private val idDaMidia = "33333333-3333-3333-3333-333333333333"

    private class Chegou { val pedidos = mutableListOf<String>() }

    private fun servicoQueResponde(chegou: Chegou, falharNoConfirmar: Boolean = false): ServicoMidia {
        val engine = MockEngine { request ->
            chegou.pedidos += "${request.method.value} ${request.url.encodedPath}"
            val json = headersOf(HttpHeaders.ContentType, "application/json")
            when {
                request.url.encodedPath.endsWith("/solicitar_upload_midia") -> respond(
                    """{"midia_id":"$idDaMidia","upload_url":"https://frila.supabase.co/functions/v1/enviar-midia?midia_id=$idDaMidia&token=T","expira_em":"2026-11-17T05:00:00+00:00"}""",
                    HttpStatusCode.OK,
                    json,
                )
                request.method == HttpMethod.Put -> respond("", HttpStatusCode.OK)
                falharNoConfirmar -> respond("""{"code":"midia_invalida","message":"x","details":"formato"}""", HttpStatusCode.UnprocessableEntity, json)
                else -> respond("""{"id":"$idDaMidia","tipo":"foto_perfil","estado":"em_analise","pode_pedir_nova_analise":false}""", HttpStatusCode.OK, json)
            }
        }
        return ServicoMidia(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
    }

    private fun fluxo(resultado: ResultadoDaVerificacaoLocal, chegou: Chegou, falharNoConfirmar: Boolean = false) =
        FluxoDaFotoDePerfil({ resultado }, servicoQueResponde(chegou, falharNoConfirmar))

    private val tresPedidos = listOf(
        "POST /rest/v1/rpc/solicitar_upload_midia",
        "PUT /functions/v1/enviar-midia",
        "POST /rest/v1/rpc/confirmar_upload_midia",
    )

    @Test
    fun `foto com rosto liberada vai ao servidor`() = runBlocking {
        val chegou = Chegou()
        val saida = withTimeout(5_000) { fluxo(ResultadoDaVerificacaoLocal.Liberada, chegou).enviar(foto) }
        assertTrue(saida is SaidaDoEnvioDaFoto.Enviada)
        assertEquals(tresPedidos, chegou.pedidos)
    }

    @Test
    fun `foto sem rosto avisa e nada vai ao servidor ate a pessoa decidir`() = runBlocking {
        val chegou = Chegou()
        val saida = withTimeout(5_000) { fluxo(ResultadoDaVerificacaoLocal.AvisoSemRosto, chegou).enviar(foto) }
        assertEquals(SaidaDoEnvioDaFoto.AvisoSemRosto, saida)
        assertTrue(chegou.pedidos.isEmpty())
    }

    @Test
    fun `enviar mesmo assim chega ao servidor`() = runBlocking {
        val chegou = Chegou()
        val saida = withTimeout(5_000) { fluxo(ResultadoDaVerificacaoLocal.AvisoSemRosto, chegou).enviar(foto, enviarMesmoAssim = true) }
        assertTrue(saida is SaidaDoEnvioDaFoto.Enviada)
        assertEquals(tresPedidos, chegou.pedidos)
    }

    @Test
    fun `mais de um rosto bloqueia e enviar mesmo assim nao destrava`() = runBlocking {
        val chegou = Chegou()
        val bloqueada = ResultadoDaVerificacaoLocal.Bloqueada(MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS)
        val saida = withTimeout(5_000) { fluxo(bloqueada, chegou).enviar(foto, enviarMesmoAssim = true) }
        assertEquals(SaidaDoEnvioDaFoto.Bloqueada(MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS), saida)
        assertTrue(chegou.pedidos.isEmpty())
    }

    @Test
    fun `analise indisponivel continua falhando fechada, mesmo com enviar mesmo assim`() = runBlocking {
        val chegou = Chegou()
        val bloqueada = ResultadoDaVerificacaoLocal.Bloqueada(MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL)
        val saida = withTimeout(5_000) { fluxo(bloqueada, chegou).enviar(foto, enviarMesmoAssim = true) }
        assertEquals(SaidaDoEnvioDaFoto.Bloqueada(MotivoDeBloqueioLocal.ANALISE_INDISPONIVEL), saida)
        assertTrue(chegou.pedidos.isEmpty())
    }

    @Test
    fun `recusa do servidor volta como falha com o codigo da API`() = runBlocking {
        val chegou = Chegou()
        val saida = withTimeout(5_000) { fluxo(ResultadoDaVerificacaoLocal.Liberada, chegou, falharNoConfirmar = true).enviar(foto) }
        val falhou = saida as SaidaDoEnvioDaFoto.Falhou
        assertEquals("midia_invalida", (falhou.erro as ErroDaApi).codigoOriginal)
    }
}

/** O aviso é o mesmo texto do iOS (`TextosFotoDePerfil.bloqueio(.rostoNaoEncontrado)`); a paridade de texto é conferida aqui à mão. */
class TextosDaFotoDePerfilTest {
    @Test
    fun `o aviso de sem rosto tem o mesmo texto do iOS e os botoes pedidos`() {
        assertEquals("Não achei seu rosto. Tente com mais luz e de frente", TextosDaFotoDePerfil.AVISO_SEM_ROSTO)
        assertEquals("Enviar mesmo assim", TextosDaFotoDePerfil.ENVIAR_MESMO_ASSIM)
        assertEquals("Escolha uma foto em que apareça apenas você.", TextosDaFotoDePerfil.bloqueio(MotivoDeBloqueioLocal.MULTIPLOS_ROSTOS))
    }
}
