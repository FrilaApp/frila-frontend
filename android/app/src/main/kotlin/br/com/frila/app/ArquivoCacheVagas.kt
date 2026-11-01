package br.com.frila.app

import br.com.frila.core.seguranca.Sessao
import java.io.File
import java.security.MessageDigest
import java.util.Base64
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.contentOrNull

/** Usa o sujeito estável apenas como namespace do cache, nunca para autenticar. */
internal fun arquivoCacheVagas(diretorioPrivado: File, sessao: Sessao?): File? {
    val identidade = try {
        val corpo = sessao?.accessToken?.split('.')?.takeIf { it.size == 3 }?.get(1) ?: return null
        val sujeito = Json.parseToJsonElement(String(Base64.getUrlDecoder().decode(corpo)))
            .jsonObject["sub"]?.jsonPrimitive ?: return null
        sujeito.takeIf { it.isString }?.contentOrNull?.takeIf { it.isNotBlank() } ?: return null
    } catch (_: IllegalArgumentException) {
        return null
    }
    val resumo = MessageDigest.getInstance("SHA-256").digest(identidade.toByteArray())
        .joinToString("") { "%02x".format(it) }
    return File(diretorioPrivado, "vagas/$resumo.json")
}
