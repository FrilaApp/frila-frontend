package br.com.frila.feature.entrada.entrada

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.BotaoSecundario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.feature.entrada.fraseComLinksLegais

/** O que o [EntradaViewModel] escreve quando o e-mail não tem o formato certo: erro do campo, não da ação. */
private const val ERRO_EMAIL_INVALIDO = "Informe um e-mail válido."

/**
 * T6 (entrada por e-mail, sem senha), no desenho do Fabrício e sem a abertura animada, sem ilustração e
 * sem entrar com Apple ou Google: título e apoio, o campo com o rótulo acima e, ancorado embaixo, o texto
 * do que o toque faz (os Termos e a Política) e o único botão laranja. O erro do formato do e-mail fica no
 * campo; o da ação (rede, limite) fica junto ao botão. Quem muda de tela é o `aoReceberCodigo`.
 */
@Composable
fun TelaEntrada(
    viewModel: EntradaViewModel,
    aoReceberCodigo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val erroDoCampo = estado.erro?.takeIf { it == ERRO_EMAIL_INVALIDO }
    val erroDaAcao = estado.erro?.takeUnless { it == ERRO_EMAIL_INVALIDO }
    val cores = FrilaTema.cores

    LaunchedEffect(estado.otpSolicitado) {
        if (estado.otpSolicitado) {
            aoReceberCodigo()
            viewModel.aoNavegarParaCodigo()
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
                    texto = if (estado.carregando) "Enviando…" else "Receber código",
                    aoClicar = viewModel::solicitarCodigo,
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
                TituloDaTela("Bem-vindo ao Frila")
                Text(
                    text = "Entre com seu e-mail para receber o código de acesso.",
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
            }

            CampoDeTexto(
                valor = estado.email,
                aoMudar = viewModel::aoMudarEmail,
                rotulo = "E-mail",
                erro = erroDoCampo,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email, imeAction = ImeAction.Done),
                // O erro aparece junto do campo: o leitor de tela o anuncia quando surge, como antes.
                modifier = Modifier.semantics {
                    if (erroDoCampo != null) liveRegion = LiveRegionMode.Assertive
                },
            )

            BotaoSecundario(
                texto = "Entrar em modo demonstração",
                aoClicar = {
                    viewModel.aoMudarEmail(DemonstracaoContas.EMAIL_PROFISSIONAL)
                    viewModel.solicitarCodigo()
                },
                modifier = Modifier.fillMaxWidth(),
            )

            Text(
                text = "Classificação indicativa: 18 anos",
                style = FrilaTipo.legenda,
                color = cores.tintaSuave,
            )
        }
    }
}
