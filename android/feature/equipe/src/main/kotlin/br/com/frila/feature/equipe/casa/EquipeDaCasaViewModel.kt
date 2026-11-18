package br.com.frila.feature.equipe.casa

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.AdministracaoTransferidaDto
import br.com.frila.core.rede.ConviteMembroDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MembroDoEstabelecimentoDto
import br.com.frila.core.rede.MembroRemovidoDto
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Uma pessoa da casa, como o administrador a vê. [papel] é nulo para um papel que este cliente não conhece. */
data class MembroDaCasa(
    val membroId: String,
    val nome: String,
    val papel: PapelMembro?,
    val desde: Instant?,
    val eVoce: Boolean,
)

internal fun MembroDoEstabelecimentoDto.paraMembroDaCasa() = MembroDaCasa(
    membroId = membroId,
    nome = nome,
    papel = PapelMembro.deChave(papel),
    desde = runCatching { OffsetDateTime.parse(desde).toInstant() }.getOrNull(),
    eVoce = eVoce,
)

/** O que a lista mostra. As mensagens já vêm em texto do Frila: a tela não decide texto de erro. */
sealed interface ListaDaEquipe {
    data object Carregando : ListaDaEquipe

    /** Quem não é administrador não lê a lista: a tela só diz isso, sem botão algum. */
    data object SoAdministrador : ListaDaEquipe
    data class Conteudo(val membros: List<MembroDaCasa>) : ListaDaEquipe
    data class Erro(val mensagem: String, val podeTentarDeNovo: Boolean = true) : ListaDaEquipe
}

/** O que a pessoa vai fazer com alguém da casa, atrás de uma confirmação. */
enum class AcaoSobreMembro { REMOVER, TRANSFERIR }

/** Uma ação aguardando o "Confirmar". Guarda só o id e o nome, para o diálogo. */
data class AcaoPendente(val acao: AcaoSobreMembro, val membroId: String, val nome: String)

/** Convite gerado: o link para compartilhar e até quando vale (`null` se o servidor mandou um instante ilegível). */
data class ConviteGerado(val link: String, val email: String, val expiraEm: Instant?)

data class EstadoEquipeDaCasa(
    /** O papel de quem abriu a tela nesta casa. Só `administrador` convida, remove e transfere. */
    val papel: PapelMembro?,
    val lista: ListaDaEquipe = ListaDaEquipe.Carregando,
    val email: String = "",
    val papelConvidado: PapelMembro = PapelMembro.OPERADOR,
    val erroDoEmail: String? = null,
    val gerandoConvite: Boolean = false,
    val convite: ConviteGerado? = null,
    val erroDoConvite: String? = null,
    /** Uma pergunta de confirmação aberta. */
    val pendente: AcaoPendente? = null,
    /** O `membroId` cuja ação está em voo. */
    val agindoEm: String? = null,
    val aviso: String? = null,
    val erroDaAcao: String? = null,
) {
    val podeGerenciar: Boolean get() = papel?.podeGerenciarEquipe == true
    val ocupado: Boolean get() = gerandoConvite || agindoEm != null
}

/**
 * Equipe da casa (RF21, US24; contrato 0.2.73 e 0.2.103; paridade com a web, PRs #891 e #916): lista de quem faz parte,
 * convite por link, remover e tornar administrador.
 *
 * **Quem pode:** só o administrador. Com outro papel, o ViewModel nem pede a lista e a tela não tem botão algum; o
 * servidor continua sendo a regra (`403 sem_permissao` em cada chamada vira uma mensagem, mesmo depois de a lista
 * ter vindo). Quem está na lista como "você" não tem "Remover" nem "Tornar administrador": o app não oferece sair
 * da casa por aqui.
 *
 * **Convite sem deep link:** [montarLink] monta o link da web (`<origem>/convite#<token>`); a tela o entrega à folha de
 * compartilhar do sistema. O token nunca vai para log nem para mensagem de erro.
 *
 * [listar], [convidar], [remover] e [transferir] são as chamadas de `ServicoMembros`. `escopo`: mesma razão do
 * `PerfilViewModel`.
 */
