package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.ResultadoCancelamento
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Turnos do chamador como profissional (RF13/RF14/RF15/RN06/RN07/RN08/RN11/RN12/RN22/RNF06, UC05/UC06/UC13). */
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

    /**
     * `POST /rest/v1/rpc/avaliar`. Avaliação binária ("Você trabalharia nesse local de novo?",
     * RN07) — nunca nota de 1 a 5. Reenviar a mesma resposta devolve a avaliação já gravada;
     * resposta diferente é conflito. Erros esperados: `422 avaliacao_indisponivel`
     * (`antes_do_fim`, `sem_presenca_verificada`), `409 avaliacao_ja_registrada`,
     * `403 sem_permissao`.
     */
    suspend fun avaliarTurno(turnoId: String, resposta: Boolean): AvaliacaoDto {
        val respostaHttp = cliente.http.post(cliente.urlRpc("avaliar")) {
            contentType(ContentType.Application.Json)
            setBody(AvaliarDto(turnoId = turnoId, resposta = resposta))
        }
        return cliente.corpoOuErro(respostaHttp)
    }

    /**
     * Cancela uma posição confirmada com motivo (RN12). O backend é a fonte de verdade para
     * `falta` e reabertura; `409 posicao_nao_cancelavel` e recusas `422` preservam seus códigos
     * em [ErroDaApi].
     */
    suspend fun cancelarPosicao(posicaoId: String, motivo: String): ResultadoCancelamento {
        val resposta = cliente.http.post(cliente.urlRpc("cancelar_posicao")) {
            contentType(ContentType.Application.Json)
            setBody(CancelarPosicaoDto(posicaoId = posicaoId, motivo = motivo))
        }
        return cliente.corpoOuErro(resposta)
    }
}
