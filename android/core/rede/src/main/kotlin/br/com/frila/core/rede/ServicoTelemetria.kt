package br.com.frila.core.rede

import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

class ServicoTelemetria(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    suspend fun registrarEvento(registro: RegistroDeEventoDto): Boolean {
        val cliente = provedorDeCliente()
        val resposta = cliente.http.post(cliente.urlRpc("registrar_evento")) {
            contentType(ContentType.Application.Json)
            setBody(registro)
        }
        // O código de domínio pode ser novo/desconhecido; 400/422 nunca devem voltar à fila.
        if (resposta.status.value == 400 || resposta.status.value == 422) {
            val erro = cliente.erroDaResposta(resposta)
            throw ErroDaApi(erro.codigo, "http_${resposta.status.value}", erro.detalhes, erro.mensagemCrua)
        }
        return cliente.corpoOuErro<EventoRegistradoDto>(resposta).registrado
    }
}
