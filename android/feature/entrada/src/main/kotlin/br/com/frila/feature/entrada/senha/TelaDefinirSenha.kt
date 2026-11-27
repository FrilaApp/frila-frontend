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
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.delay
import java.text.BreakIterator
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
                CampoDeSenhaComRevelacaoBreve(
                    valor = estado.senha,
                    aoMudar = viewModel::aoMudarSenha,
                    rotulo = "Nova senha",
                    dica = "Mínimo de 8 caracteres",
                    habilitado = !estado.carregando,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Next,
                        autoCorrectEnabled = false,
                    ),
                    modifier = Modifier.semantics { contentType = ContentType.NewPassword },
                )

                CampoDeSenhaComRevelacaoBreve(
                    valor = estado.confirmacao,
                    aoMudar = viewModel::aoMudarConfirmacao,
                    rotulo = "Confirmar senha",
                    dica = "Repita a nova senha",
                    habilitado = !estado.carregando,
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

private fun ehUmUnicoGrafema(trecho: String): Boolean {
    if (trecho.isEmpty()) return false
    val iterador = BreakIterator.getCharacterInstance()
    iterador.setText(trecho)
    val primeiroFim = iterador.next()
    return primeiroFim == trecho.length
}

internal fun intervaloCaractereRecemDigitado(anterior: TextFieldValue, atual: TextFieldValue): IntRange? {
    if (atual.composition != null) return null
    if (!anterior.selection.collapsed || !atual.selection.collapsed) return null
    val delta = atual.text.length - anterior.text.length
    if (delta <= 0) return null
    val fim = atual.selection.end
    val inicio = fim - delta
    if (inicio < 0 || fim > atual.text.length) return null
    if (atual.text.removeRange(inicio, fim) != anterior.text) return null
    val inserido = atual.text.substring(inicio, fim)
    return if (ehUmUnicoGrafema(inserido)) inicio until fim else null
}

internal class MascaramentoDeSenhaComRevelacaoBreve(
    private val intervaloRevelado: IntRange?,
    private val mascara: Char = '\u2022',
) : VisualTransformation {
    override fun filter(text: AnnotatedString): TransformedText {
        val mascarado = buildString(text.text.length) {
            for (i in text.text.indices) {
                val revelar = intervaloRevelado != null && i in intervaloRevelado
                append(if (revelar) text.text[i] else mascara)
            }
        }
        return TransformedText(AnnotatedString(mascarado), OffsetMapping.Identity)
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is MascaramentoDeSenhaComRevelacaoBreve) return false
        return intervaloRevelado == other.intervaloRevelado && mascara == other.mascara
    }

    override fun hashCode(): Int = 31 * (intervaloRevelado?.hashCode() ?: 0) + mascara.hashCode()
}

@Composable
private fun CampoDeSenhaComRevelacaoBreve(
    valor: String,
    aoMudar: (String) -> Unit,
    rotulo: String,
    dica: String,
    habilitado: Boolean,
    keyboardOptions: KeyboardOptions,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    modifier: Modifier = Modifier,
) {
    var valorCampo by remember { mutableStateOf(TextFieldValue(valor, selection = TextRange(valor.length))) }
    if (valorCampo.text != valor) {
        valorCampo = TextFieldValue(valor, selection = TextRange(valor.length))
    }
    var intervaloRevelado by remember { mutableStateOf<IntRange?>(null) }
    var cicloRevelacao by remember { mutableIntStateOf(0) }

    LaunchedEffect(cicloRevelacao) {
        if (intervaloRevelado != null) {
            delay(ATRASO_MASCARAMENTO_CARACTERE_SENHA_MS)
            intervaloRevelado = null
        }
    }

    val visualTransformation = remember(intervaloRevelado) {
        MascaramentoDeSenhaComRevelacaoBreve(intervaloRevelado = intervaloRevelado)
    }

    CampoDeTexto(
        valor = valorCampo,
        aoMudar = { novo ->
            val textoMudou = novo.text != valorCampo.text
            if (textoMudou) {
                intervaloRevelado = intervaloCaractereRecemDigitado(valorCampo, novo)
                if (intervaloRevelado != null) {
                    cicloRevelacao += 1
                }
            }
            valorCampo = novo
            if (textoMudou) {
                aoMudar(novo.text)
            }
        },
        rotulo = rotulo,
        dica = dica,
        habilitado = habilitado,
        visualTransformation = visualTransformation,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        modifier = modifier,
    )
}
