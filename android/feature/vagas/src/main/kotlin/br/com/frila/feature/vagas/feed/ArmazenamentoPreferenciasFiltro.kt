package br.com.frila.feature.vagas.feed

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.edit
import kotlinx.coroutines.flow.first

/**
 * Persistência local de preferências do filtro de vagas (RF05/RN01).
 * Permite manter a faixa de remuneração por hora selecionada entre sessões.
 */
interface ArmazenamentoPreferenciasFiltro {
    suspend fun salvarFaixaRemuneracaoHora(minimo: Float, maximo: Float, ativa: Boolean)
    suspend fun obterFaixaRemuneracaoHora(): PreferenciaFaixaRemuneracao?
    suspend fun limparFaixaRemuneracaoHora()
}

data class PreferenciaFaixaRemuneracao(
    val minima: Float,
    val maxima: Float,
    val ativa: Boolean,
)

/** Implementação em memória para testes unitários em JVM pura. */
class ArmazenamentoPreferenciasFiltroEmMemoria(
    private var preferencia: PreferenciaFaixaRemuneracao? = null,
) : ArmazenamentoPreferenciasFiltro {

    override suspend fun salvarFaixaRemuneracaoHora(minimo: Float, maximo: Float, ativa: Boolean) {
        preferencia = PreferenciaFaixaRemuneracao(minimo, maximo, ativa)
    }

    override suspend fun obterFaixaRemuneracaoHora(): PreferenciaFaixaRemuneracao? = preferencia

    override suspend fun limparFaixaRemuneracaoHora() {
        preferencia = null
    }
}

/** Implementação persistente; as três chaves mantêm os nomes legados da migração. */
class ArmazenamentoPreferenciasFiltroDataStore(
    private val dados: DataStore<Preferences>,
) : ArmazenamentoPreferenciasFiltro {
    override suspend fun salvarFaixaRemuneracaoHora(minimo: Float, maximo: Float, ativa: Boolean) {
        dados.edit {
            it[MINIMO] = minimo
            it[MAXIMO] = maximo
            it[ATIVA] = ativa
        }
    }

    override suspend fun obterFaixaRemuneracaoHora(): PreferenciaFaixaRemuneracao? {
        val preferencias = dados.data.first()
        return PreferenciaFaixaRemuneracao(
            preferencias[MINIMO] ?: return null,
            preferencias[MAXIMO] ?: return null,
            preferencias[ATIVA] ?: false,
        )
    }

    override suspend fun limparFaixaRemuneracaoHora() {
        dados.edit { it.remove(MINIMO); it.remove(MAXIMO); it.remove(ATIVA) }
    }

    companion object {
        private val MINIMO = floatPreferencesKey("filtro_remuneracao_hora_minimo")
        private val MAXIMO = floatPreferencesKey("filtro_remuneracao_hora_maximo")
        private val ATIVA = booleanPreferencesKey("filtro_remuneracao_hora_ativa")
    }
}
