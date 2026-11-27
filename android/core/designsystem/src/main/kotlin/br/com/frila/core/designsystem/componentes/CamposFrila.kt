package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/**
 * Campo de texto do Frila: rótulo visível ACIMA (rótulo de grupo), caixa de 48dp em superfície com
 * contorno `bordaControle` e raio 16. Em foco, e também com erro, o contorno é de 2dp em tinta. O erro
 * vem escrito embaixo, em tinta: problema não tem cor.
 *
 * O rótulo, a dica e o erro fazem parte do próprio campo para o leitor de tela e para os testes
 * (`onNodeWithText("E-mail")` acha o campo, como no campo do Material).
 */
@Composable
fun CampoDeTexto(
    valor: String,
    aoMudar: (String) -> Unit,
    rotulo: String,
    modifier: Modifier = Modifier,
    dica: String? = null,
    apoio: String? = null,
    erro: String? = null,
    habilitado: Boolean = true,
    umaLinha: Boolean = true,
    linhasMinimas: Int = 1,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    acessorio: @Composable (() -> Unit)? = null,
) {
    val cores = FrilaTema.cores
    val interacao = remember { MutableInteractionSource() }
    val emFoco by interacao.collectIsFocusedAsState()
    val destacado = emFoco || erro != null
    val forma = RoundedCornerShape(FrilaRaios.interno)

    BasicTextField(
        value = valor,
        onValueChange = aoMudar,
        modifier = modifier
            .fillMaxWidth()
            .semantics { if (erro != null) error(erro) },
        enabled = habilitado,
        textStyle = FrilaTipo.corpo.copy(color = if (habilitado) cores.tinta else cores.tintaSuave),
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        singleLine = umaLinha,
        minLines = linhasMinimas,
        visualTransformation = visualTransformation,
        interactionSource = interacao,
        cursorBrush = SolidColor(cores.tinta),
        decorationBox = { campo ->
            DecoracaoCampoDeTexto(
                vazio = valor.isEmpty(),
                rotulo = rotulo,
                dica = dica,
                apoio = apoio,
                erro = erro,
                destacado = destacado,
                umaLinha = umaLinha,
                forma = forma,
                acessorio = acessorio,
                campo = campo,
            )
        },
    )
}

@Composable
fun CampoDeTexto(
    valor: TextFieldValue,
    aoMudar: (TextFieldValue) -> Unit,
    rotulo: String,
    modifier: Modifier = Modifier,
    dica: String? = null,
    apoio: String? = null,
    erro: String? = null,
    habilitado: Boolean = true,
    umaLinha: Boolean = true,
    linhasMinimas: Int = 1,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    acessorio: @Composable (() -> Unit)? = null,
) {
    val cores = FrilaTema.cores
    val interacao = remember { MutableInteractionSource() }
    val emFoco by interacao.collectIsFocusedAsState()
    val destacado = emFoco || erro != null
    val forma = RoundedCornerShape(FrilaRaios.interno)

    BasicTextField(
        value = valor,
        onValueChange = aoMudar,
        modifier = modifier
            .fillMaxWidth()
            .semantics { if (erro != null) error(erro) },
        enabled = habilitado,
        textStyle = FrilaTipo.corpo.copy(color = if (habilitado) cores.tinta else cores.tintaSuave),
        keyboardOptions = keyboardOptions,
        keyboardActions = keyboardActions,
        singleLine = umaLinha,
        minLines = linhasMinimas,
        visualTransformation = visualTransformation,
        interactionSource = interacao,
        cursorBrush = SolidColor(cores.tinta),
        decorationBox = { campo ->
            DecoracaoCampoDeTexto(
                vazio = valor.text.isEmpty(),
                rotulo = rotulo,
                dica = dica,
                apoio = apoio,
                erro = erro,
                destacado = destacado,
                umaLinha = umaLinha,
                forma = forma,
                acessorio = acessorio,
                campo = campo,
            )
        },
    )
}

@Composable
private fun DecoracaoCampoDeTexto(
    vazio: Boolean,
    rotulo: String,
    dica: String?,
    apoio: String?,
    erro: String?,
    destacado: Boolean,
    umaLinha: Boolean,
    forma: RoundedCornerShape,
    acessorio: @Composable (() -> Unit)?,
    campo: @Composable () -> Unit,
) {
    val cores = FrilaTema.cores
    Column(verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        Text(text = rotulo, style = FrilaTipo.rotuloDeGrupo, color = cores.tintaSuave)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = FrilaMetricas.alturaCampo)
                .background(cores.superficie, forma)
                .border(
                    width = if (destacado) 2.dp else 1.dp,
                    color = if (destacado) cores.tinta else cores.bordaControle,
                    shape = forma,
                )
                .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.compacto),
            verticalAlignment = if (umaLinha) Alignment.CenterVertically else Alignment.Top,
            horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
        ) {
            Box(modifier = Modifier.weight(1f)) {
                if (vazio && dica != null) {
                    Text(text = dica, style = FrilaTipo.corpo, color = cores.tintaSuave)
                }
                campo()
            }
            acessorio?.invoke()
        }
        if (erro != null) {
            Text(text = erro, style = FrilaTipo.apoio, color = cores.tinta)
        } else if (apoio != null) {
            Text(text = apoio, style = FrilaTipo.apoio, color = cores.tintaSuave)
        }
    }
}

