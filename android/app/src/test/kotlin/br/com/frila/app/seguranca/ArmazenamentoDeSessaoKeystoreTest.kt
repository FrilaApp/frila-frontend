package br.com.frila.app.seguranca

import android.app.Application
import android.content.Context
import br.com.frila.app.moduloSeguranca
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.koin.android.ext.koin.androidContext
import org.koin.core.context.GlobalContext
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class ArmazenamentoDeSessaoKeystoreTest {

    private lateinit var contexto: Context
    private lateinit var armazenamento: ArmazenamentoDeSessaoKeystore

    private val sessaoCompleta = Sessao(
        accessToken = "access-token",
        refreshToken = "refresh-token",
        tokenType = "bearer",
        expiresIn = 3_600L,
        vinculoId = "vinculo-123",
    )

    @Before
    fun preparar() {
        contexto = RuntimeEnvironment.getApplication()
        contexto.deleteSharedPreferences("sessao_segura")
        armazenamento = novoArmazenamento()
    }

    @After
    fun limpar() {
        stopKoin()
        armazenamento.limparSessao()
        contexto.deleteSharedPreferences("sessao_segura")
    }

    @Test
    fun `salva e recupera sessao completa incluindo vinculoId`() {
        armazenamento.salvarSessao(sessaoCompleta)

        val preferencias = contexto.getSharedPreferences("sessao_segura", Context.MODE_PRIVATE)
        assertEquals("access-token", preferencias.getString("access_token", null))
        assertEquals("refresh-token", preferencias.getString("refresh_token", null))
        assertEquals("bearer", preferencias.getString("token_type", null))
        assertEquals(3_600L, preferencias.getLong("expires_in", -1L))
        assertEquals("vinculo-123", preferencias.getString("vinculo_id", null))
        assertEquals(sessaoCompleta, armazenamento.obterSessao())
    }

    @Test
    fun `limpa sessao e deixa autenticacao falsa`() {
        armazenamento.salvarSessao(sessaoCompleta)

        armazenamento.limparSessao()

        assertNull(armazenamento.obterSessao())
        assertFalse(armazenamento.estaAutenticado())
    }

    @Test
    fun `persiste sessao entre instancias que usam o mesmo armazenamento`() {
        armazenamento.salvarSessao(sessaoCompleta)

        val novaInstancia = novoArmazenamento()

        assertEquals(sessaoCompleta, novaInstancia.obterSessao())
    }

    @Test
    fun `falha de chave retorna nulo sem propagar excecao`() {
        val armazenamentoComFalha = ArmazenamentoDeSessaoKeystore(contexto) {
            throw SecurityException("chave corrompida")
        }

        assertNull(armazenamentoComFalha.obterSessao())
        assertFalse(armazenamentoComFalha.estaAutenticado())
    }

    @Test
    fun `koin com contexto seleciona armazenamento keystore`() {
        startKoin {
            androidContext(contexto)
            modules(moduloSeguranca)
        }

        assertTrue(GlobalContext.get().get<ArmazenamentoDeSessao>() is ArmazenamentoDeSessaoKeystore)
    }

    private fun novoArmazenamento() = ArmazenamentoDeSessaoKeystore(contexto) {
        it.getSharedPreferences("sessao_segura", Context.MODE_PRIVATE)
    }
}
