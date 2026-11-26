package br.com.frila.app

import android.app.Application
import android.util.Log
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
    }

    private fun sessao(conta: String) = Sessao(
        accessToken = "cabecalho." + java.util.Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"sub":"$conta"}""".toByteArray()) + ".assinatura-sintetica",
        refreshToken = "refresh-$conta", tokenType = "bearer", expiresIn = 3_600L, vinculoId = null,
    )

    private fun avatar(nome: String = "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}1.jpg") =
        File(arquivos, nome).also { it.writeText("foto-sintetica") }

    /** Tira a permissão de escrita da pasta: `File.delete()` dos arquivos dentro dela passa a devolver `false`. */
    private fun impedirExclusao() {
        arquivos.setWritable(false)
        bloqueadas += arquivos
        assertFalse("o ambiente de teste não impede a exclusão (executando como administrador?)", arquivos.canWrite())
    }

    private fun cache() = CacheVagasDaSessao(raiz = null, diretorioDosAvatares = arquivos)

    @Test
    fun `falha ao apagar o avatar nao faz limpar lancar e fica registrada`() {
        avatar()
        impedirExclusao()

        cache().limpar()

        val registros = ShadowLog.getLogsForTag("FrilaSessao")
        assertEquals("esperava um registro da falha", 1, registros.size)
        assertEquals(Log.WARN, registros.single().type)
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
        val arquivoDoAvatar = avatar()

        cache().limpar()

        assertTrue("pasta vazia com o prefixo fica", vazia.isDirectory)
        assertTrue("pasta com conteúdo fica", File(cheia, "dentro.txt").exists())
        assertFalse(arquivoDoAvatar.exists())
    }
}
