package br.com.frila.feature.chamadas.profissional

/**
 * Textos do lado do profissional na chamada direta: serviços com preço, preferências de chamada e chamada
 * recebida. Cópia do desenho do iOS já aprovado (`TextosChamadaDireta.swift`, `TelaEditarServicos.swift`,
 * `TextosDosServicos.swift`); só os textos marcados como "novo" não têm par no iOS ainda (o iOS não tem o
 * "Aceito chamadas diretas" nem as pendências da busca) e seguem o contrato 0.2.88 e o parecer jurídico J1.
 */
object TextosChamadaProfissional {
    // --- Comuns ---------------------------------------------------------------------------------
    const val ROTULO_VOLTAR = "Voltar"
    const val CANCELAR = "Cancelar"
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val CARREGANDO = "Carregando…"
    const val DESLIGADO = "A chamada direta está indisponível no momento."
    const val ERRO = "Não foi possível concluir a chamada. Verifique sua conexão e tente novamente."
    const val INDISPONIVEL = "Este profissional não está disponível para esta chamada."
    const val CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, isto não muda."
    const val SO_PROFISSIONAL = "Só profissionais usam esta tela."

    // --- Serviços (TelaEditarServicos) ---------------------------------------------------------
    const val SERVICOS_TITULO = "Editar serviços"
    const val SERVICOS_EXPLICACAO = "Serviços são opcionais. Você recebe o valor integral; o Frila não desconta nada."
    const val SERVICOS_SALVAR = "Salvar alterações"
    const val SERVICOS_SALVOS = "Serviços salvos"
    const val SERVICOS_UNIDADE = "Unidade de preço"
    const val SERVICOS_A_COMBINAR = "A combinar: o total será confirmado na chamada."
    const val SERVICOS_VALOR = "Valor em reais"
    const val SERVICOS_VALOR_MAXIMO = "Valor máximo em reais (opcional)"
    const val SERVICOS_FAIXA_DE_VALOR = "De R\$ 10 a R\$ 10.000 por unidade."
    const val SERVICOS_HORAS_DIARIA = "Horas incluídas (4 a 12)"
    const val SERVICOS_MINIMO_HORAS = "Mínimo de horas (opcional, 1 a 12)"
    const val SERVICOS_DURACAO = "Duração em horas (opcional, 1 a 24)"
    const val SERVICOS_ATE_PESSOAS = "Até quantas pessoas (opcional, 1 a 2.000)"
    const val SERVICOS_MINIMO_PESSOAS = "Mínimo de pessoas (1 a 2.000)"
    const val SERVICOS_DESCRICAO_PACOTE = "Descrição do pacote (até 120 caracteres)"
    const val SERVICOS_LEVA_MATERIAL = "Leva material?"
    const val SERVICOS_MATERIAL_NAO_INFORMADO = "Não informado"
    const val SERVICOS_INCLUI = "O que está incluído (até 300 caracteres)"
    const val SERVICOS_ESPECIALIDADES = "Escolha até 8 especialidades."
    const val SERVICOS_SEM_FUNCOES = "Você ainda não marcou nenhuma função no perfil."

    /** Novo: o contrato devolve `422 funcao_nao_marcada` (RN27) e o iOS cai no texto genérico. */
    const val SERVICOS_FUNCAO_NAO_MARCADA = "Uma das funções não está marcada no seu perfil. Marque a função e tente de novo."

    fun resumoDaDiaria(valor: String, horas: Int): String = "$valor por diária de $horas h"

    fun unidade(unidade: String): String = when (unidade) {
        "hora" -> "Hora"
        "diaria" -> "Diária"
        "evento" -> "Evento"
        "pacote" -> "Pacote"
        "por_pessoa" -> "Por pessoa"
        else -> "A combinar"
    }

    fun material(material: String): String = when (material) {
        "sim" -> "Sim"
        "nao" -> "Não"
        else -> "Depende"
    }

