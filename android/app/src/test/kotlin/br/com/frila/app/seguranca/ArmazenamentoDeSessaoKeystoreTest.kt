package br.com.frila.app.seguranca

import android.app.Application
import android.content.Context
import br.com.frila.app.SessaoComCacheVagas
import br.com.frila.app.moduloSeguranca
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import java.io.InputStream
import java.io.OutputStream
import java.security.Key
import java.security.KeyStoreSpi
import java.security.Provider
import java.security.SecureRandom
import java.security.Security
import java.security.cert.Certificate
import java.security.spec.AlgorithmParameterSpec
import java.util.Collections
import java.util.Date
import java.util.Enumeration
import javax.crypto.KeyGeneratorSpi
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
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
        FakeAndroidKeyStoreProvider.registrar()
        contexto = RuntimeEnvironment.getApplication()
        contexto.deleteSharedPreferences("sessao_segura")
        armazenamento = novoArmazenamento()
    }

    @After
    fun limpar() {
        stopKoin()
        armazenamento.limparSessao()
        contexto.deleteSharedPreferences("sessao_segura")
        FakeAndroidKeyStoreProvider.resetar()
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
    fun `biometria comeca desativada e pode ser ativada e persiste entre instancias`() {
        assertFalse(armazenamento.isBiometriaAtivada())

        armazenamento.definirBiometriaAtivada(true)

        assertTrue(armazenamento.isBiometriaAtivada())
        assertTrue(novoArmazenamento().isBiometriaAtivada())
    }

    @Test
    fun `limparSessao desativa a biometria RN15`() {
        armazenamento.salvarSessao(sessaoCompleta)
        armazenamento.definirBiometriaAtivada(true)
        assertTrue(armazenamento.isBiometriaAtivada())

        armazenamento.limparSessao()

        assertFalse(armazenamento.isBiometriaAtivada())
    }

    @Test
    fun `koin com contexto seleciona armazenamento keystore`() {
        startKoin {
            androidContext(contexto)
            modules(moduloSeguranca)
        }

        assertTrue((GlobalContext.get().get<ArmazenamentoDeSessao>() as SessaoComCacheVagas).origem is ArmazenamentoDeSessaoKeystore)
    }

    @Test
    fun `fabrica de producao com keystore persiste tokens criptografados em repouso e nao em claro`() {
        // Usa o construtor de produção que invoca criarPreferenciasCriptografadas
        val armazenamentoProducao = ArmazenamentoDeSessaoKeystore(contexto)
        armazenamentoProducao.salvarSessao(sessaoCompleta)

        // 1. O armazenamento recupera a sessão decifrada com sucesso
        val sessaoRecuperada = armazenamentoProducao.obterSessao()
        assertNotNull(sessaoRecuperada)
        assertEquals(sessaoCompleta, sessaoRecuperada)

        // 2. No arquivo bruto de preferências (em repouso), os tokens NÃO aparecem em texto claro
        val prefsBrutas = contexto.getSharedPreferences("sessao_segura", Context.MODE_PRIVATE)
        val todosValores = prefsBrutas.all

        // As chaves "access_token" e "refresh_token" não devem existir em texto plano
        assertFalse("access_token não deve estar em claro", prefsBrutas.contains("access_token"))
        assertFalse("refresh_token não deve estar em claro", prefsBrutas.contains("refresh_token"))

        // Nenhum valor bruto no SharedPreferences deve conter os tokens em texto plano
        for ((_, valor) in todosValores) {
            val valorTexto = valor.toString()
            assertFalse("Token em claro encontrado em repouso: $valorTexto", valorTexto.contains("access-token"))
            assertFalse("Refresh token em claro encontrado em repouso: $valorTexto", valorTexto.contains("refresh-token"))
        }
    }

    @Test
    fun `falha no keystore na fabrica de producao recupera sem quebrar app e descarta armazenamento invalido`() {
        // 1. Salva com o construtor de produção e Keystore funcional
        val armazenamentoProducao = ArmazenamentoDeSessaoKeystore(contexto)
        armazenamentoProducao.salvarSessao(sessaoCompleta)
        assertEquals(sessaoCompleta, armazenamentoProducao.obterSessao())

        // 2. Simula falha de chave de hardware no Keystore
        FakeAndroidKeyStoreProvider.simularFalha = true

        // 3. Nova instância tentando abrir preferências com Keystore corrompido/inacessível
        val novaInstancia = ArmazenamentoDeSessaoKeystore(contexto)
        assertNull(novaInstancia.obterSessao())
        assertFalse(novaInstancia.estaAutenticado())

        // 4. Restaura Keystore e confirma que armazenamento foi invalidado com segurança
        FakeAndroidKeyStoreProvider.simularFalha = false
        val instanciaRecuperada = ArmazenamentoDeSessaoKeystore(contexto)
        assertNull(instanciaRecuperada.obterSessao())
        assertFalse(instanciaRecuperada.estaAutenticado())
    }

    private fun novoArmazenamento() = ArmazenamentoDeSessaoKeystore(contexto) {
        it.getSharedPreferences("sessao_segura", Context.MODE_PRIVATE)
    }
}