/**
 * Campo de busca em cápsula: 48dp, superfície, contorno `bordaControle`, lupa à esquerda e o limpar à
 * direita quando há texto. Filtra enquanto a pessoa digita, sem botão de buscar. `dica` diz o que o
 * campo procura e é também o nome acessível.
 */
@Composable
fun CampoDeBusca(
    texto: String,
    aoMudar: (String) -> Unit,
    dica: String,
    modifier: Modifier = Modifier,
) {
    val cores = FrilaTema.cores
    val interacao = remember { MutableInteractionSource() }
    val emFoco by interacao.collectIsFocusedAsState()

    BasicTextField(
        value = texto,
        onValueChange = aoMudar,
        modifier = modifier
            .fillMaxWidth()
            .semantics { contentDescription = dica },
        textStyle = FrilaTipo.corpo.copy(color = cores.tinta),
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
        singleLine = true,
        interactionSource = interacao,
        cursorBrush = SolidColor(cores.tinta),
        decorationBox = { campo ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = FrilaMetricas.alturaCampo)
                    .background(cores.superficie, CircleShape)
                    .border(
                        width = if (emFoco) 2.dp else 1.dp,
                        color = if (emFoco) cores.tinta else cores.bordaControle,
                        shape = CircleShape,
                    )
                    .padding(start = FrilaEspacamento.bloco, end = if (texto.isEmpty()) FrilaEspacamento.bloco else 0.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
            ) {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = null,
                    tint = cores.tinta,
                    modifier = Modifier.size(24.dp),
                )
                Box(modifier = Modifier.weight(1f)) {
                    if (texto.isEmpty()) {
                        Text(text = dica, style = FrilaTipo.corpo, color = cores.tintaSuave)
                    }
                    campo()
                }
                if (texto.isNotEmpty()) {
                    IconButton(onClick = { aoMudar("") }, modifier = Modifier.size(FrilaMetricas.alvoMinimo)) {
                        Icon(imageVector = Icons.Default.Close, contentDescription = "Limpar busca", tint = cores.tintaSuave)
                    }
                }
            }
        },
    )
}

/**
 * As caixas de um código numérico (a tela do código de acesso): um campo só recebe o teclado e a
 * colagem; as caixas só desenham. A caixa da vez tem contorno de 2dp em tinta, como o foco dos
 * campos; com erro, todas ficam assim. Só aceita dígitos, até `quantidade`.
 */
@Composable
fun CaixasDeCodigo(
    codigo: String,
    aoMudar: (String) -> Unit,
    modifier: Modifier = Modifier,
    quantidade: Int = 6,
    comErro: Boolean = false,
    habilitado: Boolean = true,
    rotulo: String = "Código de acesso",
    keyboardActions: KeyboardActions = KeyboardActions.Default,
) {
    val cores = FrilaTema.cores
    val interacao = remember { MutableInteractionSource() }
    val emFoco by interacao.collectIsFocusedAsState()
    val forma = RoundedCornerShape(FrilaRaios.interno)

    BasicTextField(
        value = codigo,
        onValueChange = { novo -> aoMudar(novo.filter(Char::isDigit).take(quantidade)) },
        modifier = modifier
            .fillMaxWidth()
            .semantics { contentDescription = rotulo },
        enabled = habilitado,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword, imeAction = ImeAction.Done),
        keyboardActions = keyboardActions,
        singleLine = true,
        interactionSource = interacao,
        decorationBox = {
            Row(horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
                repeat(quantidade) { indice ->
                    val destacada = comErro || (emFoco && indice == codigo.length)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .heightIn(min = FrilaMetricas.alturaCaixaDeCodigo)
                            .background(cores.superficie, forma)
                            .border(
                                width = if (destacada) 2.dp else 1.dp,
                                color = if (destacada) cores.tinta else cores.bordaControle,
                                shape = forma,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = codigo.getOrNull(indice)?.toString().orEmpty(),
                            style = EstiloDoDigito,
                            color = cores.tinta,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
            }
        },
    )
}

private val EstiloDoDigito = TextStyle(
    fontSize = 22.sp,
    lineHeight = 28.sp,
    fontWeight = FontWeight.SemiBold,
    fontFeatureSettings = "tnum",
)
