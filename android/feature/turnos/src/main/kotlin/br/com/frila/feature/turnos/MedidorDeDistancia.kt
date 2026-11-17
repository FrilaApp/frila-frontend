package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import kotlinx.coroutines.CancellationException

/**
 * Mede, no toque, a distância até a vaga. Só a distância sai do aparelho, nunca a coordenada (RN22). Devolve `null`
 * (e o servidor decide) sem permissão, com a localização do sistema desligada, sem leitura no prazo, com erro
 * acima de [CheckinViewModel.PRECISAO_MAXIMA_METROS] (não prova nada) ou sem o ponto da vaga. Nunca lança, e não
 * abre diálogo: quem quer o fluxo defensivo do check-in é o [CheckinViewModel.fazerCheckin].
 */
class MedidorDeDistancia(
    private val provedorDeLocalizacao: ProvedorDeLocalizacao,
    private val coordenadaDaVaga: Coordenada?,
) {
    suspend fun medir(): Int? {
        if (coordenadaDaVaga == null) return null
        return try {
            if (!provedorDeLocalizacao.temPermissaoDeLocalizacao() || !provedorDeLocalizacao.isGpsAtivado()) return null
            val leitura = provedorDeLocalizacao.lerParaCheckin() ?: return null
            if (leitura.precisaoMetros > CheckinViewModel.PRECISAO_MAXIMA_METROS) return null
            CheckinViewModel.calcularDistanciaMetros(leitura.coordenada, coordenadaDaVaga)
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: Exception) {
            null
        }
    }
}
