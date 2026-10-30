package br.com.frila.app.seguranca

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import br.com.frila.app.BuildConfig
import br.com.frila.core.seguranca.LeitorDeAmbiente
import java.io.File
import java.security.MessageDigest

/**
 * Implementação real de [LeitorDeAmbiente] (RN15, cartão Cdv0sS5w) sobre `Build.*`,
 * `File.exists()` e `PackageManager` — único ponto do app que toca essas APIs para a verificação
 * de integridade. `minSdk` já é 28 (`Build.VERSION_CODES.P`), então sempre usa
 * `GET_SIGNING_CERTIFICATES`, sem precisar do caminho legado de `GET_SIGNATURES`.
 */
class LeitorDeAmbienteAndroid(private val contexto: Context) : LeitorDeAmbiente {

    override fun arquivoExiste(caminho: String): Boolean = try {
        File(caminho).exists()
    } catch (_: Exception) {
        false
    }

    override fun buildTags(): String = Build.TAGS ?: ""

    override fun buildFingerprint(): String = Build.FINGERPRINT ?: ""

    override fun buildHardware(): String = Build.HARDWARE ?: ""

    override fun buildProduct(): String = Build.PRODUCT ?: ""

    override fun assinaturasDoPacote(): List<String> = try {
        val gerenciadorDePacotes = contexto.packageManager
        val info = gerenciadorDePacotes.getPackageInfo(
            contexto.packageName,
            PackageManager.GET_SIGNING_CERTIFICATES,
        )
        val assinaturas = info.signingInfo?.let { signingInfo ->
            if (signingInfo.hasMultipleSigners()) {
                signingInfo.apkContentsSigners
            } else {
                signingInfo.signingCertificateHistory
            }
        }.orEmpty()
        assinaturas.map { sha256Hex(it.toByteArray()) }
    } catch (_: Exception) {
        emptyList()
    }

    /**
     * Nenhum hash de release oficial embutido ainda (DEDUZIDO: igual a `SUPABASE_ANON_KEY` em
     * `ModulosKoin.kt`, isto vem de `BuildConfig` em produção, não de literal). Até a chave de
     * release ser gerada e seu hash de certificado, de propósito, documentado aqui, a checagem
     * fica desativada (retorna `null`) em vez de comparar contra um valor inventado — RN15 exige
     * nunca afirmar adulteração sem uma referência real.
     */
    override fun assinaturaEsperada(): String? = null

    override fun isDebug(): Boolean = BuildConfig.DEBUG

    private fun sha256Hex(bytes: ByteArray): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return digest.joinToString(separator = "") { "%02x".format(it) }
    }
}
