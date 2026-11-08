package br.com.frila.core.designsystem.mascara

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation

/**
 * VisualTransformation para números telefônicos brasileiros.
 * Formata progressivamente:
 * - Fixo (10 dígitos): (XX) XXXX-XXXX
 * - Celular (11 dígitos): (XX) XXXXX-XXXX
 *
 * Preserva o texto puro (somente dígitos) no StateFlow / TextFieldValue.
 */
class TelefoneVisualTransformation : VisualTransformation {

    override fun filter(text: AnnotatedString): TransformedText {
        val digitos = text.text.filter { it.isDigit() }.take(11)
        val ehCelular = digitos.length > 10
        val separadorHifen = if (ehCelular) 7 else 6

        val out = buildString {
            if (digitos.isNotEmpty()) append('(')
            for (i in digitos.indices) {
                append(digitos[i])
                if (i == 1 && digitos.length > 2) {
                    append(") ")
                } else if (i == separadorHifen - 1 && i != digitos.lastIndex) {
                    append('-')
                }
            }
        }

        val offsetMapping = object : OffsetMapping {
            override fun originalToTransformed(offset: Int): Int {
                val clamped = offset.coerceIn(0, digitos.length)
                if (digitos.isEmpty()) return 0
                return when {
                    clamped <= 0 -> 1 // após '('
                    clamped <= 2 -> (clamped + 1).coerceAtMost(out.length)
                    clamped <= separadorHifen -> (clamped + 3).coerceAtMost(out.length)
                    else -> (clamped + 4).coerceAtMost(out.length)
                }
            }

            override fun transformedToOriginal(offset: Int): Int {
                if (digitos.isEmpty() || out.isEmpty()) return 0
                val clamped = offset.coerceIn(0, out.length)
                return when {
                    clamped <= 1 -> 0
                    clamped <= 3 -> (clamped - 1).coerceIn(0, 2)
                    clamped <= 5 -> 2
                    clamped <= separadorHifen + 3 -> (clamped - 3).coerceIn(2, separadorHifen)
                    clamped <= separadorHifen + 4 -> separadorHifen
                    else -> (clamped - 4).coerceIn(separadorHifen, digitos.length)
                }.coerceIn(0, digitos.length)
            }
        }

        return TransformedText(AnnotatedString(out), offsetMapping)
    }
}
