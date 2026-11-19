package br.com.frila.app

import android.util.Log
import com.google.firebase.messaging.FirebaseMessaging
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * O token do FCM deste aparelho, ou `null` se não saiu (sem Play Services, sem rede, Firebase sem configuração). Sem o
 * `google-services.json` (CI e build local sem o arquivo) o Firebase não inicia e `getInstance()` lança: quem chama
 * ([br.com.frila.core.notificacoes.RegistradorDeDispositivo]) trata o erro como "sem token" e nada sai.
 */
suspend fun lerTokenDoFcm(): String? = suspendCancellableCoroutine { continuacao ->
    FirebaseMessaging.getInstance().token.addOnCompleteListener { tarefa ->
        val token = if (tarefa.isSuccessful) tarefa.result else null
        if (BuildConfig.DEBUG && token != null) {
            Log.d("FrilaFcmToken", "token=$token")
        }
        if (continuacao.isActive) continuacao.resume(token)
    }
}
