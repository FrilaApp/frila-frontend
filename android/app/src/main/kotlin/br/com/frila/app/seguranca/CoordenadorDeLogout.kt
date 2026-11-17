package br.com.frila.app.seguranca

import android.content.Context
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.perfil.CompressorDeFotoPerfil
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import kotlin.coroutines.cancellation.CancellationException

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
    private val servicoDispositivo: ServicoDispositivo? = null,
    /** Token FCM atual do aparelho; `null` (ou sem provedor) pula a chamada remota, como no iOS. */
    private val provedorDeTokenFcm: (suspend () -> String?)? = null,
    private val tempoMaximoRemocaoMs: Long = TEMPO_MAXIMO_REMOCAO_PADRAO_MS,
    /** C0-10: onde roda o `remover_dispositivo` do Sair, depois da limpeza local. Sem escopo, o Sair só limpa o aparelho. */
    private val escopoDaRemocao: CoroutineScope? = null,
    /** Só o motivo, nunca o token nem a sessão (o app manda ao Log). */
    private val registrarFalha: (String) -> Unit = {},
) : ArmazenamentoDeSessao by armazenamentoDeSessao {

    /** Construtor para uso em ambiente Android real a partir de [Context]. */
    constructor(
        armazenamentoDeSessao: ArmazenamentoDeSessao,
        contexto: Context,
        escopoDeCorrotinas: CoroutineScope? = null,
        gestorClienteKtor: GestorClienteKtor? = null,
        servicoDispositivo: ServicoDispositivo? = null,
        provedorDeTokenFcm: (suspend () -> String?)? = null,
        tempoMaximoRemocaoMs: Long = TEMPO_MAXIMO_REMOCAO_PADRAO_MS,
        escopoDaRemocao: CoroutineScope? = null,
        registrarFalha: (String) -> Unit = {},
    ) : this(
        armazenamentoDeSessao = armazenamentoDeSessao,
        diretorioCache = contexto.cacheDir,
        diretorioArquivos = contexto.filesDir,
        escopoDeCorrotinas = escopoDeCorrotinas,
        gestorClienteKtor = gestorClienteKtor,
        servicoDispositivo = servicoDispositivo,
        provedorDeTokenFcm = provedorDeTokenFcm,
        tempoMaximoRemocaoMs = tempoMaximoRemocaoMs,
        escopoDaRemocao = escopoDaRemocao,
        registrarFalha = registrarFalha,
    )

    /**
     * Intercepta a limpeza de sessão delegada para garantir a execução coordenada
     * de todos os expurgos seguros locais (RN15 / LGPD). É por aqui que passa o Sair do Perfil (e "outra conta" e
     * conta suspensa): limpa o aparelho na hora, porque a tela navega logo depois, e então pede `remover_dispositivo`
     * em segundo plano com o token de acesso de quem saiu, guardado antes (C0-10).
     */
    override fun limparSessao() {
        val tokenDeAcesso = armazenamentoDeSessao.obterSessao()?.accessToken
        deslogar()
        if (tokenDeAcesso != null) removerDispositivoEmSegundoPlano(tokenDeAcesso)
    }

    /** Só uma tentativa, com prazo: falha (rede, API, token do FCM) vira [registrarFalha] e nunca lança. */
    private fun removerDispositivoEmSegundoPlano(tokenDeAcesso: String) {
        val escopo = escopoDaRemocao ?: return
        val servico = servicoDispositivo ?: return
        val provedor = provedorDeTokenFcm ?: return
        escopo.launch {
            try {
                withTimeout(tempoMaximoRemocaoMs) {
                    val tokenFcm = provedor()
                    if (!tokenFcm.isNullOrBlank()) servico.removerDispositivo(tokenFcm, tokenDeAcesso)
                }
            } catch (_: TimeoutCancellationException) {
                registrarFalha("remover_dispositivo passou do prazo de ${tempoMaximoRemocaoMs / 1000} s")
            } catch (cancelado: CancellationException) {
                throw cancelado
            } catch (erro: Exception) {
                registrarFalha("remover_dispositivo falhou: ${erro::class.simpleName}")
            }
        }
    }

    /**
     * Logout completo: tenta `remover_dispositivo` com a sessão ainda válida e só então limpa
     * tudo (cartão 0G88x7YT, RN15). A chamada remota é só uma tentativa: falha de rede, erro da API,
     * exceção do provedor do token ou estouro de [tempoMaximoRemocaoMs] nunca impedem
     * [deslogar]. Roda em [NonCancellable] para que o cancelamento de quem chamou também não
     * deixe a sessão de pé.
     */
    suspend fun deslogarRemovendoDispositivo(): ResultadoLimpezaLogout = withContext(NonCancellable) {
        tentarRemoverDispositivo()
        deslogar()
    }

    private suspend fun tentarRemoverDispositivo() {
        val servico = servicoDispositivo ?: return
        val provedor = provedorDeTokenFcm ?: return
        withTimeoutOrNull(tempoMaximoRemocaoMs) {
            runCatching {
                val token = provedor()
                if (!token.isNullOrBlank()) servico.removerDispositivo(token)
            }
        }
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
     * Cancela todas as corrotinas filhas ativas em segundo plano. Devolve `false` quando não há
     * escopo configurado: nada foi cancelado e o resultado não pode afirmar o contrário.
     */
    fun cancelarCorrotinasEmSegundoPlano(): Boolean {
        val contexto = escopoDeCorrotinas?.coroutineContext ?: return false
        contexto.cancelChildren()
        return true
    }

    private companion object {
        const val TEMPO_MAXIMO_REMOCAO_PADRAO_MS = 5_000L
    }
}
