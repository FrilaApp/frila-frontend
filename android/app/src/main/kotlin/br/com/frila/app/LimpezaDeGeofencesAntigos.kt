package br.com.frila.app

import kotlinx.coroutines.CancellationException

/**
 * Faxina de versão anterior, na abertura do app: o geofence de aproximação saiu, mas uma instalação antiga pode ter deixado
 * registros no Play Services, que valem até o fim do turno e que o Sair não apagava. Com sessão, lê os turnos da conta e manda
 * remover o registro de cada um.
 *
 * Limite: o registro só sai pelo id do turno, e sem sessão não há como saber os ids. Nesse caso o registro antigo expira sozinho
 * no fim do turno e, sem o receptor (que também saiu), não dispara nada.
 */
internal class LimpezaDeGeofencesAntigos(
    private val temSessao: () -> Boolean,
    private val idsDosTurnos: suspend () -> List<String>,
    private val remover: (List<String>) -> Unit,
) {
    /** Nunca lança: é faxina e não pode atrapalhar a abertura do app. */
    suspend fun executar() {
        try {
            if (!temSessao()) return
            remover(idsDosTurnos())
        } catch (erro: CancellationException) {
            throw erro
        } catch (_: Exception) {
        }
    }
}
