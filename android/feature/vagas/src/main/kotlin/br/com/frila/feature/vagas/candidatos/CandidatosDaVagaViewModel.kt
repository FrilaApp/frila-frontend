package br.com.frila.feature.vagas.candidatos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ResultadoConfirmacaoDto
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** O que a lista de candidatos mostra. [Carregados] nunca traz lista vazia: ela é [Vazio]. */
sealed interface EstadoDosCandidatos {
    data object Carregando : EstadoDosCandidatos
    data class Carregados(val candidatos: List<CandidatoDto>) : EstadoDosCandidatos
    data object Vazio : EstadoDosCandidatos
    data object SemConexao : EstadoDosCandidatos
    data object Falha : EstadoDosCandidatos
}

/** O candidato está confirmado. [vagaPreenchida] diz que era a última posição: os outros foram recusados e avisados. */
data class ResultadoDaEscolha(val nome: String, val vagaPreenchida: Boolean)

/** Por que a escolha não valeu (ou não se sabe se valeu). Os que citam o candidato guardam o nome. */
sealed interface FalhaDaEscolha {
    /** `409 posicao_ja_preenchida`: outra escolha ocupou a última posição antes (RN19). */
    data object PosicaoJaPreenchida : FalhaDaEscolha

    /** `409 candidatura_indisponivel`: retirada, expirada ou já escolhida. */
    data class CandidaturaIndisponivel(val nome: String) : FalhaDaEscolha

    /** `409 vaga_encerrada`: a seleção fechou (24 h antes do início), ou a vaga foi cancelada ou encerrada. */
    data object SelecaoEncerrada : FalhaDaEscolha

    /** `422 inelegivel` com `turno_sobreposto`: confirmado em outro turno no mesmo horário (RN21). */
    data class TurnoSobreposto(val nome: String) : FalhaDaEscolha

    /** `422 inelegivel` com outro motivo, como conta suspensa do profissional (RN13). */
    data class Inelegivel(val nome: String) : FalhaDaEscolha

    /** `422 vaga_oculta`: a moderação ocultou a vaga; a candidatura segue pendente. */
    data object VagaOculta : FalhaDaEscolha

    /** `403 sem_permissao` sem `details`: candidatura inexistente, de outra casa ou com bloqueio mútuo. */
    data object SemPermissao : FalhaDaEscolha
    data object PerfilIncompativel : FalhaDaEscolha
    data object ContaSuspensa : FalhaDaEscolha
    data object SessaoExpirada : FalhaDaEscolha

    /** A chamada não saiu do aparelho: nada mudou no servidor. A escolha não entra em fila. */
    data object SemRede : FalhaDaEscolha

    /** A resposta não disse se a escolha valeu e a lista relida também não: o candidato saiu dela. */
    data class ResultadoIncerto(val nome: String) : FalhaDaEscolha
    data object Generica : FalhaDaEscolha
}

data class EstadoCandidatosDaVaga(
    val lista: EstadoDosCandidatos = EstadoDosCandidatos.Carregando,
    /** Releitura com a lista já na tela (puxar para atualizar). */
    val atualizando: Boolean = false,
    /** A última releitura falhou com candidatos na tela: o que aparece pode estar velho. */
    val desatualizada: Boolean = false,
    /** A candidatura cuja escolha está em voo: enquanto houver uma, nenhuma outra sai. */
    val escolhendo: String? = null,
    /** O candidato cuja escolha espera a confirmação de quem tocou em "Escolher". */
    val emConfirmacao: CandidatoDto? = null,
    val resultado: ResultadoDaEscolha? = null,
    val falha: FalhaDaEscolha? = null,
    /** Posições ainda abertas, se quem abriu a tela sabe; `null` esconde o aviso da última posição. */
    val posicoesAbertas: Int? = null,
    /** Até quando a casa escolhe: 24 h antes do início (RN24); `null` se o início não é conhecido. */
    val prazoDeEscolha: Instant? = null,
    /** O relógio do aparelho na última leitura; só decide se o prazo já passou. */
    val agora: Instant,
) {
    val candidatos: List<CandidatoDto> get() = (lista as? EstadoDosCandidatos.Carregados)?.candidatos.orEmpty()
    val ultimaPosicao: Boolean get() = posicoesAbertas == 1
    val prazoPassou: Boolean get() = prazoDeEscolha != null && !agora.isBefore(prazoDeEscolha)
}