    /** O texto do campo do contrato que a API recusou (`details` de `422 campo_invalido`). */
    fun campo(campo: String?): String = when (campo) {
        "valor_centavos" -> "Confira o valor: de R\$ 10 a R\$ 10.000."
        "valor_max_centavos" -> "Confira o valor máximo: deve ser igual ou maior que o valor inicial, até R\$ 10.000."
        "horas_incluidas" -> SERVICOS_HORAS_DIARIA
        "minimo_horas" -> SERVICOS_MINIMO_HORAS
        "duracao_tipica_h" -> SERVICOS_DURACAO
        "ate_pessoas" -> SERVICOS_ATE_PESSOAS
        "minimo_pessoas" -> SERVICOS_MINIMO_PESSOAS
        "descricao_pacote" -> SERVICOS_DESCRICAO_PACOTE
        "inclui" -> "Revise o que está incluído. Não informe contato ou Pix."
        "especialidade_ids" -> "Escolha até 8 especialidades da mesma função."
        else -> "Revise os serviços selecionados."
    }

    // --- Preferências de chamada (TelaPreferenciasDeChamada) ------------------------------------
    const val PREFERENCIAS_TITULO = "Preferências de chamadas"
    const val PREFERENCIAS_SALVAR = "Salvar preferências"
    const val PREFERENCIAS_SALVAS = "Preferências atualizadas com sucesso."
    const val RECEBER_DE_QUEM_JA_TRABALHOU = "Receber de quem já trabalhou comigo"
    const val RECEBER_DE_QUEM_JA_TRABALHOU_SUBTITULO =
        "Permite que contratantes onde você já realizou turnos te chamem diretamente."
    const val PAUSAR_CHAMADAS = "Pausar novas chamadas"
    const val PAUSAR_ATE_DATA = "Pausar até"
    const val ANTECEDENCIA_MINIMA = "Antecedência mínima"
    const val ANTECEDENCIA_2H = "2 horas antes"
    const val ANTECEDENCIA_6H = "6 horas antes (padrão)"
    const val ANTECEDENCIA_24H = "24 horas antes"
    const val ANTECEDENCIA_48H = "48 horas antes"
    const val QUEM_PODE_CHAMAR = "Quem pode me chamar"
    const val QUEM_TODOS = "Todos os estabelecimentos"
    const val QUEM_SO_CNPJ = "Apenas estabelecimentos com CNPJ"
    const val AVISO_CHAMADAS_EXISTENTES =
        "Alterações nas preferências não afetam chamadas que você já recebeu; elas continuam disponíveis até o prazo limite."

    /** Novo: "Aceito chamadas diretas" (CD-P10 a CD-P12). Texto do pedido sem "autorizo" nem "consinto" (parecer J1). */
    const val ACEITO_TITULO = "Aceito chamadas diretas"
    const val ACEITO_TEXTO = "Quero aparecer na busca e receber chamadas de contratantes"
    const val ACEITO_O_QUE_APARECE =
        "Seu telefone, seu endereço e sua data de nascimento não aparecem. O Frila não troca telefone entre as partes."
    const val ACEITO_DESLIGAR = "Você pode desligar quando quiser. Desligar tira você da busca na hora."
    const val PENDENCIAS_TITULO = "Para aparecer na busca, falta:"
    const val PENDENCIA_SEM_SERVICO = "Definir ao menos um serviço com preço."
    const val PENDENCIA_SEM_REGIAO = "Marcar as regiões onde você atende."
    const val PENDENCIA_PAUSADO = "Retomar as chamadas, que estão pausadas."
    const val PENDENCIA_SEM_APARELHO = "Atualizar o app e permitir notificações neste aparelho."
    const val EDITAR_SERVICOS = "Editar serviços e preços"
    const val DATA_DA_PAUSA_INVALIDA = "Escolha uma data a partir de amanhã para a pausa."
    const val ESCOLHER_DATA = "Escolher data"
    const val CONFIRMAR = "Confirmar"

    /** Versão do texto "Aceito chamadas diretas" gravada no servidor ao ligar (`versao_texto_busca`, até 20 caracteres). */
    const val VERSAO_TEXTO_BUSCA = "busca-v1"

