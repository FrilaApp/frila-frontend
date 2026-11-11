package br.com.frila.feature.estabelecimento

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EstabelecimentoDto
import br.com.frila.core.rede.NovoEstabelecimentoDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Campos do formulário que podem receber uma recusa. */
enum class CampoCadastro { NOME, DOCUMENTO, ENDERECO, REGIAO_ADMINISTRATIVA, LATITUDE, LONGITUDE }

/** Erro que não é de um campo só, mostrado acima do botão. */
enum class ErroGlobalCadastro(val mensagem: String) {
    DOCUMENTO_DUPLICADO(TextosCadastroEstabelecimento.ERRO_DOCUMENTO_DUPLICADO),
    CONFIRA_CAMPOS(TextosCadastroEstabelecimento.ERRO_CONFIRA_CAMPOS),
    PERFIL_INCOMPATIVEL(TextosCadastroEstabelecimento.ERRO_PERFIL_INCOMPATIVEL),
    SEM_PERMISSAO(TextosCadastroEstabelecimento.ERRO_SEM_PERMISSAO),
    CONTA_SUSPENSA(TextosCadastroEstabelecimento.ERRO_CONTA_SUSPENSA),
    SESSAO_EXPIRADA(TextosCadastroEstabelecimento.ERRO_SESSAO),
    SEM_REDE(TextosCadastroEstabelecimento.ERRO_SEM_REDE),
    GENERICO(TextosCadastroEstabelecimento.ERRO_GENERICO),
}

data class EstadoCadastroEstabelecimento(
    val nome: String = "",
    /** Só dígitos, no máximo 14. */
    val documento: String = "",
    val tipo: TipoEstabelecimento = TipoEstabelecimento.ALIMENTACAO,
    val endereco: String = "",
    val regiaoAdministrativa: String = "",
    /** Texto digitado; aceita vírgula ou ponto como separador decimal. */
    val latitude: String = "",
    val longitude: String = "",
    val enviando: Boolean = false,
    /** Mensagem por campo, preenchida pela validação local ou pela recusa do servidor. */
    val errosDeCampo: Map<CampoCadastro, String> = emptyMap(),
    val erro: ErroGlobalCadastro? = null,
    val estabelecimentoCriado: EstabelecimentoDto? = null,
) {
    val concluido: Boolean get() = estabelecimentoCriado != null
    val podeEditar: Boolean get() = !enviando && !concluido
}

/**
 * Cadastro do estabelecimento do contratante (RF02, RN25, UC10; paridade com
 * `CadastroEstabelecimentoViewModel.swift`, sem mapa: o ponto vem de coordenadas digitadas). Valida
 * tudo o que o contrato exige antes de chamar a rede e mostra todos os campos errados de uma vez.
 * Cada recusa do servidor vira mensagem própria, e nenhuma falha, inclusive resposta que não é JSON,
 * deixa o botão preso em "Cadastrando…".
 *
 * [cadastrar] é `ServicoMembros.cadastrarEstabelecimento`. `escopo`: mesma razão do `PerfilViewModel`.
 */
