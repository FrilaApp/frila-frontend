package br.com.frila.feature.chamadas.capturas.r6

import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.test.onRoot
import java.io.File

/**
 * Captura de tela dos testes (prints dos PRs do redesign), sem dependência nova: o Robolectric desenha a
 * árvore do Compose num `Bitmap` com os gráficos nativos (`@GraphicsMode(NATIVE)` na classe de teste).
 *
 * Só grava quando a variável de ambiente `FRILA_CAPTURAS_DIR` existe; sem ela (na CI, por exemplo) o
 * teste só confere que a tela desenha. Devolve o arquivo gravado, ou `null` quando não gravou.
 */
fun ComposeContentTestRule.capturar(nome: String): File? {
    waitForIdle()
    val vista = (onRoot().fetchSemanticsNode().root as ViewRootForTest).view
    val imagem = Bitmap.createBitmap(vista.width, vista.height, Bitmap.Config.ARGB_8888)
    vista.draw(Canvas(imagem))

    val pasta = System.getenv("FRILA_CAPTURAS_DIR")?.takeIf { it.isNotBlank() } ?: return null
    val arquivo = File(pasta, "$nome.png")
    arquivo.parentFile?.mkdirs()
    arquivo.outputStream().use { imagem.compress(Bitmap.CompressFormat.PNG, 100, it) }
    return arquivo
}

/**
 * Como [capturar], mas de uma janela que não é a principal (a folha modal e o diálogo vivem em janela própria, e
 * `onRoot()` reclama de mais de uma raiz). `indice` conta as raízes na ordem em que o Compose as devolve; a última é
 * a janela mais ao alto.
 */
fun ComposeContentTestRule.capturarJanela(nome: String, indice: Int = -1): File? {
    waitForIdle()
    val raizes = onAllNodes(androidx.compose.ui.test.isRoot()).fetchSemanticsNodes()
    val raiz = if (indice < 0) raizes[raizes.size + indice] else raizes[indice]
    val vista = (raiz.root as ViewRootForTest).view
    val imagem = Bitmap.createBitmap(vista.width, vista.height, Bitmap.Config.ARGB_8888)
    vista.draw(Canvas(imagem))

    val pasta = System.getenv("FRILA_CAPTURAS_DIR")?.takeIf { it.isNotBlank() } ?: return null
    val arquivo = File(pasta, "$nome.png")
    arquivo.parentFile?.mkdirs()
    arquivo.outputStream().use { imagem.compress(Bitmap.CompressFormat.PNG, 100, it) }
    return arquivo
}
