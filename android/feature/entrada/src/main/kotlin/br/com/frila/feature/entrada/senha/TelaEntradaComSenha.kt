package br.com.frila.feature.entrada.senha

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.abertura.RotuloDaMarca
import br.com.frila.core.designsystem.abertura.destinoDoRotuloDaAbertura
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.LinkFrila
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.feature.entrada.entrada.IlustracaoDeBoasVindas
import br.com.frila.feature.entrada.fraseComLinksLegais

private val ALTURA_DA_MARCA = 32.dp
private const val ERRO_EMAIL_INVALIDO = "Informe um e-mail válido."
private const val ERRO_SENHA_VAZIA = "Digite sua senha para entrar."

/**
 * Tela principal de entrada por e-mail e senha (acesso rotineiro sem novo OTP).
 * - Contas novas seguem por "Criar conta" (OTP único + definição de senha).
 * - Contas legadas OTP-only ou esquecimento de senha seguem por "Esqueci ou ainda não tenho senha"
 *   (fluxo recovery-only `create_user: false`).
 * - Contas de demonstração da Play Store seguem exclusivamente pelo botão de modo demonstração.
 */
@Composable
fun TelaEntradaComSenha(
    viewModel: EntradaComSenhaViewModel,
    aoAutenticar: () -> Unit,
    aoCriarConta: (String) -> Unit,
    aoRecuperarSenha: (String) -> Unit,
    aoEntrarDemonstracao: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val cores = FrilaTema.cores
    val erroEmail = estado.erro?.takeIf { it == ERRO_EMAIL_INVALIDO }
    val erroSenha = estado.erro?.takeIf { it == ERRO_SENHA_VAZIA }
    val erroDaAcao = estado.erro?.takeUnless { it == ERRO_EMAIL_INVALIDO || it == ERRO_SENHA_VAZIA }

    LaunchedEffect(estado.autenticado) {
        if (estado.autenticado) {
            aoAutenticar()
            viewModel.aoConsumirAutenticacao()
        }
    }

    DisposableEffect(Unit) {
        onDispose { viewModel.cancelarTentativaAtual() }
    }

    // Conta de demonstração digitada (profissional ou contratante) segue para o modo demonstração, sem senha.
    val entrarDemonstracao = {
        viewModel.cancelarTentativaAtual()
        aoEntrarDemonstracao(viewModel.emailDaDemonstracao())
    }
    val entrar: () -> Unit = {
        if (viewModel.digitouContaDeDemonstracao()) {
            entrarDemonstracao()
        } else {
            viewModel.entrar()
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = cores.fundo,
        bottomBar = {
            RodapeAncorado {
                Text(
                    text = fraseComLinksLegais(
                        antes = "Ao continuar, você aceita os ",
                        termos = "Termos de Uso",
                        conector = " e a ",
                        privacidade = "Política de Privacidade",
                        depois = ".",
                    ),
                    style = FrilaTipo.legenda,
                    color = cores.tintaSuave,
                    modifier = Modifier.fillMaxWidth(),
                )
                erroDaAcao?.let { mensagem ->
                    MensagemJuntoAoBotao(
                        texto = mensagem,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
                BotaoPrimario(
                    texto = if (estado.carregando) "Entrando…" else "Entrar",
                    aoClicar = entrar,
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
            RotuloDaMarca(
                modifier = Modifier
                    .height(ALTURA_DA_MARCA)
                    .destinoDoRotuloDaAbertura(),
            )

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto)) {
                IlustracaoDeBoasVindas()
                Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                    TituloDaTela("Bem-vindo ao Frila")
                    Text(
                        text = "Entre com seu e-mail e senha.",
                        style = FrilaTipo.apoio,
                        color = cores.tintaSuave,
                    )
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                CampoDeTexto(
                    valor = estado.email,
                    aoMudar = viewModel::aoMudarEmail,
                    rotulo = "E-mail",
                    erro = erroEmail,
                    habilitado = !estado.carregando,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Next),
                    modifier = Modifier.semantics {
                        contentType = ContentType.Username
                        if (erroEmail != null) liveRegion = LiveRegionMode.Assertive
                    },
                )

                CampoDeTexto(
                    valor = estado.senha,
                    aoMudar = viewModel::aoMudarSenha,
                    rotulo = "Senha",
                    erro = erroSenha,
                    habilitado = !estado.carregando,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Done,
                        autoCorrectEnabled = false,
                    ),
                    keyboardActions = KeyboardActions(onDone = { entrar() }),
                    modifier = Modifier.semantics {
                        contentType = ContentType.Password
                        if (erroSenha != null) liveRegion = LiveRegionMode.Assertive
                    },
                )

                LinkFrila(
                    texto = "Esqueci ou ainda não tenho senha",
                    aoClicar = {
                        viewModel.cancelarTentativaAtual()
                        aoRecuperarSenha(estado.email.trim().lowercase())
                    },
                    habilitado = !estado.carregando,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                BotaoSecundario(
                    texto = "Criar conta",
                    aoClicar = {
                        viewModel.cancelarTentativaAtual()
                        aoCriarConta(estado.email.trim().lowercase())
                    },
                    habilitado = !estado.carregando,
                    modifier = Modifier.fillMaxWidth(),
                )

                LinkFrila(
                    texto = "Entrar em modo demonstração",
                    aoClicar = entrarDemonstracao,
                    habilitado = !estado.carregando,
                )
            }

            Text(
                text = "Classificação indicativa: 18 anos",
                style = FrilaTipo.legenda,
                color = cores.tintaSuave,
            )
        }
    }
}
