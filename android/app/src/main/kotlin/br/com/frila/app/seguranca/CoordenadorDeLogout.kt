package br.com.frila.app.seguranca

import android.content.Context
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.perfil.CompressorDeFotoPerfil
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.cancelChildren
import java.io.File

/**
 * Resultado estruturado da execução da limpeza segura de logout (Cartão 101 / LGPD).
 */
data class ResultadoLimpezaLogout(
    val sessaoVazia: Boolean,
    val arquivosDeImagemRemovidos: Int,
    val corrotinasCanceladas: Boolean,
    val clienteKtorRecriado: Boolean,
)

/**
 * Coordenador central de limpeza segura de dados em logout e encerramento de sessão (Cartão 101).
 *
 * Em conformidade com a LGPD (minimização e descarte de dados sensíveis) e segurança RN15:
 * 1. Sessão vazia: limpa credenciais, tokens de acesso/refresh, flag de biometria e cache de vagas da conta.
 * 2. Cache de imagens limpo: expurga arquivos em cache (fotos temporárias de ocorrências,
 *    relatórios PDF) e avatares persistidos no armazenamento privado da conta que saiu.
 * 3. Corrotinas canceladas: interrompe corrotinas ativas em segundo plano da sessão para impedir
 *    requisições fantasmas ou vazamento de tarefas assíncronas.
 * 4. Cliente Ktor recriado: fecha o cliente HTTP anterior e reinstancia um cliente novo,
 *    descartando caches em memória do plugin Auth e conexões abertas.
 */
class CoordenadorDeLogout(
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
    private val diretorioCache: File? = null,
    private val diretorioArquivos: File? = null,
    private val escopoDeCorrotinas: CoroutineScope? = null,
    private val gestorClienteKtor: GestorClienteKtor? = null,
) : ArmazenamentoDeSessao by armazenamentoDeSessao {

    /** Construtor para uso em ambiente Android real a partir de [Context]. */
    constructor(
        armazenamentoDeSessao: ArmazenamentoDeSessao,
        contexto: Context,
        escopoDeCorrotinas: CoroutineScope? = null,
        gestorClienteKtor: GestorClienteKtor? = null,
    ) : this(
        armazenamentoDeSessao = armazenamentoDeSessao,
        diretorioCache = contexto.cacheDir,
        diretorioArquivos = contexto.filesDir,
        escopoDeCorrotinas = escopoDeCorrotinas,
        gestorClienteKtor = gestorClienteKtor,
    )

    /**
     * Intercepta a limpeza de sessão delegada para garantir a execução coordenada
     * de todos os expurgos seguros locais (RN15 / LGPD).
     */
    override fun limparSessao() {
        deslogar()
    }

    /**
     * Executa a limpeza segura de todos os dados locais da conta.
     */
    fun deslogar(): ResultadoLimpezaLogout {
        // 1. Sessão vazia: limpa tokens, biometria e cache de vagas
        armazenamentoDeSessao.limparSessao()

        // 2. Cache de imagens limpo: expurga arquivos de imagem/temporários
        val arquivosRemovidos = limparCacheDeImagens()

        // 3. Corrotinas canceladas: cancela todas as corrotinas filhas ativas no escopo da sessão
        val corrotinasCanceladas = cancelarCorrotinasEmSegundoPlano()

        // 4. Cliente Ktor recriado: fecha o cliente antigo e cria nova instância
        val novoCliente = gestorClienteKtor?.recriar()

        return ResultadoLimpezaLogout(
            sessaoVazia = !armazenamentoDeSessao.estaAutenticado() && armazenamentoDeSessao.obterSessao() == null,
            arquivosDeImagemRemovidos = arquivosRemovidos,
            corrotinasCanceladas = corrotinasCanceladas,
            clienteKtorRecriado = novoCliente != null && !novoCliente.estaFechado,
        )
    }

    /**
     * Remove todos os arquivos e diretórios de [diretorioCache] e os avatares/temporários de [diretorioArquivos].
     * Preserva arquivos não relacionados a imagens (como preferências do DataStore).
     */
    fun limparCacheDeImagens(): Int {
        var removidos = 0
        diretorioCache?.listFiles()?.forEach { arquivo ->
            if (arquivo.deleteRecursively()) {
                removidos++
            }
        }
        diretorioArquivos?.listFiles { arquivo ->
            arquivo.name.startsWith(CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR) ||
                arquivo.name.endsWith(".tmp") ||
                arquivo.name.startsWith("avatar_")
        }?.forEach { arquivo ->
            if (arquivo.delete()) {
                removidos++
            }
        }
        return removidos
    }

    /**
     * Cancela todas as corrotinas filhas ativas em segundo plano.
     */
    fun cancelarCorrotinasEmSegundoPlano(): Boolean {
        val contexto = escopoDeCorrotinas?.coroutineContext ?: return true
        contexto.cancelChildren()
        return true
    }
}
