package br.com.frila.core.seguranca

import io.mockk.every
import io.mockk.mockk
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * RN15 (cartão Cdv0sS5w): verificação defensiva, NUNCA bloqueante — produz um
 * [RelatorioIntegridade] para telemetria, nunca `exitProcess`/crash/travamento.
 */
class VerificadorDeIntegridadeTest {

    private fun leitorIntegro(): LeitorDeAmbiente {
        val leitor = mockk<LeitorDeAmbiente>()
        every { leitor.arquivoExiste(any()) } returns false
        every { leitor.buildTags() } returns "release-keys"
        every { leitor.buildFingerprint() } returns "google/walleye/walleye:10/QP1A.190711.020/5538267:user/release-keys"
        every { leitor.buildHardware() } returns "walleye"
        every { leitor.buildProduct() } returns "walleye"
        every { leitor.assinaturasDoPacote() } returns listOf("abc123")
        every { leitor.assinaturaEsperada() } returns "abc123"
        every { leitor.isDebug() } returns false
        return leitor
    }

    @Test
    fun `dispositivo integro produz relatorio sem nenhum achado`() {
        val relatorio = VerificadorDeIntegridade.verificar(leitorIntegro())

        assertTrue(relatorio.integro)
        assertFalse(relatorio.rootDetectado)
        assertFalse(relatorio.emuladorDetectado)
        assertFalse(relatorio.assinaturaAdulterada)
    }

    @Test
    fun `detecta root por caminho conhecido de su`() {
        val leitor = leitorIntegro()
        every { leitor.arquivoExiste("/system/bin/su") } returns true

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertTrue(relatorio.rootDetectado)
        assertFalse(relatorio.integro)
    }

    @Test
    fun `detecta root por build tags test-keys`() {
        val leitor = leitorIntegro()
        every { leitor.buildTags() } returns "test-keys"

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertTrue(relatorio.rootDetectado)
    }

    @Test
    fun `detecta emulador por hardware goldfish`() {
        val leitor = leitorIntegro()
        every { leitor.buildHardware() } returns "goldfish"

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertTrue(relatorio.emuladorDetectado)
        assertFalse(relatorio.integro)
    }

    @Test
    fun `detecta emulador por hardware ranchu`() {
        val leitor = leitorIntegro()
        every { leitor.buildHardware() } returns "ranchu"

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertTrue(relatorio.emuladorDetectado)
    }

    @Test
    fun `detecta emulador por produto sdk`() {
        val leitor = leitorIntegro()
        every { leitor.buildProduct() } returns "sdk_gphone64_arm64"

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertTrue(relatorio.emuladorDetectado)
    }

    @Test
    fun `detecta emulador por fingerprint generic`() {
        val leitor = leitorIntegro()
        every { leitor.buildFingerprint() } returns "generic/sdk_gphone64_arm64/emulator64_arm64:14/..."

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertTrue(relatorio.emuladorDetectado)
    }

    @Test
    fun `detecta assinatura adulterada quando a lista do pacote nao contem a esperada`() {
        val leitor = leitorIntegro()
        every { leitor.assinaturasDoPacote() } returns listOf("hash-diferente")

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertTrue(relatorio.assinaturaAdulterada)
        assertFalse(relatorio.integro)
    }

    @Test
    fun `nao marca assinatura adulterada quando nao ha assinatura esperada conhecida`() {
        val leitor = leitorIntegro()
        every { leitor.assinaturaEsperada() } returns null
        every { leitor.assinaturasDoPacote() } returns listOf("qualquer-coisa")

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertFalse(relatorio.assinaturaAdulterada)
    }

    @Test
    fun `tolera assinatura divergente em build de debug`() {
        val leitor = leitorIntegro()
        every { leitor.isDebug() } returns true
        every { leitor.assinaturasDoPacote() } returns listOf("hash-de-debug-local")

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertFalse(relatorio.assinaturaAdulterada)
    }

    @Test
    fun `degrada graciosamente sem lancar quando o leitor lanca excecao`() {
        val leitor = mockk<LeitorDeAmbiente>()
        every { leitor.arquivoExiste(any()) } throws SecurityException("sem permissão")
        every { leitor.buildTags() } throws RuntimeException("falha de leitura")
        every { leitor.buildFingerprint() } throws RuntimeException("falha de leitura")
        every { leitor.buildHardware() } throws RuntimeException("falha de leitura")
        every { leitor.buildProduct() } throws RuntimeException("falha de leitura")
        every { leitor.assinaturasDoPacote() } throws RuntimeException("falha de leitura")
        every { leitor.assinaturaEsperada() } throws RuntimeException("falha de leitura")
        every { leitor.isDebug() } throws RuntimeException("falha de leitura")

        val relatorio = VerificadorDeIntegridade.verificar(leitor)

        assertFalse(relatorio.rootDetectado)
        assertFalse(relatorio.emuladorDetectado)
        assertFalse(relatorio.assinaturaAdulterada)
    }
}
