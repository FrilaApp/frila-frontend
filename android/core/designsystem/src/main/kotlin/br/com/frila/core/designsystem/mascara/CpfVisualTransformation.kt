package br.com.frila.core.designsystem.mascara

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation

/**
 * VisualTransformation para formatação visual de CPF (000.000.000-00).
 * Mantém a entrada de texto bruta (somente dígitos) intocada e mapeia as posições
 * do cursor bidirecionalmente sem saltos ou colisões.
 */
class CpfVisualTransformation : VisualTransformation {

    override fun filter(text: AnnotatedString): TransformedText {
        val digitos = text.text.filter { it.isDigit() }.take(11)

        val out = buildString {
            for (i in digitos.indices) {
                append(digitos[i])
                if ((i == 2 || i == 5) && i != digitos.lastIndex) {
                    append('.')
                } else if (i == 8 && i != digitos.lastIndex) {
                    append('-')
                }
            }
        }

        val offsetMapping = object : OffsetMapping {
            override fun originalToTransformed(offset: Int): Int {
                val clamped = offset.coerceIn(0, digitos.length)
                return when {
                    clamped <= 3 -> clamped
                    clamped <= 6 -> (clamped + 1).coerceAtMost(out.length)
                    clamped <= 9 -> (clamped + 2).coerceAtMost(out.length)
                    else -> (clamped + 3).coerceAtMost(out.length)
                }
            }

            override fun transformedToOriginal(offset: Int): Int {
                val clamped = offset.coerceIn(0, out.length)
                return when {
                    clamped <= 3 -> clamped
                    clamped <= 7 -> (clamped - 1).coerceAtLeast(3)
                    clamped <= 11 -> (clamped - 2).coerceAtLeast(6)
                    else -> (clamped - 3).coerceAtLeast(9)
                }.coerceIn(0, digitos.length)
            }
        }

        return TransformedText(AnnotatedString(out), offsetMapping)
    }
}
