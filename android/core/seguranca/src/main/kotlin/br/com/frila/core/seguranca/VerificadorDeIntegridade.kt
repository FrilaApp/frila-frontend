package br.com.frila.core.seguranca

/**
 * Verificação defensiva de integridade de execução (RN15, cartão Cdv0sS5w): detecção básica de
 * root, de emulador, e de assinatura de pacote adulterada.
 *
 * ESTRITAMENTE NÃO-BLOQUEANTE (normativo): produz um [RelatorioIntegridade] para
 * telemetria/auditoria. Nunca chama `exitProcess`, nunca lança, nunca impede o uso do app — um
 * emulador AVD de desenvolvimento, o pipeline de CI do GitHub Actions e a análise automatizada
 * de loja continuam funcionando normalmente, só reportados como não íntegros.
 *
 * Cada grupo de leituras é isolado em `runCatching`: se [LeitorDeAmbiente] lançar (permissão
 * negada, API ausente em um fabricante exótico), o achado correspondente degrada para "não
 * detectado" em vez de propagar a exceção — o verificador nunca pode ser, ele mesmo, a causa de
 * uma trava ou crash.
 */
object VerificadorDeIntegridade {

    /** Caminhos conhecidos de binários/pacotes de root (su, Magisk, Superuser). */
    private val CAMINHOS_SU = listOf(
        "/system/bin/su",
        "/system/xbin/su",
        "/sbin/su",
        "/system/sd/xbin/su",
        "/system/bin/failsafe/su",
        "/data/local/su",
        "/data/local/bin/su",
        "/data/local/xbin/su",
        "/system/app/Superuser.apk",
        "/system/app/Magisk.apk",
        "/sbin/.magisk",
    )

    /** Substring em `Build.TAGS` presente em builds não-oficiais assinadas com chave de teste. */
    private const val TAG_SUSPEITA = "test-keys"

    /** `Build.HARDWARE` dos emuladores padrão do Android Studio (AVD). */
    private val HARDWARE_EMULADOR = setOf("goldfish", "ranchu")

    /** Substrings de `Build.PRODUCT` comuns a emuladores (AVD, Genymotion, VirtualBox). */
    private val PRODUTO_EMULADOR = listOf("sdk", "emulator", "vbox", "genymotion")

    /** Substrings de `Build.FINGERPRINT` comuns a emuladores. */
    private val FINGERPRINT_EMULADOR = listOf("generic", "sdk", "emulator")

    fun verificar(leitor: LeitorDeAmbiente): RelatorioIntegridade {
        return RelatorioIntegridade(
            rootDetectado = detectarRoot(leitor),
            emuladorDetectado = detectarEmulador(leitor),
            assinaturaAdulterada = detectarAssinaturaAdulterada(leitor),
        )
    }

    private fun detectarRoot(leitor: LeitorDeAmbiente): Boolean = runCatching {
        CAMINHOS_SU.any { leitor.arquivoExiste(it) } || leitor.buildTags().contains(TAG_SUSPEITA)
    }.getOrDefault(false)

    private fun detectarEmulador(leitor: LeitorDeAmbiente): Boolean = runCatching {
        val hardware = leitor.buildHardware().lowercase()
        val produto = leitor.buildProduct().lowercase()
        val fingerprint = leitor.buildFingerprint().lowercase()

        hardware in HARDWARE_EMULADOR ||
            PRODUTO_EMULADOR.any { produto.contains(it) } ||
            FINGERPRINT_EMULADOR.any { fingerprint.contains(it) }
    }.getOrDefault(false)

    private fun detectarAssinaturaAdulterada(leitor: LeitorDeAmbiente): Boolean = runCatching {
        if (leitor.isDebug()) return@runCatching false
        val esperada = leitor.assinaturaEsperada() ?: return@runCatching false
        esperada !in leitor.assinaturasDoPacote()
    }.getOrDefault(false)
}
