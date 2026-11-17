package br.com.frila.core.localizacao

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.tasks.CancellationToken
import com.google.android.gms.tasks.OnFailureListener
import com.google.android.gms.tasks.OnSuccessListener
import com.google.android.gms.tasks.Task
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import br.com.frila.core.dominio.modelo.Coordenada
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ProvedorDeLocalizacaoTest {

    @Test
    fun `sem nenhuma permissao concedida, temPermissaoDeLocalizacao e falso`() {
        val contexto = mockk<Context>()
        every { contexto.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) } returns PackageManager.PERMISSION_DENIED
        every { contexto.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) } returns PackageManager.PERMISSION_DENIED
        val clienteFused = mockk<FusedLocationProviderClient>()
        val provedor = ProvedorDeLocalizacaoFused(contexto, clienteFused)

        assertFalse(provedor.temPermissaoDeLocalizacao())
    }

    @Test
    fun `sem permissao, obterCoordenadaAtual cai graciosamente para nulo sem tocar no cliente fused`() = runTest {
        val contexto = mockk<Context>()
        every { contexto.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) } returns PackageManager.PERMISSION_DENIED
        every { contexto.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) } returns PackageManager.PERMISSION_DENIED
        val clienteFused = mockk<FusedLocationProviderClient>()
        val provedor = ProvedorDeLocalizacaoFused(contexto, clienteFused)

        val coordenada = provedor.obterCoordenadaAtual()

        assertNull(coordenada)
        // RN22: sem permissão, o provedor nem pede a localização ao GPS.
        verify(exactly = 0) { clienteFused.getCurrentLocation(any<Int>(), any<CancellationToken>()) }
    }

    @Test
    fun `com permissao fina concedida, temPermissaoDeLocalizacao e verdadeiro`() {
        val contexto = mockk<Context>()
        every { contexto.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) } returns PackageManager.PERMISSION_GRANTED
        every { contexto.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) } returns PackageManager.PERMISSION_DENIED
        val clienteFused = mockk<FusedLocationProviderClient>()
        val provedor = ProvedorDeLocalizacaoFused(contexto, clienteFused)

        assert(provedor.temPermissaoDeLocalizacao())
    }

    @Test
    fun `com GPS ou rede ativo, isGpsAtivado e verdadeiro`() {
        val contexto = mockk<Context>()
        val gerenciador = mockk<LocationManager>()
        every { contexto.getSystemService(Context.LOCATION_SERVICE) } returns gerenciador
        every { gerenciador.isProviderEnabled(LocationManager.GPS_PROVIDER) } returns true
        every { gerenciador.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } returns false
        val provedor = ProvedorDeLocalizacaoFused(contexto, mockk<FusedLocationProviderClient>())

        assertTrue(provedor.isGpsAtivado())
    }

    @Test
    fun `com GPS e rede desligados, isGpsAtivado e falso`() {
        val contexto = mockk<Context>()
        val gerenciador = mockk<LocationManager>()
        every { contexto.getSystemService(Context.LOCATION_SERVICE) } returns gerenciador
        every { gerenciador.isProviderEnabled(LocationManager.GPS_PROVIDER) } returns false
        every { gerenciador.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } returns false
        val provedor = ProvedorDeLocalizacaoFused(contexto, mockk<FusedLocationProviderClient>())

        assertFalse(provedor.isGpsAtivado())
    }

    @Test
    fun `sem LocationManager disponivel (getSystemService nulo), isGpsAtivado e falso sem lancar`() {
        val contexto = mockk<Context>()
        every { contexto.getSystemService(Context.LOCATION_SERVICE) } returns null
        val provedor = ProvedorDeLocalizacaoFused(contexto, mockk<FusedLocationProviderClient>())

        assertFalse(provedor.isGpsAtivado())
    }

    @Test
    fun `quando isProviderEnabled lanca exececao, isGpsAtivado cai graciosamente para falso`() {
        val contexto = mockk<Context>()
        val gerenciador = mockk<LocationManager>()
        every { contexto.getSystemService(Context.LOCATION_SERVICE) } returns gerenciador
        every { gerenciador.isProviderEnabled(any()) } throws IllegalArgumentException("provedor desconhecido")
        val provedor = ProvedorDeLocalizacaoFused(contexto, mockk<FusedLocationProviderClient>())

        assertFalse(provedor.isGpsAtivado())
    }

    private fun contextoComPermissaoFina(): Context {
        val contexto = mockk<Context>()
        every { contexto.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) } returns PackageManager.PERMISSION_GRANTED
        every { contexto.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) } returns PackageManager.PERMISSION_GRANTED
        return contexto
    }

    /** Em lugar fechado o Play Services demora; a leitura do check-in desiste em 10 s, como no iOS. */
    @Test
    fun `leitura para o checkin que nao chega dentro do prazo devolve nulo`() = runTest {
        val clienteFused = mockk<FusedLocationProviderClient>()
        // Tarefa que nunca responde: os ouvintes são registrados e nada acontece.
        every { clienteFused.getCurrentLocation(any<Int>(), any<CancellationToken>()) } returns mockk<Task<Location>>(relaxed = true)
        val provedor = ProvedorDeLocalizacaoFused(contextoComPermissaoFina(), clienteFused)

        val leitura = provedor.lerParaCheckin()

        assertNull(leitura)
    }

    @Test
    fun `leitura para o checkin leva a coordenada a precisao e a origem`() = runTest {
        val local = mockk<Location>()
        every { local.latitude } returns -15.7932
        every { local.longitude } returns -47.8822
        every { local.hasAccuracy() } returns true
        every { local.accuracy } returns 35f
        every { local.isFromMockProvider } returns false
        val tarefa = mockk<Task<Location>>()
        every { tarefa.addOnSuccessListener(any<OnSuccessListener<in Location>>()) } answers {
            firstArg<OnSuccessListener<Location>>().onSuccess(local)
            tarefa
        }
        every { tarefa.addOnFailureListener(any<OnFailureListener>()) } returns tarefa
        val clienteFused = mockk<FusedLocationProviderClient>()
        every { clienteFused.getCurrentLocation(any<Int>(), any<CancellationToken>()) } returns tarefa
        val provedor = ProvedorDeLocalizacaoFused(contextoComPermissaoFina(), clienteFused)

        val leitura = provedor.lerParaCheckin()

        assertEquals(-15.7932, leitura!!.coordenada.latitude)
        assertEquals(35f, leitura.precisaoMetros)
        assertFalse(leitura.simulada)
    }

    /** Revisão do #812: ao desistir no prazo, o pedido ao GPS também é cancelado (senão segue ligado e um 2º toque abre outro). */
    @Test
    fun `o pedido ao GPS leva um token e ele e cancelado quando a leitura desiste no prazo`() = runTest {
        val token = slot<CancellationToken>()
        val clienteFused = mockk<FusedLocationProviderClient>()
        every { clienteFused.getCurrentLocation(any<Int>(), capture(token)) } returns mockk<Task<Location>>(relaxed = true)
        val provedor = ProvedorDeLocalizacaoFused(contextoComPermissaoFina(), clienteFused)

        assertNull(provedor.lerParaCheckin())

        assertTrue(token.isCaptured)
        assertTrue(token.captured.isCancellationRequested)
    }

    /** Revisão do #812: um provedor que não sobrescreve a leitura não pode pular a regra dos 100 m em silêncio. */
    @Test
    fun `provedor sem leitura propria nao finge precisao e a leitura nao vale como prova`() = runTest {
        val provedor = object : ProvedorDeLocalizacao {
            override suspend fun obterCoordenadaAtual(): Coordenada = Coordenada(-15.7932, -47.8822)
            override fun temPermissaoDeLocalizacao(): Boolean = true
            override fun isGpsAtivado(): Boolean = true
        }

        assertEquals(Float.POSITIVE_INFINITY, provedor.lerParaCheckin()!!.precisaoMetros)
    }
}
