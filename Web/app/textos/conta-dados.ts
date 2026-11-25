/** Textos da página da conta (2.11): exportar os próprios dados e excluir a conta. As frases seguem as do app. */
export const contaDados = {
  tituloDaAba: "Minha conta · Frila",
  titulo: "Minha conta",
  abrir: "Minha conta: meus dados e exclusão",
  voltar: "Voltar ao início",
  dispositivos: {
    titulo: "Dispositivos conectados",
    corpo: "Encerre todas as sessões ativas e revogue os dispositivos lembrados por 30 dias em todos os aparelhos.",
    botao: "Sair de todos os dispositivos",
    encerrando: "Encerrando sessões…",
    erros: {
      limite: "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo.",
      indisponivel: "Não foi possível encerrar os dispositivos agora. Tente de novo em instantes.",
    },
  },
  exportar: {
    titulo: "Exportar meus dados",
    corpo: "Baixe um arquivo com os dados que você deu ao Frila e o que o Frila registrou sobre você. As avaliações recebidas vêm sem o autor.",
    botao: "Baixar meus dados",
    semConta: "Sua conta ainda não tem dados para exportar.",
    falhou: "Não foi possível exportar agora. Tente de novo em instantes.",
  },
  excluir: {
    titulo: "Excluir conta",
    aviso: "Atenção: a exclusão da sua conta é permanente e não poderá ser desfeita.",
    oQueAcontece: "O que acontece ao excluir sua conta:",
    anonimizacao: "Seus dados pessoais cadastrados serão anonimizados definitivamente.",
    turnos: "Os turnos futuros do profissional são cancelados sem falta. Para contratantes, o cancelamento ocorre quando a conta é o único membro do estabelecimento. Turnos em andamento seguem até o fim.",
    prazo: "O prazo para a exclusão completa das cópias de backup é de até 15 dias.",
    confirmacao: "Estou ciente das consequências e confirmo a exclusão definitiva da minha conta",
    botao: "Excluir minha conta definitivamente",
    excluindo: "Excluindo conta…",
    erros: {
      sem_confirmacao: "Para excluir, marque que está ciente das consequências.",
      administrador_unico: "Você é o único administrador deste estabelecimento. Não é possível excluir a conta enquanto houver outros membros.",
      indisponivel: "Não foi possível concluir a exclusão da conta. Tente novamente.",
    },
  },
} as const;
