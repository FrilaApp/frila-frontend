package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CaixasDeCodigo
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import java.time.Instant

/**
 * Como a tela cria o [ValidacaoDoCodigoViewModel] de um turno. `null` (padrão): sem confirmação por código na tela,
 * que é o caso da chave `checkin_por_codigo` desligada e de enquanto a fiação (L1-7) não existe.
 */
val LocalCriarValidacaoDoCodigo = staticCompositionLocalOf<(@Composable (turno: ItemTurno) -> ValidacaoDoCodigoViewModel)?> { null }

/**
 * O check-out do turno (L1-4). Aparece com o check-in feito e o check-out ainda não, até 60 min depois do fim; feito,
 * só diz que foi registrado. O botão é o primário só quando [destaque] (nenhum outro laranja no cartão); enquanto o
 * check-out é registrado, fica no lugar, desligado, sem indicador girando. O erro vem logo acima do botão.
 */
@Composable
internal fun SecaoDeCheckout(
    turno: ItemTurno,
    viewModel: CheckinViewModel,
    agora: Instant,
    destaque: Boolean = true,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val feito = turno.checkoutEm != null || estado.checkout == StatusCheckout.FEITO
    val checkinFeito = estado.comprovante != null || turno.comprovante != null
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        when {
            feito -> Text(TextosCheckoutECodigo.CHECKOUT_FEITO, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
            estado.checkout == StatusCheckout.REGISTRANDO -> BotaoDeAcaoDoTurno(
                texto = TextosCheckoutECodigo.CHECKOUT_REGISTRANDO,
                aoClicar = {},
                destaque = destaque,
                habilitado = false,
            )
            estado.checkout == StatusCheckout.NA_FILA -> Text(
                estado.checkoutNaFila?.let(TextosDaFilaDePresenca::checkoutNaFila) ?: TextosCheckoutECodigo.CHECKOUT_REGISTRANDO,
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tinta,
            )
            RegraDePresenca.podeFazerCheckout(checkinFeito, checkoutFeito = false, fim = turno.fim, agora = agora) -> {
                val comErro = estado.checkout == StatusCheckout.ERRO
                if (comErro) {
                    MensagemDeAcao(texto = estado.mensagemErroCheckout ?: TextosCheckoutECodigo.CHECKOUT_ERRO_PADRAO)
                }
                estado.avisoCheckout?.let { MensagemDeAcao(texto = it) }
                BotaoDeAcaoDoTurno(
                    texto = if (comErro) TextosCheckoutECodigo.BOTAO_CHECKOUT_TENTAR_DE_NOVO else TextosCheckoutECodigo.BOTAO_CHECKOUT,
                    aoClicar = { viewModel.fazerCheckout() },
                    destaque = destaque,
                )
            }
        }
    }
}

/**
 * Digitar o código da casa, com o check-in manual pendente (L1-4). Só aparece se a tela recebeu
 * [LocalCriarValidacaoDoCodigo]. O resultado (código errado, longe do local, bloqueio) vem escrito logo acima do botão,
 * e o botão é o primário do cartão: confirmar o código é o que fecha a presença.
 */
@Composable
internal fun CampoDoCodigo(turno: ItemTurno) {
    val criar = LocalCriarValidacaoDoCodigo.current ?: return
    val viewModel = criar(turno)
    val resultado by viewModel.estado.collectAsStateWithLifecycle()
    var texto by rememberSaveable(turno.turnoId) { mutableStateOf("") }
    val enviando = resultado == ResultadoDaValidacao.Enviando
    val comErro = resultado == ResultadoDaValidacao.Invalido || resultado == ResultadoDaValidacao.FormatoInvalido
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        Text(TextosCheckoutECodigo.CODIGO_EXPLICACAO, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
        CaixasDeCodigo(
            codigo = texto,
            aoMudar = { novo -> texto = novo.filter { it in '0'..'9' }.take(6) },
            modifier = Modifier.testTag("campo-do-codigo"),
            comErro = comErro,
            habilitado = !enviando,
            rotulo = TextosCheckoutECodigo.CODIGO_ROTULO,
        )
        textoDoResultado(resultado)?.let { mensagem ->
            MensagemJuntoAoBotao(texto = mensagem)
        }
        BotaoPrimario(
            texto = if (enviando) TextosCheckoutECodigo.CODIGO_ENVIANDO else TextosCheckoutECodigo.BOTAO_CONFIRMAR_CODIGO,
            aoClicar = { viewModel.validar(texto) },
            modifier = Modifier.fillMaxWidth(),
            habilitado = !enviando && RegraDePresenca.formatoDoCodigoValido(texto),
        )
    }
}

internal fun textoDoResultado(resultado: ResultadoDaValidacao): String? = when (resultado) {
    ResultadoDaValidacao.Aguardando, ResultadoDaValidacao.Enviando -> null
    ResultadoDaValidacao.ForaDoRaio -> TextosCheckoutECodigo.CODIGO_FORA_DO_RAIO
    is ResultadoDaValidacao.ChegueMaisPerto -> TextosCheckoutECodigo.CODIGO_CHEGUE_MAIS_PERTO.format(resultado.distanciaMetros)
    ResultadoDaValidacao.SemLocalizacao -> TextosCheckoutECodigo.CODIGO_SEM_LOCALIZACAO
    ResultadoDaValidacao.FormatoInvalido -> TextosCheckoutECodigo.CODIGO_FORMATO_INVALIDO
    is ResultadoDaValidacao.Verificado -> TextosCheckoutECodigo.CODIGO_VERIFICADO
    ResultadoDaValidacao.JaVerificado -> TextosCheckoutECodigo.CODIGO_JA_VERIFICADO
    ResultadoDaValidacao.Invalido -> TextosCheckoutECodigo.CODIGO_INVALIDO
    is ResultadoDaValidacao.Bloqueado -> when (resultado.bloqueio) {
        BloqueioDoCodigo.TEMPORARIO -> TextosCheckoutECodigo.CODIGO_BLOQUEADO_TEMPORARIO
        BloqueioDoCodigo.ENCERRADO -> TextosCheckoutECodigo.CODIGO_BLOQUEADO_ENCERRADO
    }
    ResultadoDaValidacao.RecursoDesligado -> TextosCheckoutECodigo.CODIGO_RECURSO_DESLIGADO
    ResultadoDaValidacao.RespostaPerdida -> TextosCheckoutECodigo.CODIGO_RESPOSTA_PERDIDA
    ResultadoDaValidacao.Falhou -> TextosCheckoutECodigo.CODIGO_FALHOU
}
