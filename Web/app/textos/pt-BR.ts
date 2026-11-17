/**
 * Catálogo único de textos da web. Tela nenhuma escreve texto direto no JSX:
 * todo texto visível sai daqui.
 */
export const textos = {
  marca: "Frila",
  imagemDeCompartilhamento: "Logo do Frila em branco sobre o laranja",
  emBreve: {
    titulo: "A web do Frila está chegando",
    corpo: "Em breve você vai poder publicar vagas e pegar turnos também pelo navegador. Por enquanto, o Frila está no iPhone.",
    tituloDaAba: "Frila: em breve na web",
    descricao: "O Frila liga bares, restaurantes e eventos do Distrito Federal a profissionais autônomos, por turno ou diária.",
  },
  inicio: {
    titulo: "Olá",
    corpo: "A fundação da web do Frila está no ar.",
    tituloDaAba: "Frila",
    ambiente: "Ambiente",
    configuracao: "Configuração do app no servidor",
    estadoDaConfiguracao: {
      ok: "lida",
      sem_configuracao: "ainda não existe para a web",
      indisponivel: "servidor indisponível",
      nao_configurado: "endereço do servidor não configurado neste ambiente",
      chave_recusada: "a chave configurada neste ambiente foi recusada",
    },
    versaoMinima: "Versão mínima",
  },
  entrar: {
    tituloDaAba: "Entrar no Frila",
    titulo: "Entrar",
    corpo: "Digite seu e-mail. A gente manda um código de 6 dígitos para você entrar, sem senha.",
    rotuloDoEmail: "E-mail",
    pedirCodigo: "Receber código",
    enviando: "Enviando…",
    tituloDoCodigo: "Digite o código",
    corpoDoCodigo: "Se o e-mail estiver certo, o código chega em instantes em",
    rotuloDoCodigo: "Código de 6 dígitos",
    confirmar: "Entrar",
    conferindo: "Conferindo…",
    trocarEmail: "Usar outro e-mail",
    reenviar: "Mandar outro código",
    termos: "Ao entrar, você concorda com os Termos de Uso e a Política de Privacidade do Frila.",
    linkDosTermos: "Termos de Uso",
    linkDaPrivacidade: "Política de Privacidade",
    erros: {
      email_invalido: "Confira o e-mail: ele parece incompleto.",
      codigo_incompleto: "O código tem 6 dígitos.",
      codigo_invalido: "Código errado ou vencido. Confira ou peça outro.",
      limite: "Muitas tentativas. Espere um minuto e tente de novo.",
      indisponivel: "Não deu para falar com o servidor. Tente de novo em instantes.",
    },
  },
  conta: {
    entrou: "Você entrou como",
    semEmail: "sua conta",
    sair: "Sair",
    sairFalhou: "Não deu para sair agora. Tente de novo.",
    estado: {
      ok: "Conta",
      sem_conta: "Falta completar o cadastro. Essa parte chega em breve na web; por enquanto, faça pelo app.",
      indisponivel: "Não deu para carregar sua conta agora. Tente de novo em instantes.",
    },
    perfil: { profissional: "Profissional", contratante: "Contratante" },
    entrar: "Entrar",
  },
  erro: {
    naoEncontradoTitulo: "Página não encontrada",
    naoEncontradoCorpo: "O endereço pode ter mudado ou a página não existe mais.",
    inesperadoTitulo: "Algo deu errado",
    inesperadoCorpo: "Não foi você. Tente de novo em instantes.",
    voltarAoInicio: "Voltar ao início",
  },
} as const;
