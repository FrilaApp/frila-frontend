package br.com.frila.core.designsystem.tema

import androidx.compose.ui.graphics.Color

/**
 * Cores do Design System do Frila, convertidas 1 a 1 do catálogo de cores do iOS (cada
 * `Contents.json` de cor em `iOS/Resources/DesignSystem.xcassets`, MEDIDO: componentes sRGB
 * convertidos para hex) — ver mapeamento normativo em `docs/android/02-tokens-material3.md`.
 *
 * Terracota da marca (`brandAccentLight` = #EA5A36) é só acento: ícone, marca, destaque
 * pontual — nunca fundo de tela ou de cartão (mesma regra do iOS).
 */
object FrilaCores {
    // BrandPrimary: seleção ativa e botão principal — quase preto no claro, quase branco no escuro.
    val brandPrimaryLight = Color(0xFF111110)
    val brandPrimaryDark = Color(0xFFF5F4F0)

    // BrandOnPrimary: texto/ícone sobre BrandPrimary.
    val brandOnPrimaryLight = Color(0xFFFFFFFF)
    val brandOnPrimaryDark = Color(0xFF111110)

    // Surface: fundo agrupado das telas.
    val surfaceLight = Color(0xFFF2F2F0)
    val surfaceDark = Color(0xFF0B0B0A)

    // SurfaceElevated: cartões, campos e linhas sobre o fundo agrupado.
    val surfaceElevatedLight = Color(0xFFFFFFFF)
    val surfaceElevatedDark = Color(0xFF1C1C1A)

    // SurfaceOled: preto puro para o modo OLED (RNF10) — só o fundo (`background`); cartões
    // continuam em surfaceElevatedDark para manter elevação visual sobre o preto puro.
    val surfaceOled = Color(0xFF000000)

    val textPrimaryLight = Color(0xFF111110)
    val textPrimaryDark = Color(0xFFF5F4F0)

    val textSecondaryLight = Color(0xFF5C5B57)
    val textSecondaryDark = Color(0xFFA3A29C)

    // BrandAccent: terracota da marca (#EA5A36 no claro).
    val brandAccentLight = Color(0xFFEA5A36)
    val brandAccentDark = Color(0xFFF26643)

    val successLight = Color(0xFF007A33)
    val successDark = Color(0xFF4ADE80)

    val warningLight = Color(0xFF9E5C00)
    val warningDark = Color(0xFFFBBF24)

    val dangerLight = Color(0xFFD70015)
    val dangerDark = Color(0xFFFF6961)

    // Hairline: fio de 1dp de cartões e divisórias (preto 8% no claro, branco 10% no escuro).
    val hairlineLight = Color(0x14000000)
    val hairlineDark = Color(0x1AFFFFFF)

    // ControlBorder: contorno de chip inativo, botão outline e campo.
    val controlBorderLight = Color(0x24000000)
    val controlBorderDark = Color(0x33FFFFFF)
}
