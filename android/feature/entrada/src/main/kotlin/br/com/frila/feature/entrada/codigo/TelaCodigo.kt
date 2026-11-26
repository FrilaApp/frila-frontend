package br.com.frila.feature.entrada.codigo

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.rede.DemonstracaoContas
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
 * Hint oficial do AndroidX Autofill (`HintConstants.AUTOFILL_HINT_EMAIL_OTP = "emailOTPCode"`,
 * autofill 1.2.0+) para código de uso único recebido por e-mail. Usa o construtor [ContentType]
 * do Compose UI sem adicionar dependência extra.
 */
internal val CONTEUDO_CODIGO_OTP_EMAIL: ContentType = ContentType("emailOTPCode")

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
                    text = textoDeApoioDoCodigo(viewModel.modo, estado.email),
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
                    // Dica de preenchimento automático (Compose 1.8 / AndroidX HintConstants):
                    // expõe `emailOTPCode` apenas quando o código vem por e-mail (nunca no modo demo).
                    modifier = Modifier
                        .focusRequester(focoDoCodigo)
                        .then(
                            if (viewModel.usaCodigoPorEmail) {
                                Modifier.semantics { contentType = CONTEUDO_CODIGO_OTP_EMAIL }
                            } else {
                                Modifier
                            },
                        ),
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

            if (viewModel.modo != ModoCodigo.DEMO && !DemonstracaoContas.ehContaDeDemonstracao(estado.email)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = FrilaMetricas.alvoMinimo)
                        .testTag("codigo-lembrar-dispositivo")
                        .toggleable(
                            value = estado.lembrarDispositivo,
                            enabled = !estado.carregando,
                            role = Role.Checkbox,
                            onValueChange = viewModel::aoAlternarLembrarDispositivo,
                        ),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
                ) {
                    Checkbox(
                        checked = estado.lembrarDispositivo,
                        onCheckedChange = null,
                        enabled = !estado.carregando,
                    )
                    Text(
                        text = "Lembrar este dispositivo por 30 dias",
                        style = FrilaTipo.corpo,
                        color = cores.tinta,
                    )
                }
            }
        }
    }
}

/**
 * Na recuperação a tela não confirma que a conta existe: o mesmo texto aparece com e sem conta
 * (anti-enumeração). Nos outros modos o código sempre é enviado, então o texto afirma o envio.
 */
internal fun textoDeApoioDoCodigo(modo: ModoCodigo, email: String): String = when (modo) {
    ModoCodigo.RECUPERACAO ->
        "Se houver uma conta com este e-mail, enviamos um código de 6 dígitos para $email."
    ModoCodigo.LOGIN_DISPOSITIVO ->
        "Enviamos um código de 6 dígitos para $email para confirmar este dispositivo."
    else ->
        "Enviamos um código de 6 dígitos para $email."
}