    fun pendencia(codigo: String): String? = when (codigo) {
        "sem_servico_com_preco" -> PENDENCIA_SEM_SERVICO
        "sem_regiao" -> PENDENCIA_SEM_REGIAO
        "pausado" -> PENDENCIA_PAUSADO
        "sem_aparelho_atualizado" -> PENDENCIA_SEM_APARELHO
        else -> null
    }

    fun retomadaDaPausa(dataDoDiaSeguinte: String): String =
        "A retomada ocorre às 00:00 (horário de Brasília) de $dataDoDiaSeguinte."

    // --- Chamada recebida (TelaDetalheChamadaRecebida) ------------------------------------------
    const val RECEBIDA_TITULO = "Nova chamada"
    const val RECADO_DO_CONTRATANTE = "Recado do contratante"
    const val INCLUSOS = "Inclusos"
    const val REFEICAO_INCLUSA = "Refeição inclusa"
    const val TRANSPORTE_INCLUSO = "Transporte incluso"
    const val EXIGE_MATERIAL_PROPRIO = "Exige material próprio"
    const val NENHUM_BENEFICIO = "Nenhum benefício adicional especificado."
    const val CONTA_NOVA_BADGE = "Conta nova"
    const val CONTA_NOVA_AVISO = "Este estabelecimento ainda não tem turnos concluídos no Frila."
    const val AVISO_SEGURANCA = "Nenhum pagamento é feito por fora. O valor combinado é o valor pago no aplicativo."
    const val ACEITAR_CHAMADA = "Aceitar chamada"
    const val RECUSAR_CHAMADA = "Recusar chamada"
    const val CHAMADA_RECUSADA = "Chamada recusada. Nenhuma penalidade foi aplicada."
    const val CHAMADA_ACEITA = "Você aceitou a chamada. O local e o responsável já estão liberados."
    const val ENDERECO_DO_TURNO = "Endereço do turno:"
    const val RESPONSAVEL_NO_LOCAL = "Responsável no local:"
    const val VER_TURNO = "Ver meu turno"
    const val MOTIVO_TITULO = "Motivo da recusa (opcional)"
    const val MOTIVO_ROTULO = "Motivo da recusa"
    const val MOTIVO_NENHUM = "Nenhum motivo específico"
    const val MOTIVO_AGENDA = "Conflito de agenda"
    const val MOTIVO_DISTANCIA = "Distância ou transporte"
    const val MOTIVO_VALOR = "Valor proposto"
    const val MOTIVO_TIPO_DE_SERVICO = "Tipo de serviço"
    const val MOTIVO_OUTRO = "Outro motivo"
    const val CHAMADA_ENCERRADA =
        "Esta vaga foi preenchida ou encerrada. Nada muda para você e não há nenhuma penalidade."
    const val CHAMADA_EXPIRADA = "O prazo para aceitar esta chamada expirou."
    const val CHAMADA_CANCELADA = "O contratante cancelou esta chamada. Nada muda para você."
    const val RESPONDER_ATE = "Responda até"

    /** Novo: `422 inelegivel` no aceite (`funcao_incompativel`, `turno_sobreposto`); o iOS cai no texto genérico. */
    const val INELEGIVEL_FUNCAO = "Esta chamada pede uma função que você não marcou no seu perfil."
    const val INELEGIVEL_TURNO_SOBREPOSTO = "Você já tem um turno neste horário. Não dá para aceitar esta chamada."

    /** O texto do motivo que o profissional escolheu ao recusar; nunca o código do contrato. */
    fun motivo(motivo: String): String = when (motivo) {
        "agenda" -> MOTIVO_AGENDA
        "distancia" -> MOTIVO_DISTANCIA
        "valor" -> MOTIVO_VALOR
        "tipo_de_servico" -> MOTIVO_TIPO_DE_SERVICO
        else -> MOTIVO_OUTRO
    }

    fun faixaDeDistancia(faixa: String): String = when (faixa) {
        "ate_5_km" -> "Até 5 km"
        "de_5_a_15_km" -> "De 5 a 15 km"
        else -> "Mais de 15 km"
    }

    fun intervalo(inicio: String, fim: String): String = "$inicio até $fim"
}
