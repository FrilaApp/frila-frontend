package br.com.frila.feature.vagas.escala

/** Textos da escala de evento (pedido 18-02; paridade de conteúdo com `contratante-escala.ts` da web). */
object TextosEscala {
    const val TITULO = "Escala do evento"
    const val ROTULO_VOLTAR = "Voltar"
    const val SUBTITULO = "Um evento com várias funções: cada uma vira uma vaga. Ou entram todas, ou nenhuma."
    const val ENDERECO = "O evento é no endereço da casa: %s"

    const val EVENTO = "O evento"
    const val NOME = "Nome do evento"
    const val NOME_AJUDA = "Por exemplo: Formatura de Direito. De 3 a 100 letras."
    const val DATA = "Dia do evento"
    const val DATA_DO_EVENTO = "Data do evento"
    const val DATA_AJUDA = "As vagas novas começam neste dia. Se mudar o dia, os horários das vagas acompanham."

    const val VAGA = "Vaga %d de %d"
    const val ADICIONAR = "Adicionar outra vaga"
    const val MENOS_OPCOES = "Menos opções"
    const val REMOVER = "Remover a vaga %d"
    const val LIMITE = "Uma escala tem até %d vagas. Para mais, publique outra escala."
    const val POSICOES_NA_ESCALA = "Na escala, cada vaga vai até 100 pessoas, e a soma de todas também."
    const val TOTAL_DA_ESCALA = "Total de pessoas na escala: %d"

    const val PUBLICAR = "Publicar escala"
    const val PUBLICANDO = "Publicando…"
    const val TENTAR_NOVAMENTE = "Tentar novamente"
    const val PENDENTE =
        "A publicação não foi concluída. Toque em tentar novamente: a mesma escala é reenviada, sem criar outra."

    const val PUBLICADA_TITULO = "Escala publicada"
    const val PUBLICADA_UMA = "1 vaga publicada. Os profissionais são avisados em até 30 segundos."
    const val PUBLICADA_VARIAS = "%d vagas publicadas. Os profissionais são avisados em até 30 segundos."
    const val VER_MINHAS_VAGAS = "Ver minhas vagas"

    const val ENTRADA = "Publicar escala do evento"
    const val ENTRADA_APOIO = "Várias funções de um evento, de uma vez."

    const val FUNCAO_CAMPO = "Escolha uma função."
    const val FUNCAO_SELECIONAR = "Selecione uma função"
    const val FUNCAO_ESCOLHA = "Escolha a função"
    const val FUNCOES_CARREGANDO = "Carregando funções…"
    const val FUNCOES_FALHA = "Não foi possível carregar as funções."

    const val NOME_CAMPO = "Dê um nome ao evento, de 3 a 100 letras, sem termos que não podem ser publicados."
    const val DATA_CAMPO = "Informe o dia do evento."
    const val ESTABELECIMENTO_CAMPO = "Não encontramos o endereço da casa. Confira o cadastro do estabelecimento."
    const val POSICOES_CAMPO = "Informe de 1 a 100 pessoas."
    const val CAMPO_OBRIGATORIO = "Preencha este campo."
    const val CAMPO_INVALIDO = "Confira o valor informado."
    const val QUANDO_CAMPO_INICIO = "O início precisa estar no futuro."
    const val QUANDO_CAMPO_FIM = "O fim precisa ser depois do início."
    const val SELECAO_SEM_ANTECEDENCIA_CAMPO = "A seleção exige início a mais de 24 horas."
    const val VALOR_CAMPO = "Informe um valor maior que zero."
    const val RESPONSAVEL_CAMPO = "Informe quem recebe o profissional no local."

    const val ERRO_CONFIRA_CAMPOS = "Confira os campos marcados. Nada foi publicado."
    const val ERRO_QUANTIDADE = "Uma escala tem de 1 a 10 vagas."
    const val ERRO_SOMA_DE_POSICOES =
        "A escala passou de 100 pessoas somando todas as vagas. Diminua ou publique outra escala."
    const val ERRO_CADASTRO_DA_CASA = "O endereço da casa precisa de ajuste no cadastro do estabelecimento. Nada foi publicado."
    const val ERRO_PERFIL_INCOMPATIVEL = "Esta conta é de profissional. Só contratantes publicam escalas."
    const val ERRO_SEM_PERMISSAO = "Você não tem permissão para publicar neste estabelecimento."
    const val ERRO_CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, não é possível publicar."
    const val ERRO_SESSAO = "Sua sessão expirou. Entre de novo."
    const val ERRO_SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO_GENERICO = "Não foi possível confirmar a publicação da escala. Tente novamente."

    // Rota (carga do estabelecimento antes do formulário).
    const val ROTA_TITULO_FALHA = "Não foi possível abrir a escala"
}
