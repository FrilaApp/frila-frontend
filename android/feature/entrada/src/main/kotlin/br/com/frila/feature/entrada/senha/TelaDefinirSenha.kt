package br.com.frila.feature.entrada.senha

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.view.Window
import android.view.WindowManager
import java.util.WeakHashMap
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentType
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.password
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
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
                    ocultarAoEnviar = estado.carregando,
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
                    ocultarAoEnviar = estado.carregando,
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

private tailrec fun Context.encontrarActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.encontrarActivity()
    else -> null
}

/**
 * Coordena `FLAG_SECURE` por [Window] com contagem de referências para que múltiplos campos de
 * senha na mesma tela não removam a proteção enquanto outro campo ainda estiver visível, nem
 * removam um `FLAG_SECURE` previamente definido por outra origem.
 */
internal object CoordenadorFlagSecureJanela {
    private data class Estado(var ativos: Int, val jaEraSeguroAntes: Boolean)

    private val porJanela = WeakHashMap<Window, Estado>()

    @Synchronized
    fun adquirir(window: Window) {
        val existente = porJanela[window]
        if (existente == null) {
            val jaEraSeguro = (window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0
            if (!jaEraSeguro) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            porJanela[window] = Estado(ativos = 1, jaEraSeguroAntes = jaEraSeguro)
        } else {
            existente.ativos += 1
        }
    }

    @Synchronized
    fun liberar(window: Window) {
        val existente = porJanela[window] ?: return
        existente.ativos -= 1
        if (existente.ativos <= 0) {
            porJanela.remove(window)
            if (!existente.jaEraSeguroAntes) {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }
}

private val IconeOlhoAberto: ImageVector by lazy {
    ImageVector.Builder(
        name = "OlhoAberto",
        defaultWidth = 24.dp,
        defaultHeight = 24.dp,
        viewportWidth = 24f,
        viewportHeight = 24f,
    ).apply {
        path(
            fill = null,
            stroke = SolidColor(Color.Black),
            strokeLineWidth = 2f,
            strokeLineCap = StrokeCap.Round,
            strokeLineJoin = StrokeJoin.Round,
            pathFillType = PathFillType.NonZero,
        ) {
            moveTo(1f, 12f)
            curveTo(3.5f, 7f, 7.5f, 4f, 12f, 4f)
            curveTo(16.5f, 4f, 20.5f, 7f, 23f, 12f)
            curveTo(20.5f, 17f, 16.5f, 20f, 12f, 20f)
            curveTo(7.5f, 20f, 3.5f, 17f, 1f, 12f)
            close()
        }
        path(
            fill = null,
            stroke = SolidColor(Color.Black),
            strokeLineWidth = 2f,
            strokeLineCap = StrokeCap.Round,
            strokeLineJoin = StrokeJoin.Round,
            pathFillType = PathFillType.NonZero,
        ) {
            moveTo(15f, 12f)
            arcTo(3f, 3f, 0f, isMoreThanHalf = true, isPositiveArc = true, 9f, 12f)
            arcTo(3f, 3f, 0f, isMoreThanHalf = true, isPositiveArc = true, 15f, 12f)
            close()
        }
    }.build()
}

private val IconeOlhoOculto: ImageVector by lazy {
    ImageVector.Builder(
        name = "OlhoOculto",
        defaultWidth = 24.dp,
        defaultHeight = 24.dp,
        viewportWidth = 24f,
        viewportHeight = 24f,
    ).apply {
        path(
            fill = null,
            stroke = SolidColor(Color.Black),
            strokeLineWidth = 2f,
            strokeLineCap = StrokeCap.Round,
            strokeLineJoin = StrokeJoin.Round,
            pathFillType = PathFillType.NonZero,
        ) {
            moveTo(3f, 3f)
            lineTo(21f, 21f)
            moveTo(10.58f, 10.58f)
            arcTo(2f, 2f, 0f, isMoreThanHalf = false, isPositiveArc = false, 13.42f, 13.42f)
            moveTo(9.88f, 5.08f)
            curveTo(10.57f, 4.86f, 11.28f, 4.75f, 12f, 4.75f)
            curveTo(16.5f, 4.75f, 20.5f, 7.5f, 23f, 12f)
            curveTo(22.15f, 13.52f, 21.08f, 14.85f, 19.84f, 15.93f)
            moveTo(6.61f, 6.61f)
            curveTo(4.24f, 8.05f, 2.29f, 9.9f, 1f, 12f)
            curveTo(3.5f, 16.5f, 7.5f, 19.25f, 12f, 19.25f)
            curveTo(13.94f, 19.25f, 15.79f, 18.74f, 17.39f, 17.85f)
        }
    }.build()
}

@Composable
internal fun CampoDeSenhaComRevelacaoBreve(
    valor: String,
    aoMudar: (String) -> Unit,
    rotulo: String,
    dica: String? = null,
    erro: String? = null,
    habilitado: Boolean,
    keyboardOptions: KeyboardOptions,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    ocultarAoEnviar: Boolean = false,
    revelacaoBreve: Boolean = true,
    modifier: Modifier = Modifier,
) {
    var valorCampo by remember { mutableStateOf(TextFieldValue(valor, selection = TextRange(valor.length))) }
    if (valorCampo.text != valor) {
        valorCampo = TextFieldValue(valor, selection = TextRange(valor.length))
    }
    var visivel by remember { mutableStateOf(false) }
    var intervaloRevelado by remember { mutableStateOf<IntRange?>(null) }
    var cicloRevelacao by remember { mutableIntStateOf(0) }

    // Volta a oculto quando o formulário entra em envio.
    LaunchedEffect(ocultarAoEnviar) {
        if (ocultarAoEnviar) {
            visivel = false
            intervaloRevelado = null
        }
    }

    // Volta a oculto ao ir para segundo plano e ao sair da tela.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_PAUSE || event == Lifecycle.Event.ON_STOP) {
                visivel = false
                intervaloRevelado = null
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            visivel = false
            intervaloRevelado = null
        }
    }

    // Protege contra gravação/espelhamento/snapshot enquanto a senha estiver visível,
    // coordenado por Window com contagem de referências entre campos.
    val view = LocalView.current
    DisposableEffect(visivel, view) {
        val window = if (visivel) view.context.encontrarActivity()?.window else null
        if (window != null) {
            CoordenadorFlagSecureJanela.adquirir(window)
        }
        onDispose {
            if (window != null) {
                CoordenadorFlagSecureJanela.liberar(window)
            }
        }
    }

    LaunchedEffect(cicloRevelacao, visivel) {
        if (!visivel && intervaloRevelado != null) {
            delay(ATRASO_MASCARAMENTO_CARACTERE_SENHA_MS)
            intervaloRevelado = null
        }
    }

    val visualTransformation = remember(visivel, intervaloRevelado, revelacaoBreve) {
        when {
            visivel -> VisualTransformation.None
            revelacaoBreve -> MascaramentoDeSenhaComRevelacaoBreve(intervaloRevelado = intervaloRevelado)
            else -> PasswordVisualTransformation()
        }
    }

    val cores = FrilaTema.cores
    val descricaoBotao = if (visivel) "Ocultar senha" else "Mostrar senha"
    val estadoAnunciado = if (visivel) "Senha visível" else "Senha oculta"

    CampoDeTexto(
        valor = valorCampo,
        aoMudar = { novo ->
            val textoMudou = novo.text != valorCampo.text
            if (textoMudou) {
                if (revelacaoBreve && !visivel) {
                    intervaloRevelado = intervaloCaractereRecemDigitado(valorCampo, novo)
                    if (intervaloRevelado != null) {
                        cicloRevelacao += 1
                    }
                } else {
                    intervaloRevelado = null
                }
            }
            valorCampo = novo
            if (textoMudou) {
                aoMudar(novo.text)
            }
        },
        rotulo = rotulo,
        dica = dica,
        erro = erro,
        habilitado = habilitado,
        visualTransformation = visualTransformation,
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        acessorio = {
            IconButton(
                onClick = {
                    visivel = !visivel
                    if (!visivel) {
                        intervaloRevelado = null
                    }
                },
                enabled = habilitado,
                modifier = Modifier
                    .size(48.dp)
                    .semantics {
                        stateDescription = estadoAnunciado
                    },
            ) {
                Icon(
                    imageVector = if (visivel) IconeOlhoOculto else IconeOlhoAberto,
                    contentDescription = descricaoBotao,
                    tint = cores.tintaSuave,
                )
            }
        },
        modifier = modifier.semantics { password() },
    )
}
