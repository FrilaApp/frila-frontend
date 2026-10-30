package br.com.frila.feature.turnos

import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/**
 * RN06 (Uu04zAt4): `TurnoDto.vaga` (`VagaResumoDto`) nunca traz coordenada (MEDIDO em
 * `Dtos.kt` — só `local`/`regiao_administrativa` em texto). Este resolvedor infere uma
 * coordenada aproximada via `GeocodificadorDfOffline`, sem chamada de rede.
 *
 * MEDIDO (Shisui, PR #598, bloqueante): o centroide de Região Administrativa isolado coloca o
 * círculo de 500m a 3-6 km do estabelecimento real (ex.: Asa Norte a 3.776m do centroide "Plano
 * Piloto"). Por isso o polo urbano (granularidade de bairro) tem prioridade sobre a RA inteira.
 */
class ResolvedorCoordenadaDaVagaTest {

    private fun turnoComVaga(local: String, regiaoAdministrativa: String) = TurnoDto(
        id = "turno-1",
        posicaoId = "posicao-1",
        vaga = VagaResumoDto(
            id = "vaga-1",
            funcao = "garçom",
            local = local,
            regiaoAdministrativa = regiaoAdministrativa,
            inicioEm = "2026-11-01T20:30:00Z",
            fimEm = "2026-11-02T03:00:00Z",
            valorCentavos = 16_000,
        ),
        contraparte = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = "Bar do Zé",
            reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
        ),
        contatoVisivelAte = "2026-11-02T03:00:00Z",
        verificacao = "pendente",
        valorAcordadoCentavos = 16_000,
        podeAvaliar = false,
        estado = "confirmada",
    )

    @Test
    fun `resolve coordenada pelo polo urbano quando o texto do local casa um bairro`() {
        // "regiaoAdministrativa" propositalmente diferente, para provar que o polo (granularidade
        // fina) tem prioridade sobre o centroide da RA inteira (granularidade grosseira).
        val turno = turnoComVaga(local = "SQN 108, Asa Norte", regiaoAdministrativa = "Gama")
        val resolvida = ResolvedorCoordenadaDaVaga.resolver(turno)
        assertEquals(-15.7600, resolvida?.coordenada?.latitude)
        assertEquals(-47.8850, resolvida?.coordenada?.longitude)
        assertEquals("Asa Norte", resolvida?.rotulo)
    }

    @Test
    fun `cai para o centroide da regiao administrativa quando nenhum polo urbano casa`() {
        val turno = turnoComVaga(local = "endereço sem bairro reconhecivel", regiaoAdministrativa = "Gama")
        val resolvida = ResolvedorCoordenadaDaVaga.resolver(turno)
        assertEquals(-16.016667, resolvida?.coordenada?.latitude)
        assertEquals(-48.066667, resolvida?.coordenada?.longitude)
        assertEquals("Gama", resolvida?.rotulo)
    }

    @Test
    fun `degrada graciosamente para null quando nada casa`() {
        val turno = turnoComVaga(local = "endereço sem bairro reconhecivel", regiaoAdministrativa = "regiao inexistente")
        assertNull(ResolvedorCoordenadaDaVaga.resolver(turno))
    }
}
