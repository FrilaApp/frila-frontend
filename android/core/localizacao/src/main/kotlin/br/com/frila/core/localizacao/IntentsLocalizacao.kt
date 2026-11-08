package br.com.frila.core.localizacao

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings

/**
 * Intents para os dois diálogos defensivos de check-in (RN06/RN22): permissão de localização
 * negada e GPS do sistema desligado. Só constrói o [Intent] — quem dispara (`context.startActivity`)
 * deve usar [abrirConfiguracoesComFallback], que trata `ActivityNotFoundException` defensivamente
 * (aparelhos customizados que removem a tela de configurações do sistema).
 */

/** Tela de permissões do app nas configurações do sistema (botão "Abrir configurações"). */
fun criarIntentConfiguracoesApp(contexto: Context): Intent =
    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
        data = Uri.fromParts("package", contexto.packageName, null)
    }

/** Tela de fontes de localização do sistema (botão "Ativar GPS"). */
fun criarIntentConfiguracoesGps(): Intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)

/**
 * Dispara [intent] com `startActivity`, devolvendo `false` sem lançar quando o aparelho não tem
 * nenhuma activity capaz de tratar a tela de configurações pedida.
 */
fun abrirConfiguracoesComFallback(contexto: Context, intent: Intent): Boolean = try {
    contexto.startActivity(intent)
    true
} catch (_: ActivityNotFoundException) {
    false
}
