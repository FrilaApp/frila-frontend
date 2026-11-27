package br.com.frila.app

import android.app.Application
import android.util.Log
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.perfil.CompressorDeFotoPerfil
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLog

/**
 * Revisão do PR #1068 (cartão TGQEI6xN). `CacheVagasDaSessao.limpar()` apaga o avatar da conta que saiu. Se um arquivo não puder ser
 * apagado, a falha não pode subir: no Sair ela abortava o `CoordenadorDeLogout.deslogar()` antes da limpeza de imagens e, na troca
 * de conta, `salvarSessao` lançava antes de gravar a sessão nova e impedia o login. A falha do avatar é registrada e a limpeza segue,
 * como a da telemetria. Só arquivos entram na limpeza (como em `CompressorDeFotoPerfil.avatarExistente`): pasta com o prefixo fica.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class LimpezaDoAvatarTest {

    @get:Rule
    val pasta = TemporaryFolder()

    private lateinit var arquivos: File
    private val bloqueadas = mutableListOf<File>()

    @Before
    fun preparar() {
        arquivos = pasta.newFolder("files")
        ShadowLog.clear()
    }

    @After
    fun restaurar() {
        // O TemporaryFolder não consegue apagar uma pasta sem permissão de escrita.
        bloqueadas.forEach { it.setWritable(true) }
        // O filesDir do Robolectric pode ser compartilhado entre testes: não deixa avatar de um para o seguinte.
        RuntimeEnvironment.getApplication().filesDir.listFiles()?.forEach { it.deleteRecursively() }
    }

    private fun sessao(conta: String) = Sessao(
        accessToken = "cabecalho." + java.util.Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"sub":"$conta"}""".toByteArray()) + ".assinatura-sintetica",
        refreshToken = "refresh-$conta", tokenType = "bearer", expiresIn = 3_600L, vinculoId = null,
    )

    private fun avatar(nome: String = "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}1.jpg") =
        File(arquivos, nome).also { it.writeText("foto-sintetica") }

    /** Tira a permissão de escrita da pasta: `File.delete()` dos arquivos dentro dela passa a devolver `false`. */
    private fun impedirExclusao(alvo: File = arquivos) {
        alvo.setWritable(false)
        bloqueadas += alvo
        assertFalse("o ambiente de teste não impede a exclusão (executando como administrador?)", alvo.canWrite())
    }

    /** Tira a permissão de escrita do próprio arquivo: sem ela `descartar` também não consegue esvaziá-lo. */
    private fun impedirEsvaziar(arquivo: File) {
        arquivo.setWritable(false)
        bloqueadas += arquivo
        assertFalse("o ambiente de teste não impede a escrita (executando como administrador?)", arquivo.canWrite())
    }

    private val filesDir: File get() = RuntimeEnvironment.getApplication().filesDir

    private fun avatarNoFilesDir(nome: String = "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}1.jpg") =
        File(filesDir, nome).also { it.writeText("foto-de-a") }

    /** Pasta de cache da conta com um arquivo que não dá para apagar: `limpar()` falha na parte da sessão, não na do avatar. */
    private fun raizComCacheImpossivelDeApagar(): File {
        val raiz = pasta.newFolder("raiz")
        val vagas = File(raiz, "vagas").also { it.mkdirs() }
        File(vagas, "cache.json").writeText("[]")
        impedirExclusao(vagas)
        return raiz
    }

    private fun cache() = CacheVagasDaSessao(raiz = null, diretorioDosAvatares = arquivos)

    @Test
    fun `avatar que nao da para apagar nem esvaziar faz limpar lancar e fica registrado`() {
        impedirEsvaziar(avatar())
        impedirExclusao()

        try {
            cache().limpar()
            org.junit.Assert.fail("esperava IOException: a foto seguiria legível")
        } catch (esperada: java.io.IOException) {
            assertEquals("Não foi possível apagar nem esvaziar o avatar", esperada.message)
        }

        val registros = ShadowLog.getLogsForTag("FrilaSessao")
        assertEquals("esperava um registro da falha", 1, registros.size)
        assertEquals(Log.WARN, registros.single().type)
    }

    @Test
    fun `avatar que nao da para apagar mas da para escrever e esvaziado sem registro de falha`() {
        val arquivoDoAvatar = avatar()
        impedirExclusao()

        cache().limpar()

        assertTrue(arquivoDoAvatar.exists())
        assertEquals("a foto sai do arquivo", 0L, arquivoDoAvatar.length())
        assertEquals(emptyList<Any>(), ShadowLog.getLogsForTag("FrilaSessao"))
    }

    @Test
    fun `Sair conclui mesmo quando o avatar nao pode ser apagado`() {
        val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache())
        armazenamento.salvarSessao(sessao("a"))
        avatar()
        impedirExclusao()

        armazenamento.limparSessao()

        assertNull(armazenamento.obterSessao())
        assertEquals(1, armazenamento.encerramentos.value)
    }

    @Test
    fun `login da conta nova segue funcionando quando o avatar da anterior nao pode ser apagado`() {
        val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache())
        armazenamento.salvarSessao(sessao("a"))
        avatar()
        impedirExclusao()

        armazenamento.salvarSessao(sessao("b"))

        assertEquals("refresh-b", armazenamento.obterSessao()?.refreshToken)
    }

    @Test
    fun `limpar apaga os avatares e o temporario`() {
        val a = avatar("${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}1.jpg")
        val b = avatar("${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}2.jpg")
        val temporario = avatar(CompressorDeFotoPerfil.NOME_ARQUIVO_TEMPORARIO)
        val alheio = avatar("outro_arquivo.txt")

        cache().limpar()

        assertFalse(a.exists())
        assertFalse(b.exists())
        assertFalse(temporario.exists())
        assertTrue("só o que é avatar sai", alheio.exists())
    }

    @Test
    fun `pasta com o prefixo do avatar nao e apagada nem lanca`() {
        val vazia = File(arquivos, "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}pasta").also { it.mkdir() }
        val cheia = File(arquivos, "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}cheia").also { it.mkdir() }
        File(cheia, "dentro.txt").writeText("conteudo")
        val temporarioPasta = File(arquivos, CompressorDeFotoPerfil.NOME_ARQUIVO_TEMPORARIO).also { it.mkdir() }
        val arquivoDoAvatar = avatar()

        cache().limpar()

        assertTrue("pasta vazia com o prefixo fica", vazia.isDirectory)
        assertTrue("pasta com conteúdo fica", File(cheia, "dentro.txt").exists())
        assertTrue("pasta com o nome do temporário também fica", temporarioPasta.isDirectory)
        assertFalse(arquivoDoAvatar.exists())
    }

    @Test
    fun `com o avatar impedido de apagar a troca de conta nao deixa a foto da anterior legivel`() {
        val armazenamento = SessaoComCacheVagas(
            ArmazenamentoDeSessaoEmMemoria(), CacheVagasDaSessao(raiz = null, diretorioDosAvatares = filesDir),
        )
        armazenamento.salvarSessao(sessao("a"))
        avatarNoFilesDir()
        impedirExclusao(filesDir)

        armazenamento.salvarSessao(sessao("b"))

        assertEquals("refresh-b", armazenamento.obterSessao()?.refreshToken)
        assertNull("a foto de A não pode ser a que o Perfil de B lê", CompressorDeFotoPerfil.avatarExistente(RuntimeEnvironment.getApplication()))
    }

    @Test
    fun `com o avatar impedido de apagar o Sair nao deixa a foto legivel`() {
        val armazenamento = SessaoComCacheVagas(
            ArmazenamentoDeSessaoEmMemoria(), CacheVagasDaSessao(raiz = null, diretorioDosAvatares = filesDir),
        )
        armazenamento.salvarSessao(sessao("a"))
        avatarNoFilesDir()
        impedirExclusao(filesDir)

        CoordenadorDeLogout(armazenamento, RuntimeEnvironment.getApplication()).limparSessao()

        assertNull(armazenamento.origem.obterSessao())
        assertNull(CompressorDeFotoPerfil.avatarExistente(RuntimeEnvironment.getApplication()))
    }

    @Test
    fun `a limpeza de imagens do Sair tambem nao deixa a foto legivel quando nao consegue apagar`() {
        // Sem o cache de sessão no caminho: só o passo de imagens do CoordenadorDeLogout.
        avatarNoFilesDir()
        avatarNoFilesDir(CompressorDeFotoPerfil.NOME_ARQUIVO_TEMPORARIO)
        impedirExclusao(filesDir)

        CoordenadorDeLogout(ArmazenamentoDeSessaoEmMemoria(), RuntimeEnvironment.getApplication()).limparCacheDeImagens()

        assertNull(CompressorDeFotoPerfil.avatarExistente(RuntimeEnvironment.getApplication()))
    }

    @Test
    fun `falha da sessao ainda sobe, mas so depois de apagar o avatar`() {
        val cache = CacheVagasDaSessao(raizComCacheImpossivelDeApagar(), diretorioDosAvatares = arquivos)
        val arquivoDoAvatar = avatar()

        try {
            cache.limpar()
            org.junit.Assert.fail("esperava IOException do cache de vagas que não saiu")
        } catch (esperada: java.io.IOException) {
            assertEquals("Não foi possível apagar o cache de vagas", esperada.message)
        }
        assertFalse("o avatar sai antes de a falha da sessão subir", arquivoDoAvatar.exists())
    }

    @Test
    fun `Sair com falha da sessao propaga a falha mas encerra a sessao`() {
        val origem = ArmazenamentoDeSessaoEmMemoria().also { it.salvarSessao(sessao("a")) }
        val armazenamento = SessaoComCacheVagas(origem, CacheVagasDaSessao(raizComCacheImpossivelDeApagar(), diretorioDosAvatares = arquivos))

        try {
            armazenamento.limparSessao()
            org.junit.Assert.fail("esperava IOException do cache de vagas que não saiu")
        } catch (_: java.io.IOException) {
        }

        assertNull("a sessão cai mesmo com a falha da limpeza", origem.obterSessao())
        assertEquals(1, armazenamento.encerramentos.value)
    }

    @Test
    fun `so os arquivos do avatar saem, nomes parecidos ficam`() {
        val parecidos = listOf("avatar_perfil.jpg", "avatar_outro.jpg", "avatarfoto.png", "perfil_avatar_1.jpg").map { avatar(it) }

        cache().limpar()

        parecidos.forEach { assertTrue("${it.name} não é avatar do perfil e fica", it.exists()) }
    }

    @Test
    fun `o registro da falha nao traz nome nem caminho do arquivo`() {
        impedirEsvaziar(avatar("${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}conta-sintetica-123.jpg"))
        impedirExclusao()

        try { cache().limpar() } catch (_: java.io.IOException) { }

        val mensagem = ShadowLog.getLogsForTag("FrilaSessao").single().msg
        assertFalse(mensagem, mensagem.contains("conta-sintetica-123"))
        assertFalse(mensagem, mensagem.contains(CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR))
        assertFalse(mensagem, mensagem.contains(arquivos.path))
    }

    @Test
    fun `foto de A que nao da para apagar nem esvaziar barra a entrada de B, em vez de ficar legivel para ele`() {
        // Revisão do time (#1087, P1): sem apagar nem esvaziar, a foto de A seguiria legível; na main esse caso falhava fechado.
        val armazenamento = SessaoComCacheVagas(
            ArmazenamentoDeSessaoEmMemoria(), CacheVagasDaSessao(raiz = null, diretorioDosAvatares = filesDir),
        )
        armazenamento.salvarSessao(sessao("a"))
        impedirEsvaziar(avatarNoFilesDir())
        impedirExclusao(filesDir)

        val barrada = try { armazenamento.salvarSessao(sessao("b")); false } catch (_: java.io.IOException) { true }

        val fotoDeALegivel = CompressorDeFotoPerfil.avatarExistente(RuntimeEnvironment.getApplication()) != null
        assertFalse("B entrou e a foto de A segue legível para o Perfil dele", !barrada && fotoDeALegivel)
        assertTrue("a entrada de B é barrada enquanto a foto de A não sai", barrada)
        assertEquals("a sessão de A fica como estava", "refresh-a", armazenamento.origem.obterSessao()?.refreshToken)
    }

    // ── Revisão do ANBU no #1087 (8a89ba61): o caso raro não pode prender a pessoa na sessão que ela tentou encerrar ──────────

    /** O caso raro: nem apagar nem esvaziar funcionam (arquivo e pasta sem escrita), com a sessão de A ativa. */
    private fun sessaoDeAComFotoQueNaoSai(): SessaoComCacheVagas {
        val armazenamento = SessaoComCacheVagas(
            ArmazenamentoDeSessaoEmMemoria(), CacheVagasDaSessao(raiz = null, diretorioDosAvatares = filesDir),
        )
        armazenamento.salvarSessao(sessao("a"))
        impedirEsvaziar(avatarNoFilesDir())
        impedirExclusao(filesDir)
        return armazenamento
    }

    private fun liberarAFoto() {
        filesDir.setWritable(true)
        filesDir.listFiles()?.forEach { it.setWritable(true) }
    }

    @Test
    fun `Sair no caso raro encerra a sessao e chega a Entrada sem lancar`() {
        val armazenamento = sessaoDeAComFotoQueNaoSai()

        armazenamento.limparSessao() // não pode lançar: o CoordenadorDeLogout seguiria até o fim e a navegação voltaria à Entrada

        assertNull("a sessão de A caiu", armazenamento.origem.obterSessao())
        assertEquals("a navegação é avisada (C0-8)", 1, armazenamento.encerramentos.value)
    }

    @Test
    fun `depois do Sair no caso raro, reabrir o app le a sessao sem lancar de novo`() {
        val armazenamento = sessaoDeAComFotoQueNaoSai()
        armazenamento.limparSessao()

        // O observador e o reinício leem a sessão (`estaAutenticado`/`obterSessao`) e antes tentavam a mesma limpeza e lançavam.
        repeat(3) {
            assertFalse(armazenamento.estaAutenticado())
            assertNull(armazenamento.obterSessao())
        }
    }

    @Test
    fun `o Sair pelo CoordenadorDeLogout chega ao fim no caso raro`() {
        val armazenamento = sessaoDeAComFotoQueNaoSai()

        CoordenadorDeLogout(armazenamento, RuntimeEnvironment.getApplication()).limparSessao()

        assertNull(armazenamento.origem.obterSessao())
        assertEquals(1, armazenamento.encerramentos.value)
    }

    @Test
    fun `no caso raro a proxima gravacao de sessao, de B ou de A de novo, segue barrada ate a foto sair`() {
        val armazenamento = sessaoDeAComFotoQueNaoSai()
        armazenamento.limparSessao()

        for (conta in listOf("b", "a")) {
            val barrada = try { armazenamento.salvarSessao(sessao(conta)); false } catch (_: java.io.IOException) { true }
            assertTrue("a sessão de $conta é barrada enquanto a foto de A não sai", barrada)
            assertNull("nada foi gravado", armazenamento.origem.obterSessao())
        }

        liberarAFoto() // a foto agora pode ser esvaziada: a gravação tenta de novo e passa
        armazenamento.salvarSessao(sessao("b"))
        assertEquals("refresh-b", armazenamento.origem.obterSessao()?.refreshToken)
        assertNull("a foto de A não é legível para B", CompressorDeFotoPerfil.avatarExistente(RuntimeEnvironment.getApplication()))
    }

    @Test
    fun `reiniciar o app com a foto de A ainda presa le a sessao sem lancar`() {
        // O processo recomeçou: o armazenamento novo não tem sessão e a limpeza da foto ainda não foi tentada nesta vida do objeto.
        // O observador e o reinício chamam `estaAutenticado()`; antes lançava a cada chamada e prendia a pessoa fora da Entrada.
        impedirEsvaziar(avatarNoFilesDir())
        impedirExclusao(filesDir)
        val reiniciado = SessaoComCacheVagas(
            ArmazenamentoDeSessaoEmMemoria(), CacheVagasDaSessao(raiz = null, diretorioDosAvatares = filesDir),
        )

        repeat(3) {
            assertFalse(reiniciado.estaAutenticado())
            assertNull(reiniciado.obterSessao())
        }
        val barrada = try { reiniciado.salvarSessao(sessao("a")); false } catch (_: java.io.IOException) { true }
        assertTrue("a gravação segue barrada até a foto sair", barrada)
    }
}
