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
    fun `resolve coordenada pelo texto do local quando casa uma regiao administrativa`() {
        // "Asa Norte" casa com a regra de Plano Piloto em GeocodificadorDfOffline — a
        // granularidade é da Região Administrativa (centroide), não do bairro/polo: a API
        // pública de GeocodificadorDfOffline não expõe casamento texto->polo, só texto->RA
        // (DEDUZIDO, ver GeocodificadorDfOffline.kt: casarRegiaoAdministrativa retorna nome de RA).
        // `regiaoAdministrativa` do backend é propositalmente diferente do que o texto indica,
        // para provar que o casamento por `local` tem prioridade sobre o campo cru do contrato.
        val turno = turnoComVaga(local = "SQN 108, Asa Norte", regiaoAdministrativa = "Gama")
        val coordenada = ResolvedorCoordenadaDaVaga.resolver(turno)
        assertEquals(-15.793889, coordenada?.latitude)
        assertEquals(-47.882778, coordenada?.longitude)
    }

    @Test
    fun `cai para o centroide da regiao administrativa quando o local nao casa`() {
        val turno = turnoComVaga(local = "endereço sem bairro reconhecivel", regiaoAdministrativa = "Gama")
        val coordenada = ResolvedorCoordenadaDaVaga.resolver(turno)
        assertEquals(-16.016667, coordenada?.latitude)
        assertEquals(-48.066667, coordenada?.longitude)
    }

    @Test
    fun `degrada graciosamente para null quando nada casa`() {
        val turno = turnoComVaga(local = "endereço sem bairro reconhecivel", regiaoAdministrativa = "regiao inexistente")
        assertNull(ResolvedorCoordenadaDaVaga.resolver(turno))
    }
}
