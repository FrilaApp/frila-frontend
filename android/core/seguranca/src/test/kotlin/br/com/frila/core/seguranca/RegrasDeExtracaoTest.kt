package br.com.frila.core.seguranca

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.w3c.dom.Document
import org.w3c.dom.Element
import javax.xml.parsers.DocumentBuilderFactory

/**
 * Confere que `data_extraction_rules.xml` e `backup_rules.xml` bloqueiam, de fato, os domínios
 * que carregam dado de sessão (LGPD, RN15) — não só que os arquivos existem.
 *
 * Nota sobre "keystore": o esquema de regras de extração do Android não tem domínio `keystore`
 * — chave do Android Keystore não é representável como arquivo backupável, então não existe
 * `exclude` possível para ela (ver comentário nos dois XMLs). Este teste confere que esse fato
 * está documentado explicitamente no arquivo, em vez de simular um atributo que o schema real
 * não aceita.
 */
class RegrasDeExtracaoTest {

    private fun carregarXml(recurso: String): Document {
        val entrada = javaClass.getResourceAsStream(recurso)
            ?: error("Recurso não encontrado no classpath: $recurso")
        return DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(entrada)
    }

    private fun lerBruto(recurso: String): String =
        javaClass.getResourceAsStream(recurso)?.bufferedReader()?.readText()
            ?: error("Recurso não encontrado no classpath: $recurso")

    private fun exclusoesDe(elementoPai: Element): List<Pair<String?, String?>> {
        val nos = elementoPai.getElementsByTagName("exclude")
        return (0 until nos.length).map { indice ->
            val no = nos.item(indice) as Element
            no.getAttribute("domain") to no.getAttribute("path").ifEmpty { null }
        }
    }

    @Test
    fun `data_extraction_rules bloqueia sharedpref e database em cloud-backup e device-transfer`() {
        val doc = carregarXml("/xml/data_extraction_rules.xml")

        val cloudBackup = doc.getElementsByTagName("cloud-backup").item(0) as Element
        val deviceTransfer = doc.getElementsByTagName("device-transfer").item(0) as Element

        val exclusoesCloud = exclusoesDe(cloudBackup)
        val exclusoesDevice = exclusoesDe(deviceTransfer)

        assertTrue(exclusoesCloud.any { it.first == "sharedpref" }, "cloud-backup deve excluir sharedpref")
        assertTrue(exclusoesCloud.any { it.first == "database" }, "cloud-backup deve excluir database")
        assertTrue(exclusoesDevice.any { it.first == "sharedpref" }, "device-transfer deve excluir sharedpref")
        assertTrue(exclusoesDevice.any { it.first == "database" }, "device-transfer deve excluir database")
    }

    @Test
    fun `data_extraction_rules exige capacidade de criptografia no cloud-backup`() {
        val doc = carregarXml("/xml/data_extraction_rules.xml")
        val cloudBackup = doc.getElementsByTagName("cloud-backup").item(0) as Element

        assertEquals("true", cloudBackup.getAttribute("disableIfNoEncryptionCapability"))
    }

    @Test
    fun `data_extraction_rules documenta explicitamente por que keystore nao precisa de exclusao`() {
        val bruto = lerBruto("/xml/data_extraction_rules.xml")

        assertTrue(bruto.contains("Keystore", ignoreCase = false))
        assertTrue(bruto.contains("não saem do hardware seguro") || bruto.contains("hardware seguro"))
    }

    @Test
    fun `backup_rules (legado) bloqueia sharedpref e database`() {
        val doc = carregarXml("/xml/backup_rules.xml")

        val raiz = doc.documentElement
        assertEquals("full-backup-content", raiz.tagName)

        val exclusoes = exclusoesDe(raiz)

        assertTrue(exclusoes.any { it.first == "sharedpref" }, "backup_rules deve excluir sharedpref")
        assertTrue(exclusoes.any { it.first == "database" }, "backup_rules deve excluir database")
    }

    @Test
    fun `backup_rules tambem documenta a razao de keystore nao ter exclusao`() {
        val bruto = lerBruto("/xml/backup_rules.xml")

        assertTrue(bruto.contains("Keystore", ignoreCase = false))
    }

    @Test
    fun `nenhum dos dois XMLs exclui o caminho de sessao sem tambem excluir database`() {
        // Regressão: se alguém remover a exclusão de database por engano (ex.: ao "limpar" o
        // XML), este teste cai — a sessão sozinha sem o cache local ainda vazaria estado de
        // domínio do profissional logado.
        listOf("/xml/data_extraction_rules.xml", "/xml/backup_rules.xml").forEach { caminho ->
            val doc = carregarXml(caminho)
            val todasExclusoes = (0 until doc.getElementsByTagName("exclude").length)
                .map { doc.getElementsByTagName("exclude").item(it) as Element }
                .map { it.getAttribute("domain") }

            assertTrue("sharedpref" in todasExclusoes, "$caminho sem exclusão de sharedpref")
            assertTrue("database" in todasExclusoes, "$caminho sem exclusão de database")
        }
    }
}
