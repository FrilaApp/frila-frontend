package br.com.frila.core.designsystem.tema

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import br.com.frila.core.designsystem.R

/**
 * Papéis de texto do desenho do Fabrício (tabela de Tipografia do protótipo), com os mesmos nomes do
 * iOS. Poucos pesos: a hierarquia vem da cor (tinta × tinta suave). Tudo em `sp`, então acompanha o
 * tamanho de fonte do sistema.
 */
object FrilaTipo {
    /**
     * Prodigy Sans 700 (OFL 1.1, licença em `res/raw`): só no título de tela e no dinheiro principal.
     * Fica aqui dentro, e antes dos estilos, para não haver ciclo de inicialização com `FrilaTypography`.
     */
    val prodigySans = FontFamily(Font(R.font.prodigy_sans_bold, FontWeight.Bold))

    private fun prodigy(tamanho: Int, linha: Int) = TextStyle(
        fontFamily = prodigySans,
        fontWeight = FontWeight.Bold,
        fontSize = tamanho.sp,
        lineHeight = linha.sp,
    )

    private fun sistema(tamanho: Int, linha: Int, peso: FontWeight = FontWeight.Normal) = TextStyle(
        fontWeight = peso,
        fontSize = tamanho.sp,
        lineHeight = linha.sp,
    )

    /** Valor em dinheiro do cartão: o maior texto do cartão. */
    val valorEmDestaque = prodigy(28, 32)

    /** Título de tela. */
    val tituloDaTela = prodigy(24, 28)

    /** Valor ao lado do botão, no rodapé do detalhe da vaga. */
    val valorDoRodape = prodigy(20, 24)

    /** Rótulo do botão primário: o único rótulo pesado, porque branco sobre o laranja só passa assim. */
    val rotuloDoPrimario = sistema(20, 24, FontWeight.Bold)

    /** Frase do modo ("Se aceitar, o turno é seu."). */
    val fraseDoModo = sistema(20, 24, FontWeight.SemiBold)

    /** Nome de casa ou de pessoa em cartão e linha. */
    val nome = sistema(17, 22, FontWeight.SemiBold)

    /** Corpo e dados. */
    val corpo = sistema(16, 22)

    /** Valor escrito ("Até 5 km", data e horário) e rótulo do botão secundário. */
    val rotuloSecundario = sistema(16, 22, FontWeight.SemiBold)

    /** Apoio, em tinta suave. */
    val apoio = sistema(15, 20)

    /** Nome de grupo ou seção, em tinta suave. */
    val rotuloDeGrupo = sistema(15, 20, FontWeight.SemiBold)

    val chip = sistema(15, 20, FontWeight.Medium)

    val selo = sistema(15, 20, FontWeight.SemiBold)

    val legenda = sistema(13, 16)
}

/**
 * Os papéis do Frila nas posições do Material 3, para `MaterialTheme.typography` e os componentes do
 * Material (título de barra, diálogo, campo, botão) já saírem no desenho. Código novo usa [FrilaTipo].
 */
val FrilaTypography = Typography(
    displayLarge = FrilaTipo.valorEmDestaque,
    displayMedium = FrilaTipo.valorEmDestaque,
    displaySmall = FrilaTipo.valorEmDestaque,
    headlineLarge = FrilaTipo.tituloDaTela,
    headlineMedium = FrilaTipo.tituloDaTela,
    headlineSmall = FrilaTipo.tituloDaTela,
    titleLarge = FrilaTipo.tituloDaTela,
    titleMedium = FrilaTipo.nome,
    titleSmall = FrilaTipo.rotuloSecundario,
    bodyLarge = FrilaTipo.corpo,
    bodyMedium = FrilaTipo.apoio,
    bodySmall = FrilaTipo.legenda,
    labelLarge = FrilaTipo.rotuloSecundario,
    labelMedium = FrilaTipo.selo,
    labelSmall = FrilaTipo.legenda.copy(fontWeight = FontWeight.Medium),
)
