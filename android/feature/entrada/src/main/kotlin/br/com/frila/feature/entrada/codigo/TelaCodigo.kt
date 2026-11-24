package br.com.frila.feature.entrada.codigo

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CaixasDeCodigo
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.RotuloDeGrupo
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import kotlinx.coroutines.delay

/**
 * T6b (os seis números enviados por e-mail), no desenho do Fabrício e sem ilustração: título, o e-mail de
 * destino e o link "Trocar e-mail", o código nas caixas e, ancorado embaixo, a mensagem da vez (erro, ou o
 * aviso do reenvio) junto do único botão laranja. "Reenviar código" é um link; nos primeiros 60 s ele vira a
 * contagem, sem toque. [aoTrocarEmail] volta para a entrada: sem ele, o link não aparece (fica o voltar do sistema).
 */
@Composable
fun TelaCodigo(
    viewModel: CodigoViewModel,
    aoAutenticar: () -> Unit,
    modifier: Modifier = Modifier,
    aoTrocarEmail: (() -> Unit)? = null,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val cores = FrilaTema.cores

    LaunchedEffect(estado.autenticado) {
        if (estado.autenticado) {
            aoAutenticar()
        }
    }

    // Contagem de 60 s para reenviar, como no iOS. O relógio é o do ViewModel; a tela só relê a cada segundo.
    var segundosParaReenviar by remember { mutableLongStateOf(viewModel.segundosParaReenviar()) }
    LaunchedEffect(estado.reenviosFeitos) {
        while (true) {
            segundosParaReenviar = viewModel.segundosParaReenviar()
            if (segundosParaReenviar <= 0) break
            delay(1_000)
        }
    }

    val focoDoCodigo = remember { FocusRequester() }

    // Uma mensagem só junto do botão: o erro vence o aviso do reenvio.
    val mensagem = estado.erro ?: (estado.mensagemReenvio ?: "Novo código enviado para seu e-mail.").takeIf { estado.reenviado }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        bottomBar = {
            RodapeAncorado {
                mensagem?.let { texto ->
                    MensagemJuntoAoBotao(
                        texto = texto,
                        modifier = if (estado.erro != null) {
                            Modifier.semantics { liveRegion = LiveRegionMode.Assertive }
                        } else {
                            Modifier
                        },
                    )
                }
                BotaoPrimario(
                    texto = if (estado.carregando) "Confirmando…" else "Confirmar código",
                    aoClicar = viewModel::confirmarCodigo,
                    habilitado = !estado.carregando,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
    ) { preenchimento ->
        // O campo já abre com foco e teclado, como no iOS: quem chega aqui só tem de digitar o código. O pedido
        // fica aqui dentro porque o conteúdo do Scaffold só entra em composição na medição, depois da tela.
        LaunchedEffect(Unit) { focoDoCodigo.requestFocus() }
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
                TituloDaTela("Confirme seu código")
                Text(
                    text = "Enviamos um código de 6 dígitos para ${estado.email}.",
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
                aoTrocarEmail?.let { LinkFrila(texto = "Trocar e-mail", aoClicar = it) }
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                RotuloDeGrupo("Código de 6 dígitos")
                CaixasDeCodigo(
                    codigo = estado.codigo,
                    aoMudar = { viewModel.aoMudarCodigo(it) },
                    comErro = estado.erro != null,
                    // Como na main: o campo continua editável enquanto confirma (o ViewModel já impede o envio em dobro).
                    rotulo = "Código de 6 dígitos",
                    // Dica de preenchimento automático (Compose 1.8): o teclado e o serviço de preenchimento do aparelho
                    // podem sugerir o código recebido, sem a pessoa copiar.
                    modifier = Modifier
                        .focusRequester(focoDoCodigo)
                        .semantics { contentType = ContentType.SmsOtpCode },
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                Text(
                    text = "Não chegou? Veja a caixa de spam.",
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
                if (segundosParaReenviar > 0) {
                    // Contagem, não link: sem toque até acabar os 60 s.
                    Box(
                        modifier = Modifier.heightIn(min = FrilaMetricas.alvoMinimo),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        Text(
                            text = "Reenviar código em %d:%02d".format(segundosParaReenviar / 60, segundosParaReenviar % 60),
                            style = FrilaTipo.corpo.copy(fontFeatureSettings = "tnum"),
                            color = cores.tintaSuave,
                            modifier = Modifier.semantics { disabled() },
                        )
                    }
                } else {
                    LinkFrila(
                        texto = "Reenviar código",
                        aoClicar = { viewModel.reenviarCodigo() },
                        habilitado = !estado.carregando,
                    )
                }
            }
        }
    }
}
