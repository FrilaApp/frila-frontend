package br.com.frila.feature.chamadas.casa

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.FrilaBottomSheet
import br.com.frila.core.designsystem.componentes.FrilaGrupoDeLinhas
import br.com.frila.core.designsystem.componentes.FrilaLinhaDeOpcao
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.MeuEstabelecimentoDto
import java.time.Duration
import java.time.Instant

/** O que a folha da busca decide ao tocar em "Enviar chamadas". */
internal sealed interface ResultadoDaFolha {
    data class Pronto(val trabalho: TrabalhoDaChamada, val recado: String?) : ResultadoDaFolha

    /** O primeiro motivo que impede o envio, no texto de [TextosChamadaCasa]. */
    data class Falta(val motivo: String) : ResultadoDaFolha
}

/**
 * Valida os campos da folha com as mesmas regras de [EstadoChamadaDireta] (valor, total confirmado, responsável,
 * início a 2 h ou mais, turno de 2 a 16 h, recado até 300 caracteres) e monta o [TrabalhoDaChamada] de todos os
 * selecionados. O início e o término vêm como o texto "dd/mm/aaaa hh:mm" no fuso do DF.
 */
internal fun validarFolhaDaBusca(
    funcaoId: String?,
    casa: MeuEstabelecimentoDto?,
    valorTexto: String,
    totalConfirmado: Boolean,
    inicioTexto: String,
    fimTexto: String,
    responsavel: String,
    recado: String,
    agora: Instant,
): ResultadoDaFolha {
    if (funcaoId == null || casa == null) return ResultadoDaFolha.Falta(TextosChamadaCasa.BUSCA_SEM_CASA)
    val valor = ValorEmReais.centavos(valorTexto) ?: 0L
    val inicio = lerDataEHora(inicioTexto)
    val fim = lerDataEHora(fimTexto)
    return when {
        valor <= 0 -> ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_VALOR)
        !totalConfirmado -> ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL)
        responsavel.isBlank() -> ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_RESPONSAVEL)
        inicio == null || fim == null -> ResultadoDaFolha.Falta(TextosChamadaCasa.BUSCA_DATA_INVALIDA)
        Duration.between(agora, inicio) < EstadoChamadaDireta.ANTECEDENCIA_MINIMA ->
            ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_ANTECEDENCIA)
        Duration.between(inicio, fim) !in EstadoChamadaDireta.DURACAO_MINIMA..EstadoChamadaDireta.DURACAO_MAXIMA ->
            ResultadoDaFolha.Falta(TextosChamadaCasa.FALTA_DURACAO)
        recado.length > EstadoChamadaDireta.TAMANHO_MAXIMO_DO_RECADO -> ResultadoDaFolha.Falta(TextosChamadaCasa.RECADO_LONGO)
        else -> ResultadoDaFolha.Pronto(
            trabalho = TrabalhoDaChamada(
                funcaoId = funcaoId,
                inicio = inicio,
                fim = fim,
                local = casa.endereco,
                regiaoAdministrativa = casa.regiaoAdministrativa,
                ponto = casa.ponto,
                valorCentavos = valor,
                responsavelLocal = responsavel.trim(),
            ),
            recado = recado.trim().takeIf { it.isNotEmpty() },
        )
    }
}

