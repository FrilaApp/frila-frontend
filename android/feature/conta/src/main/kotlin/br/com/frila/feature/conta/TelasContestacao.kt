package br.com.frila.feature.conta

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.EstiloDoSelo
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.SeloDeStatus
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

// A contestação da suspensão (dentro da tela "Conta suspensa") e o pedido de revisão do despacho. Sem desenho
// do Fabrício: extrapoladas do mesmo sistema (leitura + uma ação; o campo com o rótulo acima; o erro junto ao botão).

/** O que a seção de contestação pode pedir ao [ContaSuspensaViewModel]. */
data class AcoesContestacaoDaSuspensao(
    val aoAbrirFormulario: () -> Unit = {},
    val aoCancelar: () -> Unit = {},
    val aoMudarRelato: (String) -> Unit = {},
    val aoEnviar: () -> Unit = {},
)

/** A tela "Conta suspensa" ligada ao servidor: lê a situação ao abrir, mostra motivo e data, e deixa contestar. */
@Composable
fun TelaContaSuspensaComContestacao(
    viewModel: ContaSuspensaViewModel,
    emailSuporte: String,
    aoContatarSuporte: (String) -> Unit,
    aoSair: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsState()
    LaunchedEffect(viewModel) { viewModel.carregar() }
    TelaContaSuspensa(
        emailSuporte = emailSuporte,
        aoContatarSuporte = aoContatarSuporte,
        aoSair = aoSair,
        modifier = modifier,
        motivo = estado.motivo,
        desde = estado.desde,
        contestacao = {
            SecaoContestacaoDaSuspensao(
                estado = estado,
                emailSuporte = emailSuporte,
                acoes = AcoesContestacaoDaSuspensao(
                    aoAbrirFormulario = viewModel::abrirFormulario,
                    aoCancelar = viewModel::cancelarFormulario,
                    aoMudarRelato = viewModel::mudarRelato,
                    aoEnviar = { viewModel.enviarContestacao() },
                ),
            )
        },
    )
}

/**
 * Um de quatro momentos: o protocolo da contestação já feita, o aviso de que ela já existe, o formulário, ou
 * o botão de contestar. O botão que avança (abrir o formulário, depois enviar) é o único laranja da tela;
 * "Cancelar" é discreto.
 */
@Composable
fun SecaoContestacaoDaSuspensao(estado: EstadoContaSuspensa, emailSuporte: String, acoes: AcoesContestacaoDaSuspensao) {
    val cores = FrilaTema.cores
    val protocolo = estado.protocolo
    val comBotoes = protocolo == null && !estado.contaReativada && !estado.contestacaoJaExiste
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        RotuloDeGrupo(TextosContaSuspensa.SECAO_CONTESTACAO)
        if (estado.carregando) TextoAoVivo(TextosContaSuspensa.CARREGANDO)
        when {
            estado.contaReativada -> TextoAoVivo(TextosContaSuspensa.CONTA_REATIVADA)
            protocolo != null -> CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                    Text(TextosContaSuspensa.PROTOCOLO_TITULO, style = FrilaTipo.rotuloSecundario, color = cores.tinta)
                    if (estado.emAnalise) SeloDeStatus(TextosContaSuspensa.EM_ANALISE, EstiloDoSelo.CONTORNO)
                    Informacao(TextosContaSuspensa.PROTOCOLO_NUMERO, protocolo.numero)
                    Informacao(TextosContaSuspensa.PROTOCOLO_DATA, protocolo.enviadoEm)
                    Informacao(TextosContaSuspensa.PRAZO_RESPOSTA, protocolo.prazoRespostaAte)
                    TextoAoVivo(
                        if (estado.emAnalise) {
                            TextosContaSuspensa.MENSAGEM_EM_ANALISE
                        } else {
                            TextosContaSuspensa.MENSAGEM_APOS_PRAZO.format(emailSuporte)
                        },
                        cor = cores.tintaSuave,
                    )
                }
            }
            estado.contestacaoJaExiste -> TextoAoVivo(TextosContaSuspensa.CONTESTACAO_JA_EXISTE)
            estado.formularioAberto -> {
                CampoDoRelato(
                    valor = estado.relato,
                    rotulo = TextosContaSuspensa.ROTULO_RELATO,
                    dica = TextosContaSuspensa.DICA_RELATO,
                    habilitado = !estado.enviando,
                    aoMudar = acoes.aoMudarRelato,
                )
                if (estado.enviando) TextoAoVivo(TextosContaSuspensa.ENVIANDO)
            }
            else -> Text(TextosContaSuspensa.PRAZO_ANALISE, style = FrilaTipo.corpo, color = cores.tintaSuave)
        }
        // O erro vem logo acima do botão que o disparou; sem botão na tela, fecha a seção.
        estado.mensagemErro?.let { MensagemJuntoAoBotao(it) }
        if (comBotoes) {
            if (estado.formularioAberto) {
                BotaoPrimario(TextosContaSuspensa.BOTAO_ENVIAR, acoes.aoEnviar, Modifier.fillMaxWidth(), habilitado = !estado.enviando)
                AcaoDiscreta(TextosContaSuspensa.CANCELAR, acoes.aoCancelar, habilitado = !estado.enviando)
            } else {
                BotaoPrimario(TextosContaSuspensa.BOTAO_CONTESTAR, acoes.aoAbrirFormulario, Modifier.fillMaxWidth())
            }
        }
    }
}