class EquipeDaCasaViewModel(
    private val estabelecimentoId: String,
    papel: PapelMembro?,
    private val listar: suspend (estabelecimentoId: String) -> List<MembroDoEstabelecimentoDto>,
    private val convidar: suspend (estabelecimentoId: String, email: String, papel: String) -> ConviteMembroDto,
    private val remover: suspend (estabelecimentoId: String, membroId: String) -> MembroRemovidoDto,
    private val transferir: suspend (estabelecimentoId: String, novoAdminId: String) -> AdministracaoTransferidaDto,
    private val montarLink: (token: String) -> String,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(
        EstadoEquipeDaCasa(
            papel = papel,
            lista = if (papel?.podeGerenciarEquipe == true) ListaDaEquipe.Carregando else ListaDaEquipe.SoAdministrador,
        ),
    )
    val estado: StateFlow<EstadoEquipeDaCasa> = _estado.asStateFlow()

    /** Lê a lista. Sem efeito para quem não é administrador. [silencioso] relê com a lista antiga na tela (depois de uma ação). */
    fun carregar(silencioso: Boolean = false): Job {
        if (!_estado.value.podeGerenciar) return escopoDeTrabalho.launch { }
        if (!silencioso) _estado.update { it.copy(lista = ListaDaEquipe.Carregando) }
        return escopoDeTrabalho.launch {
            try {
                val membros = listar(estabelecimentoId).map { it.paraMembroDaCasa() }
                _estado.update { it.copy(lista = ListaDaEquipe.Conteudo(membros)) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { atual ->
                    when {
                        // 403 sem `details`: a pessoa não é (mais) administrador. Some a lista e somem as ações.
                        erro.ehRecusaDeAdministrador -> atual.semAcessoDeAdministrador()
                        // Conta suspensa: nada da casa se administra agora; a lista antiga não fica na tela.
                        erro.codigo == CodigoErroAPI.CONTA_SUSPENSA || erro.detalhes == "conta_suspensa" ->
                            atual.copy(lista = ListaDaEquipe.Erro(TextosEquipeDaCasa.CONTA_SUSPENSA))
                        // Com a lista antiga na tela, a falha da releitura não a apaga.
                        silencioso && atual.lista is ListaDaEquipe.Conteudo -> atual
                        else -> atual.copy(lista = ListaDaEquipe.Erro(mensagemDaLista(erro)))
                    }
                }
            } catch (_: Exception) {
                // Corpo que não é JSON ou campo ausente escapam do ErroDaApi; sem isto a tela ficaria em "carregando".
                _estado.update { atual ->
                    if (silencioso && atual.lista is ListaDaEquipe.Conteudo) atual else atual.copy(lista = ListaDaEquipe.Erro(TextosEquipeDaCasa.ERRO_DA_LISTA))
                }
            }
        }
    }

    fun editarEmail(texto: String) = editar { copy(email = texto, erroDoEmail = null, erroDoConvite = null) }

    fun escolherPapel(papel: PapelMembro) = editar { copy(papelConvidado = papel, erroDoConvite = null) }

    private fun editar(mudar: EstadoEquipeDaCasa.() -> EstadoEquipeDaCasa) {
        _estado.update { if (it.podeGerenciar && !it.gerandoConvite) it.mudar() else it }
    }

    /** Valida o e-mail e gera o convite. Sem efeito para quem não é administrador e durante outra chamada. */
    fun gerarConvite(): Job {
        val atual = _estado.value
        if (!atual.podeGerenciar || atual.ocupado) return escopoDeTrabalho.launch { }
        val email = atual.email.trim()
        if (!EMAIL.matches(email)) {
            _estado.update { it.copy(erroDoEmail = TextosEquipeDaCasa.EMAIL_INVALIDO, erroDoConvite = null) }
            return escopoDeTrabalho.launch { }
        }
        val papel = atual.papelConvidado
        _estado.update { it.copy(gerandoConvite = true, erroDoEmail = null, erroDoConvite = null, aviso = null, erroDaAcao = null) }
        return escopoDeTrabalho.launch {
            try {
                val convite = convidar(estabelecimentoId, email, papel.chave)
                if (!TOKEN.matches(convite.token)) throw IllegalStateException("token fora do formato")
                _estado.update {
                    it.copy(
                        gerandoConvite = false,
                        email = "",
                        convite = ConviteGerado(
                            link = montarLink(convite.token),
                            email = email,
                            expiraEm = runCatching { OffsetDateTime.parse(convite.expiraEm).toInstant() }.getOrNull(),
                        ),
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update {
                    if (erro.ehRecusaDeAdministrador) {
                        it.semAcessoDeAdministrador(erroDoConvite = TextosEquipeDaCasa.SO_ADMINISTRADOR)
                    } else {
                        aplicarErroDoConvite(it.copy(gerandoConvite = false), erro)
                    }
                }
            } catch (_: Exception) {
                _estado.update { it.copy(gerandoConvite = false, erroDoConvite = TextosEquipeDaCasa.ERRO) }
            }
        }
    }

    /** Abre a confirmação. Remover e transferir não valem para a linha de "você". */
    fun pedirConfirmacao(acao: AcaoSobreMembro, membro: MembroDaCasa) {
        _estado.update {
            if (!it.podeGerenciar || it.ocupado || membro.eVoce) it else it.copy(pendente = AcaoPendente(acao, membro.membroId, membro.nome), erroDaAcao = null)
        }
    }

    fun cancelarConfirmacao() = _estado.update { it.copy(pendente = null) }

    /** Executa a ação confirmada. Depois do sucesso a lista é relida; a recusa do servidor vira mensagem. */
    fun confirmar(): Job {
        val atual = _estado.value
        val pendente = atual.pendente
        if (pendente == null || !atual.podeGerenciar || atual.ocupado) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(pendente = null, agindoEm = pendente.membroId, aviso = null, erroDaAcao = null) }
        return escopoDeTrabalho.launch {
            try {
                when (pendente.acao) {
                    AcaoSobreMembro.REMOVER -> remover(estabelecimentoId, pendente.membroId)
                    AcaoSobreMembro.TRANSFERIR -> transferir(estabelecimentoId, pendente.membroId)
                }
                _estado.update {
                    it.copy(
                        agindoEm = null,
                        aviso = if (pendente.acao == AcaoSobreMembro.REMOVER) TextosEquipeDaCasa.REMOVIDA else TextosEquipeDaCasa.TRANSFERIDA,
                    )
                }
                carregar(silencioso = true).join()
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                if (erro.ehRecusaDeAdministrador) {
                    _estado.update { it.semAcessoDeAdministrador(erroDaAcao = TextosEquipeDaCasa.SO_ADMINISTRADOR) }
                } else {
                    _estado.update { it.copy(agindoEm = null, erroDaAcao = mensagemDaAcao(erro)) }
                    // A ação recusada pode ter perdido o sentido (quem foi removido por outro administrador, por exemplo):
                    // a lista que vale é a do servidor.
                    carregar(silencioso = true).join()
                }
            } catch (_: Exception) {
                _estado.update { it.copy(agindoEm = null, erroDaAcao = TextosEquipeDaCasa.ERRO) }
                carregar(silencioso = true).join()
            }
        }
    }

    /** `403 sem_permissao` sem `details`: o servidor diz que quem chama não é administrador desta casa. */
    private val ErroDaApi.ehRecusaDeAdministrador: Boolean
        get() = codigo == CodigoErroAPI.SEM_PERMISSAO && detalhes != "conta_suspensa"

    /**
     * Depois de um 403 a tela deixa de se comportar como administrador: o papel que ela tinha cai, a lista, o convite e a
     * confirmação aberta somem, e nenhuma ação chega mais ao servidor. A mensagem certa é a do "só o administrador".
     */
    private fun EstadoEquipeDaCasa.semAcessoDeAdministrador(
        erroDoConvite: String? = null,
        erroDaAcao: String? = null,
    ) = copy(
        papel = null,
        lista = ListaDaEquipe.SoAdministrador,
        email = "",
        erroDoEmail = null,
        gerandoConvite = false,
        convite = null,
        pendente = null,
        agindoEm = null,
        aviso = null,
        erroDoConvite = erroDoConvite,
        erroDaAcao = erroDaAcao,
    )

    private fun aplicarErroDoConvite(estado: EstadoEquipeDaCasa, erro: ErroDaApi): EstadoEquipeDaCasa = when {
        erro.codigo == CodigoErroAPI.CAMPO_INVALIDO && erro.detalhes == "email" -> estado.copy(erroDoEmail = TextosEquipeDaCasa.EMAIL_INVALIDO)
        erro.codigo in setOf(CodigoErroAPI.CAMPO_OBRIGATORIO, CodigoErroAPI.CAMPO_INVALIDO) && erro.detalhes == "papel" ->
            estado.copy(erroDoConvite = TextosEquipeDaCasa.PAPEL_INVALIDO)
        else -> estado.copy(erroDoConvite = mensagemDaAcao(erro))
    }

    private fun mensagemDaLista(erro: ErroDaApi): String = when {
        erro.codigo == CodigoErroAPI.CONTA_SUSPENSA || erro.detalhes == "conta_suspensa" -> TextosEquipeDaCasa.CONTA_SUSPENSA
        erro.codigo == CodigoErroAPI.NAO_AUTENTICADO -> TextosEquipeDaCasa.SESSAO
        erro.codigo == CodigoErroAPI.SEM_REDE -> TextosEquipeDaCasa.SEM_REDE
        else -> TextosEquipeDaCasa.ERRO_DA_LISTA
    }

    /** As recusas de convidar, remover e transferir, em texto do Frila. `403 sem_permissao` sem `details` é "não é administrador". */
    private fun mensagemDaAcao(erro: ErroDaApi): String = when {
        erro.codigo == CodigoErroAPI.CONTA_SUSPENSA || erro.detalhes == "conta_suspensa" -> TextosEquipeDaCasa.CONTA_SUSPENSA
        erro.codigo == CodigoErroAPI.SEM_PERMISSAO -> TextosEquipeDaCasa.SO_ADMINISTRADOR
        erro.codigo == CodigoErroAPI.ULTIMO_ADMINISTRADOR -> TextosEquipeDaCasa.ULTIMO_ADMINISTRADOR
        erro.codigo == CodigoErroAPI.NAO_ENCONTRADO -> TextosEquipeDaCasa.INDISPONIVEL
        erro.codigo == CodigoErroAPI.NAO_AUTENTICADO -> TextosEquipeDaCasa.SESSAO
        erro.codigo == CodigoErroAPI.SEM_REDE -> TextosEquipeDaCasa.SEM_REDE
        else -> TextosEquipeDaCasa.ERRO
    }

    private companion object {
        val EMAIL = Regex("""^[^\s@]+@[^\s@]+\.[^\s@]+$""")
        val TOKEN = Regex("^[0-9a-f]{64}$")
    }
}

private val FUSO = ZoneId.of("America/Sao_Paulo")
private val FORMATO_DO_PRAZO = DateTimeFormatter.ofPattern("dd/MM 'às' HH:mm", Locale.forLanguageTag("pt-BR"))

/** "17/11 às 15:30", no horário de Brasília. */
internal fun formatarPrazoDoConvite(instante: Instant): String = instante.atZone(FUSO).format(FORMATO_DO_PRAZO)
