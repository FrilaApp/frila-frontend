package br.com.frila.app.seguranca

import android.content.Context
import android.content.SharedPreferences
import androidx.test.core.app.ApplicationProvider
import br.com.frila.core.seguranca.ProvedorOAuthSocial
import br.com.frila.core.seguranca.TransacaoOAuthPendente
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.core.context.stopKoin
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ArmazenamentoOAuthPendenteKeystoreTest {

    @After
    fun depois() {
        runCatching { stopKoin() }
    }

    private val context = ApplicationProvider.getApplicationContext<Context>()

    private fun criarFabrica(nome: String = "teste_prefs"): (Context) -> SharedPreferences = { ctx ->
        ctx.getSharedPreferences(nome, Context.MODE_PRIVATE)
    }

    @Test
    fun `salva e recupera transacao valida dentro do TTL`() {
        var agora = 1_000_000L
        val armazenamento = ArmazenamentoOAuthPendenteKeystore(context, criarFabrica("p1"), relogio = { agora })

        val transacao = TransacaoOAuthPendente(
            provedor = ProvedorOAuthSocial.GOOGLE,
            transacaoId = "tx-123",
            verifier = "verifier-456",
            txLocal = "state-789",
            expiraEmMillis = agora + 600_000L,
        )
        armazenamento.salvar(transacao)

        val recuperada = armazenamento.obter()
        assertNotNull(recuperada)
        assertEquals(transacao, recuperada)
    }

    @Test
    fun `transacao expirada e descartada automaticamente no obter`() {
        var agora = 1_000_000L
        val armazenamento = ArmazenamentoOAuthPendenteKeystore(context, criarFabrica("p2"), relogio = { agora })

        val transacao = TransacaoOAuthPendente(
            provedor = ProvedorOAuthSocial.APPLE,
            transacaoId = "tx-apple",
            verifier = "verifier-apple",
            txLocal = "state-apple",
            expiraEmMillis = agora + 10_000L,
        )
        armazenamento.salvar(transacao)

        // Avança 11 segundos
        agora += 11_000L
        assertNull(armazenamento.obter())
    }

    @Test
    fun `limpar apaga transacao persistida`() {
        val agora = 1_000_000L
        val armazenamento = ArmazenamentoOAuthPendenteKeystore(context, criarFabrica("p3"), relogio = { agora })

        armazenamento.salvar(
            TransacaoOAuthPendente(
                provedor = ProvedorOAuthSocial.GOOGLE,
                transacaoId = "tx-1",
                verifier = "v-1",
                txLocal = "s-1",
                expiraEmMillis = agora + 600_000L,
            ),
        )
        assertNotNull(armazenamento.obter())

        armazenamento.limpar()
        assertNull(armazenamento.obter())
    }
}
