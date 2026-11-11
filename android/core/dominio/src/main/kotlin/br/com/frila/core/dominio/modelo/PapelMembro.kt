package br.com.frila.core.dominio.modelo

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Papel de um membro no estabelecimento (schema `PapelMembro` do contrato 0.2.73, RF21, US24).
 * O `operador` publica e acompanha as vagas da casa; só o `administrador` gerencia a equipe
 * (convida, remove, transfere a administração, inclui na equipe de confiança). A tela esconde o
 * que o servidor recusaria com `403 sem_permissao`; o servidor continua sendo a autoridade.
 */
@Serializable
enum class PapelMembro(val chave: String) {
    @SerialName("administrador") ADMINISTRADOR("administrador"),
    @SerialName("operador") OPERADOR("operador"),
    ;

    val podeGerenciarEquipe: Boolean get() = this == ADMINISTRADOR

    companion object {
        /** `null` para papel que este cliente não conhece: quem chama decide, nunca assume `operador`. */
        fun deChave(chave: String?): PapelMembro? = entries.firstOrNull { it.chave == chave }
    }
}
