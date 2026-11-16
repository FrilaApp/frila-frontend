package br.com.frila.feature.chamadas.profissional

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.DefinirPreferenciaChamadasDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PerfilProfissionalDetalhadoDto
import br.com.frila.core.rede.PreferenciaChamadasDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import java.time.LocalDate

data class EstadoPreferenciasChamada(
    val carregando: Boolean = true,
    /** Lido do servidor com sucesso; sem isso a tela não deixa salvar valores inventados. */
    val carregou: Boolean = false,
    val salvando: Boolean = false,
    val aceitaChamadas: Boolean = false,
    val aceitaDeQuemJaTrabalhou: Boolean = true,
    val pausar: Boolean = false,
    val pausadoAte: LocalDate,
    val antecedenciaMinimaH: Int = 6,
    /** `todos` ou `so_cnpj`. */
    val aceitaDe: String = "todos",
    /** O que ainda impede de aparecer na busca (`pendencias_para_busca` da última resposta). */
    val pendencias: List<String> = emptyList(),
    val erro: String? = null,
    val sucesso: Boolean = false,
) {
    /** O dia em que a pausa acaba de fato: a retomada é às 00:00 do dia seguinte à data escolhida. */
    val diaDaRetomada: LocalDate get() = pausadoAte.plusDays(1)
}

/**
 * Preferências de chamada do profissional (CD-P10 a CD-P12, RN30, RN43; paridade com
 * `PreferenciasChamadaViewModel.swift`): "Aceito chamadas diretas" (com a versão do texto), pausa até uma data,
 * antecedência mínima, quem pode chamar. Lê de `meu_perfil_detalhado` e grava por `definir_preferencia_chamadas`,
 * que traz de volta as `pendencias_para_busca`. Cada campo só vai ao servidor se mudou: campo omitido fica como
 * está, e `aceita_chamadas` ligado de novo gravaria outro registro do pedido do titular sem necessidade.
 *
 * [carregarPerfil] é `ServicoChamadaDireta.meuPerfilDetalhado`; [definirPreferencias] é `definirPreferenciaChamadas`.
 * [hoje] devolve o dia civil de Brasília (teste injeta); uma pausa NOVA só vale a partir de amanhã, e a do servidor (inclusiva) vale até hoje.
 */
