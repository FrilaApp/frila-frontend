package br.com.frila.feature.turnos

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import java.time.Instant

/**
 * Como a tela cria o [ValidacaoDoCodigoViewModel] de um turno. `null` (padrão): sem confirmação por código na tela,
 * que é o caso da chave `checkin_por_codigo` desligada e de enquanto a fiação (L1-7) não existe.
 */
val LocalCriarValidacaoDoCodigo = staticCompositionLocalOf<(@Composable (turno: ItemTurno) -> ValidacaoDoCodigoViewModel)?> { null }

/**
 * O check-out do turno (L1-4). Aparece com o check-in feito e o check-out ainda não, até 60 min depois do fim; feito,
 * só diz que foi registrado. TELA PROVISÓRIA: substituir pelo high-fi do Fabrício.
 */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
internal fun SecaoDeCheckout(
    turno: ItemTurno,
    criarCheckinViewModel: @Composable (turno: ItemTurno) -> CheckinViewModel,
    agora: Instant,
) {
    val viewModel = criarCheckinViewModel(turno)
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val feito = turno.checkoutEm != null || estado.checkout == StatusCheckout.FEITO
    val checkinFeito = estado.comprovante != null || turno.comprovante != null
    Column(
        modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
    ) {
        when {
            feito -> Text(TextosCheckoutECodigo.CHECKOUT_FEITO, style = MaterialTheme.typography.bodySmall)
            estado.checkout == StatusCheckout.REGISTRANDO ->
                Text(TextosCheckoutECodigo.CHECKOUT_REGISTRANDO, style = MaterialTheme.typography.bodySmall)
            RegraDePresenca.podeFazerCheckout(checkinFeito, checkoutFeito = false, fim = turno.fim, agora = agora) -> {
                val comErro = estado.checkout == StatusCheckout.ERRO
                if (comErro) {
                    Text(
                        text = estado.mensagemErroCheckout ?: TextosCheckoutECodigo.CHECKOUT_ERRO_PADRAO,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
                BotaoSecundario(
                    texto = if (comErro) TextosCheckoutECodigo.BOTAO_CHECKOUT_TENTAR_DE_NOVO else TextosCheckoutECodigo.BOTAO_CHECKOUT,
                    aoClicar = { viewModel.fazerCheckout() },
                )
            }
        }
    }
}

/**
 * Campo para digitar o código da casa, com o check-in manual pendente (L1-4). Só aparece se a tela recebeu
 * [LocalCriarValidacaoDoCodigo]. TELA PROVISÓRIA: substituir pelo high-fi do Fabrício.
 */
// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
@Composable
internal fun CampoDoCodigo(turno: ItemTurno) {
    val criar = LocalCriarValidacaoDoCodigo.current ?: return
    val viewModel = criar(turno)
    val resultado by viewModel.estado.collectAsStateWithLifecycle()
    var texto by rememberSaveable(turno.turnoId) { mutableStateOf("") }
    val enviando = resultado == ResultadoDaValidacao.Enviando
    Column(
        modifier = Modifier.padding(top = FrilaEspacamento.pequeno),
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.minimo),
    ) {
        Text(TextosCheckoutECodigo.CODIGO_EXPLICACAO, style = MaterialTheme.typography.bodySmall)
        OutlinedTextField(
            value = texto,
            onValueChange = { novo -> texto = novo.filter { it in '0'..'9' }.take(6) },
            label = { Text(TextosCheckoutECodigo.CODIGO_ROTULO) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth().testTag("campo-do-codigo"),
        )
        textoDoResultado(resultado)?.let { mensagem ->
            Text(
                text = mensagem,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
            )
        }
        BotaoSecundario(
            texto = if (enviando) TextosCheckoutECodigo.CODIGO_ENVIANDO else TextosCheckoutECodigo.BOTAO_CONFIRMAR_CODIGO,
            aoClicar = { viewModel.validar(texto) },
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
