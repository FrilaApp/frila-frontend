package br.com.frila.core.rede

import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Turnos do chamador como profissional (RF13/RF14/RF15/RN06/RN12/RN22/RNF06, UC05/UC13). */
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

    /**
     * `POST /rest/v1/rpc/fazer_checkin`. O chamador só manda a distância já calculada no
     * aparelho (RN22, minimização LGPD) — nunca a coordenada. Até 200 m o backend confirma
     * `geolocalizado`/`verificado` na hora (RN06); sem localização ou acima de 200 m vira
     * `manual`/`pendente`, à espera de `confirmar_checkin_manual`. Erros esperados:
     * `422 fora_da_janela`, `422 registro_no_futuro`, `409 vaga_encerrada` (posição cancelada).
     */
    suspend fun fazerCheckin(turnoId: String, distanciaMetros: Int?, registradoEm: String): ResultadoRegistroDto {
        val resposta = cliente.http.post(cliente.urlRpc("fazer_checkin")) {
            contentType(ContentType.Application.Json)
            setBody(RegistroDePresencaDto(turnoId = turnoId, distanciaM = distanciaMetros, registradoEm = registradoEm))
        }
        return cliente.corpoOuErro(resposta)
    }
}
