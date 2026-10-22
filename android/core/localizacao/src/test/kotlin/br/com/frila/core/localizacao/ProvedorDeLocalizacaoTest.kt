package br.com.frila.core.localizacao

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.tasks.CancellationToken
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
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
}