/**
 * Candidatos de uma vaga em modo seleção e a escolha (RF09, RF10, RN06, RN19, RN21, RN24, UC04;
 * paridade com `CandidatosDaVagaViewModel` de `CandidatosDaVaga.swift`).
 *
 * **A escolha não é idempotente e não entra em fila:** escolher de novo a candidatura já escolhida
 * responde `409 candidatura_indisponivel`. Por isso, sem rede a tela só avisa; e quando a resposta não
 * diz se a escolha valeu (resposta que não é JSON, queda no meio da chamada), o ViewModel relê a lista
 * e diz o que sabe: com o candidato ainda nela, a escolha falhou; sem ele, é [FalhaDaEscolha.ResultadoIncerto],
 * porque sumir da lista também é o que a retirada faz.
 *
 * **Geração:** cada resposta do servidor a uma escolha sobe um contador. Uma leitura que saiu antes
 * dela e volta depois traria de volta quem acabou de ser confirmado; ela é descartada e refeita.
 *
 * [buscar] é `ServicoVagas.candidatosDaVaga`; [escolher] é `ServicoVagas.escolherCandidato`.
 * [posicoesAbertas] e [inicioDaVaga] vêm de quem abre a tela (a casa sabe da vaga). `escopo`: mesma
 * razão do `PerfilViewModel`.
 */