/**
 * A folha de chamar os selecionados: formulário curto, com valor total e a confirmação dele, horário, responsável e
 * recado, uma vez para todos. UM primário por vez ("Enviar chamadas"; depois do envio, o que resolve o resultado:
 * tentar de novo, confirmar o aviso ou confirmar os termos da vaga já aberta). Depois do envio mostra o resultado de
 * cada pessoa (enviada, aviso J7 para confirmar ou erro).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun FolhaDeChamadaDaBusca(
    estado: EstadoBusca,
    relogio: () -> Instant,
    aoChamar: (TrabalhoDaChamada, String?) -> Unit,
    aoReenviar: () -> Unit,
    aoConfirmarJ7: () -> Unit,
    aoFechar: () -> Unit,
    modifier: Modifier = Modifier,
    aoConfirmarTermos: () -> Unit = {},
    aoCancelarTermos: () -> Unit = {},
) {
    val horarioDoFiltro = estado.horario
    val comeco = horarioDoFiltro?.inicio ?: relogio().plus(Duration.ofHours(24))
    val termino = horarioDoFiltro?.fim ?: comeco.plus(Duration.ofHours(4))
    var valor by rememberSaveable { mutableStateOf("") }
    var totalConfirmado by rememberSaveable { mutableStateOf(false) }
    var inicioTexto by rememberSaveable { mutableStateOf(dataEHora(comeco)) }
    var fimTexto by rememberSaveable { mutableStateOf(dataEHora(termino)) }
    var responsavel by rememberSaveable { mutableStateOf(estado.casa?.nome.orEmpty()) }
    var recado by rememberSaveable { mutableStateOf("") }
    var faltando by rememberSaveable { mutableStateOf<String?>(null) }
    val travada = estado.enviando || estado.resultadosDaChamada.isNotEmpty()

    FrilaBottomSheet(onDismissRequest = aoFechar, modifier = modifier, titulo = TextosChamadaCasa.BUSCA_FOLHA_TITULO) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = FrilaEspacamento.grupo)
                .padding(bottom = FrilaEspacamento.grupo),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco),
        ) {
            if (estado.casa == null) {
                AvisoFrila(tom = TomAviso.ALERTA, mensagem = TextosChamadaCasa.BUSCA_SEM_CASA)
            }
            CampoDeTexto(
                valor = valor,
                aoMudar = {
                    valor = ValorEmReais.digitado(it, anterior = valor)
                    totalConfirmado = false
                },
                rotulo = "${TextosChamadaCasa.VALOR_TOTAL} (${TextosChamadaCasa.MOEDA})",
                dica = TextosChamadaCasa.VALOR_EXEMPLO,
                habilitado = !travada,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.testTag("folha-valor"),
            )
            FrilaGrupoDeLinhas {
                linha {
                    FrilaLinhaDeOpcao(
                        titulo = TextosChamadaCasa.CONFIRMAR_TOTAL,
                        marcada = totalConfirmado,
                        aoClicar = { totalConfirmado = !totalConfirmado },
                        habilitada = !travada,
                        modifier = Modifier.testTag("folha-confirmar-total"),
                    )
                }
            }
            CampoDeTexto(
                valor = inicioTexto,
                aoMudar = { inicioTexto = it },
                rotulo = TextosChamadaCasa.BUSCA_INICIO,
                habilitado = !travada,
                modifier = Modifier.testTag("folha-inicio"),
            )
            CampoDeTexto(
                valor = fimTexto,
                aoMudar = { fimTexto = it },
                rotulo = TextosChamadaCasa.BUSCA_TERMINO,
                habilitado = !travada,
                modifier = Modifier.testTag("folha-fim"),
            )
            CampoDeTexto(
                valor = responsavel,
                aoMudar = { responsavel = it },
                rotulo = TextosChamadaCasa.RESPONSAVEL,
                habilitado = !travada,
                modifier = Modifier.testTag("folha-responsavel"),
            )
            CampoDeTexto(
                valor = recado,
                aoMudar = { recado = it },
                rotulo = TextosChamadaCasa.RECADO,
                habilitado = !travada,
                umaLinha = false,
                linhasMinimas = 3,
                modifier = Modifier.testTag("folha-recado"),
            )
            if (estado.resultadosDaChamada.isEmpty()) {
                faltando?.let { motivo ->
                    if (!estado.enviando) MensagemJuntoAoBotao(motivo, modifier = Modifier.testTag("folha-falta"))
                }
                if (estado.enviando) {
                    Text(text = TextosChamadaCasa.CARREGANDO, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
                }
                BotaoPrimario(
                    texto = TextosChamadaCasa.BUSCA_FOLHA_ENVIAR,
                    aoClicar = {
                        val resultado = validarFolhaDaBusca(
                            funcaoId = estado.filtroDaBusca?.funcaoId,
                            casa = estado.casa,
                            valorTexto = valor,
                            totalConfirmado = totalConfirmado,
                            inicioTexto = inicioTexto,
                            fimTexto = fimTexto,
                            responsavel = responsavel,
                            recado = recado,
                            agora = relogio(),
                        )
                        when (resultado) {
                            is ResultadoDaFolha.Falta -> faltando = resultado.motivo
                            is ResultadoDaFolha.Pronto -> {
                                faltando = null
                                aoChamar(resultado.trabalho, resultado.recado)
                            }
                        }
                    },
                    habilitado = !estado.enviando,
                    modifier = Modifier.fillMaxWidth().testTag("folha-enviar"),
                )
            }
            if (estado.resultadosDaChamada.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(TextosChamadaCasa.RESUMO_DA_CHAMADA)
                    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                            estado.selecionados.forEach { id ->
                                val nome = estado.resultados.firstOrNull { it.id == id }?.nome ?: id
                                val texto = when (val resultado = estado.resultadosDaChamada[id]) {
                                    is ResultadoDaChamadaDaBusca.Enviada -> TextosChamadaCasa.BUSCA_RESULTADO_ENVIADA
                                    ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia -> TextosChamadaCasa.BUSCA_RESULTADO_J7
                                    ResultadoDaChamadaDaBusca.NaoEnviada -> TextosChamadaCasa.BUSCA_RESULTADO_NAO_ENVIADA
                                    is ResultadoDaChamadaDaBusca.Erro -> resultado.mensagem
                                    is ResultadoDaChamadaDaBusca.PedeConfirmacaoDosTermos ->
                                        TextosChamadaCasa.buscaTermosDaVagaAberta(linhaDosTermos(resultado.termos))
                                    null -> TextosChamadaCasa.CARREGANDO
                                }
                                Text(
                                    text = "$nome: $texto",
                                    style = FrilaTipo.corpo,
                                    color = FrilaTema.cores.tinta,
                                    modifier = Modifier.testTag("folha-resultado-$id"),
                                )
                            }
                        }
                    }
                }
            }
            if (estado.podeReenviar) {
                // Mesmo trabalho e mesma chave: os campos seguem travados para o servidor devolver a chamada já criada.
                BotaoPrimario(
                    texto = TextosChamadaCasa.BUSCA_REENVIAR,
                    aoClicar = aoReenviar,
                    modifier = Modifier.fillMaxWidth().testTag("folha-reenviar"),
                )
            }
            if (estado.mostrarJ7) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    AvisoFrila(tom = TomAviso.ALERTA, titulo = TextosChamadaCasa.J7_TITULO, mensagem = TextosChamadaCasa.J7_MENSAGEM)
                    // Com envio incerto pendente a vaga pode já existir: confirmar agora poderia criar outra.
                    if (estado.podeReenviar) MensagemJuntoAoBotao(TextosChamadaCasa.BUSCA_CONFIRMAR_DEPOIS)
                    BotaoPrimario(
                        texto = TextosChamadaCasa.J7_CONFIRMAR,
                        aoClicar = aoConfirmarJ7,
                        // Com termos da vaga aberta por confirmar, eles vêm primeiro (o J7 não mandaria nada).
                        habilitado = !estado.enviando && !estado.podeReenviar && estado.termosParaConfirmar == null,
                        modifier = Modifier.fillMaxWidth().testTag("folha-confirmar-j7"),
                    )
                }
            }
            estado.termosParaConfirmar?.let { termos ->
                // 0.2.95: a vaga já aberta do trabalho tem outros termos; nada sai antes de Confirmar, e Cancelar não manda nada.
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    Text(
                        text = TextosChamadaCasa.buscaTermosDaVagaAberta(linhaDosTermos(termos)),
                        style = FrilaTipo.corpo,
                        color = FrilaTema.cores.tinta,
                        modifier = Modifier.testTag("folha-termos-da-vaga"),
                    )
                    BotaoPrimario(
                        texto = TextosChamadaCasa.BUSCA_TERMOS_DA_VAGA_CONFIRMAR,
                        aoClicar = aoConfirmarTermos,
                        habilitado = !estado.enviando,
                        modifier = Modifier.fillMaxWidth().testTag("folha-termos-confirmar"),
                    )
                    BotaoSecundario(
                        texto = TextosChamadaCasa.CANCELAR,
                        aoClicar = aoCancelarTermos,
                        modifier = Modifier.fillMaxWidth().testTag("folha-termos-cancelar"),
                    )
                }
            }
            AcaoDiscreta(
                texto = if (travada) TextosChamadaCasa.FECHAR else TextosChamadaCasa.CANCELAR,
                aoClicar = aoFechar,
                modifier = Modifier.testTag("folha-fechar"),
            )
        }
    }
}

/** "R$ 150,00, Refeição inclusa, sem transporte" (e ", Exige material próprio" quando a vaga exige), como no iOS. */
internal fun linhaDosTermos(termos: TermosDaVagaAberta): String {
    val refeicaoETransporte = when {
        termos.incluiRefeicao && termos.incluiTransporte -> TextosChamadaCasa.REFEICAO_E_TRANSPORTE_INCLUSOS
        termos.incluiRefeicao -> TextosChamadaCasa.REFEICAO_INCLUSA_SEM_TRANSPORTE
        termos.incluiTransporte -> TextosChamadaCasa.SEM_REFEICAO_TRANSPORTE_INCLUSO
        else -> TextosChamadaCasa.SEM_REFEICAO_NEM_TRANSPORTE
    }
    val material = TextosChamadaCasa.EXIGE_MATERIAL_PROPRIO.takeIf { termos.exigeMaterialProprio }
    return listOfNotNull(dinheiro(termos.valorCentavos), refeicaoETransporte, material).joinToString(", ")
}
