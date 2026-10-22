package br.com.frila.core.rede

import io.ktor.client.request.get

/** Turnos do chamador como profissional (RF13/RF14/RF15/RN12/RNF06, UC13). */
class ServicoTurnos(private val cliente: ClienteSupabase) {

    /**
     * `GET /rest/v1/rpc/meus_turnos`. Hoje e os próximos primeiro; os anteriores depois, do
     * mais recente para o mais antigo. Turno cancelado continua na lista (`estado: cancelada`,
     * RN12) — não é filtrado aqui, quem decide o que mostrar é a camada de apresentação.
     */
    suspend fun listarMeusTurnos(): List<TurnoDto> {
        val resposta = cliente.http.get(cliente.urlRpc("meus_turnos"))
        return cliente.corpoOuErro(resposta)
    }
}
