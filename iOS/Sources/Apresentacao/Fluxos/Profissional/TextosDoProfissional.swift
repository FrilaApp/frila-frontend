// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Substitui por ora a alta fidelidade do
// profissional (#15) e os padrões de estado (#172).
//
// Textos PROVISÓRIOS, tirados do protótipo low-fi dos cartões #104/#105 (telas "Vagas no DF" e
// "Detalhe da vaga"). O guia de voz (#186) ainda não existe; quando existir, os textos mudam só aqui.

import Foundation
import FrilaDominio

enum TextosDoProfissional {
    enum Lista {
        static let titulo = String(localized: "Vagas no DF")
        static let qualquerFuncao = String(localized: "Qualquer função")
        static let qualquerData = String(localized: "Qualquer data")
        static let hoje = String(localized: "Hoje")
        static let amanha = String(localized: "Amanhã")
        static let qualquerDistancia = String(localized: "Qualquer distância")
        static func ateKm(_ km: Int) -> String { String(localized: "Até \(km) km") }
        static let vazioTitulo = String(localized: "Nenhuma vaga aberta")
        static let vazioMensagem = String(localized: "Mude os filtros ou puxe para atualizar.")
        static let erroMensagem = String(localized: "Não foi possível carregar as vagas.")
        static let semPontoDeReferencia = String(localized: "Complete seu perfil com o ponto de partida para ver as vagas por distância.")
        static let perfilIncompativel = String(localized: "Esta lista é para quem trabalha como profissional.")
        static let semConexaoMensagem = String(localized: "Sem conexão. Tente de novo quando a internet voltar.")
    }

    enum Detalhe {
        static let titulo = String(localized: "Vaga")
        static let quando = String(localized: "Quando")
        static let horario = String(localized: "Horário")
        static let valor = String(localized: "Valor")
        static let posicoes = String(localized: "Posições")
        static let valorIntegral = String(localized: "O valor é integral: o Frila não desconta taxa do turno.")
        static let incluso = String(localized: "O que está incluso")
        static let quemRecebe = String(localized: "Quem recebe você")
        static let traje = String(localized: "Traje")
        static let urgencia = String(localized: "Urgência")
        static let urgenciaDetalhe = String(localized: "quem aceitar primeiro fica com a vaga")
        static let selecao = String(localized: "Seleção")
        static let selecaoDetalhe = String(localized: "o estabelecimento escolhe entre os candidatos")
        static func avisoRN10(_ estabelecimento: String) -> String {
            String(localized: "Ao confirmar, seu telefone e WhatsApp serão mostrados ao \(estabelecimento) para combinar o turno.")
        }
        static let candidatar = String(localized: "Candidatar-me")
        static let denunciar = String(localized: "Denunciar")
        static let bloquear = String(localized: "Bloquear")
        static let erroMensagem = String(localized: "Não foi possível abrir esta vaga.")
        static let naoEncontrada = String(localized: "Esta vaga não está mais disponível.")
    }

    /// Candidatura e resultados (#105). "Vaga preenchida" e "Meu turno" vêm do low-fi; inelegível, conta
    /// suspensa e vaga encerrada são textos provisórios autorizados pelo Cauê (o low-fi não tem essas telas).
    enum Candidatura {
        static let enviando = String(localized: "Enviando candidatura…")
        static let voltarParaLista = String(localized: "Ver outras vagas perto de você")

        static let confirmadoTitulo = String(localized: "Você está confirmado")
        static let contato = String(localized: "Contato")
        static let contatoLiberado = String(localized: "Liberado com a confirmação. Fica visível até 7 dias depois do turno.")
        static let abrirWhatsApp = String(localized: "Abrir no WhatsApp")

        static let preenchidaTitulo = String(localized: "Essa vaga já foi preenchida")
        static let preenchidaMensagem = String(localized: "Outra pessoa aceitou antes. No modo urgência, quem aceita primeiro fica com a vaga. Nada muda na sua reputação.")

        static let encerradaTitulo = String(localized: "Essa vaga não está mais aberta")
        static let encerradaMensagem = String(localized: "Ela foi cancelada, encerrada ou o horário de início já passou. Nada muda na sua reputação.")

        static let sobrepostoTitulo = String(localized: "Você já tem um turno nesse horário")
        static let sobrepostoMensagem = String(localized: "O horário desta vaga coincide com um turno seu já confirmado. Não dá para estar em dois turnos ao mesmo tempo.")

        static let funcaoTitulo = String(localized: "Essa vaga pede outra função")
        static let funcaoMensagem = String(localized: "A função desta vaga não está no seu perfil. Você pode ajustar suas funções no perfil.")
        static let inelegivelTitulo = String(localized: "Você não pode se candidatar a esta vaga")
        static let inelegivelMensagem = String(localized: "O Frila não aceitou a candidatura para esta vaga.")