class PreferenciasChamadaViewModel(
    private val carregarPerfil: suspend () -> PerfilProfissionalDetalhadoDto,
    private val definirPreferencias: suspend (DefinirPreferenciaChamadasDto) -> PreferenciaChamadasDto,
    private val hoje: () -> LocalDate = { LocalDate.now(FormatoChamada.fuso) },
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoPreferenciasChamada(pausadoAte = hoje().plusDays(1)))
    val estado: StateFlow<EstadoPreferenciasChamada> = _estado.asStateFlow()

    /** O que o servidor tem agora; a base para saber o que mudou. */
    private var base: PreferenciaChamadasDto? = null
    private var carregandoAgora = false

    /** Também serve de "tentar novamente". Duas cargas ao mesmo tempo viram uma. */
    fun carregar(): Job {
        if (carregandoAgora) return escopoDeTrabalho.launch { }
        carregandoAgora = true
        _estado.update { it.copy(carregando = true, erro = null, sucesso = false) }
        return escopoDeTrabalho.launch {
            try {
                val perfil = carregarPerfil()
                val preferencias = perfil.preferenciaChamadas
                if (preferencias == null) {
                    _estado.update { it.copy(carregando = false, erro = TextosChamadaProfissional.ERRO) }
                } else {
                    aplicar(preferencias, sucesso = false)
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(carregando = false, erro = TextosChamadaProfissional.ERRO) }
            } finally {
                carregandoAgora = false
            }
        }
    }

    fun alternarAceitaChamadas(ligado: Boolean) = editar { it.copy(aceitaChamadas = ligado) }
    fun alternarAceitaDeQuemJaTrabalhou(ligado: Boolean) = editar { it.copy(aceitaDeQuemJaTrabalhou = ligado) }
    fun alternarPausa(ligada: Boolean) = editar { it.copy(pausar = ligada) }
    fun escolherDataDaPausa(dia: LocalDate) = editar { it.copy(pausadoAte = dia) }
    fun escolherAntecedencia(horas: Int) = editar { it.copy(antecedenciaMinimaH = horas) }
    fun escolherQuemPodeChamar(aceitaDe: String) = editar { it.copy(aceitaDe = aceitaDe) }

    private fun editar(mudanca: (EstadoPreferenciasChamada) -> EstadoPreferenciasChamada) {
        _estado.update { mudanca(it).copy(sucesso = false) }
    }

    /** Sem efeito antes de carregar ou com outro salvamento em voo: o segundo toque não dispara outro pedido. */
    fun salvar(): Job {
        val atual = _estado.value
        val servidor = base
        if (!atual.carregou || atual.salvando || servidor == null) return escopoDeTrabalho.launch { }
        // "A partir de amanhã" vale só para uma data que a pessoa mudou; a pausa que o servidor já tem (até hoje, inclusive) segue.
        if (atual.pausar && atual.pausadoAte != pausaVigente(servidor) && !atual.pausadoAte.isAfter(hoje())) {
            _estado.update { it.copy(erro = TextosChamadaProfissional.DATA_DA_PAUSA_INVALIDA, sucesso = false) }
            return escopoDeTrabalho.launch { }
        }
        val pedido = montarPedido(atual, servidor)
        if (pedido == DefinirPreferenciaChamadasDto()) {
            // Nada mudou: o servidor recusaria um pedido sem campo (`campo_obrigatorio`, `nenhum_campo`).
            _estado.update { it.copy(erro = null, sucesso = true) }
            return escopoDeTrabalho.launch { }
        }
        _estado.update { it.copy(salvando = true, erro = null, sucesso = false) }
        return escopoDeTrabalho.launch {
            try {
                val resposta = definirPreferencias(pedido)
                aplicar(resposta, sucesso = true)
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(salvando = false, erro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(salvando = false, erro = TextosChamadaProfissional.ERRO) }
            }
        }
    }

    private fun montarPedido(tela: EstadoPreferenciasChamada, servidor: PreferenciaChamadasDto): DefinirPreferenciaChamadasDto {
        val ligouAgora = tela.aceitaChamadas && servidor.aceitaChamadas != true
        val desligouAgora = !tela.aceitaChamadas && servidor.aceitaChamadas == true
        // Pausa já vencida no servidor vale como "sem pausa": não é mudança da pessoa, então não vai no pedido.
        val pausaAtual = pausaVigente(servidor)?.toString()
        val pausaDaTela = if (tela.pausar) tela.pausadoAte.toString() else null
        return DefinirPreferenciaChamadasDto(
            aceitaDeQuemJaTrabalhou = tela.aceitaDeQuemJaTrabalhou.takeIf { it != servidor.aceitaDeQuemJaTrabalhou },
            // `null` do JSON tira a pausa; ausente a mantém. Só vai se a pausa mudou.
            pausadoAte = when {
                pausaDaTela == pausaAtual -> null
                pausaDaTela == null -> JsonNull
                else -> JsonPrimitive(pausaDaTela)
            },
            antecedenciaMinimaH = tela.antecedenciaMinimaH.takeIf { it != servidor.antecedenciaMinimaH },
            aceitaDe = tela.aceitaDe.takeIf { it != servidor.aceitaDe },
            aceitaChamadas = if (ligouAgora || desligouAgora) tela.aceitaChamadas else null,
            versaoTextoBusca = if (ligouAgora) TextosChamadaProfissional.VERSAO_TEXTO_BUSCA else null,
        )
    }

    private fun aplicar(servidor: PreferenciaChamadasDto, sucesso: Boolean) {
        base = servidor
        _estado.update { tela ->
            val pausa = pausaVigente(servidor)
            tela.copy(
                carregando = false,
                carregou = true,
                salvando = false,
                aceitaChamadas = servidor.aceitaChamadas == true,
                aceitaDeQuemJaTrabalhou = servidor.aceitaDeQuemJaTrabalhou,
                pausar = pausa != null,
                pausadoAte = pausa ?: tela.pausadoAte,
                antecedenciaMinimaH = servidor.antecedenciaMinimaH,
                aceitaDe = servidor.aceitaDe,
                pendencias = servidor.pendenciasParaBusca,
                erro = null,
                sucesso = sucesso,
            )
        }
    }

    /**
     * A pausa que ainda vale: `pausado_ate` é INCLUSIVO (a data até a qual ninguém chama; a retomada é às 00:00 do dia
     * seguinte), então uma pausa até hoje continua em vigor e a pessoa pode tirá-la (vai `pausado_ate: null`). Só data
     * ANTES de hoje volta como sem pausa. A regra "a partir de amanhã" vale para a data que a pessoa escolhe, nunca
     * para o que veio do servidor, senão uma pausa vencida travaria o Salvar de qualquer outro campo.
     */
    private fun pausaVigente(servidor: PreferenciaChamadasDto): LocalDate? =
        servidor.pausadoAte
            ?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
            ?.takeIf { !it.isBefore(hoje()) }

    private fun mensagemDeErro(erro: ErroDaApi): String = when {
        erro.recursoDesligado -> TextosChamadaProfissional.DESLIGADO
        erro.contaSuspensa -> TextosChamadaProfissional.CONTA_SUSPENSA
        erro.codigo == CodigoErroAPI.PERFIL_INCOMPATIVEL -> TextosChamadaProfissional.SO_PROFISSIONAL
        erro.codigo == CodigoErroAPI.CAMPO_INVALIDO && erro.detalhes == "pausado_ate" ->
            TextosChamadaProfissional.DATA_DA_PAUSA_INVALIDA
        else -> TextosChamadaProfissional.ERRO
    }
}
