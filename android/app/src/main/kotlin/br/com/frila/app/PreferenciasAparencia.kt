package br.com.frila.app

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import java.io.IOException
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map

/** Preferência do aparelho, independente da conta e preservada na limpeza de sessão. */
internal class PreferenciasAparencia(private val dados: DataStore<Preferences>) {
    val temaEscuro = dados.data.map { it[ESCURO] ?: false }
        .catch { erro -> if (erro is IOException) emit(false) else throw erro }
        .distinctUntilChanged()

    suspend fun escolher(escuro: Boolean) {
        dados.edit { it[ESCURO] = escuro }
    }

    private companion object {
        val ESCURO = booleanPreferencesKey("aparencia_escura")
    }
}