        static let suspensaTitulo = String(localized: "Sua conta está suspensa")
        static let suspensaMensagem = String(localized: "Enquanto a suspensão durar, você não pode se candidatar a vagas. O motivo e o caminho para contestar ficam na área da sua conta.")
        static let contestar = String(localized: "Contestar a suspensão")
        static let contestarEmBreve = String(localized: "A contestação chega numa próxima versão do app.")

        static let naoEncontrada = String(localized: "Esta vaga não está mais disponível. Volte para a lista e escolha outra.")
        static let falha = String(localized: "Não foi possível enviar a candidatura. Tente de novo.")
        static let semConexao = String(localized: "Sem conexão. A candidatura não foi enviada; tente de novo quando a internet voltar.")
        static let outraEmAndamento = String(localized: "Aguarde o envio da candidatura anterior.")
    }

    static func simNao(_ valor: Bool) -> String { valor ? String(localized: "sim") : String(localized: "não") }

    /// Reputação do estabelecimento vista pelo profissional (US08).
    static func reputacaoDoEstabelecimento(_ reputacao: Reputacao) -> String {
        reputacao.semHistorico
            ? String(localized: "Sem histórico")
            : String(localized: "Trabalhariam lá de novo: \(reputacao.positivas) de \(reputacao.total)")
    }

    public enum Perfil {
        public static let titulo = String(localized: "Funções e horários", bundle: bundleApresentacao)
        public static let cabecalho = String(localized: "Seu perfil de profissional", bundle: bundleApresentacao)
        public static let secaoFuncoes = String(localized: "Funções", bundle: bundleApresentacao)
        public static let pontoBase = String(localized: "Ponto base", bundle: bundleApresentacao)
        public static let pontoBaseSalvo = String(localized: "Ponto base salvo", bundle: bundleApresentacao)
        public static let dicaPontoBase = String(localized: "Serve para calcular a distância até as vagas. Não é a sua localização em tempo real.", bundle: bundleApresentacao)
        public static let buscarPontoBase = String(localized: "Buscar endereço ou bairro", bundle: bundleApresentacao)
        public static let secaoHorarios = String(localized: "Horários em que você pode trabalhar", bundle: bundleApresentacao)
        public static let adicionarHorario = String(localized: "Adicionar horário", bundle: bundleApresentacao)
        public static let diaSeguinte = String(localized: "(dia seguinte)", bundle: bundleApresentacao)
        public static let avisoFixo = String(localized: "Você recebe vagas da sua função, perto de você (até 15 km), nos horários que marcar.", bundle: bundleApresentacao)
        public static let salvarCriacao = String(localized: "Salvar e começar", bundle: bundleApresentacao)
        public static let salvarEdicao = String(localized: "Salvar alterações", bundle: bundleApresentacao)
        public static let erroSemFuncao = String(localized: "Selecione ao menos uma função.", bundle: bundleApresentacao)
        public static let erroSemPontoBase = String(localized: "Informe o ponto base.", bundle: bundleApresentacao)
        public static let erroJanelaDuracaoZero = String(localized: "O horário de início e fim não podem ser iguais.", bundle: bundleApresentacao)
        public static let nenhumHorario = String(localized: "Nenhum horário cadastrado. Sem horários definidos, você não receberá notificações de vagas.", bundle: bundleApresentacao)
        public static let domingo = String(localized: "Domingo", bundle: bundleApresentacao)
        public static let segunda = String(localized: "Segunda-feira", bundle: bundleApresentacao)
        public static let terca = String(localized: "Terça-feira", bundle: bundleApresentacao)
        public static let quarta = String(localized: "Quarta-feira", bundle: bundleApresentacao)
        public static let quinta = String(localized: "Quinta-feira", bundle: bundleApresentacao)
        public static let sexta = String(localized: "Sexta-feira", bundle: bundleApresentacao)
        public static let sabado = String(localized: "Sábado", bundle: bundleApresentacao)
        public static let diaSemana = String(localized: "Dia da semana", bundle: bundleApresentacao)
        public static let inicio = String(localized: "Início", bundle: bundleApresentacao)
        public static let fim = String(localized: "Fim", bundle: bundleApresentacao)
        public static let adicionar = String(localized: "Adicionar", bundle: bundleApresentacao)
        public static let remover = String(localized: "Remover", bundle: bundleApresentacao)
        public static let erroHorarioInvalido = String(localized: "Horário inválido. Use o formato HH:mm.", bundle: bundleApresentacao)
        public static let erroCoordenadasInvalidas = String(localized: "Coordenadas inválidas.", bundle: bundleApresentacao)
        public static let erroCarregar = String(localized: "Não foi possível carregar as informações.", bundle: bundleApresentacao)
        public static let erroSalvar = String(localized: "Não foi possível salvar o perfil.", bundle: bundleApresentacao)
        public static let perfilSalvoComSucesso = String(localized: "Perfil salvo com sucesso!", bundle: bundleApresentacao)
        public static let buscar = String(localized: "Buscar", bundle: bundleApresentacao)
    }
}
