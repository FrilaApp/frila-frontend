package br.com.frila.core.designsystem.mascara

import androidx.compose.ui.text.AnnotatedString
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class MascaraVisualTransformationTest {

    private val cpfTransformation = CpfVisualTransformation()
    private val telefoneTransformation = TelefoneVisualTransformation()

    @Test
    fun `CpfVisualTransformation formata 11 digitos corretamente`() {
        val transformed = cpfTransformation.filter(AnnotatedString("12345678901"))
        assertEquals("123.456.789-01", transformed.text.text)
    }

    @Test
    fun `CpfVisualTransformation mapeia offsets progressivamente sem estourar limites`() {
        val raw = "12345678901"
        val transformed = cpfTransformation.filter(AnnotatedString(raw))
        val mapper = transformed.offsetMapping

        // Início
        assertEquals(0, mapper.originalToTransformed(0))
        assertEquals(0, mapper.transformedToOriginal(0))

        // Primeiro bloco (123.)
        assertEquals(3, mapper.originalToTransformed(3))
        // Posição final
        assertEquals(14, mapper.originalToTransformed(11))
        assertEquals(11, mapper.transformedToOriginal(14))

        // Valores fora do limite são limitados com segurança (clamp)
        assertEquals(14, mapper.originalToTransformed(20))
        assertEquals(11, mapper.transformedToOriginal(20))
    }

    @Test
    fun `TelefoneVisualTransformation formata celular de 11 digitos corretamente`() {
        val transformed = telefoneTransformation.filter(AnnotatedString("11987654321"))
        assertEquals("(11) 98765-4321", transformed.text.text)
    }

    @Test
    fun `TelefoneVisualTransformation formata telefone fixo de 10 digitos corretamente`() {
        val transformed = telefoneTransformation.filter(AnnotatedString("1134567890"))
        assertEquals("(11) 3456-7890", transformed.text.text)
    }

    @Test
    fun `TelefoneVisualTransformation mapeia offsets sem corromper posicao do cursor`() {
        val raw = "11987654321"
        val transformed = telefoneTransformation.filter(AnnotatedString(raw))
        val mapper = transformed.offsetMapping

        assertEquals(1, mapper.originalToTransformed(0)) // após '('
        assertEquals(15, mapper.originalToTransformed(11))
        assertEquals(11, mapper.transformedToOriginal(15))
    }
}