/** Liga o [ContestarDespachoViewModel] ao [ConteudoContestarDespacho]. */
@Composable
fun TelaContestarDespacho(viewModel: ContestarDespachoViewModel, aoVoltar: () -> Unit, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsState()
    ConteudoContestarDespacho(estado, aoMudarRelato = viewModel::mudarRelato, aoEnviar = { viewModel.contestar() }, aoVoltar = aoVoltar, modifier = modifier)
}

/**
 * O pedido de revisão do despacho, como uma tela de formulário: título, a explicação e o campo do relato,
 * com o erro e o botão laranja ancorados embaixo. Depois do envio (ou se já existe um pedido) não há mais
 * ação além de voltar: o protocolo vira leitura e o "Voltar" fica ancorado.
 */
@Composable
fun ConteudoContestarDespacho(
    estado: EstadoContestarDespacho,
    aoMudarRelato: (String) -> Unit,
    aoEnviar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val protocolo = estado.protocolo
    val emFormulario = protocolo == null && !estado.contestacaoJaAberta

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        bottomBar = {
            RodapeAncorado {
                if (emFormulario) {
                    estado.mensagemErro?.let { MensagemJuntoAoBotao(it) }
                    BotaoPrimario(
                        TextosContestarDespacho.BOTAO_ENVIAR,
                        aoEnviar,
                        Modifier.fillMaxWidth(),
                        habilitado = !estado.enviando,
                    )
                } else {
                    BotaoSecundario(
                        TextosContestarDespacho.VOLTAR,
                        aoVoltar,
                        Modifier.fillMaxWidth(),
                        habilitado = !estado.enviando,
                    )
                }
            }
        },
    ) { preenchimento ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(preenchimento)
                .verticalScroll(rememberScrollState())
                .padding(
                    start = FrilaEspacamento.grupo,
                    end = FrilaEspacamento.grupo,
                    top = FrilaEspacamento.respiro,
                    bottom = FrilaEspacamento.grupo,
                ),
            verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.grupo),
        ) {
            TituloDaTela(TextosContestarDespacho.TITULO)
            when {
                protocolo != null -> {
                    TextoAoVivo(TextosContestarDespacho.PEDIDO_ENVIADO, estilo = FrilaTipo.nome)
                    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                            Informacao(TextosContestarDespacho.PROTOCOLO_NUMERO, protocolo.numero)
                            Informacao(TextosContestarDespacho.PROTOCOLO_DATA, protocolo.enviadoEm)
                            Informacao(TextosContestarDespacho.PRAZO_RESPOSTA, protocolo.prazoRespostaAte)
                        }
                    }
                    Text(TextosContestarDespacho.MENSAGEM_ENVIADO, style = FrilaTipo.corpo, color = cores.tintaSuave)
                }
                estado.contestacaoJaAberta -> TextoAoVivo(TextosContestarDespacho.CONTESTACAO_JA_ABERTA)
                else -> {
                    Text(TextosContestarDespacho.EXPLICACAO, style = FrilaTipo.corpo, color = cores.tintaSuave)
                    CampoDoRelato(
                        valor = estado.relato,
                        rotulo = TextosContestarDespacho.ROTULO_RELATO,
                        dica = TextosContestarDespacho.DICA_RELATO,
                        habilitado = !estado.enviando,
                        aoMudar = aoMudarRelato,
                    )
                    if (estado.enviando) TextoAoVivo(TextosContestarDespacho.ENVIANDO)
                }
            }
        }
    }
}

@Composable
private fun CampoDoRelato(valor: String, rotulo: String, dica: String, habilitado: Boolean, aoMudar: (String) -> Unit) {
    CampoDeTexto(
        valor = valor,
        aoMudar = aoMudar,
        rotulo = rotulo,
        apoio = dica,
        habilitado = habilitado,
        umaLinha = false,
        linhasMinimas = 3,
    )
}

@Composable
private fun TextoAoVivo(
    texto: String,
    estilo: androidx.compose.ui.text.TextStyle = FrilaTipo.corpo,
    cor: androidx.compose.ui.graphics.Color = FrilaTema.cores.tinta,
) {
    Text(texto, style = estilo, color = cor, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
}
