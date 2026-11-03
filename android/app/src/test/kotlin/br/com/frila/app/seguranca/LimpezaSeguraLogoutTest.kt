package br.com.frila.app.seguranca

import android.app.Application
import android.content.Context
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.perfil.CompressorDeFotoPerfil
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class LimpezaSeguraLogoutTest {

    private lateinit var contexto: Context
    private lateinit var armazenamento: ArmazenamentoDeSessaoEmMemoria
    private lateinit var escopo: CoroutineScope
    private lateinit var gestorCliente: GestorClienteKtor

    private val sessaoTeste = Sessao(
        accessToken = "jwt-acesso-12345",
        refreshToken = "jwt-refresh-67890",
        tokenType = "bearer",
        expiresIn = 3_600L,
        vinculoId = "vinculo-aparelho-abc",
    )

    private fun criarClienteSupabase() = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-anonima-teste",
        armazenamentoDeSessao = armazenamento,
        engine = MockEngine { respond("ok", HttpStatusCode.OK) },
    )

    @Before
    fun preparar() {
        contexto = RuntimeEnvironment.getApplication()
        armazenamento = ArmazenamentoDeSessaoEmMemoria()
        escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        gestorCliente = GestorClienteKtor { criarClienteSupabase() }

        // Limpa resíduos de execuções anteriores no sandbox
        contexto.cacheDir.deleteRecursively()
        contexto.cacheDir.mkdirs()
        contexto.filesDir.listFiles()?.forEach { it.deleteRecursively() }
    }

    @After
    fun finalizar() {
        escopo.cancel()
        gestorCliente.close()
    }

    @Test
    fun `logout completo prova os quatro criterios simultaneamente`() = runBlocking {
        // 1. Preparação da Sessão
        armazenamento.salvarSessao(sessaoTeste)
        armazenamento.definirBiometriaAtivada(true)
        assertTrue(armazenamento.estaAutenticado())
        assertTrue(armazenamento.isBiometriaAtivada())

        // 2. Preparação do Cache de Imagens e Arquivos Temporários
        val fotoOcorrencia = File(contexto.cacheDir, "ocorrencia_123.jpg").apply { writeBytes(byteArrayOf(1, 2, 3)) }
        val extratoPdf = File(contexto.cacheDir, "extrato_456.pdf").apply { writeBytes(byteArrayOf(4, 5, 6)) }
        val subpastaCache = File(contexto.cacheDir, "miniaturas").apply { mkdirs() }
        val fotoMiniatura = File(subpastaCache, "miniatura_789.jpg").apply { writeBytes(byteArrayOf(7, 8, 9)) }

        val avatar = File(contexto.filesDir, "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}123.jpg").apply { writeBytes(byteArrayOf(10, 11)) }
        val avatarTmp = File(contexto.filesDir, CompressorDeFotoPerfil.NOME_ARQUIVO_TEMPORARIO).apply { writeBytes(byteArrayOf(12, 13)) }
        val datastoreDir = File(contexto.filesDir, "datastore").apply { mkdirs() }
        val arquivoDatastore = File(datastoreDir, "filtros.preferences_pb").apply { writeBytes(byteArrayOf(99, 99)) }

        assertTrue(fotoOcorrencia.exists())
        assertTrue(extratoPdf.exists())
        assertTrue(fotoMiniatura.exists())
        assertTrue(avatar.exists())
        assertTrue(avatarTmp.exists())
        assertTrue(arquivoDatastore.exists())

        // 3. Preparação das Corrotinas em Segundo Plano
        val jobBackground = escopo.launch {
            delay(60_000)
        }
        assertTrue(jobBackground.isActive)
        assertFalse(jobBackground.isCancelled)

        // 4. Preparação do Cliente Ktor
        val clienteAntigo = gestorCliente.clienteAtual
        assertFalse(clienteAntigo.estaFechado)

        // Execução do Coordenador de Logout (Cartão 101)
        val coordenador = CoordenadorDeLogout(
            armazenamentoDeSessao = armazenamento,
            contexto = contexto,
            escopoDeCorrotinas = escopo,
            gestorClienteKtor = gestorCliente,
        )
        val resultado = coordenador.deslogar()

        // PROVA CRITÉRIO 1: Sessão vazia
        assertTrue("Sessão deveria estar vazia no resultado", resultado.sessaoVazia)
        assertNull("Tokens de sessão devem ser nulos", armazenamento.obterSessao())
        assertFalse("Não deve constar como autenticado", armazenamento.estaAutenticado())
        assertFalse("Flag biométrica RN15 deve ser desativada", armazenamento.isBiometriaAtivada())

        // PROVA CRITÉRIO 2: Cache de imagens limpo
        assertTrue("Deveria registrar remoção de arquivos de imagem", resultado.arquivosDeImagemRemovidos >= 4)
        assertFalse("Foto de ocorrência no cacheDir deve ser excluída", fotoOcorrencia.exists())
        assertFalse("PDF no cacheDir deve ser excluído", extratoPdf.exists())
        assertFalse("Subpastas no cacheDir devem ser excluídas", fotoMiniatura.exists())
        assertFalse("Avatar persistido em filesDir deve ser excluído", avatar.exists())
        assertFalse("Arquivo temporário de avatar em filesDir deve ser excluído", avatarTmp.exists())
        assertTrue("Arquivo não relacionado a imagens (DataStore) deve ser preservado", arquivoDatastore.exists())

        // PROVA CRITÉRIO 3: Corrotinas canceladas
        assertTrue("Corrotinas deveriam constar como canceladas no resultado", resultado.corrotinasCanceladas)
        assertTrue("Job em segundo plano deve ser cancelado", jobBackground.isCancelled)
        assertFalse("Job em segundo plano não pode continuar ativo", jobBackground.isActive)

        // PROVA CRITÉRIO 4: Cliente Ktor recriado
        assertTrue("Cliente Ktor recriado no resultado", resultado.clienteKtorRecriado)
        assertTrue("Cliente Ktor antigo deve ser fechado", clienteAntigo.estaFechado)
        val novoCliente = gestorCliente.clienteAtual
        assertNotSame("Novo cliente deve ser uma instância diferente", clienteAntigo, novoCliente)
        assertFalse("Novo cliente recriado não deve estar fechado", novoCliente.estaFechado)
    }

    @Test
    fun `limparSessao delegada aciona deslogar e realiza limpeza completa`() = runBlocking {
        armazenamento.salvarSessao(sessaoTeste)
        val foto = File(contexto.cacheDir, "foto_temp.jpg").apply { writeBytes(byteArrayOf(1)) }
        val job = escopo.launch { delay(60_000) }
        val clienteAntigo = gestorCliente.clienteAtual

        val coordenador = CoordenadorDeLogout(
            armazenamentoDeSessao = armazenamento,
            contexto = contexto,
            escopoDeCorrotinas = escopo,
            gestorClienteKtor = gestorCliente,
        )

        // Chama via interface ArmazenamentoDeSessao
        coordenador.limparSessao()

        assertNull(armazenamento.obterSessao())
        assertFalse(foto.exists())
        assertTrue(job.isCancelled)
        assertTrue(clienteAntigo.estaFechado)
        assertNotSame(clienteAntigo, gestorCliente.clienteAtual)
    }

    @Test
    fun `cancelamento de corrotinas cancela multiplas tarefas ativas em background`() = runBlocking {
        val job1 = escopo.launch { delay(30_000) }
        val job2 = escopo.launch { delay(30_000) }
        val job3 = escopo.launch { delay(30_000) }

        assertTrue(job1.isActive && job2.isActive && job3.isActive)

        val coordenador = CoordenadorDeLogout(
            armazenamentoDeSessao = armazenamento,
            contexto = contexto,
            escopoDeCorrotinas = escopo,
        )
        coordenador.deslogar()

        assertTrue("Job 1 cancelado", job1.isCancelled)
        assertTrue("Job 2 cancelado", job2.isCancelled)
        assertTrue("Job 3 cancelado", job3.isCancelled)
        assertFalse(job1.isActive || job2.isActive || job3.isActive)
    }

    @Test
    fun `sem escopo de corrotinas o resultado nao afirma cancelamento`() {
        val coordenador = CoordenadorDeLogout(armazenamentoDeSessao = armazenamento, contexto = contexto)

        assertFalse(coordenador.cancelarCorrotinasEmSegundoPlano())
        assertFalse(coordenador.deslogar().corrotinasCanceladas)
    }

    @Test
    fun `limpeza de cache preserva arquivos e configuracoes que nao sao imagens`() {
        val avatar = File(contexto.filesDir, "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}foto.jpg").apply { writeBytes(byteArrayOf(1)) }
        val arquivoJson = File(contexto.filesDir, "config.json").apply { writeText("""{"tema":"escuro"}""") }
        val subpastaDados = File(contexto.filesDir, "dados_app").apply { mkdirs() }
        val arquivoDados = File(subpastaDados, "estado.bin").apply { writeBytes(byteArrayOf(42)) }

        val coordenador = CoordenadorDeLogout(
            armazenamentoDeSessao = armazenamento,
            contexto = contexto,
        )
        val removidos = coordenador.limparCacheDeImagens()

        assertEquals(1, removidos)
        assertFalse("Avatar deve ser removido", avatar.exists())
        assertTrue("config.json deve ser preservado", arquivoJson.exists())
        assertTrue("arquivo de estado em subpasta deve ser preservado", arquivoDados.exists())
    }
}
