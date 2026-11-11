package br.com.frila.feature.estabelecimento

/** Textos do cadastro (paridade com `TextosCadastro` de `CadastroEstabelecimento.swift`). */
object TextosCadastroEstabelecimento {
    const val TITULO = "Dados do negócio"
    const val SUBTITULO = "Conta de contratante"
    const val ROTULO_VOLTAR = "Voltar"
    const val NOME = "Nome do estabelecimento"
    const val DOCUMENTO = "CNPJ ou CPF"
    const val DOCUMENTO_AJUDA = "Só números: 11 dígitos de CPF ou 14 de CNPJ."
    const val TIPO = "Tipo do estabelecimento"
    const val ENDERECO = "Endereço"
    const val ENDERECO_AJUDA = "Logradouro, número e complemento."
    const val REGIAO = "Região Administrativa"
    const val REGIAO_SELECIONAR = "Selecione a Região Administrativa"
    const val REGIAO_AJUDA = "A Região Administrativa do DF onde o estabelecimento fica. Ex.: Plano Piloto, Águas Claras, Taguatinga."
    const val PONTO = "Ponto do estabelecimento"
    const val PONTO_AJUDA = "Informe a coordenada em graus decimais. Ex.: latitude -15,7801 e longitude -47,9292."
    const val LATITUDE = "Latitude"
    const val LONGITUDE = "Longitude"
    const val CADASTRAR = "Cadastrar estabelecimento"
    const val CADASTRANDO = "Cadastrando…"
    const val CONCLUIDO = "Estabelecimento cadastrado."
    const val CANCELAR = "Cancelar"

    const val CAMPO_OBRIGATORIO = "Preencha este campo."
    const val DOCUMENTO_INVALIDO = "Informe 11 dígitos (CPF) ou 14 dígitos (CNPJ)."
    const val REGIAO_INVALIDA = "Escolha uma Região Administrativa do Distrito Federal."
    const val COORDENADA_INVALIDA = "Confira o valor informado."
    const val CAMPO_INVALIDO = "Confira o valor informado."

    const val ERRO_DOCUMENTO_DUPLICADO =
        "CNPJ ou CPF: este documento já tem um estabelecimento no Frila. Se o negócio é seu, entre com o e-mail usado nesse cadastro."
    const val ERRO_CONFIRA_CAMPOS = "Confira os campos indicados."
    const val ERRO_PERFIL_INCOMPATIVEL = "Esta conta é de profissional. O cadastro de estabelecimento é só para contratantes."
    const val ERRO_SEM_PERMISSAO = "Você não tem permissão para cadastrar um estabelecimento."
    const val ERRO_CONTA_SUSPENSA = "Sua conta está suspensa. Enquanto a suspensão durar, não é possível cadastrar."
    const val ERRO_SESSAO = "Sua sessão expirou. Entre de novo."
    const val ERRO_SEM_REDE = "Sem conexão. Verifique sua internet e tente novamente."
    const val ERRO_GENERICO = "Não foi possível cadastrar o estabelecimento. Tente novamente."
}
