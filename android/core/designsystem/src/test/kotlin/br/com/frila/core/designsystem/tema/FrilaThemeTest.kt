package br.com.frila.core.designsystem.tema

import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Test

class FrilaThemeTest {

    @Test
    fun `EsquemaClaro aplica exatamente os tokens claros`() {
        assertEquals(FrilaCores.tintaClaro, EsquemaClaro.primary)
        assertEquals(FrilaCores.superficieClaro, EsquemaClaro.onPrimary)
        assertEquals(FrilaCores.fundoClaro, EsquemaClaro.background)
        assertEquals(FrilaCores.tintaClaro, EsquemaClaro.onBackground)
        assertEquals(FrilaCores.superficieClaro, EsquemaClaro.surface)
        assertEquals(FrilaCores.tintaClaro, EsquemaClaro.onSurface)
        assertEquals(FrilaCores.superficieClaro, EsquemaClaro.surfaceVariant)
        assertEquals(FrilaCores.tintaSuaveClaro, EsquemaClaro.onSurfaceVariant)
        assertEquals(FrilaCores.bordaControleClaro, EsquemaClaro.outline)
        assertEquals(FrilaCores.bordaClaro, EsquemaClaro.outlineVariant)
    }

    @Test
    fun `EsquemaEscuro aplica exatamente os tokens escuros`() {
        assertEquals(FrilaCores.tintaEscuro, EsquemaEscuro.primary)
        assertEquals(FrilaCores.fundoEscuro, EsquemaEscuro.onPrimary)
        assertEquals(FrilaCores.fundoEscuro, EsquemaEscuro.background)
        assertEquals(FrilaCores.tintaEscuro, EsquemaEscuro.onBackground)
        assertEquals(FrilaCores.superficieEscuro, EsquemaEscuro.surface)
        assertEquals(FrilaCores.tintaEscuro, EsquemaEscuro.onSurface)
        assertEquals(FrilaCores.superficieEscuro, EsquemaEscuro.surfaceVariant)
        assertEquals(FrilaCores.tintaSuaveEscuro, EsquemaEscuro.onSurfaceVariant)
        assertEquals(FrilaCores.bordaControleEscuro, EsquemaEscuro.outline)
        assertEquals(FrilaCores.bordaEscuro, EsquemaEscuro.outlineVariant)
    }

    @Test
    fun `o laranja nunca e primary, secondary nem tertiary - selecao e foco do Material ficam em tinta`() {
        listOf(EsquemaClaro, EsquemaEscuro, EsquemaEscuroOled).forEach { esquema ->
            assertNotEquals(FrilaCores.acao, esquema.primary)
            assertNotEquals(FrilaCores.acao, esquema.secondary)
            assertNotEquals(FrilaCores.acao, esquema.tertiary)
            assertNotEquals(FrilaCores.acao, esquema.surface)
        }
    }

    @Test
    fun `problema nao tem cor - error e a tinta nos dois modos`() {
        assertEquals(EsquemaClaro.onBackground, EsquemaClaro.error)
        assertEquals(EsquemaEscuro.onBackground, EsquemaEscuro.error)
    }

    @Test
    fun `chip marcado do Material sai em tinta com texto claro`() {
        assertEquals(FrilaCores.tintaClaro, EsquemaClaro.secondaryContainer)
        assertEquals(FrilaCores.superficieClaro, EsquemaClaro.onSecondaryContainer)
        assertEquals(FrilaCores.tintaEscuro, EsquemaEscuro.secondaryContainer)
        assertEquals(FrilaCores.fundoEscuro, EsquemaEscuro.onSecondaryContainer)
    }

    @Test
    fun `superficies de conteiner do Material nao ficam com o lilas padrao`() {
        val padrao = lightColorScheme()

        assertEquals(FrilaCores.superficieClaro, EsquemaClaro.surfaceContainer)
        assertEquals(FrilaCores.superficieClaro, EsquemaClaro.surfaceContainerHigh)
        assertEquals(FrilaCores.superficieClaro, EsquemaClaro.surfaceContainerLow)
        assertEquals(FrilaCores.superficiePressionadaClaro, EsquemaClaro.surfaceContainerHighest)
        assertNotEquals(padrao.surfaceContainerHigh, EsquemaClaro.surfaceContainerHigh)
        assertEquals(Color.Transparent, EsquemaClaro.surfaceTint)
    }

    @Test
    fun `EsquemaEscuroOled troca so o background para preto puro (RNF10)`() {
        assertEquals(FrilaCores.fundoOled, EsquemaEscuroOled.background)
        // surface/surfaceVariant continuam em superficieEscuro: é o que separa os cartões do preto
        // puro, não é o mesmo tom do fundo.
        assertEquals(FrilaCores.superficieEscuro, EsquemaEscuroOled.surface)
        assertEquals(FrilaCores.superficieEscuro, EsquemaEscuroOled.surfaceVariant)
        assertNotEquals(EsquemaEscuroOled.background, EsquemaEscuroOled.surface)
    }

    @Test
    fun `EsquemaEscuroOled preserva todos os outros tokens de EsquemaEscuro`() {
        assertEquals(EsquemaEscuro.primary, EsquemaEscuroOled.primary)
        assertEquals(EsquemaEscuro.onPrimary, EsquemaEscuroOled.onPrimary)
        assertEquals(EsquemaEscuro.onBackground, EsquemaEscuroOled.onBackground)
        assertEquals(EsquemaEscuro.onSurface, EsquemaEscuroOled.onSurface)
        assertEquals(EsquemaEscuro.onSurfaceVariant, EsquemaEscuroOled.onSurfaceVariant)
        assertEquals(EsquemaEscuro.error, EsquemaEscuroOled.error)
        assertEquals(EsquemaEscuro.outline, EsquemaEscuroOled.outline)
        assertEquals(EsquemaEscuro.outlineVariant, EsquemaEscuroOled.outlineVariant)
        assertEquals(EsquemaEscuro.tertiary, EsquemaEscuroOled.tertiary)
    }

    @Test
    fun `cores dinamicas preservam a tinta e a regra do erro nos dois temas`() {
        val secondaryDinamico = Color(0xFF123456)
        val esquemaDinamico = lightColorScheme(
            primary = Color.Magenta,
            onPrimary = Color.Yellow,
            error = Color.Cyan,
            secondary = secondaryDinamico,
        )

        val claro = esquemaDinamico.comCoresCriticasFrila(temaEscuro = false)
        val escuro = esquemaDinamico.comCoresCriticasFrila(temaEscuro = true)

        assertEquals(FrilaCores.tintaClaro, claro.primary)
        assertEquals(FrilaCores.superficieClaro, claro.onPrimary)
        assertEquals(FrilaCores.tintaClaro, claro.error)
        assertEquals(secondaryDinamico, claro.secondary)
        assertEquals(FrilaCores.tintaEscuro, escuro.primary)
        assertEquals(FrilaCores.fundoEscuro, escuro.onPrimary)
        assertEquals(FrilaCores.tintaEscuro, escuro.error)
        assertEquals(secondaryDinamico, escuro.secondary)
    }
}
