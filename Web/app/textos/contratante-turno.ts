/**
 * Textos do dia do turno do lado da casa (lista dos turnos, código de chegada, confirmação manual, atraso e falta).
 * As frases seguem as do app (TextosDoAcompanhamento e TextosDoCheckinPorCodigoCasa).
 */
export const contratanteTurno = {
  lista: {
    tituloDaAba: "Turnos da casa · Frila",
    titulo: "Turnos da casa",
    vazia: "Nenhum turno por aqui ainda. Os turnos aparecem quando alguém é confirmado numa vaga.",
    semCasa: "Sua conta ainda não tem uma casa cadastrada.",
    trocarDeCasa: "Ver os turnos de",
  },
  chegada: {
    aguardando: "Ainda não fez o check-in.",
    aCaminho: "Avisou que está a caminho.",
    pendente: "Chegou ao local. Falta confirmar a presença.",
    verificada: "Presença verificada.",
    naoVerificada: "Presença não verificada.",
    saiu: "Saída registrada.",
  },
  estado: {
    aberta: "Aberto",
    confirmada: "Confirmado",
    cumprida: "Cumprido",
    cancelada: "Cancelado",
  },
  avisos: {
    perfil_incompativel: "Esta área é de quem contrata. A sua conta é de profissional.",
    conta_suspensa: "Sua conta está suspensa. Por enquanto, não dá para acompanhar turnos.",
    sem_permissao: "Só quem faz parte da casa vê os turnos dela.",
    indisponivel: "Não deu para carregar os turnos agora. Tente de novo em instantes.",
  },
} as const;
