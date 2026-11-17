package br.com.frila.core.localizacao

import android.content.Context
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.tasks.Task
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.Test

/** O que uma versão anterior deixou registrado no Play Services sai pelo id do turno; esta versão não registra geofence nenhum. */
class RemovedorDeGeofencesAntigosTest {

    private val contexto = mockk<Context>(relaxed = true)

    @Test
    fun `remove do Play Services os geofences dos turnos informados`() {
        val cliente = mockk<GeofencingClient>()
        every { cliente.removeGeofences(any<List<String>>()) } returns mockk<Task<Void>>(relaxed = true)

        RemovedorDeGeofencesAntigosDoPlayServices(contexto, cliente).remover(listOf("turno-1", "turno-2"))

        verify(exactly = 1) { cliente.removeGeofences(listOf("turno-1", "turno-2")) }
    }

    @Test
    fun `sem turnos nao chama o Play Services`() {
        val cliente = mockk<GeofencingClient>()

        RemovedorDeGeofencesAntigosDoPlayServices(contexto, cliente).remover(emptyList())

        verify(exactly = 0) { cliente.removeGeofences(any<List<String>>()) }
    }

    @Test
    fun `sem permissao ou sem Play Services a remocao nao lanca`() {
        val cliente = mockk<GeofencingClient>()
        every { cliente.removeGeofences(any<List<String>>()) } throws SecurityException("sem permissão de localização")

        RemovedorDeGeofencesAntigosDoPlayServices(contexto, cliente).remover(listOf("turno-1"))

        verify(exactly = 1) { cliente.removeGeofences(listOf("turno-1")) }
    }
}
