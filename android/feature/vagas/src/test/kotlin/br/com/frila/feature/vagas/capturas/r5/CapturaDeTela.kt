package br.com.frila.feature.vagas.capturas.r5

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.test.isRoot
import androidx.compose.ui.test.onRoot
import java.io.File

/**
 * Captura de tela dos testes (prints dos PRs do redesign), sem dependência nova: o Robolectric desenha a
 * árvore do Compose num `Bitmap` com os gráficos nativos (`@GraphicsMode(NATIVE)` na classe de teste).
 *
 * Só grava quando a variável de ambiente `FRILA_CAPTURAS_DIR` existe; sem ela (na CI, por exemplo) o
 * teste só confere que a tela desenha. Devolve o arquivo gravado, ou `null` quando não gravou.
 */
fun ComposeContentTestRule.capturar(nome: String): File? = capturarJanela(nome, janela = null)

/**
 * Como [capturar], mas de uma janela específica: folha e diálogo abrem outra janela, e então há mais de uma
 * raiz. `janela = 1` é a primeira janela por cima da tela (a folha).
 */
fun ComposeContentTestRule.capturarJanela(nome: String, janela: Int?): File? {
    waitForIdle()
    val raiz = if (janela == null) onRoot().fetchSemanticsNode() else onAllNodes(isRoot()).fetchSemanticsNodes()[janela]
    val vista = (raiz.root as ViewRootForTest).view
    val imagem = Bitmap.createBitmap(vista.width, vista.height, Bitmap.Config.ARGB_8888)
    vista.draw(Canvas(imagem))

    val pasta = System.getenv("FRILA_CAPTURAS_DIR")?.takeIf { it.isNotBlank() } ?: return null
    val arquivo = File(pasta, "$nome.png")
    arquivo.parentFile?.mkdirs()
    arquivo.outputStream().use { imagem.compress(Bitmap.CompressFormat.PNG, 100, it) }
    return arquivo
}