class CadastroEstabelecimentoViewModel(
    private val cadastrar: suspend (NovoEstabelecimentoDto) -> EstabelecimentoDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoCadastroEstabelecimento())
    val estado: StateFlow<EstadoCadastroEstabelecimento> = _estado.asStateFlow()

    private fun editar(campo: CampoCadastro?, mudar: EstadoCadastroEstabelecimento.() -> EstadoCadastroEstabelecimento) {
        _estado.update {
            if (!it.podeEditar) it else it.mudar().let { novo ->
                novo.copy(errosDeCampo = if (campo == null) novo.errosDeCampo else novo.errosDeCampo - campo, erro = null)
            }
        }
    }

    fun editarNome(nome: String) = editar(CampoCadastro.NOME) { copy(nome = nome) }

    /** Fica só com os dígitos, até 14: o contrato é `^([0-9]{11}|[0-9]{14})$`. */
    fun editarDocumento(texto: String) = editar(CampoCadastro.DOCUMENTO) { copy(documento = texto.filter(Char::isDigit).take(14)) }

    fun escolherTipo(tipo: TipoEstabelecimento) = editar(null) { copy(tipo = tipo) }

    fun editarEndereco(endereco: String) = editar(CampoCadastro.ENDERECO) { copy(endereco = endereco) }

    fun escolherRegiao(regiao: String) = editar(CampoCadastro.REGIAO_ADMINISTRATIVA) { copy(regiaoAdministrativa = regiao) }

    fun editarLatitude(texto: String) = editar(CampoCadastro.LATITUDE) { copy(latitude = texto) }

    fun editarLongitude(texto: String) = editar(CampoCadastro.LONGITUDE) { copy(longitude = texto) }

    /** Sem efeito durante o envio ou depois de concluído: o segundo toque não cria dois estabelecimentos. */
    fun cadastrar(): Job {
        val atual = _estado.value
        if (!atual.podeEditar) return escopoDeTrabalho.launch { }

        val erros = validar(atual)
        if (erros.isNotEmpty()) {
            _estado.update { it.copy(errosDeCampo = erros, erro = null) }
            return escopoDeTrabalho.launch { }
        }
        val corpo = NovoEstabelecimentoDto(
            nome = atual.nome.trim(),
            documento = atual.documento,
            tipo = atual.tipo.chave,
            endereco = atual.endereco.trim(),
            regiaoAdministrativa = atual.regiaoAdministrativa,
            ponto = CoordenadaDto(lerGrau(atual.latitude)!!, lerGrau(atual.longitude)!!),
        )
        _estado.update { it.copy(enviando = true, errosDeCampo = emptyMap(), erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val criado = cadastrar(corpo)
                _estado.update { it.copy(enviando = false, estabelecimentoCriado = criado) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { aplicarRecusa(it.copy(enviando = false), erro) }
            } catch (_: Exception) {
                // Corpo não-JSON de gateway ou campo ausente escapam do ErroDaApi; sem isto o botão
                // ficaria em "Cadastrando…" para sempre. A mensagem nunca carrega o corpo cru (RN15).
                _estado.update { it.copy(enviando = false, erro = ErroGlobalCadastro.GENERICO) }
            }
        }
    }

    private fun validar(estado: EstadoCadastroEstabelecimento): Map<CampoCadastro, String> = buildMap {
        if (estado.nome.isBlank()) put(CampoCadastro.NOME, TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO)
        if (estado.documento.length != 11 && estado.documento.length != 14) {
            put(CampoCadastro.DOCUMENTO, TextosCadastroEstabelecimento.DOCUMENTO_INVALIDO)
        }
        if (estado.endereco.isBlank()) put(CampoCadastro.ENDERECO, TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO)
        if (estado.regiaoAdministrativa.isBlank()) {
            put(CampoCadastro.REGIAO_ADMINISTRATIVA, TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO)
        } else if (estado.regiaoAdministrativa !in REGIOES_ADMINISTRATIVAS_DF) {
            put(CampoCadastro.REGIAO_ADMINISTRATIVA, TextosCadastroEstabelecimento.REGIAO_INVALIDA)
        }
        validarGrau(estado.latitude, 90.0)?.let { put(CampoCadastro.LATITUDE, it) }
        validarGrau(estado.longitude, 180.0)?.let { put(CampoCadastro.LONGITUDE, it) }
    }

    private fun validarGrau(texto: String, limite: Double): String? {
        if (texto.isBlank()) return TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO
        val grau = lerGrau(texto)
        return if (grau == null || grau < -limite || grau > limite) TextosCadastroEstabelecimento.COORDENADA_INVALIDA else null
    }

    private fun aplicarRecusa(estado: EstadoCadastroEstabelecimento, erro: ErroDaApi): EstadoCadastroEstabelecimento =
        when (erro.codigo) {
            CodigoErroAPI.DOCUMENTO_JA_CADASTRADO -> estado.copy(
                erro = ErroGlobalCadastro.DOCUMENTO_DUPLICADO,
                errosDeCampo = mapOf(CampoCadastro.DOCUMENTO to TextosCadastroEstabelecimento.ERRO_DOCUMENTO_DUPLICADO),
            )
            CodigoErroAPI.CAMPO_OBRIGATORIO, CodigoErroAPI.CAMPO_INVALIDO -> {
                val mensagem = if (erro.codigo == CodigoErroAPI.CAMPO_OBRIGATORIO) {
                    TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO
                } else {
                    TextosCadastroEstabelecimento.CAMPO_INVALIDO
                }
                val campos = camposDaRecusa(erro.detalhes)
                if (campos.isEmpty()) {
                    estado.copy(erro = ErroGlobalCadastro.CONFIRA_CAMPOS)
                } else {
                    estado.copy(errosDeCampo = campos.associateWith { mensagem }, erro = ErroGlobalCadastro.CONFIRA_CAMPOS)
                }
            }
            CodigoErroAPI.PERFIL_INCOMPATIVEL -> estado.copy(erro = ErroGlobalCadastro.PERFIL_INCOMPATIVEL)
            CodigoErroAPI.CONTA_SUSPENSA -> estado.copy(erro = ErroGlobalCadastro.CONTA_SUSPENSA)
            CodigoErroAPI.SEM_PERMISSAO -> estado.copy(
                erro = if (erro.detalhes == "conta_suspensa") ErroGlobalCadastro.CONTA_SUSPENSA else ErroGlobalCadastro.SEM_PERMISSAO,
            )
            CodigoErroAPI.NAO_AUTENTICADO -> estado.copy(erro = ErroGlobalCadastro.SESSAO_EXPIRADA)
            CodigoErroAPI.SEM_REDE -> estado.copy(erro = ErroGlobalCadastro.SEM_REDE)
            else -> estado.copy(erro = ErroGlobalCadastro.GENERICO)
        }

    /** O servidor devolve o nome do campo do contrato em `details`; `ponto` cobre latitude e longitude. */
    private fun camposDaRecusa(detalhes: String?): Set<CampoCadastro> = when (detalhes) {
        "nome" -> setOf(CampoCadastro.NOME)
        "documento" -> setOf(CampoCadastro.DOCUMENTO)
        "endereco" -> setOf(CampoCadastro.ENDERECO)
        "regiao_administrativa" -> setOf(CampoCadastro.REGIAO_ADMINISTRATIVA)
        "ponto", "latitude", "longitude" -> setOf(CampoCadastro.LATITUDE, CampoCadastro.LONGITUDE)
        else -> emptySet()
    }
}

/** Aceita "-15,78" e "-15.78"; `null` se não for um número finito. */
internal fun lerGrau(texto: String): Double? =
    texto.trim().replace(',', '.').toDoubleOrNull()?.takeIf { it.isFinite() }
