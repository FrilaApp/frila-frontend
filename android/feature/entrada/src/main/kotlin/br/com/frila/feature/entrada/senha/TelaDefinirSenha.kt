package br.com.frila.feature.entrada.senha

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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.autofill.ContentType
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.delay
import br.com.frila.core.designsystem.componentes.BotaoPrimario
import br.com.frila.core.designsystem.componentes.CampoDeTexto
import br.com.frila.core.designsystem.componentes.MensagemJuntoAoBotao
import br.com.frila.core.designsystem.componentes.RodapeAncorado
import br.com.frila.core.designsystem.componentes.TituloDaTela
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Tela de criação ou atualização de senha na sessão autenticada atual (`PUT /auth/v1/user`),
 * preservando o mesmo `auth.uid`. Usada após OTP de criação, após OTP recovery-only e no Perfil.
 */
@Composable
fun TelaDefinirSenha(
    viewModel: DefinirSenhaViewModel,
    aoConcluir: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val estado by viewModel.estado.collectAsStateWithLifecycle()
    val cores = FrilaTema.cores

    LaunchedEffect(estado.concluido) {
        if (estado.concluido) {
            aoConcluir()
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
                estado.erro?.let { mensagem ->
                    MensagemJuntoAoBotao(
                        texto = mensagem,
                        modifier = Modifier.semantics { liveRegion = LiveRegionMode.Assertive },
                    )
                }
                BotaoPrimario(
                    texto = if (estado.carregando) "Salvando…" else "Salvar senha",
                    aoClicar = viewModel::salvar,
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
                TituloDaTela("Definir senha")
                Text(
                    text = "Crie uma senha para esta conta. Nos próximos acessos você entrará usando seu e-mail e esta senha.",
                    style = FrilaTipo.apoio,
                    color = cores.tintaSuave,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.bloco)) {
                val transformacaoSenha = rememberVisualTransformationDeSenha(estado.senha)
                val transformacaoConfirmacao = rememberVisualTransformationDeSenha(estado.confirmacao)

                CampoDeTexto(
                    valor = estado.senha,
                    aoMudar = viewModel::aoMudarSenha,
                    rotulo = "Nova senha",
                    dica = "Mínimo de 8 caracteres",
                    habilitado = !estado.carregando,
                    visualTransformation = transformacaoSenha,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Next,
                        autoCorrectEnabled = false,
                    ),
                    modifier = Modifier.semantics { contentType = ContentType.NewPassword },
                )

                CampoDeTexto(
                    valor = estado.confirmacao,
                    aoMudar = viewModel::aoMudarConfirmacao,
                    rotulo = "Confirmar senha",
                    dica = "Repita a nova senha",
                    habilitado = !estado.carregando,
                    visualTransformation = transformacaoConfirmacao,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Done,
                        autoCorrectEnabled = false,
                    ),
                    keyboardActions = KeyboardActions(onDone = { viewModel.salvar() }),
                    modifier = Modifier.semantics { contentType = ContentType.NewPassword },
                )
            }
        }
    }
}

internal const val ATRASO_MASCARAMENTO_CARACTERE_SENHA_MS = 1_000L

internal fun indiceCaractereRecemDigitado(anterior: String, atual: String): Int? {
    if (atual.length != anterior.length + 1) return null
    val indice = anterior.indices.firstOrNull { anterior[it] != atual[it] } ?: anterior.length
    val semNovo = atual.removeRange(indice, indice + 1)
    return if (semNovo == anterior) indice else null
}

internal class MascaramentoDeSenhaComRevelacaoBreve(
    private val indiceRevelado: Int?,
    private val mascara: Char = '\u2022',
) : VisualTransformation {
    override fun filter(text: AnnotatedString): TransformedText {
        val mascarado = buildString(text.text.length) {
            for (i in text.text.indices) {
                append(if (i == indiceRevelado) text.text[i] else mascara)
            }
        }
        return TransformedText(AnnotatedString(mascarado), OffsetMapping.Identity)
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is MascaramentoDeSenhaComRevelacaoBreve) return false
        return indiceRevelado == other.indiceRevelado && mascara == other.mascara
    }

    override fun hashCode(): Int = 31 * (indiceRevelado ?: -1) + mascara.hashCode()
}

@Composable
private fun rememberVisualTransformationDeSenha(valor: String): VisualTransformation {
    var valorAnterior by remember { mutableStateOf(valor) }
    var indiceRevelado by remember { mutableStateOf<Int?>(null) }
    var cicloRevelacao by remember { mutableIntStateOf(0) }

    if (valor != valorAnterior) {
        indiceRevelado = indiceCaractereRecemDigitado(valorAnterior, valor)
        if (indiceRevelado != null) {
            cicloRevelacao += 1
        }
        valorAnterior = valor
    }

    LaunchedEffect(cicloRevelacao) {
        if (indiceRevelado != null) {
            delay(ATRASO_MASCARAMENTO_CARACTERE_SENHA_MS)
            indiceRevelado = null
        }
    }

    return remember(indiceRevelado) {
        MascaramentoDeSenhaComRevelacaoBreve(indiceRevelado = indiceRevelado)
    }
}
