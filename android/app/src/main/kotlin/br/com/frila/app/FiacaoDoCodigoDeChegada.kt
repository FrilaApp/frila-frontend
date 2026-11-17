package br.com.frila.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import br.com.frila.feature.turnos.ItemTurno
import br.com.frila.feature.turnos.LocalCriarValidacaoDoCodigo
import br.com.frila.feature.turnos.ValidacaoDoCodigoViewModel
import br.com.frila.feature.turnos.contratante.CodigoDaCasaViewModel
import org.koin.androidx.compose.koinViewModel
import org.koin.core.parameter.parametersOf

/**
 * Liga o campo do código de chegada (L1-4b) à lista de Meus turnos, atrás da chave `checkin_por_codigo` do servidor (`configuracao_do_app`).
 * Desligada, a tela não recebe criador nenhum e fica como era. Ligada, cada turno tem o seu [ValidacaoDoCodigoViewModel] (por chave), criado com o
 * ponto da vaga, para medir a distância no toque; ao verificar a presença, [aoPresencaVerificada] relê o turno.
 */
@Composable
fun ComConfirmacaoPorCodigo(habilitada: Boolean, aoPresencaVerificada: () -> Unit, conteudo: @Composable () -> Unit) {
    val aoVerificar by rememberUpdatedState(aoPresencaVerificada)
    val criar: (@Composable (ItemTurno) -> ValidacaoDoCodigoViewModel)? =
        if (!habilitada) {
            null
        } else {
            remember {
                val criador: @Composable (ItemTurno) -> ValidacaoDoCodigoViewModel = { turno ->
                    koinViewModel(
                        key = "codigo-${turno.turnoId}",
                        parameters = { parametersOf(turno.turnoId, turno.pontoDaVaga, { aoVerificar() }) },
                    )
                }
                criador
            }
        }
    CompositionLocalProvider(LocalCriarValidacaoDoCodigo provides criar, content = conteudo)
}

/** O código de chegada da casa (L1-5) no turno, atrás da mesma chave. Desligada, devolve `null` e o cartão não aparece; [aoConfirmar] relê o turno. */
@Composable
fun codigoDaCasaDoTurno(habilitado: Boolean, turnoId: String, aoConfirmar: () -> Unit): CodigoDaCasaViewModel? {
    if (!habilitado) return null
    val aoConfirmarAtual by rememberUpdatedState(aoConfirmar)
    return koinViewModel(key = "codigo-da-casa-$turnoId", parameters = { parametersOf(turnoId, { aoConfirmarAtual() }) })
}
