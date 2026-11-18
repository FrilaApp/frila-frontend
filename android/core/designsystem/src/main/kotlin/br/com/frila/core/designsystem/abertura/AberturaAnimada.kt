package br.com.frila.core.designsystem.abertura

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.MutableDoubleState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import br.com.frila.core.designsystem.R
import br.com.frila.core.designsystem.componentes.animacoesAtivadas
import br.com.frila.core.designsystem.tema.FrilaTema
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

/**
 * Abertura do app: o `r` cumprimenta o `i`, o par vira o rótulo "Frila" e o pingo do `i` se abre numa janela que revela
 * o app. Porta do protótipo do Fabrício (`AberturaAnimada.swift`); a coreografia está em [CoreografiaDaAbertura] e os
 * tempos em [RoteiroDaAbertura] (a duração, numa constante só: [duracaoDaAbertura]).
 *
 * **O app carrega por baixo.** O [conteudo] entra na composição desde o primeiro quadro, com a mesma identidade antes,
 * durante e depois da abertura: nada do que ele faz (inicialização, primeira chamada de rede) espera a animação, e ela
 * termina sem recarregá-lo. A abertura é só uma camada por cima, que come os toques e esconde o app do leitor de tela
 * enquanto cobre.
 *
 * **Toque pula.** Um toque antes da saída esmaece a cena de onde ela está e assenta o app. Depois que a janela começa
 * a abrir, não há mais o que pular.
 *
 * **Reduzir movimento** ([reduzirMovimento], por padrão as animações do sistema desligadas): o rótulo aparece parado e
 * some num esmaecimento (0,9 s), sem aperto de mão e sem o app crescer.
 *
 * **Voo do rótulo.** Quando o conteúdo marca um rótulo como destino ([destinoDoRotuloDaAbertura], a tela de entrada faz
 * isso), o rótulo da abertura não some na saída: enquanto a janela abre, voa até aquele lugar e troca o branco pela
 * tinta, e vira o rótulo da tela. Sem destino, a saída é a simples.
 *
 * @param ligada falso não cobre nada: é a chave que testes e capturas desligam. Só vale na primeira composição; quem
 * decide quando tocar (abertura a frio do processo) é quem chama.
 * @param duracao a duração total; por padrão a constante [duracaoDaAbertura].
 * @param tempoCongelado só para capturas de depuração: congela a abertura naquele instante (segundos), sem relógio.
 * @param aoTerminar chamado uma vez quando a abertura sai de cena, por fim ou por toque.
 */
@Composable
fun AberturaAnimada(
    ligada: Boolean,
    modifier: Modifier = Modifier,
    duracao: Double = duracaoDaAbertura,
    reduzirMovimento: Boolean = !animacoesAtivadas(),
    tempoCongelado: Double? = null,
    aoTerminar: () -> Unit = {},
    conteudo: @Composable () -> Unit,
) {
    var ativa by remember { mutableStateOf(ligada) }
    var pulando by remember { mutableStateOf(false) }
    val roteiro = remember(reduzirMovimento, duracao) { RoteiroDaAbertura.para(reduzirMovimento, duracao) }
    // Com "reduzir movimento" o app não cresce: aparece no lugar quando a abertura esmaece.
    val escalaDoApp = remember {
        Animatable(if (ligada && !reduzirMovimento) CoreografiaDaAbertura.ESCALA_INICIAL_DO_APP else 1f)
    }
    val tempo = remember { mutableDoubleStateOf(tempoCongelado ?: 0.0) }
    val opacidadeDoPulo = remember { Animatable(1f) }
    val destino = remember { DestinoDoRotuloDaAbertura() }
    val haptico = LocalHapticFeedback.current
    val aoTerminarAtual by rememberUpdatedState(aoTerminar)

    LaunchedEffect(ativa, pulando) {
        if (!ativa) return@LaunchedEffect
        if (tempoCongelado != null) {
            // Captura de depuração: o app parado na escala que teria naquele instante.
            val andamento = ((tempoCongelado - roteiro.saida) / (roteiro.duracao - roteiro.saida)).coerceIn(0.0, 1.0)
            if (escalaDoApp.value != 1f) {
                val inicial = CoreografiaDaAbertura.ESCALA_INICIAL_DO_APP
                escalaDoApp.snapTo(inicial + (1f - inicial) * FastOutSlowInEasing.transform(andamento.toFloat()))
            }
            return@LaunchedEffect
        }
        // Um toque que pula troca a chave do efeito: o que conduzia é cancelado e este assume.
        if (pulando) {
            // Pular não corta para o rótulo montado: a cena esmaece de onde está e o app assenta.
            launch { escalaDoApp.animateTo(1f, tween(DURACAO_DO_ASSENTO_AO_PULAR_MS, easing = FastOutSlowInEasing)) }
            opacidadeDoPulo.animateTo(0f, tween(DURACAO_DO_PULO_MS, easing = CurvasDaAbertura.easeIn))
        } else {
            conduzir(roteiro, tempo, escalaDoApp) { haptico.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
        }
        ativa = false
        aoTerminarAtual()
    }

    val escondeDoLeitorDeTela = if (ativa) Modifier.clearAndSetSemantics { } else Modifier

    Box(modifier = modifier.fillMaxSize()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    scaleX = escalaDoApp.value
                    scaleY = escalaDoApp.value
                }
                .then(escondeDoLeitorDeTela),
        ) {
            CompositionLocalProvider(
                LocalAberturaCobrindo provides ativa,
                LocalDestinoDoRotuloDaAbertura provides destino,
            ) {
                conteudo()
            }
        }
        if (ativa) {
            CamadaDaAbertura(
                roteiro = roteiro,
                tempo = { tempo.doubleValue },
                opacidade = { opacidadeDoPulo.value },
                destino = destino,
                pulando = pulando,
                podePular = { tempoCongelado == null && !pulando && tempo.doubleValue < roteiro.saida },
                aoPular = { pulando = true },
            )
        }
    }
}