internal class FakeAndroidKeyStoreProvider : Provider("AndroidKeyStore", 1.0, "Fake AndroidKeyStore Provider") {
    init {
        put("KeyStore.AndroidKeyStore", FakeKeyStoreSpi::class.java.name)
        put("KeyGenerator.AES", FakeKeyGeneratorSpi::class.java.name)
    }

    companion object {
        val chaves = mutableMapOf<String, Key>()
        var simularFalha = false

        fun registrar() {
            if (Security.getProvider("AndroidKeyStore") == null) {
                Security.insertProviderAt(FakeAndroidKeyStoreProvider(), 1)
            }
        }

        fun remover() {
            Security.removeProvider("AndroidKeyStore")
            chaves.clear()
            simularFalha = false
        }

        fun resetar() {
            chaves.clear()
            simularFalha = false
        }
    }
}

class FakeKeyStoreSpi : KeyStoreSpi() {
    override fun engineGetKey(alias: String?, password: CharArray?): Key? {
        if (FakeAndroidKeyStoreProvider.simularFalha) {
            throw java.security.KeyStoreException("Falha simulada no Keystore do dispositivo")
        }
        return FakeAndroidKeyStoreProvider.chaves[alias]
    }

    override fun engineGetCertificateChain(alias: String?): Array<Certificate>? = null

    override fun engineGetCertificate(alias: String?): Certificate? = null

    override fun engineGetCreationDate(alias: String?): Date = Date()

    override fun engineSetKeyEntry(alias: String?, key: Key?, password: CharArray?, chain: Array<out Certificate>?) {
        if (alias != null && key != null) {
            FakeAndroidKeyStoreProvider.chaves[alias] = key
        }
    }

    override fun engineSetKeyEntry(alias: String?, key: ByteArray?, chain: Array<out Certificate>?) {
        if (alias != null && key != null) {
            FakeAndroidKeyStoreProvider.chaves[alias] = SecretKeySpec(key, "AES")
        }
    }

    override fun engineSetCertificateEntry(alias: String?, cert: Certificate?) {}

    override fun engineDeleteEntry(alias: String?) {
        if (alias != null) {
            FakeAndroidKeyStoreProvider.chaves.remove(alias)
        }
    }

    override fun engineAliases(): Enumeration<String> =
        Collections.enumeration(FakeAndroidKeyStoreProvider.chaves.keys)

    override fun engineContainsAlias(alias: String?): Boolean =
        FakeAndroidKeyStoreProvider.chaves.containsKey(alias)

    override fun engineSize(): Int = FakeAndroidKeyStoreProvider.chaves.size

    override fun engineIsKeyEntry(alias: String?): Boolean =
        FakeAndroidKeyStoreProvider.chaves.containsKey(alias)

    override fun engineIsCertificateEntry(alias: String?): Boolean = false

    override fun engineGetCertificateAlias(cert: Certificate?): String? = null

    override fun engineStore(stream: OutputStream?, password: CharArray?) {}

    override fun engineLoad(stream: InputStream?, password: CharArray?) {}
}

class FakeKeyGeneratorSpi : KeyGeneratorSpi() {
    private var aliasAtual: String? = null
    private var tamanhoBits: Int = 256
    private var randomSeguro = SecureRandom()

    override fun engineInit(random: SecureRandom?) {
        if (random != null) this.randomSeguro = random
    }

    override fun engineInit(params: AlgorithmParameterSpec?, random: SecureRandom?) {
        if (random != null) this.randomSeguro = random
        if (params != null) {
            try {
                val metodoAlias = params.javaClass.getMethod("getKeystoreAlias")
                aliasAtual = metodoAlias.invoke(params) as? String
            } catch (_: Exception) {
            }
            try {
                val metodoSize = params.javaClass.getMethod("getKeySize")
                val size = metodoSize.invoke(params) as? Int
                if (size != null && size > 0) tamanhoBits = size
            } catch (_: Exception) {
            }
        }
    }

    override fun engineInit(keysize: Int, random: SecureRandom?) {
        this.tamanhoBits = keysize
        if (random != null) this.randomSeguro = random
    }

    override fun engineGenerateKey(): SecretKey {
        val bytes = ByteArray(tamanhoBits / 8)
        randomSeguro.nextBytes(bytes)
        val chave = SecretKeySpec(bytes, "AES")
        aliasAtual?.let { FakeAndroidKeyStoreProvider.chaves[it] = chave }
        return chave
    }
}

