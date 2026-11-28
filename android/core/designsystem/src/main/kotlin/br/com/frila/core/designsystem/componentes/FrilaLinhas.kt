package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** Título de tela: Prodigy Sans 24, em tinta. É conteúdo da tela, não da barra de navegação. */
@Composable
fun TituloDaTela(texto: String, modifier: Modifier = Modifier) {
    Text(
        text = texto,
        style = FrilaTipo.tituloDaTela,
        color = FrilaTema.cores.tinta,
        modifier = modifier.semantics { heading() },
    )
}

/** Nome de grupo ou seção: 600 em 15sp, tinta suave, frase normal. Nomeia o grupo sem competir com o conteúdo. */
@Composable
fun RotuloDeGrupo(texto: String, modifier: Modifier = Modifier) {
    Text(
        text = texto,
        style = FrilaTipo.rotuloDeGrupo,
        color = FrilaTema.cores.tintaSuave,
        modifier = modifier.semantics { heading() },
    )
}

/** Divisória de 1dp em `borda`. Entre grupos de um cartão, com 16dp acima e abaixo (quem chama dá o espaço). */
@Composable
fun FrilaDivisoria(modifier: Modifier = Modifier, cor: Color = FrilaTema.cores.borda) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(cor),
    )
}

/** Onde as linhas de um [FrilaGrupoDeLinhas] são declaradas, uma chamada de [linha] por linha. */
class EscopoDoGrupoDeLinhas internal constructor() {
    internal val linhas = mutableListOf<@Composable () -> Unit>()

    fun linha(conteudo: @Composable () -> Unit) {
        linhas += conteudo
    }
}

/**
 * Grupo de linhas: linhas de formulário ou de menu num cartão em superfície, raio 16, fio de `borda`,
 * sem sombra, com uma divisória de 1dp entre cada linha (começando onde o texto começa).
 *
 * ```
 * FrilaGrupoDeLinhas(titulo = "Salvar como") {
 *     linha { FrilaLinhaDeOpcao("Casa", marcada = true, aoClicar = { }) }
 *     linha { FrilaLinhaDeOpcao("Trabalho", marcada = false, aoClicar = { }) }
 * }
 * ```
 */
@Composable
fun FrilaGrupoDeLinhas(
    modifier: Modifier = Modifier,
    titulo: String? = null,
    recuoDaDivisoria: Dp = FrilaEspacamento.bloco,
    linhas: EscopoDoGrupoDeLinhas.() -> Unit,
) {
    val cores = FrilaTema.cores
    val forma = RoundedCornerShape(FrilaRaios.interno)
    val escopo = EscopoDoGrupoDeLinhas().apply(linhas)

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        if (titulo != null) {
            RotuloDeGrupo(titulo)
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(forma)
                .background(cores.superficie)
                .border(1.dp, cores.borda, forma),
        ) {
            escopo.linhas.forEachIndexed { indice, linha ->
                if (indice > 0) {
                    FrilaDivisoria(modifier = Modifier.padding(start = recuoDaDivisoria))
                }
                linha()
            }
        }
    }
}

/**
 * Opção de escolha única dentro de um [FrilaGrupoDeLinhas]: título, subtítulo opcional e o check em
 * TINTA à direita, só quando marcada. Sem laranja: escolher não é a ação principal da tela. A linha
 * inteira é o alvo. Escolha única em formulário é lista com check, não chip.
 */
@Composable
fun FrilaLinhaDeOpcao(
    titulo: String,
    marcada: Boolean,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    subtitulo: String? = null,
    icone: ImageVector? = null,
    habilitada: Boolean = true,
) {
    LinhaDeGrupo(
        titulo = titulo,
        subtitulo = subtitulo,
        icone = icone,
        modifier = modifier.selectable(
            selected = marcada,
            enabled = habilitada,
            role = Role.RadioButton,
            onClick = aoClicar,
        ),
    ) {
        if (marcada) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = null,
                tint = FrilaTema.cores.tinta,
                modifier = Modifier.size(24.dp),
            )
        }
    }
}

/** Linha que abre outra tela dentro de um [FrilaGrupoDeLinhas]: título, valor opcional à direita e a seta. */
@Composable
fun FrilaLinhaDeNavegacao(
    titulo: String,
    aoClicar: () -> Unit,
    modifier: Modifier = Modifier,
    subtitulo: String? = null,
    icone: ImageVector? = null,
    valor: String? = null,
    /** O que o toque faz, para o TalkBack ("toque duas vezes para ..."): o `onClickLabel`, como o `CartaoVaga`. Nulo mantém o anúncio só de "botão". */
    rotuloDaAcao: String? = null,
) {
    val cores = FrilaTema.cores
    LinhaDeGrupo(
        titulo = titulo,
        subtitulo = subtitulo,
        icone = icone,
        modifier = modifier.clickable(onClickLabel = rotuloDaAcao, role = Role.Button, onClick = aoClicar),
    ) {
        if (valor != null) {
            Text(text = valor, style = FrilaTipo.corpo, color = cores.tintaSuave)
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = cores.tintaSuave,
            modifier = Modifier.size(24.dp),
        )
    }
}

@Composable
private fun LinhaDeGrupo(
    titulo: String,
    subtitulo: String?,
    icone: ImageVector?,
    modifier: Modifier,
    fim: @Composable () -> Unit,
) {
    val cores = FrilaTema.cores
    Row(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = FrilaMetricas.alvoMinimo)
            .padding(horizontal = FrilaEspacamento.bloco, vertical = FrilaEspacamento.item),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item),
    ) {
        if (icone != null) {
            Icon(imageVector = icone, contentDescription = null, tint = cores.tinta, modifier = Modifier.size(24.dp))
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(FrilaEspacamento.fio)) {
            Text(text = titulo, style = FrilaTipo.rotuloSecundario, color = cores.tinta)
            if (!subtitulo.isNullOrBlank()) {
                Text(text = subtitulo, style = FrilaTipo.apoio, color = cores.tintaSuave)
            }
        }
        fim()
    }
}

/**
 * Linha de dado (leitura): ícone de 20 e texto em corpo, 8dp entre os dois, ícone alinhado à primeira
 * linha. O valor fica em tinta; o qualificador opcional segue na mesma frase, em tinta suave
 * ("1,8 km" + "de distância"). Na leitura o ícone basta, sem rótulo acima. Não é campo nem botão.
 */
@Composable
fun FrilaLinhaDeDado(
    icone: ImageVector,
    valor: String,
    modifier: Modifier = Modifier,
    qualificador: String? = null,
) {
    val cores = FrilaTema.cores
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.item)) {
        Icon(
            imageVector = icone,
            contentDescription = null,
            tint = cores.tinta,
            // 1dp de recuo: centra o ícone de 20 na primeira linha do corpo (22sp de altura de linha).
            modifier = Modifier
                .padding(top = 1.dp)
                .size(20.dp),
        )
        Text(
            text = buildAnnotatedString {
                append(valor)
                if (!qualificador.isNullOrBlank()) {
                    withStyle(SpanStyle(color = cores.tintaSuave)) { append(" $qualificador") }
                }
            },
            style = FrilaTipo.corpo,
            color = cores.tinta,
        )
    }
}
