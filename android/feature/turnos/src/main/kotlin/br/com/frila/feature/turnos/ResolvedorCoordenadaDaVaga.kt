package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.GeocodificadorDfOffline
import br.com.frila.core.rede.TurnoDto
import java.text.Normalizer

/** Coordenada aproximada do estabelecimento, com o rótulo legível usado na mensagem do alerta. */
data class CoordenadaResolvida(val coordenada: Coordenada, val rotulo: String)

/**
 * Infere uma coordenada aproximada para o estabelecimento de um turno (RN06, cartão Uu04zAt4).
 *
 * `TurnoDto.vaga` é um `VagaResumoDto` — MEDIDO em `Dtos.kt`: só tem `local`/`regiao_administrativa`
 * em texto, nunca latitude/longitude. Não existe cache de `VagaAbertaDto` com coordenada própria
 * (ela também não traz coordenada — mesma limitação do contrato OpenAPI). A única fonte possível
 * é a geocodificação offline por texto, via [GeocodificadorDfOffline].
 *
 * MEDIDO (Shisui, PR #598, bloqueante): usar só [GeocodificadorDfOffline.casarRegiaoAdministrativa]
 * resolve para o centroide da Região Administrativa inteira — 11 de 22 `POLOS_URBANOS` ficam a
 * mais de 500m desse centroide (ex.: Asa Norte a 3.776m, Asa Sul a 4.171m do centroide "Plano
 * Piloto"), fazendo o alerta de 500m disparar longe do estabelecimento real. Por isso o texto
 * primeiro tenta casar com [GeocodificadorDfOffline.POLOS_URBANOS] (granularidade de bairro/polo),
 * caindo para o centroide da RA só quando nenhum polo é identificável no texto — precisão ainda
 * de "alguns km" nesse caso de fallback (DEDUZIDO: permanece sem solução completa, pois o
 * contrato não traz coordenada alguma; o rótulo retornado reflete essa precisão real, para a
 * notificação nunca prometer mais do que o app sabe).
 */
object ResolvedorCoordenadaDaVaga {

    fun resolver(turno: TurnoDto): CoordenadaResolvida? {
        val vaga = turno.vaga
        poloDoTexto(vaga.local)?.let { return CoordenadaResolvida(it.centroide, it.nomeExibicao) }

        val nomeDaRegiao = GeocodificadorDfOffline.casarRegiaoAdministrativa(vaga.local) ?: vaga.regiaoAdministrativa
        val regiao = GeocodificadorDfOffline.REGIOES_ADMINISTRATIVAS.firstOrNull { it.nome == nomeDaRegiao }
            ?: return null
        return CoordenadaResolvida(regiao.centroide, regiao.nome)
    }

    /**
     * Casa [texto] contra o nome de exibição de cada polo urbano, com fronteira de palavra (evita
     * que "Sul" dentro de outra palavra qualquer dispare um falso positivo). Prioriza o nome mais
     * longo quando mais de um casa, para "Taguatinga Centro" vencer sobre um casamento parcial.
     */
    private fun poloDoTexto(texto: String): GeocodificadorDfOffline.PoloUrbano? {
        val normalizado = normalizar(texto)
        return GeocodificadorDfOffline.POLOS_URBANOS
            .sortedByDescending { it.nomeExibicao.length }
            .firstOrNull { polo ->
                Regex("""\b${Regex.escape(normalizar(polo.nomeExibicao))}\b""").containsMatchIn(normalizado)
            }
    }

    private fun normalizar(texto: String): String {
        val semAcento = Normalizer.normalize(texto, Normalizer.Form.NFD)
        return Regex("\\p{InCombiningDiacriticalMarks}+").replace(semAcento, "").lowercase()
    }
}
