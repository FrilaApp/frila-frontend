package br.com.frila.app

import android.app.Activity
import android.os.Build

/**
 * Cortina do seletor de apps (iOS `.cortinaDePrivacidade`): no Android 13+ o sistema deixa de guardar a miniatura da tela
 * na lista de apps recentes. O app tem contrato, valor de vaga e dado de pessoa na tela, e a miniatura ficaria à vista de quem
 * pegasse o aparelho.
 *
 * Abaixo do Android 13 **nada é feito**, de propósito: a única saída seria `FLAG_SECURE`, que também bloqueia a captura de
 * tela e a gravação, e isso é decisão de produto, não de segurança do seletor.
 */
internal fun esconderMiniaturaNosRecentes(activity: Activity, sdk: Int = Build.VERSION.SDK_INT) {
    if (sdk >= Build.VERSION_CODES.TIRAMISU) activity.setRecentsScreenshotEnabled(false)
}
