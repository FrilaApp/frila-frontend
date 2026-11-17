/**
 * Catálogo único de textos da web. Tela nenhuma escreve texto direto no JSX:
 * todo texto visível sai daqui.
 */
export const textos = {
  marca: "Frila",
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
    },
    versaoMinima: "Versão mínima",
  },
  erro: {
    naoEncontradoTitulo: "Página não encontrada",
    naoEncontradoCorpo: "O endereço pode ter mudado ou a página não existe mais.",
    inesperadoTitulo: "Algo deu errado",
    inesperadoCorpo: "Não foi você. Tente de novo em instantes.",
    voltarAoInicio: "Voltar ao início",
  },
} as const;
