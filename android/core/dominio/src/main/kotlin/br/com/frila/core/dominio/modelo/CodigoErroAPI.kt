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
    @SerialName("verificacao_indisponivel") VERIFICACAO_INDISPONIVEL,
    @SerialName("evidencia_incompleta") EVIDENCIA_INCOMPLETA,
    @SerialName("ultimo_administrador") ULTIMO_ADMINISTRADOR,
    @SerialName("convite_invalido") CONVITE_INVALIDO,
    @SerialName("convite_de_outro_email") CONVITE_DE_OUTRO_EMAIL,
    // Chamada direta e busca de profissionais (contrato 0.2.88).
    @SerialName("chamada_indisponivel") CHAMADA_INDISPONIVEL,
    @SerialName("chamada_ja_aberta") CHAMADA_JA_ABERTA,
    @SerialName("recorrencia_nao_confirmada") RECORRENCIA_NAO_CONFIRMADA,
    @SerialName("profissional_indisponivel") PROFISSIONAL_INDISPONIVEL,
    @SerialName("limite_de_chamadas") LIMITE_DE_CHAMADAS,
    // 409 de `chamar_profissional` (0.2.95): a casa já tem vaga direta com chamada aberta para o mesmo trabalho (mesma
    // função, mesmo início e mesmo fim); `details` traz o `vaga_id` dela, um uuid em texto.
    @SerialName("trabalho_ja_aberto") TRABALHO_JA_ABERTO,
    // Os 14 que só o iOS tinha (`ErrosDaAPI.swift`), todos no contrato. Seis chegam como `code` e oito como `details` de outro
    // código; a tela lê os `details` por `ErroDaApi.detalhesComoCodigo`, sem comparar texto solto.
    // `code`: check-in por código (0.2.68/0.2.76) e mídia do perfil.
    @SerialName("codigo_invalido") CODIGO_INVALIDO,
    @SerialName("codigo_bloqueado") CODIGO_BLOQUEADO,
    @SerialName("fora_do_raio") FORA_DO_RAIO,
    @SerialName("sem_localizacao") SEM_LOCALIZACAO,
    @SerialName("midia_indisponivel") MIDIA_INDISPONIVEL,
    @SerialName("midia_invalida") MIDIA_INVALIDA,
    // `details` de `403 sem_permissao` (RN46, 0.2.90): o recurso desligado no servidor e os Termos pendentes da busca.
    @SerialName("recurso_desligado") RECURSO_DESLIGADO,
    @SerialName("termos_pendentes") TERMOS_PENDENTES,
    // `details` de `422 republicacao_indisponivel` (0.2.41): por que `republicar_posicoes_restantes` recusou.
    @SerialName("nao_e_selecao") NAO_E_SELECAO,
    @SerialName("selecao_em_curso") SELECAO_EM_CURSO,
    @SerialName("vaga_cancelada") VAGA_CANCELADA,
    @SerialName("ja_comecou") JA_COMECOU,
    @SerialName("sem_posicoes_restantes") SEM_POSICOES_RESTANTES,
    @SerialName("ja_republicada") JA_REPUBLICADA,
    @SerialName("cursor_invalido") CURSOR_INVALIDO,
    @SerialName("funcao_nao_marcada") FUNCAO_NAO_MARCADA,
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
