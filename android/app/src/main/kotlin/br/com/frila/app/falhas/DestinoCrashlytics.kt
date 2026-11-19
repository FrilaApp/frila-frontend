package br.com.frila.app.falhas

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.crashlytics.CustomKeysAndValues

/** Exceção sem pilha: o agrupamento no painel é pelo texto `erro_api_<codigo>` e não carrega nome de classe nem linha do app. */
private class ErroDaApiRegistrado(codigo: String) : RuntimeException("erro_api_$codigo") {
    init {
        stackTrace = emptyArray()
    }
}

/** O que vai ao Crashlytics: uma exceção sem pilha e só as três chaves abaixo (a totalidade dos metadados do evento). */
class RegistroDeFalha(val excecao: Throwable, val chaves: Map<String, Any>) {
    companion object {
        fun montar(codigo: String, rpc: String, duracaoNs: Long): RegistroDeFalha =
            RegistroDeFalha(
                excecao = ErroDaApiRegistrado(codigo),
                chaves = mapOf("codigo" to codigo, "rpc" to rpc, "duracao_ns" to duracaoNs),
            )
    }
}

/**
 * O destino real: o Crashlytics. Só é usado com a coleta ligada no manifesto (ver [TelemetriaDeFalhas]).
 * Nunca usa `setUserId`, logs nem outras chaves: sem e-mail, nome, telefone ou qualquer identificador de pessoa (como o iOS).
 */
class DestinoCrashlytics : DestinoDeFalhas {
    override fun gravar(codigo: String, rpc: String, duracaoNs: Long) {
        val registro = RegistroDeFalha.montar(codigo, rpc, duracaoNs)
        val chaves = CustomKeysAndValues.Builder()
            .putString("codigo", codigo)
            .putString("rpc", rpc)
            .putLong("duracao_ns", duracaoNs)
            .build()
        FirebaseCrashlytics.getInstance().recordException(registro.excecao, chaves)
    }
}

/** O Firebase de verdade: só existe com o `google-services.json` no build (sem ele, como na CI, o app roda sem Firebase). */
class FalhasDoFirebaseReal(private val contexto: Context) : FalhasDoFirebase {
    override val configurado: Boolean get() = FirebaseApp.getApps(contexto).isNotEmpty()

    override fun apagarRelatoriosPendentes() {
        if (!configurado) return
        FirebaseCrashlytics.getInstance().deleteUnsentReports()
    }

    override fun definirColetaAtiva(ativa: Boolean) {
        if (!configurado) return
        FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(ativa)
    }
}
