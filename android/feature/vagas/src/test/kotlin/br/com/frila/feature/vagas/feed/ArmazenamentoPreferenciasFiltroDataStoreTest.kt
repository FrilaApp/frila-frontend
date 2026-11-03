package br.com.frila.feature.vagas.feed

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import br.com.frila.core.preferencias.FabricaPreferencias
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class ArmazenamentoPreferenciasFiltroDataStoreTest {
    @TempDir lateinit var diretorio: File
    private val arquivo get() = File(diretorio, "filtros.preferences_pb")

    @Test fun `arquivo ausente devolve nulo`() = runTest {
        comArmazenamento { assertNull(it.obterFaixaRemuneracaoHora()) }
    }

    @Test fun `faixa salva persiste entre instancias`() = runTest {
        comArmazenamento { it.salvarFaixaRemuneracaoHora(35f, 95f, true) }
        comArmazenamento {
            assertEquals(PreferenciaFaixaRemuneracao(35f, 95f, true), it.obterFaixaRemuneracaoHora())
        }
    }

    @Test fun `limpar remove a faixa`() = runTest {
        comArmazenamento {
            it.salvarFaixaRemuneracaoHora(35f, 95f, true)
            it.limparFaixaRemuneracaoHora()
            assertNull(it.obterFaixaRemuneracaoHora())
        }
    }

    @Test fun `arquivo corrompido recupera o padrao sem lancar`() = runTest {
        arquivo.writeBytes(byteArrayOf(0xFF.toByte(), 0x00, 0x80.toByte()))
        comArmazenamento { assertNull(it.obterFaixaRemuneracaoHora()) }
    }

    @Test fun `apos corrupcao a nova faixa grava e sobrevive a outra instancia`() = runTest {
        arquivo.writeBytes(byteArrayOf(0xFF.toByte()))
        comArmazenamento { it.salvarFaixaRemuneracaoHora(40f, 80f, false) }
        comArmazenamento {
            assertEquals(PreferenciaFaixaRemuneracao(40f, 80f, false), it.obterFaixaRemuneracaoHora())
        }
    }

    @Test fun `faixa sem o maximo gravado e tratada como ausente`() = runTest {
        comDados { dados ->
            dados.edit { it[floatPreferencesKey("filtro_remuneracao_hora_minimo")] = 10f }
            assertNull(ArmazenamentoPreferenciasFiltroDataStore(dados).obterFaixaRemuneracaoHora())
        }
    }

    private suspend fun comDados(bloco: suspend (DataStore<Preferences>) -> Unit) {
        val job = SupervisorJob()
        try {
            bloco(FabricaPreferencias.criar(arquivo, CoroutineScope(Dispatchers.IO + job)))
        } finally {
            job.cancelAndJoin()
        }
    }

    private suspend fun comArmazenamento(bloco: suspend (ArmazenamentoPreferenciasFiltroDataStore) -> Unit) =
        comDados { bloco(ArmazenamentoPreferenciasFiltroDataStore(it)) }
}
