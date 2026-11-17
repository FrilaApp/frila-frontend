/**
 * Textos da escala em lote do lado da casa (3.3): um evento e várias vagas de uma vez. Os rótulos de cada vaga são os
 * do publicar vaga (`textos.contratante.publicar`); aqui ficam só os do evento, da lista de vagas e das recusas da escala.
 */
export const contratanteEscala = {
  tituloDaAba: "Publicar escala · Frila",
  titulo: "Publicar escala de evento",
  subtitulo: "Um evento com várias funções: cada uma vira uma vaga. Ou entram todas, ou nenhuma.",
  abrir: "Publicar escala de evento",
  voltar: "Voltar ao painel",
  endereco: "O evento é no endereço da casa:",
  nome: "Nome do evento",
  ajudaDoNome: "Por exemplo: Formatura de Direito.",
  data: "Dia do evento",
  vaga: "Vaga {n} de {total}",
  adicionar: "Adicionar outra vaga",
  remover: "Remover esta vaga",
  limite: "Uma escala tem até {n} vagas. Para mais, publique outra escala.",
  posicoesNaEscala: "Na escala, cada vaga vai até 100 pessoas, e a soma de todas também.",
  publicar: "Publicar escala",
  publicando: "Publicando…",
  publicada: "Escala publicada: {n} vagas. Os profissionais são avisados em até 30 segundos.",
  publicadaUma: "Escala publicada: 1 vaga. Os profissionais são avisados em até 30 segundos.",
  irAoPainel: "Ver no painel",
  erros: {
    nome: "Dê um nome ao evento, de 3 a 100 letras, sem termos que não podem ser publicados.",
    data: "Informe o dia do evento.",
    posicoes: "Informe de 1 a 100 pessoas.",
    temErro: "Confira os campos marcados antes de publicar. Nada foi publicado.",
    quantidade: "Uma escala tem de 1 a 10 vagas.",
    somaDePosicoes: "A escala passou de 100 pessoas somando todas as vagas. Diminua ou publique outra escala.",
  },
} as const;
