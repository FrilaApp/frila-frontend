package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.materialIcon
import androidx.compose.material.icons.materialPath
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaEspacamento
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTema
import br.com.frila.core.designsystem.tema.FrilaTipo

/** O que o selo quer dizer. Uma cor, um significado. */
enum class EstiloDoSelo {
    /** Roxo, com o raio: "é agora" (aceite direto, a vaga fecha com o primeiro que aceitar). */
    URGENCIA,

    /** Amarelo: "deu certo, é seu" ("Confirmado", "Você foi escolhida"). */
    CONFIRMADO,

    /** Tinta: em andamento ("A caminho", "Presença marcada"). */
    ANDAMENTO,

    /** Contorno: aguardando ou já passou ("Por seleção", "Aguardando resposta", "Concluído"). */
    CONTORNO,

    /** Tinta suave: fechou sem você ("Vaga fechou"). */
    ENCERRADO,
}

/**
 * Selo de status: retângulo de raio 8 e 28dp de altura, texto 600 em 15sp. NÃO é interativo: cápsula
 * é para o que se toca, canto pequeno é para o que informa. O selo com contorno tem a mesma altura
 * do preenchido (o fio conta dentro do padding).
 */
@Composable
fun SeloDeStatus(
    texto: String,
    estilo: EstiloDoSelo,
    modifier: Modifier = Modifier,
    icone: ImageVector? = when (estilo) {
        EstiloDoSelo.URGENCIA -> IconeRaio
        EstiloDoSelo.CONFIRMADO -> Icons.Default.Check
        else -> null
    },
) {
    val cores = FrilaTema.cores
    val forma = RoundedCornerShape(FrilaRaios.selo)
    val (fundo, corDoTexto) = when (estilo) {
        EstiloDoSelo.URGENCIA -> cores.destaqueRoxo to cores.sobreRoxo
        EstiloDoSelo.CONFIRMADO -> cores.destaqueAmarelo to cores.sobreAmarelo
        EstiloDoSelo.ANDAMENTO -> cores.tinta to cores.sobreTinta
        EstiloDoSelo.CONTORNO -> cores.fundo to cores.tinta
        EstiloDoSelo.ENCERRADO -> cores.tintaSuave to cores.sobreTinta
    }

    Row(
        modifier = modifier
            .heightIn(min = FrilaMetricas.alturaSelo)
            .background(fundo, forma)
            .then(if (estilo == EstiloDoSelo.CONTORNO) Modifier.border(1.dp, cores.borda, forma) else Modifier)
            .padding(horizontal = FrilaEspacamento.item, vertical = FrilaEspacamento.junto),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(FrilaEspacamento.junto),
    ) {
        if (icone != null) {
            Icon(imageVector = icone, contentDescription = null, tint = corDoTexto, modifier = Modifier.size(16.dp))
        }
        Text(text = texto, style = FrilaTipo.selo, color = corDoTexto)
    }
}

/** O raio do selo de urgência (o "bolt" do Material, que não vem no conjunto básico de ícones). */
internal val IconeRaio: ImageVector by lazy {
    materialIcon(name = "Frila.Raio") {
        materialPath {
            moveTo(11f, 21f)
            horizontalLineToRelative(-1f)
            lineToRelative(1f, -7f)
            horizontalLineTo(7.5f)
            curveToRelative(-0.88f, 0f, -0.33f, -0.75f, -0.31f, -0.78f)
            curveTo(8.48f, 10.94f, 10.42f, 7.54f, 13.01f, 3f)
            horizontalLineToRelative(1f)
            lineToRelative(-1f, 7f)
            horizontalLineToRelative(3.51f)
            curveToRelative(0.4f, 0f, 0.62f, 0.19f, 0.4f, 0.66f)
            curveTo(12.97f, 17.55f, 11f, 21f, 11f, 21f)
            close()
        }
    }
}
