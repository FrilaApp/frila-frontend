package br.com.frila.core.seguranca

/**
 * Abstração de leitura do ambiente de execução (RN15, cartão Cdv0sS5w) — encapsula
 * `File.exists()`, `Build.*` e `PackageManager`, que são APIs Android e não podem ser chamadas
 * direto de `:core:seguranca` (módulo Kotlin/JVM puro, sem dependência do SDK Android). A
 * implementação real (`LeitorDeAmbienteAndroid`) fica em `:app`, no mesmo padrão de
 * [ArmazenamentoDeSessaoKeystore] vs. [ArmazenamentoDeSessao].
 *
 * Cada leitura pode lançar em um ambiente hostil (permissão negada, API ausente) — o chamador
 * (`VerificadorDeIntegridade`) nunca propaga essas exceções: RN15 é estritamente defensivo,
 * nunca bloqueante.
 */
interface LeitorDeAmbiente {

    /** Verdadeiro se um arquivo existir em [caminho]. */
    fun arquivoExiste(caminho: String): Boolean

    /** `Build.TAGS`. */
    fun buildTags(): String

    /** `Build.FINGERPRINT`. */
    fun buildFingerprint(): String

    /** `Build.HARDWARE`. */
    fun buildHardware(): String

    /** `Build.PRODUCT`. */
    fun buildProduct(): String

    /**
     * Hash (SHA-256, hex) de cada certificado de assinatura do APK instalado, lido via
     * `PackageManager`. Lista vazia quando a leitura falhar ou não houver assinatura disponível.
     */
    fun assinaturasDoPacote(): List<String>

    /**
     * Hash esperado da assinatura de release, embutido em `BuildConfig`. `null` quando não há
     * assinatura de referência conhecida (ex.: build local sem o keystore de release) — nesse
     * caso a checagem de assinatura é pulada, nunca tratada como adulteração.
     */
    fun assinaturaEsperada(): String?

    /** `BuildConfig.DEBUG` — builds de debug toleram assinatura divergente, nunca marcam como adulterada. */
    fun isDebug(): Boolean
}

/** Fallback seguro fora de um `Context` Android real (grafo Koin em JVM puro) — nunca reporta achado. */
class LeitorDeAmbienteNulo : LeitorDeAmbiente {
    override fun arquivoExiste(caminho: String): Boolean = false
    override fun buildTags(): String = "release-keys"
    override fun buildFingerprint(): String = ""
    override fun buildHardware(): String = ""
    override fun buildProduct(): String = ""
    override fun assinaturasDoPacote(): List<String> = emptyList()
    override fun assinaturaEsperada(): String? = null
    override fun isDebug(): Boolean = true
}
