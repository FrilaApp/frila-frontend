package br.com.frila.app.falhas

import android.content.Context
import android.content.pm.PackageManager

/** O que o app precisa do Firebase para limpar os relatórios de falha. Separado do SDK para o teste não depender dele. */
interface FalhasDoFirebase {
    /** Se o `FirebaseApp` foi criado neste processo (só com o `google-services.json` no build). */
    val configurado: Boolean

    fun apagarRelatoriosPendentes()

    /** Sincroniza o estado da coleta de falhas no SDK do Crashlytics. */
    fun definirColetaAtiva(ativa: Boolean) {}
}

/** A chave do manifesto que liga ou desliga a coleta do Crashlytics (o SDK lê a mesma). */
object ColetaDeFalhas {
    const val CHAVE_NO_MANIFESTO = "firebase_crashlytics_collection_enabled"

    /** Só `true` liga. Sem a chave, valor de outro tipo ou nulo: desligada (C1, 08/11/2026: falta base legal para dados de falha irem ao Google nos EUA). */
    fun ligada(valorDoManifesto: Any?): Boolean = valorDoManifesto == true

    fun ligadaNoManifesto(contexto: Context): Boolean =
        try {
            val info = contexto.packageManager.getApplicationInfo(contexto.packageName, PackageManager.GET_META_DATA)
            ligada(info.metaData?.get(CHAVE_NO_MANIFESTO))
        } catch (_: Exception) {
            false
        }
}

object RelatorioDeFalhas {
    /**
     * Com a coleta desligada o SDK guarda no aparelho os relatórios de falha para enviar depois. Como nada será enviado, eles saem na
     * abertura (igual ao iOS). Sem Firebase configurado não há o que apagar. Devolve se apagou.
     */
    fun iniciarSeConfigurado(coletaLigada: Boolean, firebase: FalhasDoFirebase): Boolean {
        if (!firebase.configurado) return false
        firebase.definirColetaAtiva(coletaLigada)
        if (coletaLigada) return false
        firebase.apagarRelatoriosPendentes()
        return true
    }
}
