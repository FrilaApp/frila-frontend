package br.com.frila.feature.entrada.criar

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

private const val ERRO_EMAIL_INVALIDO = "Informe um e-mail válido."

/**
 * Tela de criação de conta: envia um código único de confirmação para o e-mail (`create_user: true`)
 * antes de definir a senha. Nos acessos seguintes, o usuário entra apenas com e-mail e senha.
 */
@Composable
fun TelaCriarConta(
    viewModel: CriarContaViewModel,
    aoEnviarCodigo: (String) -> Unit,
    aoVoltarParaLogin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val cores = FrilaTema.cores
    val erroEmail = estado.erro?.takeIf { it == ERRO_EMAIL_INVALIDO }
    val erroDaAcao = estado.erro?.takeUnless { it == ERRO_EMAIL_INVALIDO }

    LaunchedEffect(estado.otpSolicitado) {
        if (estado.otpSolicitado) {
            aoEnviarCodigo(estado.email)
            viewModel.aoNavegarParaCodigo()
        }
    }

    DisposableEffect(Unit) {
        onDispose { viewModel.cancelarTentativaAtual() }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        bottomBar = {
            RodapeAncorado {
                erroDaAcao?.let { mensagem ->
                    MensagemJuntoAoBotao(
                        texto = mensagem,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
                BotaoPrimario(
                    texto = if (estado.carregando) "Enviando…" else "Receber código",
                    aoClicar = viewModel::solicitarCodigoDeCriacao,
                    habilitado = !estado.carregando,
                    modifier = Modifier.fillMaxWidth(),
                )
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
            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                TituloDaTela("Criar conta")
                Text(
                    text = "Confirmamos seu e-mail com um código de 6 dígitos uma única vez. Depois você cria sua senha para os próximos acessos.",
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
            }

            CampoDeTexto(
                valor = estado.email,
                aoMudar = viewModel::aoMudarEmail,
                rotulo = "E-mail",
                erro = erroEmail,
                habilitado = !estado.carregando,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = { viewModel.solicitarCodigoDeCriacao() }),
                modifier = Modifier.semantics {
                    contentType = ContentType.EmailAddress
                    if (erroEmail != null) liveRegion = LiveRegionMode.Assertive
                },
            )

            LinkFrila(
                texto = "Já tenho conta com senha",
                aoClicar = {
                    viewModel.cancelarTentativaAtual()
                    aoVoltarParaLogin()
                },
                habilitado = !estado.carregando,
            )
        }
    }
}
