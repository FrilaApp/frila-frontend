package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.Coordenada
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.parameter
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Leitura de vagas abertas e candidatura (`/rpc/vagas_abertas`, `/rpc/candidatar`). */
class ServicoVagas(private val cliente: ClienteSupabase) {

    /**
     * `GET /rpc/vagas_abertas` (RF05/RF07/RN02). `coordenada` é opcional — sem ela, o backend usa
     * o `ponto_base` do perfil (openapi.yaml:2092-2122). `distanciaMaxKm` filtra no servidor; a
     * tela ainda refiltra localmente em `aplicarFiltros()` para resposta imediata ao toque.
     */
    suspend fun listarVagasAbertas(
        coordenada: Coordenada? = null,
        distanciaMaxKm: Double? = null,
    ): List<VagaAbertaDto> {
        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas")) {
            coordenada?.let {
                parameter("latitude", it.latitude)
                parameter("longitude", it.longitude)
            }
            distanciaMaxKm?.let { parameter("distancia_max_km", it) }
        }
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /rest/v1/rpc/candidatar`. Modo urgência confirma na hora (RN19) e já devolve turno
     * e contato (RN10); modo seleção fica pendente. Erros esperados (RF08/RF09/RN21):
     * `409 posicao_ja_preenchida`, `409 vaga_encerrada`, `422 inelegivel`.
     */
    suspend fun candidatar(vagaId: String): ResultadoCandidaturaDto {
        val resposta = cliente.http.post(cliente.urlRpc("candidatar")) {
            contentType(ContentType.Application.Json)
            setBody(CandidatarDto(vagaId = vagaId))
        }
        return cliente.corpoOuErro(resposta)
    }
}
