package br.com.frila.core.dominio.modelo

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Códigos de erro fechados do contrato OpenAPI 0.2.45 (`iOS/Contrato/openapi.yaml`).
 * Espelha `CodigoErroAPI` já validado em `iOS/Sources/Dominio/ErrosDaAPI.swift`.
 *
 * Um `code` desconhecido do backend deve decodificar para [DESCONHECIDO], nunca derrubar o
 * parse do envelope de erro inteiro — isso exige um serializer tolerante por cima do enum
 * (`@Serializable(with = ...)` com fallback no decoder), que fica para o módulo `:core:dados`
 * (não implementado aqui, que é domínio puro e não fala com JSON de verdade).
 */
@Serializable
enum class CodigoErroAPI {
    @SerialName("nao_autenticado") NAO_AUTENTICADO,
    @SerialName("sem_permissao") SEM_PERMISSAO,
    @SerialName("contato_expirado") CONTATO_EXPIRADO,
    @SerialName("nao_encontrado") NAO_ENCONTRADO,
    @SerialName("posicao_ja_preenchida") POSICAO_JA_PREENCHIDA,
    @SerialName("vaga_encerrada") VAGA_ENCERRADA,
    @SerialName("checkin_pendente") CHECKIN_PENDENTE,
    @SerialName("checkin_ja_confirmado") CHECKIN_JA_CONFIRMADO,
    @SerialName("posicao_nao_cancelavel") POSICAO_NAO_CANCELAVEL,
    @SerialName("candidatura_indisponivel") CANDIDATURA_INDISPONIVEL,
    @SerialName("avaliacao_ja_registrada") AVALIACAO_JA_REGISTRADA,
    @SerialName("conta_existente") CONTA_EXISTENTE,
    @SerialName("documento_ja_cadastrado") DOCUMENTO_JA_CADASTRADO,
    @SerialName("administrador_unico") ADMINISTRADOR_UNICO,
    @SerialName("perfil_ja_existe") PERFIL_JA_EXISTE,
    @SerialName("campo_obrigatorio") CAMPO_OBRIGATORIO,
    @SerialName("campo_invalido") CAMPO_INVALIDO,
    @SerialName("intervalo_maximo_excedido") INTERVALO_MAXIMO_EXCEDIDO,
    @SerialName("fora_da_janela") FORA_DA_JANELA,
    @SerialName("a_caminho_fora_da_janela") A_CAMINHO_FORA_DA_JANELA,
    @SerialName("registro_no_futuro") REGISTRO_NO_FUTURO,
    @SerialName("menor_de_idade") MENOR_DE_IDADE,
    @SerialName("perfil_incompativel") PERFIL_INCOMPATIVEL,
    @SerialName("selecao_sem_antecedencia") SELECAO_SEM_ANTECEDENCIA,
    @SerialName("vaga_oculta") VAGA_OCULTA,
    @SerialName("horario_invalido") HORARIO_INVALIDO,
    @SerialName("inelegivel") INELEGIVEL,
    @SerialName("funcao_incompativel") FUNCAO_INCOMPATIVEL,
    @SerialName("avaliacao_indisponivel") AVALIACAO_INDISPONIVEL,
    @SerialName("reabertura_antes_da_tolerancia") REABERTURA_ANTES_DA_TOLERANCIA,
    @SerialName("sem_suspensao_ativa") SEM_SUSPENSAO_ATIVA,
    @SerialName("contestacao_ja_aberta") CONTESTACAO_JA_ABERTA,
    @SerialName("limite_excedido") LIMITE_EXCEDIDO,
    @SerialName("republicacao_indisponivel") REPUBLICACAO_INDISPONIVEL,
    @SerialName("conta_suspensa") CONTA_SUSPENSA,
    @SerialName("sem_rede") SEM_REDE,
    @SerialName("resposta_invalida") RESPOSTA_INVALIDA,
    @SerialName("desconhecido") DESCONHECIDO,
    ;

    /** RN: recusa definitiva de publicação — repetir a mesma solicitação não pode virar sucesso. */
    val recusaDefinitivaDePublicacao: Boolean
        get() = this in setOf(
            CAMPO_OBRIGATORIO, CAMPO_INVALIDO, HORARIO_INVALIDO, FUNCAO_INCOMPATIVEL,
            PERFIL_INCOMPATIVEL, SELECAO_SEM_ANTECEDENCIA, SEM_PERMISSAO, CONTA_SUSPENSA,
            NAO_ENCONTRADO,
        )

    /** RN: recusa definitiva de cancelamento. */
    val recusaDefinitivaDeCancelamento: Boolean
        get() = this in setOf(
            POSICAO_NAO_CANCELAVEL, VAGA_ENCERRADA, NAO_ENCONTRADO, CAMPO_OBRIGATORIO,
            CAMPO_INVALIDO, SEM_PERMISSAO, PERFIL_INCOMPATIVEL, CONTA_SUSPENSA,
        )
}
