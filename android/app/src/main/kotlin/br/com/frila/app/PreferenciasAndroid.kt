package br.com.frila.app

import android.content.Context
import androidx.datastore.preferences.SharedPreferencesMigration
import br.com.frila.core.preferencias.FabricaPreferencias
import java.io.Closeable
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/** Uma instância por processo, encerrada pelo Koin. Sessão segura e notificações ficam separadas. */
internal class PreferenciasAndroid(
    contexto: Context,
    arquivo: File = File(contexto.filesDir, "datastore/filtros.preferences_pb"),
    private val escopo: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
) : Closeable {
    val dados = FabricaPreferencias.criar(
        arquivo,
        escopo,
        migracoes = listOf(SharedPreferencesMigration(contexto, "preferencias_filtros_vagas")),
    )
    override fun close() { escopo.cancel() }
}
