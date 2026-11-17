/** Textos do relatório dos turnos para baixar (3.17), os dois lados. */
export const relatorioTurnos = {
  tituloDaAba: "Relatório dos turnos · Frila",
  titulo: "Relatório dos turnos",
  abrir: "Baixar o relatório dos turnos",
  corpo: "Data, função, horários registrados, valor acordado e a outra parte de cada turno. O valor é o combinado, e não um pagamento feito pelo Frila. Turno sem presença confirmada sai marcado.",
  de: "De",
  ate: "Até",
  ajudaDoPeriodo: "Até 30 dias por relatório.",
  formato: "Formato",
  formatos: { csv: "Planilha (CSV)", pdf: "PDF" },
  deQuem: "Turnos de",
  meusTurnos: "Meus turnos como profissional",
  baixar: "Baixar relatório",
  voltar: "Voltar",
  erros: {
    vazio: "Nenhum turno nesse período. Escolha outras datas.",
    intervalo: "O período passou de 30 dias. Escolha um intervalo menor.",
    datas: "Confira as datas: o início vem antes do fim.",
    sem_permissao: "Você não faz mais parte desta casa.",
    indisponivel: "Não foi possível gerar o relatório agora. Tente novamente.",
  },
} as const;
