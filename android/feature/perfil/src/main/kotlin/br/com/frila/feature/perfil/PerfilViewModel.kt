package br.com.frila.feature.perfil

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import java.io.File
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Perfil do profissional e reputação agregada (RF03/RF16/RN07/RN08/RN15, UC09).
 *
 * `escopo`: ver nota em `br.com.frila.feature.entrada.entrada.EntradaViewModel` sobre por que
 * testes injetam um escopo próprio em vez de depender de `viewModelScope`/`Dispatchers.Main`.
 */
class PerfilViewModel(
    private val servicoPerfil: ServicoPerfil,
    private val servicoTurnos: ServicoTurnos,
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
    escopo: CoroutineScope? = null,
    /** RF03/RNF04: injetável para teste de JVM sem decodificar bitmap real (Robolectric só na tela). */
    private val comprimirFoto: (Context, Uri) -> File = CompressorDeFotoPerfil::comprimir,
    private val obterAvatarSalvo: (Context) -> File? = CompressorDeFotoPerfil::avatarExistente,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoPerfil())
    val estado: StateFlow<EstadoPerfil> = _estado.asStateFlow()

    fun carregar(): Job {
        _estado.update { it.copy(status = StatusPerfil.CARREGANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val perfil = servicoPerfil.obterMeuPerfilProfissional()
                val (resumoFinanceiro, turnosExtrato) = carregarDadosFinanceiros()
                _estado.update {
                    it.copy(
                        status = StatusPerfil.SUCESSO,
                        perfil = perfil,
                        resumoFinanceiro = resumoFinanceiro,
                        turnosExtrato = turnosExtrato,
                        biometriaAtivada = armazenamentoDeSessao.isBiometriaAtivada(),
                    )
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusPerfil.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    /**
     * RF16: soma `valor_acordado_centavos` dos turnos `cumprida` (concluído) e `confirmada`
     * (pendente), descartando `cancelada` (RN12). Falha de rede aqui não pode quebrar a tela de
     * perfil inteira — degrada para [ResumoFinanceiroPerfil.VAZIO] e lista vazia, e o perfil
     * ainda carrega. Devolve os turnos junto porque o extrato em PDF (RF16/RNF10) precisa da
     * mesma lista para montar a tabela.
     */
    private suspend fun carregarDadosFinanceiros(): Pair<ResumoFinanceiroPerfil, List<TurnoDto>> {
        val turnos = try {
            servicoTurnos.listarMeusTurnos()
        } catch (_: Throwable) {
            return ResumoFinanceiroPerfil.VAZIO to emptyList()
        }

        val cumpridos = turnos.filter { it.estado == "cumprida" }
        val confirmados = turnos.filter { it.estado == "confirmada" }
        val turnosParaExtrato = cumpridos + confirmados

        val resumo = ResumoFinanceiroPerfil(
            totalConcluidoCentavos = cumpridos.somaCentavos(),
            totalPendenteCentavos = confirmados.somaCentavos(),
            turnosCumpridosQtd = cumpridos.size,
            turnosAgendadosQtd = confirmados.size,
        )
        return resumo to turnosParaExtrato
    }

    private fun List<TurnoDto>.somaCentavos(): Long = sumOf { it.valorAcordadoCentavos }

    /**
     * RF16/RNF10: gera o extrato em PDF com o resumo e os turnos já carregados. Guard clause:
     * sem histórico (nenhum turno cumprido/agendado), não há o que exportar — devolve `null`
     * sem tentar desenhar uma página vazia.
     */
    fun exportarExtratoPdf(diretorioCache: File, nomeProfissional: String): File? {
        val resumo = _estado.value.resumoFinanceiro ?: return null
        if (!resumo.temHistorico) return null

        val pasta = File(diretorioCache, "extratos").apply { mkdirs() }
        return GeradorExtratoPdf.gerar(
            diretorioSaida = pasta,
            resumo = resumo,
            turnos = _estado.value.turnosExtrato,
            nomeProfissional = nomeProfissional,
        )
    }

    /**
     * RN15: ativa/desativa o desbloqueio rápido. A confirmação biométrica em si (RN15, exigir
     * que o profissional prove que consegue se autenticar antes de ligar a flag) é
     * responsabilidade da UI ([AutenticadorBiometrico]) — este método só persiste a decisão já
     * tomada. `limparSessao()` em [ArmazenamentoDeSessao] já zera esta flag no logout.
     */
    fun definirBiometriaAtivada(ativada: Boolean) {
        armazenamentoDeSessao.definirBiometriaAtivada(ativada)
        _estado.update { it.copy(biometriaAtivada = ativada) }
    }

    /**
     * RF03/RNF04: comprime [uri] (subamostragem + recorte 1:1) e persiste como avatar local.
     * Falha de decodificação (imagem corrompida, origem inválida) vira [StatusFotoPerfil.ERRO]
     * sem tocar em [EstadoPerfil.fotoLocalPath] — o avatar anterior continua valendo (rollback
     * defensivo: a tela nunca fica sem avatar por causa de uma foto nova que não presta).
     */
    fun selecionarFoto(contexto: Context, uri: Uri): Job {
        _estado.update { it.copy(statusFoto = StatusFotoPerfil.COMPRIMINDO, mensagemErroFoto = null) }
        return escopoDeTrabalho.launch {
            try {
                // Decodificação/recorte/escala são CPU-bound e bloqueantes — Dispatchers.IO para
                // não travar a Main thread (item não-bloqueante do Shisui, PR #590).
                val arquivo = withContext(Dispatchers.IO) { comprimirFoto(contexto, uri) }
                _estado.update {
                    it.copy(statusFoto = StatusFotoPerfil.SUCESSO, fotoLocalPath = arquivo.absolutePath)
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Throwable) {
                _estado.update {
                    it.copy(
                        statusFoto = StatusFotoPerfil.ERRO,
                        mensagemErroFoto = "Não foi possível processar a foto. Tente outra imagem.",
                    )
                }
            }
        }
    }

    /**
     * RF03/RNF04: repõe [EstadoPerfil.fotoLocalPath] a partir do avatar já persistido em
     * `filesDir`, se houver. MEDIDO (Shisui, PR #590): sem isto o avatar desaparecia ao reabrir
     * o app/tela, porque só [selecionarFoto] escrevia o caminho no estado. Chamar na montagem da
     * tela (`TelaPerfil`), independente do carregamento de rede em [carregar].
     */
    fun carregarAvatarSalvo(contexto: Context): Job = escopoDeTrabalho.launch {
        val arquivo = withContext(Dispatchers.IO) { obterAvatarSalvo(contexto) }
        if (arquivo != null) {
            _estado.update { it.copy(fotoLocalPath = arquivo.absolutePath) }
        }
    }

    /** RN15: encerra a sessão local. Não chama a rede — logout é só limpar o que ficou no aparelho. */
    fun aoDeslogar() {
        armazenamentoDeSessao.limparSessao()
    }

    /** RF02: Inicia a edição da biografia profissional copiando o texto atual para o rascunho. */
    fun iniciarEdicaoBio() {
        _estado.update { it.copy(estaEditandoBio = true, bioEmEdicao = it.bio) }
    }

    /**
     * RF02: Atualiza o rascunho da biografia. Rejeita qualquer entrada que exceda
     * o limite máximo de 280 caracteres.
     */
    fun atualizarBioEmEdicao(novoTexto: String) {
        if (novoTexto.length <= EstadoPerfil.LIMITE_MAXIMO_BIO) {
            _estado.update { it.copy(bioEmEdicao = novoTexto) }
        }
    }

    /** RF02: Salva a biografia atualizando o perfil local e fecha o modo de edição. */
    fun salvarBio() {
        _estado.update {
            it.copy(
                bio = it.bioEmEdicao.trim(),
                estaEditandoBio = false,
            )
        }
    }

    /** RF02: Cancela a edição da biografia, descartando alterações não salvas. */
    fun cancelarEdicaoBio() {
        _estado.update {
            it.copy(
                estaEditandoBio = false,
                bioEmEdicao = it.bio,
            )
        }
    }

    /** RF02: Alterna a seleção de uma especialidade (adiciona ou remove do conjunto selecionado). */
    fun alternarEspecialidade(especialidade: String) {
        _estado.update { atual ->
            val novas = if (atual.especialidadesSelecionadas.contains(especialidade)) {
                atual.especialidadesSelecionadas - especialidade
            } else {
                atual.especialidadesSelecionadas + especialidade
            }
            atual.copy(especialidadesSelecionadas = novas)
        }
    }

    /** Abre o diálogo de confirmação de exclusão de conta (RF25/UC16). */
    fun abrirDialogoExclusao() {
        _estado.update { it.copy(statusExclusao = StatusExclusao.DIALOGO_ABERTO, mensagemErroExclusao = null) }
    }

    fun cancelarExclusao() {
        _estado.update { it.copy(statusExclusao = StatusExclusao.OCIOSO) }
    }

    /**
     * Confirma a exclusão definitiva de conta (RF25/RN15/RNF08, UC16): anonimiza dados,
     * cancela turnos futuros sem falta e apaga a credencial. Só limpa a sessão local em caso
     * de sucesso — um erro (ex.: `409 administrador_unico`) mantém a sessão intacta, porque a
     * conta continua existindo e o profissional precisa resolver o bloqueio primeiro.
     */
    fun confirmarExclusao(): Job {
        _estado.update { it.copy(statusExclusao = StatusExclusao.EXCLUINDO, mensagemErroExclusao = null) }
        return escopoDeTrabalho.launch {
            try {
                val resultado = servicoPerfil.excluirConta()
                armazenamentoDeSessao.limparSessao()
                _estado.update {
                    it.copy(statusExclusao = StatusExclusao.SUCESSO, resultadoExclusao = resultado)
                }
            } catch (erro: ErroDaApi) {
                _estado.update {
                    it.copy(statusExclusao = StatusExclusao.ERRO, mensagemErroExclusao = mensagemDeErroExclusao(erro))
                }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.NAO_AUTENTICADO -> "Sua sessão expirou. Entre de novo."
        CodigoErroAPI.NAO_ENCONTRADO -> "Não encontramos seu perfil."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível carregar seu perfil. Tente de novo em instantes."
    }

    private fun mensagemDeErroExclusao(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.ADMINISTRADOR_UNICO ->
            "Você é o único administrador do estabelecimento. Transfira a administração antes de excluir sua conta."
        CodigoErroAPI.NAO_AUTENTICADO -> "Sua sessão expirou. Entre de novo."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível excluir sua conta. Tente de novo em instantes."
    }
}
