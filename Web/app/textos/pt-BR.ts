/**
 * Catálogo único de textos da web. Tela nenhuma escreve texto direto no JSX:
 * todo texto visível sai daqui.
 */
import { contaDados } from "./conta-dados";
import { contratante } from "./contratante";
import { contratanteEscala } from "./contratante-escala";
import { contratanteBusca } from "./contratante-busca";
import { contratanteCadastro } from "./contratante-cadastro";
import { contratanteChamadas } from "./contratante-chamadas";
import { contratanteEquipe } from "./contratante-equipe";
import { contratanteMembros } from "./contratante-membros";
import { contratantePerfil } from "./contratante-perfil";
import { contratanteModeracao } from "./contratante-moderacao";
import { contratanteTurno } from "./contratante-turno";
import { profissional } from "./profissional";
import { profissionalCadastro } from "./profissional-cadastro";
import { publico } from "./publico";
import { pwa } from "./pwa";
import { relatorioTurnos } from "./relatorio-turnos";
import { suporte } from "./suporte";
import { suspensao } from "./suspensao";
import { vagaPublica } from "./vaga-publica";

export const textos = {
  marca: "Frila",
  aparencia: {
    titulo: "Aparência",
    tituloDaAba: "Aparência · Frila",
    claro: "Claro",
    escuro: "Escuro",
    explicacao: "Escolha como o Frila aparece. A escolha fica só neste navegador e vale também depois de trocar de conta.",
    salvar: "Salvar aparência",
    salvando: "Salvando…",
    voltar: "Voltar à minha conta",
  },
  // Conta suspensa e contestação (os dois lados).
  suspensao,
  // Suporte a partir de um turno (os dois lados).
  suporte,
  // Páginas públicas, textos do marketing (arquivo próprio para entrar como vieram).
  publico,
  // Página pública da vaga (link sem login)
  vagaPublica,
  // Lado do profissional (arquivo próprio: o lado do contratante tem o seu).
  profissional,
  // Cadastro do profissional em passos (arquivo próprio).
  profissionalCadastro,
  // Dia do turno do lado da casa (arquivo próprio).
  contratanteTurno,
  // Perfil do profissional visto pela casa (arquivo próprio).
  contratantePerfil,
  // Denunciar e bloquear do lado da casa (arquivo próprio).
  contratanteModeracao,
  // Escala de evento em lote do lado da casa (arquivo próprio).
  contratanteEscala,
  // Busca de profissionais do lado da casa (arquivo próprio).
  contratanteBusca,
  // Cadastro da casa na web (arquivo próprio).
  contratanteCadastro,
  // Chamadas enviadas pela casa (arquivo próprio).
  contratanteChamadas,
  // Pessoas da casa e o convite (arquivo próprio).
  contratanteMembros,
  // Minha conta: exportar os dados e excluir a conta (arquivo próprio).
  contaDados,
  // Relatório dos turnos para baixar (arquivo próprio).
  relatorioTurnos,
  // Equipe de confiança do lado da casa (arquivo próprio).
  contratanteEquipe,
  // Instalar na tela de início, navegador embutido e página sem conexão (arquivo próprio).
  pwa,
  imagemDeCompartilhamento: "Logo do Frila em branco sobre o laranja",
  emBreve: {
    titulo: "A web do Frila está chegando",
    corpo: "Em breve você vai poder publicar vagas e pegar turnos também pelo navegador. Por enquanto, o Frila está no iPhone.",
    tituloDaAba: "Frila: em breve na web",
    descricao: "O Frila liga bares, restaurantes e eventos do Distrito Federal a profissionais autônomos, por turno ou diária.",
  },
  inicio: {
    titulo: "Olá",
    tituloDaAba: "Frila",
  },
  entrar: {
    tituloDaAba: "Entrar no Frila",
    titulo: "Entrar",
    corpo: "Digite seu e-mail e senha para acessar sua conta.",
    rotuloDoEmail: "E-mail",
    rotuloDaSenha: "Senha",
    entrarComSenha: "Entrar",
    entrando: "Entrando…",
    esqueciSenha: "Esqueci minha senha",
    criarConta: "Criar conta",
    entrarComCodigo: "Entrar com código ou demonstração",
    tituloDoCodigo: "Digite o código",
    corpoDoCodigo: "Se o e-mail estiver certo, o código chega em instantes em",
    rotuloDoCodigo: "Código de 6 dígitos",
    pedirCodigo: "Receber código",
    confirmar: "Entrar",
    conferindo: "Conferindo…",
    trocarEmail: "Usar outro e-mail",
    reenviar: "Mandar outro código",
    voltarAoLogin: "Voltar para o login com senha",
    termos: "Ao entrar, você concorda com os Termos de Uso e a Política de Privacidade do Frila.",
    linkDosTermos: "Termos de Uso",
    linkDaPrivacidade: "Política de Privacidade",
    erros: {
      email_invalido: "Confira o e-mail: ele parece incompleto.",
      senha_invalida: "Digite sua senha.",
      credenciais_invalidas: "E-mail ou senha incorretos. Confira os dados ou recupere sua senha.",
      codigo_incompleto: "O código tem 6 dígitos.",
      codigo_invalido: "Código errado ou vencido. Confira ou peça outro.",
      limite: "Muitas tentativas. Espere um minuto e tente de novo.",
      indisponivel: "Não deu para falar com o servidor. Tente de novo em instantes.",
    },
  },
  criarConta: {
    tituloDaAba: "Criar conta · Frila",
    titulo: "Criar sua conta",
    corpo: "Informe seu e-mail. Vamos enviar um código de confirmação para você definir sua senha e começar.",
    rotuloDoEmail: "E-mail",
    pedirCodigo: "Continuar",
    enviando: "Enviando…",
    tituloDoCodigo: "Confirme seu e-mail",
    corpoDoCodigo: "Digite o código de 6 dígitos enviado para",
    rotuloDoCodigo: "Código de 6 dígitos",
    confirmar: "Confirmar e definir senha",
    conferindo: "Confirmando…",
    trocarEmail: "Usar outro e-mail",
    reenviar: "Reenviar código",
    jaTemConta: "Já tem uma conta? Entrar",
    termos: "Ao criar sua conta, você concorda com os Termos de Uso e a Política de Privacidade do Frila.",
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
  recuperarSenha: {
    tituloDaAba: "Recuperar senha · Frila",
    titulo: "Recuperar senha",
    corpo: "Informe seu e-mail cadastrado. Se houver uma conta ativa, enviaremos um código de 6 dígitos para você redefinir sua senha.",
    rotuloDoEmail: "E-mail",
    pedirCodigo: "Enviar código",
    enviando: "Enviando…",
    mensagemNeutra: "Se existir uma conta ativa com este e-mail, enviaremos um código de 6 dígitos. Confira sua caixa de entrada.",
    tituloDoCodigo: "Digite o código",
    corpoDoCodigo: "Se o e-mail estiver cadastrado, o código de recuperação foi enviado para",
    rotuloDoCodigo: "Código de 6 dígitos",
    confirmar: "Confirmar código",
    conferindo: "Conferindo…",
    trocarEmail: "Usar outro e-mail",
    reenviar: "Mandar outro código",
    voltarAoEntrar: "Voltar para o login",
    erros: {
      email_invalido: "Confira o e-mail: ele parece incompleto.",
      codigo_incompleto: "O código tem 6 dígitos.",
      codigo_invalido: "Código errado ou vencido. Confira ou peça outro.",
      limite: "Muitas tentativas. Espere um minuto e tente de novo.",
      conta_demo: "Esta conta usa apenas o modo demonstração.",
      indisponivel: "Não deu para falar com o servidor. Tente de novo em instantes.",
    },
  },
  definirSenha: {
    tituloDaAba: "Definir senha · Frila",
    titulo: "Definir senha",
    corpo: "Crie uma senha segura para acessar sua conta nos próximos acessos.",
    rotuloDaSenha: "Nova senha",
    ajudaDaSenha: "Use pelo menos 8 caracteres.",
    rotuloDaConfirmacao: "Confirmar nova senha",
    salvar: "Salvar senha",
    salvando: "Salvando…",
    alterarSenha: "Alterar minha senha",
    erros: {
      senha_curta: "Use pelo menos 8 caracteres na senha.",
      senhas_diferentes: "As senhas não conferem. Digite a mesma senha nos dois campos.",
      senha_fraca: "Escolha uma senha mais forte, combinando letras e números.",
      senha_igual: "Escolha uma senha diferente da atual.",
      sessao_invalida: "Sua sessão expirou. Entre novamente para definir sua senha.",
      limite: "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo.",
      indisponivel: "Não foi possível salvar a senha agora. Tente de novo em instantes.",
    },
  },
  conta: {
    entrou: "Você entrou como",
    semEmail: "sua conta",
    sair: "Sair",
    sairFalhou: "Não deu para sair agora. Tente de novo.",
    estado: {
      ok: "Conta",
      sem_conta: "Falta completar o cadastro para usar o Frila.",
      indisponivel: "Não deu para carregar sua conta agora. Tente de novo em instantes.",
    },
    perfil: { profissional: "Profissional", contratante: "Contratante" },
    entrar: "Entrar",
    completarCadastro: "Completar cadastro",
    verVagas: "Ver vagas",
    verPainel: "Painel da casa",
    termosMudaram: "Os Termos de Uso e a Política de Privacidade mudaram. Leia e aceite para continuar usando o Frila.",
    aceitarTermos: "Li e aceito",
    aceiteFalhou: "Não deu para registrar o aceite agora. Tente de novo em instantes.",
    termosMudaramNaTela: "Os Termos mudaram depois que você abriu esta página. Leia a versão atual e aceite de novo.",
  },
  cadastro: {
    tituloDaAba: "Criar conta no Frila",
    titulo: "Criar sua conta",
    corpo: "Falta pouco. Você entrou com",
    contaIndisponivel: "Não deu para conferir sua conta agora. Se você já tem cadastro, tente de novo em instantes.",
    perfil: "Como você vai usar o Frila?",
    ajudaDoPerfil: "Essa escolha não muda depois. Para usar o outro perfil, é preciso outra conta, com outro e-mail.",
    opcoesDoPerfil: {
      contratante: "publico vagas para o meu bar, restaurante ou evento",
      profissional: "quero pegar turnos e diárias",
    },
    nome: "Nome completo",
    telefone: "Celular",
    ajudaDoTelefone: "Com DDD. É o contato no dia do turno.",
    nascimento: "Data de nascimento",
    ajudaDoNascimento: "O Frila é para maiores de 18 anos.",
    aceite: "Li e aceito os Termos de Uso e a Política de Privacidade do Frila.",
    abreEmOutraAba: "(abrem em outra aba)",
    criar: "Criar conta",
    enviando: "Criando…",
    sairEUsarOutroEmail: "Sair e usar outro e-mail",
    erros: {
      perfil: "Escolha como você vai usar o Frila.",
      nomeObrigatorio: "Digite seu nome completo.",
      nomeInvalido: "Esse nome não pode ser usado. Digite seu nome de verdade.",
      telefone: "Confira o celular: DDD e número, só do Brasil.",
      nascimentoObrigatorio: "Informe sua data de nascimento.",
      nascimentoInvalido: "Confira a data de nascimento.",
      menorDeIdade: "O Frila é só para maiores de 18 anos.",
      aceite: "Para criar a conta, é preciso aceitar os Termos e a Política.",
      termosDesatualizados: "Os Termos mudaram agora há pouco. Recarregue a página e tente de novo.",
      termosMudaramNaTela: "Os Termos mudaram depois que você abriu esta página. Leia a versão atual e marque o aceite de novo.",
      indisponivel: "Não deu para criar a conta agora. Tente de novo em instantes.",
    },
  },
  contratante,
  erro: {
    naoEncontradoTitulo: "Página não encontrada",
    naoEncontradoCorpo: "O endereço pode ter mudado ou a página não existe mais.",
    inesperadoTitulo: "Algo deu errado",
    inesperadoCorpo: "Não foi você. Tente de novo em instantes.",
    voltarAoInicio: "Voltar ao início",
  },
} as const;
