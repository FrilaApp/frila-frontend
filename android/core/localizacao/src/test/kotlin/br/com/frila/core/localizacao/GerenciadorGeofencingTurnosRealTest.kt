package br.com.frila.core.localizacao

import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import br.com.frila.core.dominio.modelo.Coordenada
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.tasks.Task
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.Instant
import org.junit.jupiter.api.Test

/**
 * RN06/RNF04 (Uu04zAt4): prova o tratamento defensivo de [GerenciadorGeofencingTurnosReal] — sem
 * permissão de localização, nunca toca em [GeofencingClient]; com permissão, registra o
 * geofence. `GeofencingClient`/`Context` reais exigem instrumentação, então aqui são dublês.
 */
class GerenciadorGeofencingTurnosRealTest {

    private val centroDeTeste = Coordenada(-15.793889, -47.882778)

    private fun contextoCom(permissaoConcedida: Boolean): Context {
        val contexto = mockk<Context>(relaxed = true)
        every { contexto.checkSelfPermission(any()) } returns
            if (permissaoConcedida) PackageManager.PERMISSION_GRANTED else PackageManager.PERMISSION_DENIED
        return contexto
    }

    private val pendingIntentFalso: (String, String, String, String) -> PendingIntent =
        { _, _, _, _ -> mockk(relaxed = true) }

    @Test
    fun `nao registra geofence sem permissao de localizacao`() {
        val clienteGeofencing = mockk<GeofencingClient>(relaxed = true)
        val gerenciador = GerenciadorGeofencingTurnosReal(contextoCom(permissaoConcedida = false), clienteGeofencing, pendingIntentFalso)

        gerenciador.registrarAlerta(
            id = "turno-1",
            centro = centroDeTeste,
            raioMetros = 500f,
            expiraEm = Instant.parse("2026-11-02T03:00:00Z"),
            canalNotificacao = "canal_turnos",
            titulo = "Você está chegando",
            corpo = "Menos de 500m do estabelecimento.",
        )

        verify(exactly = 0) { clienteGeofencing.addGeofences(any<GeofencingRequest>(), any()) }
    }

    @Test
    fun `registra geofence quando ha permissao de localizacao`() {
        val clienteGeofencing = mockk<GeofencingClient>(relaxed = true)
        every { clienteGeofencing.addGeofences(any<GeofencingRequest>(), any()) } returns mockk<Task<Void>>(relaxed = true)
        val gerenciador = GerenciadorGeofencingTurnosReal(contextoCom(permissaoConcedida = true), clienteGeofencing, pendingIntentFalso)

        gerenciador.registrarAlerta(
            id = "turno-1",
            centro = centroDeTeste,
            raioMetros = 500f,
            expiraEm = Instant.parse("2026-11-02T03:00:00Z"),
            canalNotificacao = "canal_turnos",
            titulo = "Você está chegando",
            corpo = "Menos de 500m do estabelecimento.",
        )

        verify(exactly = 1) { clienteGeofencing.addGeofences(any<GeofencingRequest>(), any()) }
    }

    @Test
    fun `removerAlerta chama removeGeofences com o id informado`() {
        val clienteGeofencing = mockk<GeofencingClient>(relaxed = true)
        every { clienteGeofencing.removeGeofences(any<List<String>>()) } returns mockk<Task<Void>>(relaxed = true)
        val gerenciador = GerenciadorGeofencingTurnosReal(contextoCom(permissaoConcedida = true), clienteGeofencing)

        gerenciador.removerAlerta("turno-1")

        verify(exactly = 1) { clienteGeofencing.removeGeofences(listOf("turno-1")) }
    }
}
