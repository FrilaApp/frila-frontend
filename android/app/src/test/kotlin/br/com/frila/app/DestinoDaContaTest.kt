package br.com.frila.app

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.PerfilProfissionalDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.UsuarioDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import java.io.File
import java.util.Base64
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.time.Duration.Companion.seconds
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/** Issues #782 e #783: a decisão da tela inicial pelo papel da conta, o prazo de 8 s e o destino guardado. */
@OptIn(ExperimentalCoroutinesApi::class)
class DestinoDaContaTest {

    private fun conta(perfil: String) = UsuarioDto("u1", perfil, "Conta Teste", "61999990000", "conta@exemplo.com", "1990-01-01", "ativa")
    private val perfilProfissional = PerfilProfissionalDto(
        id = "p1", usuarioId = "u1", reputacao = ReputacaoDto(0, 0, null, 0, 0),
    )
    private fun erro(codigo: CodigoErroAPI) = ErroDaApi(codigo, codigo.name.lowercase(), null, "x")
    private val bar = EstabelecimentoDaContaDto(id = "e1", nome = "Bar Teste", papel = "administrador")

    private suspend fun avaliar(
        conta: suspend () -> UsuarioDto,
        perfil: suspend () -> PerfilProfissionalDto = { error("não deveria ler o perfil") },
        casas: suspend () -> List<EstabelecimentoDaContaDto> = { error("não deveria listar casas") },
    ) = avaliarDestinoDaConta(conta, perfil, casas)

    @Test
    fun `sem conta no servidor vai para o cadastro`() = runTest {
        assertEquals(
            DestinoDaConta.Cadastro,
            avaliar(conta = { throw erro(CodigoErroAPI.NAO_ENCONTRADO) }),
        )
    }

    @Test
    fun `profissional com perfil vai para o feed`() = runTest {
        val destino = avaliar(conta = { conta("profissional") }, perfil = { perfilProfissional })
        assertEquals(DestinoDaConta.Profissional, destino)
        assertEquals(Rotas.FEED, destino.rota())
    }

    @Test
    fun `profissional sem perfil vai para o cadastro`() = runTest {
        val destino = avaliar(
            conta = { conta("profissional") },
            perfil = { throw erro(CodigoErroAPI.NAO_ENCONTRADO) },
        )
        assertEquals(DestinoDaConta.Cadastro, destino)
    }

    @Test
    fun `contratante com casa vai para Minhas vagas da primeira casa sem tocar no perfil de profissional`() = runTest {
        val destino = avaliar(conta = { conta("contratante") }, casas = { listOf(bar) })
        assertEquals(DestinoDaConta.Contratante(CasaDoContratante("e1", "Bar Teste")), destino)
        assertEquals(Rotas.minhasVagas("e1", "Bar Teste"), destino.rota())
    }

    @Test
    fun `contratante sem casa vai para o cadastro do estabelecimento`() = runTest {
        val destino = avaliar(conta = { conta("contratante") }, casas = { emptyList() })
        assertEquals(DestinoDaConta.Contratante(null), destino)
        assertEquals(Rotas.CADASTRO_ESTABELECIMENTO, destino.rota())
    }

    @Test
    fun `perfil desconhecido nao e adivinhado`() = runTest {
        assertThrows(IllegalStateException::class.java) {
            kotlinx.coroutines.runBlocking { avaliar(conta = { conta("administrador") }) }
        }
    }

