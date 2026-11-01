package br.com.frila.core.preferencias

import androidx.datastore.core.DataMigration
import androidx.datastore.core.DataStore
import androidx.datastore.core.handlers.ReplaceFileCorruptionHandler
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import java.io.File
import kotlinx.coroutines.CoroutineScope

/**
 * Preferências não sensíveis com recuperação de corrupção para o padrão vazio.
 * O chamador mantém uma única instância por arquivo `.preferences_pb` e encerra o escopo ao sair.
 * Erros de I/O continuam sendo erros: somente corrupção de conteúdo restaura o padrão.
 */
object FabricaPreferencias {
    fun criar(
        arquivo: File,
        escopo: CoroutineScope,
        migracoes: List<DataMigration<Preferences>> = emptyList(),
    ): DataStore<Preferences> =
        PreferenceDataStoreFactory.create(
            corruptionHandler = ReplaceFileCorruptionHandler { emptyPreferences() },
            scope = escopo,
            migrations = migracoes,
            produceFile = { arquivo },
        )
}
