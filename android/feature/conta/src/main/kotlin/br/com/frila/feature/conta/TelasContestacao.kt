package br.com.frila.feature.conta

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
// A contestação da suspensão (dentro da tela "Conta suspensa") e o pedido de revisão do despacho, em baixíssima
// fidelidade e só com componentes nativos, para a regra poder ser testada no emulador.

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

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** Um de quatro momentos: o protocolo da contestação já feita, o aviso de que ela já existe, o formulário, ou o botão de contestar. */
@Composable
fun SecaoContestacaoDaSuspensao(estado: EstadoContaSuspensa, emailSuporte: String, acoes: AcoesContestacaoDaSuspensao) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.pequeno)) {
        Text(TextosContaSuspensa.SECAO_CONTESTACAO, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
        if (estado.carregando) TextoAoVivo(TextosContaSuspensa.CARREGANDO)
        val protocolo = estado.protocolo
        when {
            estado.contaReativada -> TextoAoVivo(TextosContaSuspensa.CONTA_REATIVADA)
            protocolo != null -> {
                Text(TextosContaSuspensa.PROTOCOLO_TITULO, style = MaterialTheme.typography.titleSmall)
                if (estado.emAnalise) Text(TextosContaSuspensa.EM_ANALISE, style = MaterialTheme.typography.labelLarge)
                Informacao(TextosContaSuspensa.PROTOCOLO_NUMERO, protocolo.numero)
                Informacao(TextosContaSuspensa.PROTOCOLO_DATA, protocolo.enviadoEm)
                Informacao(TextosContaSuspensa.PRAZO_RESPOSTA, protocolo.prazoRespostaAte)
                TextoAoVivo(
                    if (estado.emAnalise) TextosContaSuspensa.MENSAGEM_EM_ANALISE else TextosContaSuspensa.MENSAGEM_APOS_PRAZO.format(emailSuporte),
                )
            }
            estado.contestacaoJaExiste -> TextoAoVivo(TextosContaSuspensa.CONTESTACAO_JA_EXISTE)
            estado.formularioAberto -> {
                CampoDoRelato(estado.relato, TextosContaSuspensa.ROTULO_RELATO, TextosContaSuspensa.DICA_RELATO, !estado.enviando, acoes.aoMudarRelato)
                if (estado.enviando) TextoAoVivo(TextosContaSuspensa.ENVIANDO)
                BotaoPrimario(TextosContaSuspensa.BOTAO_ENVIAR, acoes.aoEnviar, Modifier.fillMaxWidth(), habilitado = !estado.enviando)
                BotaoSecundario(TextosContaSuspensa.CANCELAR, acoes.aoCancelar, Modifier.fillMaxWidth(), habilitado = !estado.enviando)
            }
            else -> {
                Text(TextosContaSuspensa.PRAZO_ANALISE, style = MaterialTheme.typography.bodyMedium)
                BotaoSecundario(TextosContaSuspensa.BOTAO_CONTESTAR, acoes.aoAbrirFormulario, Modifier.fillMaxWidth())
            }
        }
        estado.mensagemErro?.let { TextoDeErro(it) }
    }
}

/** Liga o [ContestarDespachoViewModel] ao [ConteudoContestarDespacho]. */
@Composable
fun TelaContestarDespacho(viewModel: ContestarDespachoViewModel, aoVoltar: () -> Unit, modifier: Modifier = Modifier) {
    val estado by viewModel.estado.collectAsState()
    ConteudoContestarDespacho(estado, aoMudarRelato = viewModel::mudarRelato, aoEnviar = { viewModel.contestar() }, aoVoltar = aoVoltar, modifier = modifier)
}

// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
/** O pedido de revisão do despacho: a explicação e o relato, ou o protocolo do pedido enviado, ou o aviso de que já existe um. */
@Composable
fun ConteudoContestarDespacho(
    estado: EstadoContestarDespacho,
    aoMudarRelato: (String) -> Unit,
    aoEnviar: () -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(FrilaEspacamento.medio),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.compacto),
    ) {
        Text(TextosContestarDespacho.TITULO, style = MaterialTheme.typography.titleLarge, modifier = Modifier.semantics { heading() })
        val protocolo = estado.protocolo
        when {
            protocolo != null -> {
                TextoAoVivo(TextosContestarDespacho.PEDIDO_ENVIADO)
                Informacao(TextosContestarDespacho.PROTOCOLO_NUMERO, protocolo.numero)
                Informacao(TextosContestarDespacho.PROTOCOLO_DATA, protocolo.enviadoEm)
                Informacao(TextosContestarDespacho.PRAZO_RESPOSTA, protocolo.prazoRespostaAte)
                Text(TextosContestarDespacho.MENSAGEM_ENVIADO)
            }
            estado.contestacaoJaAberta -> TextoAoVivo(TextosContestarDespacho.CONTESTACAO_JA_ABERTA)
            else -> {
                Text(TextosContestarDespacho.EXPLICACAO)
                CampoDoRelato(estado.relato, TextosContestarDespacho.ROTULO_RELATO, TextosContestarDespacho.DICA_RELATO, !estado.enviando, aoMudarRelato)
                if (estado.enviando) TextoAoVivo(TextosContestarDespacho.ENVIANDO)
                estado.mensagemErro?.let { TextoDeErro(it) }
                BotaoPrimario(TextosContestarDespacho.BOTAO_ENVIAR, aoEnviar, Modifier.fillMaxWidth(), habilitado = !estado.enviando)
            }
        }
        BotaoSecundario(TextosContestarDespacho.VOLTAR, aoVoltar, Modifier.fillMaxWidth(), habilitado = !estado.enviando)
    }
}

@Composable
private fun CampoDoRelato(valor: String, rotulo: String, dica: String, habilitado: Boolean, aoMudar: (String) -> Unit) {
    OutlinedTextField(
        value = valor,
        onValueChange = aoMudar,
        enabled = habilitado,
        label = { Text(rotulo) },
        supportingText = { Text(dica) },
        minLines = 3,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun TextoAoVivo(texto: String) {
    Text(texto, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
}

@Composable
private fun TextoDeErro(texto: String) {
    Text(texto, color = MaterialTheme.colorScheme.error, modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
}