    @Test
    fun `erro que nao e 404 sobe para o avaliador`() = runTest {
        val falha = assertThrows(ErroDaApi::class.java) {
            kotlinx.coroutines.runBlocking { avaliar(conta = { throw erro(CodigoErroAPI.NAO_AUTENTICADO) }) }
        }
        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, falha.codigo)
    }

    // ───────────────────────── AvaliadorDeDestino: prazo e guardado ─────────────────────────

    private class GuardadoFalso(var valor: DestinoDaConta? = null) : DestinoGuardado {
        override fun obter() = valor
        override fun salvar(destino: DestinoDaConta) { valor = destino }
        override fun limpar() { valor = null }
    }

    @Test
    fun `destino avaliado e guardado`() = runTest {
        val guardado = GuardadoFalso()
        val resultado = AvaliadorDeDestino({ DestinoDaConta.Profissional }, guardado).avaliar()

        assertEquals(ResultadoDaAbertura.Destino(DestinoDaConta.Profissional), resultado)
        assertEquals(DestinoDaConta.Profissional, guardado.valor)
    }

    @Test
    fun `cadastro apaga o destino guardado`() = runTest {
        val guardado = GuardadoFalso(DestinoDaConta.Profissional)
        AvaliadorDeDestino({ DestinoDaConta.Cadastro }, guardado).avaliar()

        assertNull(guardado.valor)
    }

    @Test
    fun `prazo estourado abre pelo destino guardado`() = runTest {
        val guardado = GuardadoFalso(DestinoDaConta.Contratante(CasaDoContratante("e1", "Bar Teste")))
        val avaliador = AvaliadorDeDestino({ awaitCancellation() }, guardado, prazo = 8.seconds)

        val resultado = async { avaliador.avaliar() }
        advanceTimeBy(7_999)
        runCurrent()
        assertFalse(resultado.isCompleted, "antes dos 8 s ainda espera o servidor")
        advanceTimeBy(2)
        runCurrent()

        assertEquals(
            ResultadoDaAbertura.Destino(DestinoDaConta.Contratante(CasaDoContratante("e1", "Bar Teste"))),
            resultado.await(),
        )
    }

    @Test
    fun `prazo estourado sem destino guardado mostra sem conexao`() = runTest {
        val avaliador = AvaliadorDeDestino({ awaitCancellation() }, GuardadoFalso(), prazo = 8.seconds)

        val resultado = async { avaliador.avaliar() }
        advanceTimeBy(8_001)
        runCurrent()

        assertEquals(ResultadoDaAbertura.SemConexao, resultado.await())
    }

    @Test
    fun `sem rede abre pelo destino guardado e nao o altera`() = runTest {
        val guardado = GuardadoFalso(DestinoDaConta.Profissional)
        val resultado = AvaliadorDeDestino({ throw erro(CodigoErroAPI.SEM_REDE) }, guardado).avaliar()

        assertEquals(ResultadoDaAbertura.Destino(DestinoDaConta.Profissional), resultado)
        assertEquals(DestinoDaConta.Profissional, guardado.valor)
    }

    @Test
    fun `erro do servidor nao usa o destino guardado`() = runTest {
        val guardado = GuardadoFalso(DestinoDaConta.Profissional)
        val resultado = AvaliadorDeDestino({ throw erro(CodigoErroAPI.DESCONHECIDO) }, guardado).avaliar()

        assertEquals(ResultadoDaAbertura.Falha, resultado)
        assertEquals(DestinoDaConta.Profissional, guardado.valor)
    }

    @Test
    fun `401 na abertura e sessao vencida, nunca usa nem mantem o destino guardado`() = runTest {
        val guardado = GuardadoFalso(DestinoDaConta.Profissional)
        val resultado = AvaliadorDeDestino({ throw erro(CodigoErroAPI.NAO_AUTENTICADO) }, guardado).avaliar()

        assertEquals(ResultadoDaAbertura.SessaoVencida, resultado)
        assertNull(guardado.valor)
    }

    @Test
    fun `cancelamento nao vira resultado`() = runTest {
        val gate = CompletableDeferred<Unit>()
        val trabalho = async { AvaliadorDeDestino({ gate.await(); DestinoDaConta.Profissional }, GuardadoFalso()).avaliar() }
        runCurrent()
        trabalho.cancel()
        runCurrent()

        assertEquals(true, trabalho.isCancelled)
    }

    // ───────────────────────── Destino guardado em arquivo ─────────────────────────

    private fun jwt(sub: String): String {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("""{"sub":"$sub"}""".toByteArray())
        return "cabecalho.$corpo.assinatura"
    }

    private fun sessaoDe(sub: String) = ArmazenamentoDeSessaoEmMemoria().also {
        it.salvarSessao(Sessao(jwt(sub), "ref", "bearer", 3600))
    }

    @Test
    fun `guardado em arquivo e por conta e sobrevive a nova instancia`(@TempDir raiz: File) {
        val destino = DestinoDaConta.Contratante(CasaDoContratante("e1", "Bar do Lago | Asa Norte"))
        DestinoGuardadoEmArquivo(raiz, sessaoDe("conta-a")).salvar(destino)

        assertEquals(destino, DestinoGuardadoEmArquivo(raiz, sessaoDe("conta-a")).obter())
        assertNull(DestinoGuardadoEmArquivo(raiz, sessaoDe("conta-b")).obter(), "outra conta não herda o destino")
    }

    @Test
    fun `limpar do cache da sessao apaga o destino guardado`(@TempDir raiz: File) {
        val sessao = sessaoDe("conta-a")
        DestinoGuardadoEmArquivo(raiz, sessao).salvar(DestinoDaConta.Profissional)

        CacheVagasDaSessao(raiz).limpar()

        assertNull(DestinoGuardadoEmArquivo(raiz, sessao).obter())
    }

    @Test
    fun `sem identidade na sessao nada e guardado`(@TempDir raiz: File) {
        val sessao = ArmazenamentoDeSessaoEmMemoria().also { it.salvarSessao(Sessao("tok", "ref", "bearer", 3600)) }
        val guardado = DestinoGuardadoEmArquivo(raiz, sessao)

        guardado.salvar(DestinoDaConta.Profissional)

        assertNull(guardado.obter())
    }
}
