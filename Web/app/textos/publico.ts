/**
 * Textos das páginas públicas da web (início sem login, como funciona, perguntas e rodapé), escritos pelo marketing
 * (CMO, `orquestracao/retornos/WEB-textos-publicos.md`, versão 2 revisada, 17/11/2026). Entram como vieram: a web
 * encaixa, não reescreve. Alguns só aparecem quando o recurso existir na web: a condição está no comentário de cada um.
 * Fora daqui, de propósito: preço e pagamento (só com ok do Orquestrador 2 ou do Cauê).
 */
export const publico = {
  // Início (/app/ sem login, com a web ligada)
  inicio: {
    tituloDaAba: "Frila: turnos em bares, restaurantes e eventos no DF",
    descricao:
      "No Frila, a casa publica o turno e profissionais autônomos que estão perto veem a vaga, aceitam ou se candidatam e vão. Para bares, restaurantes e eventos do Distrito Federal.",
    titulo: "Turnos em bares, restaurantes e eventos do DF",
    subtitulo: "A casa publica o turno. Quem está perto vê a vaga com data, horário e valor, aceita ou se candidata e vai.",
    acaoCasa: "Publicar vaga",
    acaoProfissional: "Ver vagas",
    acaoEntrar: "Entrar",

    casaTitulo: "Para a casa",
    casaItem1: "Publique a vaga com função, data, horário e quantas pessoas precisa.",
    casaItem2: "A vaga chega a profissionais que estão perto do local.",
    casaItem3: "Escolha pelo histórico: a reputação mostra quantas avaliações disseram que chamariam a pessoa de novo.",
    casaAcao: "Como funciona para a casa",

    profissionalTitulo: "Para quem trabalha",
    profissionalItem1: "Veja vagas perto de você, com data, horário e valor antes de se candidatar.",
    profissionalItem2: "Aceite ou candidate-se com um toque, sem formulário.",
    profissionalItem3: "Depois do turno, a casa pode dizer se chamaria você de novo. É isso que forma a sua reputação.",
    profissionalAcao: "Como funciona para quem trabalha",

    presencaTitulo: "Presença marcada no local",
    presencaCorpo:
      "No dia, a casa mostra um código de 6 dígitos e quem chegou digita no Frila. A presença fica registrada para os dois lados.",

    avaliacaoTitulo: "Uma pergunta depois do turno",
    avaliacaoCorpo:
      "A casa responde se chamaria a pessoa de novo. Quem trabalhou responde se trabalharia lá de novo. Sem nota e sem comentário público.",

    ondeTitulo: "Por enquanto, só no Distrito Federal",
    ondeCorpo: "O Frila começou pelo DF. Use no navegador do celular ou do computador.",

    // Condição: sempre (app 1.1.0 na App Store). O link da loja vem da configuração.
    iphoneTitulo: "Também no iPhone",
    iphoneCorpo: "O app do Frila está na App Store, para quem prefere usar pelo iPhone.",
    iphoneAcao: "Baixar na App Store",
  },

  // Como funciona para a casa (/app/como-funciona/casa)
  comoFuncionaCasa: {
    tituloDaAba: "Como funciona para a casa | Frila",
    descricao:
      "Publique o turno, a vaga chega a profissionais que estão perto, a presença é marcada por código no local e, depois, você diz se chamaria de novo.",
    titulo: "Como funciona para a casa",
    subtitulo: "Para bares, restaurantes e eventos do Distrito Federal que precisam de gente para um turno.",

    passo1Titulo: "Crie a conta e cadastre a casa",
    passo1Corpo: "Entre com o seu e-mail: o Frila manda um código de 6 dígitos, sem senha. Depois, cadastre o nome, o CNPJ ou CPF e o endereço da casa.",

    passo2Titulo: "Publique a vaga",
    passo2Corpo: "Diga a função, a data, o horário, quantas pessoas precisa e o valor do turno.",
    passo2Aviso:
      "Descreva só o trabalho do turno, o traje e o que a função pede. Não peça sexo, idade, aparência, cor, estado civil ou religião: o Frila remove a vaga que fizer essa exigência e pode bloquear a conta.",

    passo3Titulo: "Escolha como a vaga é preenchida",
    passo3Corpo:
      "No modo urgência, o turno fica com o primeiro profissional que aceitar. No modo seleção, você vê os candidatos e escolhe pelo histórico de cada um.",

    passo4Titulo: "No dia, marque a presença",
    passo4Corpo:
      "Quando a pessoa chega, você mostra o código de 6 dígitos do turno e ela digita no Frila. Se precisar, você também marca a presença dela à mão.",

    passo5Titulo: "Depois, uma pergunta",
    passo5Corpo: "Responda se chamaria a pessoa de novo. A resposta entra na reputação dela, sem nota e sem comentário público.",

    // Condição: chamada_direta + busca_profissionais (e equipe_de_confianca na segunda frase). Sem eles, esconda o passo 6.
    passo6Titulo: "Chame de novo quem trabalhou bem",
    // Condição: equipe_de_confianca.
    passo6CorpoEquipe: "Guarde na sua equipe quem você quer chamar outra vez.",
    // Condição: chamada_direta + busca_profissionais.
    passo6CorpoChamada: "Para o próximo turno, procure por função e chame a pessoa direto, sem abrir vaga.",

    imprevistoTitulo: "Se o plano mudar",
    imprevistoCorpo:
      "Você pode cancelar a vaga antes do turno. Se alguém faltar ou atrasar, você libera o lugar e a vaga volta a ficar aberta.",

    segurancaTitulo: "Se algo der errado",
    segurancaCorpo: "Denuncie ou bloqueie pelo Frila. O bloqueio vale para os dois lados.",

    acao: "Publicar vaga",
  },

  // Como funciona para quem trabalha (/app/como-funciona/profissional)
  comoFuncionaProfissional: {
    tituloDaAba: "Como funciona para quem trabalha | Frila",
    descricao:
      "Veja vagas de turno perto de você no DF, com data, horário e valor, aceite ou candidate-se com um toque e marque a presença por código no local.",
    titulo: "Como funciona para quem trabalha",
    subtitulo: "Para profissionais autônomos de bar, salão, cozinha, caixa e eventos no Distrito Federal, a partir de 18 anos.",

    passo1Titulo: "Crie a conta",
    passo1Corpo: "Entre com o seu e-mail: o Frila manda um código de 6 dígitos, sem senha. A conta é só para maiores de 18 anos.",

    passo2Titulo: "Diga o que você faz e de onde parte",
    passo2Corpo:
      "Escolha as funções que você faz e o seu ponto base, o endereço de onde as distâncias partem. As vagas aparecem das mais perto para as mais longe.",

    passo3Titulo: "Veja a vaga antes de decidir",
    passo3Corpo:
      "Cada vaga mostra a casa, a função, a data, o horário e o valor do turno. Depois que o turno é confirmado para você, o Frila mostra o endereço completo.",

    passo4Titulo: "Aceite o turno ou candidate-se",
    passo4Corpo: "Na vaga de urgência, quem aceita primeiro fica com o turno. Na vaga de seleção, você se candidata e a casa escolhe.",

    passo5Titulo: "No dia, marque a presença",
    passo5Corpo: "Avise quando estiver a caminho. Ao chegar, digite o código de 6 dígitos que a casa mostra no local.",

    // Condição: chamada_direta. Sem ela, esconda o passo 6.
    passo6Titulo: "Receba chamadas das casas onde você já trabalhou",
    passo6Corpo: "Uma casa pode chamar você direto para um turno. Você aceita ou recusa, e pode escolher não receber chamadas.",

    reputacaoTitulo: "Depois, uma pergunta",
    reputacaoCorpo:
      "Responda se trabalharia lá de novo. A casa responde se chamaria você de novo, e isso forma a sua reputação. Sem nota e sem comentário público.",

    imprevistoTitulo: "Se surgir um imprevisto",
    imprevistoCorpo: "Você pode desistir de uma candidatura ou cancelar um turno pelo Frila. A regra aparece antes de você confirmar.",

    segurancaTitulo: "Se algo der errado",
    segurancaCorpo: "Denuncie ou bloqueie pelo Frila. O bloqueio vale para os dois lados.",

    acao: "Ver vagas",
  },

  // Perguntas frequentes (/app/perguntas)
  perguntas: {
    tituloDaAba: "Perguntas frequentes | Frila",
    descricao: "O que é o Frila, onde funciona, quem pode usar, como a presença é marcada e como falar com o suporte.",
    titulo: "Perguntas frequentes",

    oQueEPergunta: "O que é o Frila?",
    oQueEResposta:
      "Um app de turnos. Bares, restaurantes e eventos publicam vagas por turno, e profissionais autônomos que estão perto se candidatam.",

    ondePergunta: "Onde o Frila funciona?",
    ondeResposta: "Por enquanto, só no Distrito Federal.",

    quemPergunta: "Quem pode usar?",
    quemResposta:
      "Casas que precisam de gente para um turno e profissionais autônomos de bar, salão, cozinha, caixa e eventos. A conta é só para maiores de 18 anos.",

    ondeUsarPergunta: "Funciona no navegador?",
    ondeUsarResposta: "Funciona, no celular e no computador. Para quem tem iPhone, o Frila também está na App Store.",

    entrarPergunta: "Como eu entro?",
    entrarResposta: "Com o seu e-mail. O Frila manda um código de 6 dígitos para você entrar, sem senha.",

    vagaPergunta: "Como a vaga chega até quem trabalha?",
    vagaResposta: "O Frila mostra a vaga a profissionais que estão perto do local e fazem a função que a casa pediu.",

    modosPergunta: "Qual a diferença entre urgência e seleção?",
    modosResposta:
      "Na urgência, o turno fica com o primeiro profissional que aceitar. Na seleção, a casa vê os candidatos e escolhe.",

    presencaPergunta: "Como a presença é marcada?",
    presencaResposta:
      "A casa mostra um código de 6 dígitos no local, e quem chegou digita no Frila. A casa também pode marcar a presença à mão.",

    localizacaoPergunta: "O Frila acompanha a minha localização?",
    // Confirmar com o Prisma: a web não pede a posição do navegador na lista de vagas (usa o ponto base).
    localizacaoResposta:
      "Não. A localização é lida só no toque de marcar a presença ou a saída, nunca o tempo todo. A distância até as vagas parte do seu ponto base.",

    avaliacaoPergunta: "Como funciona a avaliação?",
    avaliacaoResposta:
      "Depois do turno, a casa responde se chamaria a pessoa de novo e quem trabalhou responde se trabalharia lá de novo. Não há nota de 1 a 5 nem comentário público.",

    cancelarPergunta: "E se eu precisar cancelar?",
    cancelarResposta:
      "A casa pode cancelar a vaga antes do turno. Quem trabalha pode desistir de uma candidatura ou cancelar um turno. A regra aparece antes de confirmar.",

    // Condição: chamada_direta. Sem ela, esconda esta pergunta.
    chamadaDiretaPergunta: "O que é uma chamada direta?",
    chamadaDiretaResposta:
      "É quando a casa chama um profissional para um turno sem abrir vaga. Quem recebe aceita ou recusa, e pode escolher não receber chamadas.",

    problemaPergunta: "O que faço se tiver um problema com alguém?",
    problemaResposta:
      "Denuncie pelo Frila, nos detalhes do turno ou no perfil. Você também pode bloquear a pessoa ou a casa, e o bloqueio vale para os dois lados.",

    suspensaoPergunta: "Minha conta foi suspensa. E agora?",
    suspensaoResposta: "Você vê o motivo no Frila e pode contestar a suspensão por lá.",

    dadosPergunta: "Como o Frila cuida dos meus dados?",
    dadosResposta: "Tudo está na Política de Privacidade do Frila.",
    // Condição: exclusão de conta na web (paridade 2.11). Sem ela, esconda esta frase.
    dadosExclusao:
      "Você pode excluir a sua conta pelo Frila: os seus dados pessoais são anonimizados e os turnos futuros, cancelados.",

    suportePergunta: "Como falo com o Frila?",
    suporteResposta: "Pelo suporte, dentro do Frila, ou pelo e-mail suporte@frilabr.com.",
  },

  // Rodapé (todas as páginas públicas)
  rodape: {
    comoFuncionaCasa: "Para a casa",
    comoFuncionaProfissional: "Para quem trabalha",
    perguntas: "Perguntas frequentes",
    suporte: "Suporte",
    termos: "Termos de Uso",
    privacidade: "Política de Privacidade",
    // Condição: só quando frilabr.com/comunidade estiver publicada.
    comunidade: "Regras da Comunidade",
    appStore: "Baixar na App Store",
    entrar: "Entrar",
    local: "Frila · Distrito Federal, Brasil",
  },
} as const;