/**
 * Prepara, fora da thread principal, o que o primeiro quadro da abertura precisa (as malhas do `r` e do `i` e os
 * contornos das letras): sem isso o primeiro quadro paga a leitura delas na thread que também compõe o app. Pode ser
 * chamada antes do `setContent`; é segura em qualquer thread e idempotente.
 */
fun aquecerAberturaAnimada() {
    Thread {
        MalhaDaLetra.r
        MalhaDaLetra.i
        ParteDaMarca.entries.forEach { it.caminho }
        CoreografiaDaAbertura.quadro(0.0)
    }.apply {
        name = "aquecer-abertura"
        isDaemon = true
        start()
    }
}

/**
 * Conduz o relógio da abertura: conta do primeiro quadro desenhado (numa abertura a frio o app ainda inicializa entre um
 * quadro e outro, e a entrada começaria pela metade), dispara o toque tátil no encaixe e solta o app na saída.
 */
private suspend fun conduzir(
    roteiro: RoteiroDaAbertura,
    tempo: MutableDoubleState,
    escalaDoApp: Animatable<Float, *>,
    aoEncaixar: () -> Unit,
) = coroutineScope {
    var inicio = -1L
    var encaixou = roteiro.encaixe == null
    var assentou = false
    while (true) {
        val agora = withFrameNanos { it }
        if (inicio < 0) inicio = agora
        val decorrido = (agora - inicio) / 1_000_000_000.0
        tempo.doubleValue = minOf(decorrido, roteiro.duracao)
        if (!encaixou && decorrido >= (roteiro.encaixe ?: 0.0)) {
            encaixou = true
            aoEncaixar()
        }
        if (!assentou && decorrido >= roteiro.saida) {
            assentou = true
            if (escalaDoApp.value != 1f) {
                val ms = ((roteiro.duracao - roteiro.saida) * 1000).toInt().coerceAtLeast(1)
                launch { escalaDoApp.animateTo(1f, tween(ms, easing = FastOutSlowInEasing)) }
            }
        }
        if (decorrido >= roteiro.duracao) break
    }
}

private const val DURACAO_DO_PULO_MS = 250
private const val DURACAO_DO_ASSENTO_AO_PULAR_MS = 350

@Composable
private fun CamadaDaAbertura(
    roteiro: RoteiroDaAbertura,
    tempo: () -> Double,
    opacidade: () -> Float,
    destino: DestinoDoRotuloDaAbertura,
    pulando: Boolean,
    podePular: () -> Boolean,
    aoPular: () -> Unit,
) {
    val paleta = FrilaTema.cores
    val cores = remember(paleta) { CoresDaAbertura(paleta.acao, paleta.sobreAcao, paleta.tinta) }
    val nome = stringResource(R.string.abertura_nome_da_marca)
    val pular = stringResource(R.string.abertura_pular)
    var origem by remember { mutableStateOf(Offset.Zero) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .onGloballyPositioned { origem = it.positionInRoot() }
            .graphicsLayer {
                // Esmaece no toque que pula; com movimento reduzido, é o esmaecimento do roteiro reduzido. A camada
                // própria deixa o furo da janela apagar só o laranja da abertura, e não o app por baixo.
                alpha = (roteiro.opacidadeReduzida(tempo()) * opacidade()).toFloat()
                compositingStrategy = CompositingStrategy.Offscreen
            }
            .semantics { contentDescription = nome }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClickLabel = pular,
                role = Role.Image,
            ) { if (podePular()) aoPular() },
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val limites: Rect? = destino.limitesNaRaiz()?.translate(-origem)
            desenharAbertura(tempo(), roteiro, limites, pulando, cores)
        }
    }
}
