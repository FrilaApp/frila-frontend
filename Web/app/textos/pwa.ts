/** Textos de instalar na tela de início, do aviso do navegador embutido e da página sem conexão. Provisórios, até o high-fi do Fabrício. */
export const pwa = {
  instalar: {
    tituloDaAba: "Instalar o Frila · Frila",
    titulo: "Frila na tela de início",
    corpo: "Com o Frila na tela de início, ele abre direto, em tela cheia, como um app.",
    link: "Instalar no celular",
    botao: "Instalar o Frila",
    jaInstalado: "O Frila já está na sua tela de início.",
    instalou: "Pronto: o Frila está na sua tela de início.",
    tituloDoIphone: "No iPhone, pelo Safari",
    passosDoIphone: {
      compartilhar: "Toque em ⋯, ao lado do endereço, e em Compartilhar. Se o seu Safari mostra o botão Compartilhar (o quadrado com a seta para cima), toque direto nele.",
      adicionar: "Toque em Adicionar à Tela de Início. Se não aparecer, toque antes em Ver Mais.",
      confirmar: "Toque em Adicionar. O Frila aparece junto dos seus apps.",
    },
    outroNavegador: "No menu do navegador, toque em Instalar app ou em Adicionar à tela inicial.",
    voltar: "Voltar ao início",
  },
  embutido: {
    aviso: "Você abriu o Frila dentro de outro app. Para entrar sem perder a sessão, instalar e receber avisos, abra no navegador: toque no menu (⋯) e em Abrir no navegador.",
    abrirNoNavegador: "Abrir no navegador",
    fechar: "Fechar aviso",
  },
  avisos: {
    tituloDaAba: "Avisos no aparelho · Frila",
    titulo: "Avisos neste aparelho",
    corpo: "Receba neste aparelho os mesmos avisos que o app do Frila manda.",
    link: "Avisos no aparelho",
    ligar: "Ligar avisos",
    ligando: "Ligando…",
    desligar: "Desligar avisos neste aparelho",
    ligados: "Os avisos estão ligados neste aparelho.",
    desligados: "Os avisos estão desligados neste aparelho.",
    semConfig: "Os avisos pelo navegador ainda não estão disponíveis.",
    semSuporte: "Este navegador não recebe avisos. Use o Chrome, o Edge ou o Firefox, ou instale o Frila na tela de início do iPhone.",
    iphoneSemInstalar: "No iPhone, os avisos só chegam com o Frila na tela de início. Instale e abra o Frila por lá para ligar os avisos.",
    instalarPrimeiro: "Instalar na tela de início",
    negado: "Os avisos do Frila estão bloqueados neste navegador. Para ligar, libere as notificações do Frila nos ajustes do navegador ou do aparelho e volte aqui.",
    falhou: "Não deu para ligar os avisos agora. Tente de novo em instantes.",
    // Todo push da web v1 mostra só este texto (decisão do O2, 17/11): o conteúdo aparece ao abrir o Frila com a sessão.
    // TEXTO PROVISÓRIO: o mesmo neutro do iOS (VinculoDoPush.swift); o final é do Fabrício.
    neutroTitulo: "Nova notificação do Frila",
    neutroCorpo: "Abra o aplicativo para conferir.",
  },
  semConexao: {
    tituloDaAba: "Sem conexão · Frila",
    titulo: "Sem conexão",
    corpo: "O Frila precisa de internet para mostrar vagas e turnos. Confira o Wi-Fi ou os dados móveis e tente de novo.",
    tentarDeNovo: "Tentar de novo",
  },
};
