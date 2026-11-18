package br.com.frila.feature.suporte.capturas

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.test.isRoot
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import java.io.File

/**
 * Captura de tela dos testes (prints dos PRs do redesign), sem dependência nova: o Robolectric desenha a
 * árvore do Compose num `Bitmap` com os gráficos nativos (`@GraphicsMode(NATIVE)` na classe de teste).
 *
 * Só grava quando a variável de ambiente `FRILA_CAPTURAS_DIR` existe; sem ela (na CI, por exemplo) o
 * teste só confere que a tela desenha. Devolve o arquivo gravado, ou `null` quando não gravou.
 *
 * Diferença da cópia do design system: com um diálogo aberto há duas raízes (a tela e a janela do diálogo). A primeira
 * é a tela; as outras são desenhadas por cima, centralizadas, sobre um véu escuro, como o sistema mostra.
 */
fun ComposeContentTestRule.capturar(nome: String): File? {
    waitForIdle()
    val vistas = onAllNodes(isRoot()).fetchSemanticsNodes().map { (it.root as ViewRootForTest).view }
    val tela = vistas.first()
    val imagem = Bitmap.createBitmap(tela.width, tela.height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(imagem)
    tela.draw(canvas)
    vistas.drop(1).forEach { janela ->
        canvas.drawColor(Color.argb(110, 0, 0, 0))
        canvas.save()
        canvas.translate((tela.width - janela.width) / 2f, (tela.height - janela.height) / 2f)
        janela.draw(canvas)
        canvas.restore()
    }

    val pasta = System.getenv("FRILA_CAPTURAS_DIR")?.takeIf { it.isNotBlank() } ?: return null
    val arquivo = File(pasta, "$nome.png")
    arquivo.parentFile?.mkdirs()
    arquivo.outputStream().use { imagem.compress(Bitmap.CompressFormat.PNG, 100, it) }
    return arquivo
}
