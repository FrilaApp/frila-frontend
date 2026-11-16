package br.com.frila.app

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import br.com.frila.core.rede.PerfilProfissionalDto
import br.com.frila.core.rede.UsuarioDto
import java.io.File
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/** Casa que abre a tela inicial do contratante (a primeira por nome, como no perfil). */
data class CasaDoContratante(val id: String, val nome: String)

/**
 * Para onde a conta vai depois do código e a cada abertura (#782, #783). Espelha o iOS
 * (`DestinoDaConta`): o servidor diz quem é a conta, o app não adivinha.
 */
sealed interface DestinoDaConta {
    /** Sem conta no servidor, ou profissional sem perfil: a única entrada de cadastro que o Android tem. */
    data object Cadastro : DestinoDaConta

    /** Profissional com perfil: feed de vagas. */
    data object Profissional : DestinoDaConta

    /** Contratante: Minhas vagas da primeira casa, ou o cadastro do estabelecimento se ainda não tem casa. */
    data class Contratante(val casa: CasaDoContratante?) : DestinoDaConta
}

/** Rota de cada destino. */
fun DestinoDaConta.rota(): String = when (this) {
    DestinoDaConta.Cadastro -> Rotas.CADASTRO
    DestinoDaConta.Profissional -> Rotas.FEED
    is DestinoDaConta.Contratante ->
        casa?.let { Rotas.minhasVagas(it.id, it.nome) } ?: Rotas.CADASTRO_ESTABELECIMENTO
}

/**
 * `minha_conta` → `404` é cadastro; perfil `contratante` → primeira casa de `meus_estabelecimentos`;
 * perfil `profissional` → `meu_perfil_profissional` (`404` é cadastro, `200` é o feed). Erro de rede ou do
 * servidor sobe para quem chamou ([AvaliadorDeDestino] decide o que fazer).
 */
suspend fun avaliarDestinoDaConta(
    buscarConta: suspend () -> UsuarioDto,
    buscarPerfilProfissional: suspend () -> PerfilProfissionalDto,
    listarCasas: suspend () -> List<EstabelecimentoDaContaDto>,
): DestinoDaConta {
    val conta = try {
        buscarConta()
    } catch (erro: ErroDaApi) {
        if (erro.codigo == CodigoErroAPI.NAO_ENCONTRADO) return DestinoDaConta.Cadastro
        throw erro
    }
    return when (conta.perfil) {
        "contratante" -> DestinoDaConta.Contratante(
            listarCasas().firstOrNull()?.let { CasaDoContratante(it.id, it.nome) },
        )
        "profissional" -> try {
            buscarPerfilProfissional()
            DestinoDaConta.Profissional
        } catch (erro: ErroDaApi) {
            if (erro.codigo == CodigoErroAPI.NAO_ENCONTRADO) DestinoDaConta.Cadastro else throw erro
        }
        else -> throw IllegalStateException("Perfil de conta desconhecido: ${conta.perfil}")
    }
}

/** Resultado da abertura: um destino, ou o motivo de não haver. */
sealed interface ResultadoDaAbertura {
    data class Destino(val destino: DestinoDaConta) : ResultadoDaAbertura

    /** Sem rede (ou prazo vencido) e nada guardado: a tela diz que está sem conexão. */
    data object SemConexao : ResultadoDaAbertura

    /** Erro do servidor ou resposta ilegível. */
    data object Falha : ResultadoDaAbertura
}

/** Último destino conhecido da conta, para abrir o app sem rede. */
interface DestinoGuardado {
    fun obter(): DestinoDaConta?
    fun salvar(destino: DestinoDaConta)
    fun limpar()
}

/**
 * Avalia o destino da conta com prazo (8 s, como o iOS): rede ruim não deixa a pessoa olhando um
 * indicador por um minuto. Sem rede ou prazo vencido, vale o último destino guardado; sem ele, [ResultadoDaAbertura.SemConexao].
 */
class AvaliadorDeDestino(
    private val descobrir: suspend () -> DestinoDaConta,
    private val guardado: DestinoGuardado,
    private val prazo: Duration = PRAZO_PADRAO,
) {
    suspend fun avaliar(): ResultadoDaAbertura = try {
        val destino = withTimeout(prazo) { descobrir() }
        if (destino is DestinoDaConta.Cadastro) guardado.limpar() else guardado.salvar(destino)
        ResultadoDaAbertura.Destino(destino)
    } catch (_: TimeoutCancellationException) {
        semConexao()
    } catch (erro: CancellationException) {
        throw erro
    } catch (erro: ErroDaApi) {
        if (erro.codigo == CodigoErroAPI.SEM_REDE) semConexao() else ResultadoDaAbertura.Falha
    } catch (_: Exception) {
        ResultadoDaAbertura.Falha
    }

    private fun semConexao(): ResultadoDaAbertura =
        guardado.obter()?.let { ResultadoDaAbertura.Destino(it) } ?: ResultadoDaAbertura.SemConexao

    companion object {
        val PRAZO_PADRAO: Duration = 8.seconds
    }
}

/**
 * Destino guardado em arquivo privado, uma conta por arquivo (o mesmo sujeito estável do cache de vagas):
 * outra conta no mesmo aparelho nunca herda o destino, e [CacheVagasDaSessao.limpar] apaga a pasta no logout.
 * Sem pasta ou sem identidade na sessão, nada é guardado.
 */
internal class DestinoGuardadoEmArquivo(
    private val raiz: File?,
    private val sessao: ArmazenamentoDeSessao,
) : DestinoGuardado {
    private fun arquivo(): File? {
        val nome = arquivoCacheVagas(File("."), sessao.obterSessao())?.name ?: return null
        return raiz?.let { File(it, "$PASTA/$nome") }
    }

    override fun obter(): DestinoDaConta? = try {
        arquivo()?.takeIf { it.isFile }?.readText()?.let(::decodificar)
    } catch (_: java.io.IOException) {
        null
    }

    override fun salvar(destino: DestinoDaConta) {
        val alvo = arquivo() ?: return
        try {
            alvo.parentFile?.mkdirs()
            alvo.writeText(codificar(destino))
        } catch (_: java.io.IOException) {
            // Sem o guardado a abertura sem rede mostra "sem conexão"; nada mais quebra.
        }
    }

    override fun limpar() {
        try {
            arquivo()?.delete()
        } catch (_: SecurityException) {
        }
    }

    internal companion object {
        const val PASTA = "destino"

        fun codificar(destino: DestinoDaConta): String = when (destino) {
            DestinoDaConta.Cadastro -> "cadastro"
            DestinoDaConta.Profissional -> "profissional"
            is DestinoDaConta.Contratante -> destino.casa
                ?.let { "contratante\n${it.id}\n${it.nome}" }
                ?: "contratante"
        }

        fun decodificar(texto: String): DestinoDaConta? {
            val linhas = texto.split("\n", limit = 3)
            return when (linhas[0]) {
                "profissional" -> DestinoDaConta.Profissional
                "contratante" ->
                    if (linhas.size == 3) DestinoDaConta.Contratante(CasaDoContratante(linhas[1], linhas[2]))
                    else DestinoDaConta.Contratante(null)
                else -> null
            }
        }
    }
}