class CandidatosDaVagaViewModel(
    private val vagaId: String,
    private val buscar: suspend (String) -> List<CandidatoDto>,
    private val escolher: suspend (String) -> ResultadoConfirmacaoDto,
    posicoesAbertas: Int? = null,
    inicioDaVaga: Instant? = null,
    private val relogio: () -> Instant = Instant::now,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(
        EstadoCandidatosDaVaga(
            posicoesAbertas = posicoesAbertas,
            prazoDeEscolha = inicioDaVaga?.minus(PRAZO_ANTES_DO_INICIO),
            agora = relogio(),
        ),
    )
    val estado: StateFlow<EstadoCandidatosDaVaga> = _estado.asStateFlow()

    private var geracao = 0
    private var leitura: Job? = null

    /** Primeira leitura e "Tentar novamente". Sem efeito se já há uma leitura em voo. */
    fun carregar(): Job = iniciarLeitura(atualizando = false)

    /** Puxar para atualizar: mantém a lista na tela e mostra o indicador. */
    fun atualizar(): Job = iniciarLeitura(atualizando = true)

    private fun iniciarLeitura(atualizando: Boolean): Job {
        leitura?.takeIf { it.isActive }?.let { return it }
        _estado.update {
            if (it.lista is EstadoDosCandidatos.Carregados || it.lista is EstadoDosCandidatos.Vazio) {
                it.copy(atualizando = atualizando)
            } else {
                it.copy(lista = EstadoDosCandidatos.Carregando)
            }
        }
        return escopoDeTrabalho.launch { ler() }.also { leitura = it }
    }

    /**
     * Lê e só aplica a resposta se nenhuma escolha respondeu enquanto a leitura estava em voo; senão
     * descarta e lê de novo. Devolve `true` se a lista foi aplicada.
     */
    private suspend fun ler(): Boolean {
        while (true) {
            val geracaoDaLeitura = geracao
            try {
                val lista = buscar(vagaId)
                if (geracaoDaLeitura != geracao) continue
                _estado.update {
                    it.copy(
                        lista = if (lista.isEmpty()) EstadoDosCandidatos.Vazio else EstadoDosCandidatos.Carregados(lista),
                        atualizando = false,
                        desatualizada = false,
                        agora = relogio(),
                    )
                }
                return true
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                // ErroDaApi, sem rede ou corpo que não é JSON: com a lista na tela ela fica e avisa que
                // pode estar velha; sem lista, vira SemConexao ou Falha, nunca um spinner eterno.
                if (geracaoDaLeitura != geracao) continue
                val semRede = (erro as? ErroDaApi)?.codigo == CodigoErroAPI.SEM_REDE
                _estado.update {
                    when (it.lista) {
                        is EstadoDosCandidatos.Carregados, EstadoDosCandidatos.Vazio ->
                            it.copy(atualizando = false, desatualizada = true)
                        else -> it.copy(
                            lista = if (semRede) EstadoDosCandidatos.SemConexao else EstadoDosCandidatos.Falha,
                            atualizando = false,
                        )
                    }
                }
                return false
            }
        }
    }

    /** A escolha confirma o profissional: a tela pergunta antes. Só vale para quem está na lista. */
    fun pedirEscolha(candidato: CandidatoDto) {
        _estado.update {
            if (it.escolhendo == null && it.candidatos.any { atual -> atual.candidaturaId == candidato.candidaturaId }) {
                it.copy(emConfirmacao = candidato)
            } else {
                it
            }
        }
    }

    fun desistirDaEscolha() {
        _estado.update { it.copy(emConfirmacao = null) }
    }

    /**
     * Só escolhe quem passou por [pedirEscolha]. Um segundo toque com a chamada em voo não envia outra
     * escolha. O pedido é lido e limpo no mesmo passo, antes de a corrotina começar.
     */
    fun confirmarEscolha(): Job {
        val atual = _estado.value
        val candidato = atual.emConfirmacao
        if (candidato == null || atual.escolhendo != null) {
            _estado.update { it.copy(emConfirmacao = null) }
            return escopoDeTrabalho.launch { }
        }
        _estado.update {
            it.copy(emConfirmacao = null, escolhendo = candidato.candidaturaId, resultado = null, falha = null)
        }
        return escopoDeTrabalho.launch { escolherConfirmado(candidato, vagaCheiaDepois = atual.ultimaPosicao) }
    }

    private suspend fun escolherConfirmado(candidato: CandidatoDto, vagaCheiaDepois: Boolean) {
        val nome = candidato.profissional.nome
        try {
            escolher(candidato.candidaturaId)
            geracao++
            _estado.update {
                val restantes = it.candidatos.filter { atual -> atual.candidaturaId != candidato.candidaturaId }
                it.copy(
                    lista = when {
                        // Última posição: o servidor recusa os pendentes, então não há mais o que escolher.
                        vagaCheiaDepois || restantes.isEmpty() -> EstadoDosCandidatos.Vazio
                        else -> EstadoDosCandidatos.Carregados(restantes)
                    },
                    posicoesAbertas = it.posicoesAbertas?.minus(1)?.coerceAtLeast(0),
                    resultado = ResultadoDaEscolha(nome, vagaPreenchida = vagaCheiaDepois),
                )
            }
            if (!vagaCheiaDepois) ler()
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: ErroDaApi) {
            geracao++
            tratar(erro, candidato)
        } catch (_: Exception) {
            // Corpo que não é JSON ou campo ausente escapam do ErroDaApi: a resposta não diz se valeu.
            geracao++
            decidirPelaLista(candidato)
        } finally {
            _estado.update { it.copy(escolhendo = null) }
        }
    }

    private suspend fun tratar(erro: ErroDaApi, candidato: CandidatoDto) {
        val nome = candidato.profissional.nome
        val falha: FalhaDaEscolha = when (erro.codigo) {
            // Não saiu do aparelho: nada mudou no servidor e não há o que reler.
            CodigoErroAPI.SEM_REDE -> FalhaDaEscolha.SemRede
            CodigoErroAPI.POSICAO_JA_PREENCHIDA -> FalhaDaEscolha.PosicaoJaPreenchida.also { ler() }
            CodigoErroAPI.VAGA_ENCERRADA -> FalhaDaEscolha.SelecaoEncerrada.also { ler() }
            CodigoErroAPI.VAGA_OCULTA -> FalhaDaEscolha.VagaOculta.also { ler() }
            CodigoErroAPI.CANDIDATURA_INDISPONIVEL -> FalhaDaEscolha.CandidaturaIndisponivel(nome).also { ler() }
            CodigoErroAPI.INELEGIVEL ->
                if (erro.detalhes == "turno_sobreposto") FalhaDaEscolha.TurnoSobreposto(nome) else FalhaDaEscolha.Inelegivel(nome)
            CodigoErroAPI.CONTA_SUSPENSA -> FalhaDaEscolha.ContaSuspensa
            CodigoErroAPI.SEM_PERMISSAO ->
                if (erro.detalhes == "conta_suspensa") FalhaDaEscolha.ContaSuspensa else FalhaDaEscolha.SemPermissao
            CodigoErroAPI.PERFIL_INCOMPATIVEL -> FalhaDaEscolha.PerfilIncompativel
            CodigoErroAPI.NAO_AUTENTICADO -> FalhaDaEscolha.SessaoExpirada
            else -> {
                decidirPelaLista(candidato)
                return
            }
        }
        _estado.update { it.copy(falha = falha) }
    }

    /** A resposta não diz se a escolha valeu: relê a lista e diz só o que ela mostra. */
    private suspend fun decidirPelaLista(candidato: CandidatoDto) {
        ler()
        // Leitura que falha deixa a lista anterior na tela, e nela o candidato segue: só uma leitura
        // que deu certo e o tirou de lá permite dizer que o resultado é incerto.
        val aindaNaLista = _estado.value.candidatos.any { it.candidaturaId == candidato.candidaturaId }
        val falha = if (!aindaNaLista) {
            FalhaDaEscolha.ResultadoIncerto(candidato.profissional.nome)
        } else {
            FalhaDaEscolha.Generica
        }
        _estado.update { it.copy(falha = falha) }
    }

    private companion object {
        /** RN24: a vaga de seleção fecha 24 horas antes do início. */
        val PRAZO_ANTES_DO_INICIO: Duration = Duration.ofHours(24)
    }
}
