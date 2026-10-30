package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.GeocodificadorDfOffline
import br.com.frila.core.rede.TurnoDto

/**
 * Infere uma coordenada aproximada para o estabelecimento de um turno (RN06, cartão Uu04zAt4).
 *
 * `TurnoDto.vaga` é um `VagaResumoDto` — MEDIDO em `Dtos.kt`: só tem `local`/`regiao_administrativa`
 * em texto, nunca latitude/longitude. Não existe cache de `VagaAbertaDto` com coordenada própria
 * (ela também não traz coordenada — mesma limitação do contrato OpenAPI). A única fonte possível
 * é a geocodificação offline por texto, via [GeocodificadorDfOffline].
 *
 * Granularidade: [GeocodificadorDfOffline.casarRegiaoAdministrativa] só resolve texto para o nome
 * da Região Administrativa, não para um polo urbano específico — a coordenada resultante é o
 * centroide da RA (precisão de alguns km), não o endereço exato (DEDUZIDO: isso significa que o
 * alerta de 500m pode disparar com folga maior ou menor que o pretendido perto das bordas da RA).
 */
object ResolvedorCoordenadaDaVaga {

    fun resolver(turno: TurnoDto): Coordenada? {
        val vaga = turno.vaga
        val nomeDaRegiao = GeocodificadorDfOffline.casarRegiaoAdministrativa(vaga.local) ?: vaga.regiaoAdministrativa
        return centroideDaRegiao(nomeDaRegiao)
    }

    private fun centroideDaRegiao(nome: String): Coordenada? =
        GeocodificadorDfOffline.REGIOES_ADMINISTRATIVAS.firstOrNull { it.nome == nome }?.centroide
}
