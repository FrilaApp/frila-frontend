package br.com.frila.core.preferencias

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import java.io.File
import java.io.IOException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class FabricaPreferenciasTest {
    @TempDir lateinit var diretorio: File
    private val arquivo get() = File(diretorio, "teste.preferences_pb")
    private val chave = booleanPreferencesKey("preferencia_sintetica")

    @Test fun `arquivo ausente devolve preferencias padrao vazias`() = runTest {
        comPreferencias { assertTrue(it.data.first().asMap().isEmpty()) }
    }

    @Test fun `arquivo corrompido volta ao padrao e pode ser relido por outra instancia`() = runTest {
        arquivo.writeBytes(byteArrayOf(0xFF.toByte(), 0x00, 0x80.toByte()))
        comPreferencias {
            assertTrue(it.data.first().asMap().isEmpty())
            assertNull(it.data.first()[chave])
        }
        comPreferencias { assertTrue(it.data.first().asMap().isEmpty()) }
    }

    @Test fun `apos corrupcao novas preferencias persistem entre instancias`() = runTest {
        arquivo.writeBytes(byteArrayOf(0xFF.toByte()))
        comPreferencias {
            it.edit { preferencias -> preferencias[chave] = true }
            assertEquals(true, it.data.first()[chave])
        }
        comPreferencias { assertEquals(true, it.data.first()[chave]) }
    }

    @Test fun `arquivo valido preserva preferencias sem restaurar o padrao`() = runTest {
        comPreferencias { it.edit { preferencias -> preferencias[chave] = false } }
        comPreferencias { assertEquals(false, it.data.first()[chave]) }
    }

    @Test fun `erro de acesso nao e tratado como corrupcao`() = runTest {
        arquivo.mkdir()
        File(arquivo, "ocupado").writeText("sintetico")
        var erro: IOException? = null
        comPreferencias {
            try { it.data.first() } catch (recebido: IOException) { erro = recebido }
        }
        assertTrue(erro != null)
        assertTrue(arquivo.isDirectory)
    }

    private suspend fun comPreferencias(bloco: suspend (DataStore<Preferences>) -> Unit) {
        val job = SupervisorJob()
        try {
            bloco(FabricaPreferencias.criar(arquivo, CoroutineScope(Dispatchers.IO + job)))
        } finally {
            job.cancelAndJoin()
        }
    }
}
