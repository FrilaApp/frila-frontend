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
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.AvisoFrila
import br.com.frila.core.designsystem.componentes.CartaoFrila
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.componentes.TomAviso
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Bloqueio de conta suspensa (RN13, `403 sem_permissao` com `details: conta_suspensa`; paridade
 * com `TelaContaSuspensa.swift`). Não há navegação para fora da tela além de falar com o suporte
 * ou sair da conta: a conta suspensa não usa o app.
 *
 * Tela de leitura com uma ação (a contestação, no [contestacao]): título, o aviso, o motivo e a data em
 * um cartão e, no fim, o suporte e o "Sair da conta" como ações discretas, uma por linha. Sem desenho do
 * Fabrício (extrapolada do mesmo sistema).
 *
 * [motivo] e [desde] vêm de quem chama, já formatados, e somem quando nulos. [emailSuporte] também vem
 * de quem chama (`EnderecosOficiais.padrao`). [contestacao] é a seção de contestar a suspensão, entre as
 * informações e o suporte; sem ela (padrão) a tela só oferece o e-mail do suporte. Quem lê a situação da
 * conta e contesta é a `TelaContaSuspensaComContestacao`, com o `ContaSuspensaViewModel`.
 */
@Composable
fun TelaContaSuspensa(
    emailSuporte: String,
    aoContatarSuporte: (String) -> Unit,
    aoSair: () -> Unit,
    modifier: Modifier = Modifier,
    motivo: String? = null,
    desde: String? = null,
    contestacao: (@Composable () -> Unit)? = null,
) {
    val cores = FrilaTema.cores
    Scaffold(modifier = modifier.fillMaxSize(), containerColor = cores.fundo) { preenchimento ->
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
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                TituloDaTela(
                    texto = TextosContaSuspensa.TITULO,
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
                )
                Text(
                    text = TextosContaSuspensa.SUBTITULO,
                    style = FrilaTipo.corpo,
                    color = cores.tintaSuave,
                )
            }
            AvisoFrila(tom = TomAviso.ALERTA, mensagem = TextosContaSuspensa.AVISO_PRINCIPAL)

            if (motivo != null || desde != null) {
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    RotuloDeGrupo(TextosContaSuspensa.SECAO_MOTIVO)
                    CartaoFrila(modifier = Modifier.fillMaxWidth()) {
                        Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                            motivo?.let { Informacao(TextosContaSuspensa.MOTIVO_TITULO, it) }
                            desde?.let { Informacao(TextosContaSuspensa.DESDE_TITULO, it) }
                        }
                    }
                }
            }

            contestacao?.invoke()

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo(TextosContaSuspensa.SECAO_SUPORTE)
                Text(
                    text = TextosContaSuspensa.PRAZO_SUPORTE,
                    style = FrilaTipo.corpo,
                    color = cores.tinta,
                )
                Text(
                    text = emailSuporte,
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
                AcaoDiscreta(
                    texto = TextosContaSuspensa.BOTAO_SUPORTE,
                    aoClicar = { aoContatarSuporte(emailSuporte) },
                )
                AcaoDiscreta(texto = TextosContaSuspensa.BOTAO_SAIR, aoClicar = aoSair)
            }
        }
    }
}

/** Um dado de leitura: o nome em tinta suave e, embaixo, o valor em tinta. */
@Composable
internal fun Informacao(titulo: String, valor: String) {
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
        Text(text = titulo, style = FrilaTipo.apoio, color = FrilaTema.cores.tintaSuave)
        Text(text = valor, style = FrilaTipo.corpo, color = FrilaTema.cores.tinta)
    }
}
