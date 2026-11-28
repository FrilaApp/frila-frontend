package br.com.frila.feature.suporte

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.material3.Text
import br.com.frila.core.designsystem.componentes.AcaoDiscreta
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * "Denunciar" e "Bloquear" de outra parte, como as ações discretas do iOS (`AcoesDeSeguranca`): texto sublinhado em tinta suave,
 * uma por linha, sem laranja nem vermelho. A consequência do bloqueio vem escrita na confirmação. Serve a toda tela que mostra
 * um perfil público (chamada recebida do profissional, perfil público visto pela casa): quem monta a rota decide para onde
 * "Denunciar" leva ([aoDenunciar]) e como o alvo é bloqueado ([BloqueioDeAlvoViewModel]).
 *
 * [nome] vai na descrição de acessibilidade; [tagBase] prefixa as tags (`<base>-denunciar`, `<base>-bloquear`,
 * `<base>-bloqueado`, `<base>-erro-bloqueio`) para as telas que mostram mais de um conjunto; [rotuloBloqueado] é o texto de depois
 * do bloqueio ("Você bloqueou este estabelecimento" na chamada).
 */
@Composable
fun AcoesDeSeguranca(
    nome: String,
    viewModel: BloqueioDeAlvoViewModel,
    aoDenunciar: () -> Unit,
    modifier: Modifier = Modifier,
    rotuloBloqueado: String = TextosSuporte.BLOQUEADO,
    tagBase: String = "seguranca",
) {
    val estado by viewModel.estado.collectAsState()
    AcoesDeSeguranca(
        nome = nome,
        estado = estado,
        aoDenunciar = aoDenunciar,
        aoAbrirBloqueio = viewModel::abrirDialogo,
        aoConfirmarBloqueio = { viewModel.confirmar() },
        aoCancelarBloqueio = viewModel::cancelar,
        modifier = modifier,
        rotuloBloqueado = rotuloBloqueado,
        tagBase = tagBase,
    )
}

/** A versão sem estado: o que a tela desenha a partir de [estado], e os eventos que ela devolve. */
@Composable
fun AcoesDeSeguranca(
    nome: String,
    estado: EstadoBloqueioDeAlvo,
    aoDenunciar: () -> Unit,
    aoAbrirBloqueio: () -> Unit,
    aoConfirmarBloqueio: () -> Unit,
    aoCancelarBloqueio: () -> Unit,
    modifier: Modifier = Modifier,
    rotuloBloqueado: String = TextosSuporte.BLOQUEADO,
    tagBase: String = "seguranca",
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        estado.erro?.let { mensagem ->
            MensagemJuntoAoBotao(
                texto = mensagem,
                modifier = Modifier
                    .testTag("$tagBase-erro-bloqueio")
                    .semantics {
                        error(mensagem)
                        liveRegion = LiveRegionMode.Assertive
                    },
            )
        }
        AcaoDiscreta(
            texto = TextosSuporte.TITULO,
            aoClicar = aoDenunciar,
            modifier = Modifier
                .testTag("$tagBase-denunciar")
                .semantics { contentDescription = TextosSuporte.DENUNCIAR_NOME.format(nome) },
        )
        if (estado.bloqueado) {
            Text(
                text = rotuloBloqueado,
                style = FrilaTipo.corpo,
                color = FrilaTema.cores.tinta,
                modifier = Modifier
                    .testTag("$tagBase-bloqueado")
                    .semantics { liveRegion = LiveRegionMode.Polite },
            )
        } else {
            AcaoDiscreta(
                texto = if (estado.bloqueando) TextosSuporte.BLOQUEANDO else TextosSuporte.BLOQUEAR,
                aoClicar = aoAbrirBloqueio,
                habilitado = !estado.bloqueando,
                modifier = Modifier
                    .testTag("$tagBase-bloquear")
                    .semantics { contentDescription = TextosSuporte.BLOQUEAR_NOME.format(nome) },
            )
        }
    }

    if (estado.dialogoAberto) {
        DialogoDeConfirmacao(
            titulo = TextosSuporte.BLOQUEIO_TITULO,
            mensagem = TextosSuporte.BLOQUEIO_EFEITO,
            textoConfirmar = TextosSuporte.BLOQUEIO_CONFIRMAR,
            aoConfirmar = aoConfirmarBloqueio,
            textoCancelar = TextosSuporte.CANCELAR,
            aoCancelar = aoCancelarBloqueio,
        )
    }
}
