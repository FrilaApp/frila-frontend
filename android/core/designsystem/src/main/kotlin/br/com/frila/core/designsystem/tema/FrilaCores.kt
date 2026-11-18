package br.com.frila.core.designsystem.tema

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Cores do Frila no desenho do Fabrício (redesign de 11/2026). Os valores claros são os do protótipo
 * (`tokens.css`); os escuros são a proposta dele para o modo escuro, ainda sem tela desenhada.
 * Mapeamento para o Material 3 em `docs/android/02-tokens-material3.md`.
 *
 * Uma cor, um significado: o laranja (`acao`) é só o botão que avança ou compromete; o amarelo é
 * "deu certo, é seu"; o roxo é "é agora"; a tinta é texto, seleção e andamento. Problema não tem cor.
 */
object FrilaCores {
    val fundoClaro = Color(0xFFF9F6F4)
    val fundoEscuro = Color(0xFF110F0E)

    /** Cartões, campos e botão secundário. */
    val superficieClaro = Color(0xFFFFFFFF)
    val superficieEscuro = Color(0xFF1D1B1A)

    val tintaClaro = Color(0xFF111111)
    val tintaEscuro = Color(0xFFF4F1EF)

    /** Texto de apoio e ações discretas. */
    val tintaSuaveClaro = Color(0xFF5A5A58)
    val tintaSuaveEscuro = Color(0xFFA5A5A2)

    /** Fio de cartões, divisórias e botão secundário. */
    val bordaClaro = Color(0xFFE5E3DD)
    val bordaEscuro = Color(0xFF2F2E29)

    /** Contorno de campo: é o único sinal de onde o campo está (3:1 contra o fundo). */
    val bordaControleClaro = Color(0xFF918F8A)
    val bordaControleEscuro = Color(0xFF767470)

    /** Fio de cima da barra de abas e do rodapé ancorado. */
    val bordaNavClaro = Color(0xFFEBE9E2)
    val bordaNavEscuro = Color(0xFF282622)

    /** Cartão, linha e botão secundário enquanto o dedo está neles. */
    val superficiePressionadaClaro = Color(0xFFEFECEA)
    val superficiePressionadaEscuro = Color(0xFF2A2826)

    /** Chip marcado enquanto o dedo está nele. O valor escuro não está no documento: é o mesmo passo, para baixo. */
    val tintaPressionadaClaro = Color(0xFF2D2D2D)
    val tintaPressionadaEscuro = Color(0xFFCFCCCA)

    /** Laranja de ação: só no botão primário e no ícone da aba ativa. Nunca em texto. Igual nos dois modos. */
    val acao = Color(0xFFF46700)
    val acaoPressionada = Color(0xFFDD5C00)

    /** Texto sobre cor fixa não inverte no escuro. */
    val sobreAcao = Color(0xFFFFFFFF)

    val destaqueAmarelo = Color(0xFFFCEB36)
    val sobreAmarelo = Color(0xFF111111)

    val destaqueRoxo = Color(0xFF9D47F5)
    val sobreRoxo = Color(0xFFFFFFFF)

    /** Preto puro do modo OLED (RNF10): só o fundo; os cartões seguem em `superficieEscuro`. */
    val fundoOled = Color(0xFF000000)
}

/** As cores do Frila já resolvidas para o modo em uso. Leia por `FrilaTema.cores`. */
@Immutable
data class PaletaFrila(
    val fundo: Color,
    val superficie: Color,
    val tinta: Color,
    val tintaSuave: Color,
    val borda: Color,
    val bordaControle: Color,
    val bordaNav: Color,
    val superficiePressionada: Color,
    val tintaPressionada: Color,
    /** Texto sobre preenchimento em tinta (chip marcado, selo de andamento). */
    val sobreTinta: Color,
    val acao: Color = FrilaCores.acao,
    val acaoPressionada: Color = FrilaCores.acaoPressionada,
    val sobreAcao: Color = FrilaCores.sobreAcao,
    val destaqueAmarelo: Color = FrilaCores.destaqueAmarelo,
    val sobreAmarelo: Color = FrilaCores.sobreAmarelo,
    val destaqueRoxo: Color = FrilaCores.destaqueRoxo,
    val sobreRoxo: Color = FrilaCores.sobreRoxo,
)

val PaletaClara = PaletaFrila(
    fundo = FrilaCores.fundoClaro,
    superficie = FrilaCores.superficieClaro,
    tinta = FrilaCores.tintaClaro,
    tintaSuave = FrilaCores.tintaSuaveClaro,
    borda = FrilaCores.bordaClaro,
    bordaControle = FrilaCores.bordaControleClaro,
    bordaNav = FrilaCores.bordaNavClaro,
    superficiePressionada = FrilaCores.superficiePressionadaClaro,
    tintaPressionada = FrilaCores.tintaPressionadaClaro,
    sobreTinta = FrilaCores.superficieClaro,
)

/** No escuro o chip marcado inverte junto: preenchimento em tinta clara e texto no fundo escuro. */
val PaletaEscura = PaletaFrila(
    fundo = FrilaCores.fundoEscuro,
    superficie = FrilaCores.superficieEscuro,
    tinta = FrilaCores.tintaEscuro,
    tintaSuave = FrilaCores.tintaSuaveEscuro,
    borda = FrilaCores.bordaEscuro,
    bordaControle = FrilaCores.bordaControleEscuro,
    bordaNav = FrilaCores.bordaNavEscuro,
    superficiePressionada = FrilaCores.superficiePressionadaEscuro,
    tintaPressionada = FrilaCores.tintaPressionadaEscuro,
    sobreTinta = FrilaCores.fundoEscuro,
)

val PaletaEscuraOled = PaletaEscura.copy(fundo = FrilaCores.fundoOled)

internal val LocalPaletaFrila = staticCompositionLocalOf { PaletaClara }

/** Porta de leitura do tema do Frila dentro de um `FrilaTheme`. */
object FrilaTema {
    val cores: PaletaFrila
        @Composable
        @ReadOnlyComposable
        get() = LocalPaletaFrila.current
}
