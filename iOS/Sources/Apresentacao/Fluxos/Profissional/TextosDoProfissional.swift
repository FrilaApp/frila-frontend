// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Substitui por ora a alta fidelidade do
// profissional (#15) e os padrões de estado (#172).
//
// Textos PROVISÓRIOS, tirados do protótipo low-fi dos cartões #104/#105 (telas "Vagas no DF" e
// "Detalhe da vaga"). O guia de voz (#186) ainda não existe; quando existir, os textos mudam só aqui.

import Foundation
import FrilaDominio

enum TextosDoProfissional {
    enum Lista {
        static let titulo = String(localized: "Vagas no DF", bundle: bundleApresentacao)
        static let qualquerFuncao = String(localized: "Qualquer função", bundle: bundleApresentacao)
        static let qualquerData = String(localized: "Qualquer data", bundle: bundleApresentacao)
        static let hoje = String(localized: "Hoje", bundle: bundleApresentacao)
        static let amanha = String(localized: "Amanhã", bundle: bundleApresentacao)
        static let qualquerDistancia = String(localized: "Qualquer distância", bundle: bundleApresentacao)
        static func ateKm(_ km: Int) -> String { String(localized: "Até \(km) km", bundle: bundleApresentacao) }
        static let vazioTitulo = String(localized: "Nenhuma vaga aberta", bundle: bundleApresentacao)
        static let vazioMensagem = String(localized: "Mude os filtros ou puxe para atualizar.", bundle: bundleApresentacao)
        static let erroMensagem = String(localized: "Não foi possível carregar as vagas.", bundle: bundleApresentacao)
        static let semPontoDeReferencia = String(localized: "Complete seu perfil com o ponto de partida para ver as vagas por distância.", bundle: bundleApresentacao)
        static let perfilIncompativel = String(localized: "Esta lista é para quem trabalha como profissional.", bundle: bundleApresentacao)
        static let semConexaoMensagem = String(localized: "Sem conexão. Tente de novo quando a internet voltar.", bundle: bundleApresentacao)
    }

    enum Detalhe {
        static let titulo = String(localized: "Vaga", bundle: bundleApresentacao)
        static let quando = String(localized: "Quando", bundle: bundleApresentacao)
        static let horario = String(localized: "Horário", bundle: bundleApresentacao)
        static let valor = String(localized: "Valor", bundle: bundleApresentacao)
        static let posicoes = String(localized: "Posições", bundle: bundleApresentacao)
        static let valorIntegral = String(localized: "O valor é integral: o Frila não desconta taxa do turno.", bundle: bundleApresentacao)
        static let incluso = String(localized: "O que está incluso", bundle: bundleApresentacao)
        static let quemRecebe = String(localized: "Quem recebe você", bundle: bundleApresentacao)
        static let traje = String(localized: "Traje", bundle: bundleApresentacao)
        static let urgencia = String(localized: "Urgência", bundle: bundleApresentacao)
        static let urgenciaDetalhe = String(localized: "quem aceitar primeiro fica com a vaga", bundle: bundleApresentacao)
        static let selecao = String(localized: "Seleção", bundle: bundleApresentacao)
        static let selecaoDetalhe = String(localized: "o estabelecimento escolhe entre os candidatos", bundle: bundleApresentacao)
        static func avisoRN10(_ estabelecimento: String) -> String {
            String(localized: "Ao confirmar, seu telefone e WhatsApp serão mostrados ao \(estabelecimento) para combinar o turno.", bundle: bundleApresentacao)
        }
        static let candidatar = String(localized: "Candidatar-me", bundle: bundleApresentacao)
        static let denunciar = String(localized: "Denunciar", bundle: bundleApresentacao)
        static let bloquear = String(localized: "Bloquear", bundle: bundleApresentacao)
        static let erroMensagem = String(localized: "Não foi possível abrir esta vaga.", bundle: bundleApresentacao)
        static let naoEncontrada = String(localized: "Esta vaga não está mais disponível.", bundle: bundleApresentacao)
    }

    /// Candidatura e resultados (#105). "Vaga preenchida" e "Meu turno" vêm do low-fi; inelegível, conta
    /// suspensa e vaga encerrada são textos provisórios autorizados pelo Cauê (o low-fi não tem essas telas).
    enum Candidatura {
        static let enviando = String(localized: "Enviando candidatura…", bundle: bundleApresentacao)
        static let voltarParaLista = String(localized: "Ver outras vagas perto de você", bundle: bundleApresentacao)

        static let confirmadoTitulo = String(localized: "Você está confirmado", bundle: bundleApresentacao)
        static let contato = String(localized: "Contato", bundle: bundleApresentacao)
        static let contatoLiberado = String(localized: "Liberado com a confirmação. Fica visível até 7 dias depois do turno.", bundle: bundleApresentacao)
        static let abrirWhatsApp = String(localized: "Abrir no WhatsApp", bundle: bundleApresentacao)

        static let preenchidaTitulo = String(localized: "Essa vaga já foi preenchida", bundle: bundleApresentacao)
        static let preenchidaMensagem = String(localized: "Outra pessoa aceitou antes. No modo urgência, quem aceita primeiro fica com a vaga. Nada muda na sua reputação.", bundle: bundleApresentacao)

        static let encerradaTitulo = String(localized: "Essa vaga não está mais aberta", bundle: bundleApresentacao)
        static let encerradaMensagem = String(localized: "Ela foi cancelada, encerrada ou o horário de início já passou. Nada muda na sua reputação.", bundle: bundleApresentacao)

        static let sobrepostoTitulo = String(localized: "Você já tem um turno nesse horário", bundle: bundleApresentacao)
        static let sobrepostoMensagem = String(localized: "O horário desta vaga coincide com um turno seu já confirmado. Não dá para estar em dois turnos ao mesmo tempo.", bundle: bundleApresentacao)

        static let funcaoTitulo = String(localized: "Essa vaga pede outra função", bundle: bundleApresentacao)
        static let funcaoMensagem = String(localized: "A função desta vaga não está no seu perfil. Você pode ajustar suas funções no perfil.", bundle: bundleApresentacao)
        static let inelegivelTitulo = String(localized: "Você não pode se candidatar a esta vaga", bundle: bundleApresentacao)
        static let inelegivelMensagem = String(localized: "O Frila não aceitou a candidatura para esta vaga.", bundle: bundleApresentacao)

        static let suspensaTitulo = String(localized: "Sua conta está suspensa", bundle: bundleApresentacao)
        static let suspensaMensagem = String(localized: "Enquanto a suspensão durar, você não pode se candidatar a vagas. O motivo e o caminho para contestar ficam na área da sua conta.", bundle: bundleApresentacao)
        static let contestar = String(localized: "Contestar a suspensão", bundle: bundleApresentacao)

        static let naoEncontrada = String(localized: "Esta vaga não está mais disponível. Volte para a lista e escolha outra.", bundle: bundleApresentacao)
        static let falha = String(localized: "Não foi possível enviar a candidatura. Tente de novo.", bundle: bundleApresentacao)
        static let semConexao = String(localized: "Sem conexão. A candidatura não foi enviada; tente de novo quando a internet voltar.", bundle: bundleApresentacao)
        static let outraEmAndamento = String(localized: "Aguarde o envio da candidatura anterior.", bundle: bundleApresentacao)
    }

    enum Turnos {
        static let tituloMeusTurnos = String(localized: "Meus turnos", bundle: bundleApresentacao)
        static let tituloMeuTurno = String(localized: "Meu turno", bundle: bundleApresentacao)
        static let canceladoTitulo = String(localized: "Turno cancelado", bundle: bundleApresentacao)
        static let cancelamentoTitulo = String(localized: "Cancelamento", bundle: bundleApresentacao)
        static let cancelamentoComFalta = String(localized: "Este cancelamento contou como falta.", bundle: bundleApresentacao)
        static let cancelamentoSemFalta = String(localized: "Este cancelamento não contou como falta.", bundle: bundleApresentacao)

        static func causaDoCancelamento(_ causa: CausaDoCancelamento) -> String {
            switch causa {
            case .profissional:
                String(localized: "Você cancelou este turno.", bundle: bundleApresentacao)
            case .estabelecimento:
                String(localized: "O estabelecimento cancelou este turno.", bundle: bundleApresentacao)
            case .reaberturaPorAtraso:
                String(localized: "O estabelecimento reabriu a posição por atraso.", bundle: bundleApresentacao)
            case .noShowSemCheckin:
                String(localized: "O turno terminou sem check-in.", bundle: bundleApresentacao)
            case .outro:
                String(localized: "Cancelamento registrado.", bundle: bundleApresentacao)
            }
        }
        static let confirmadoTitulo = String(localized: "Você está confirmado", bundle: bundleApresentacao)
        static let avisoCache = String(localized: "Modo offline: exibindo dados salvos anteriormente.", bundle: bundleApresentacao)
        static let vazioTitulo = String(localized: "Nenhum turno confirmado", bundle: bundleApresentacao)
        static let vazioMensagem = String(localized: "Quando você tiver turnos confirmados, eles aparecerão aqui.", bundle: bundleApresentacao)
        static let erroAoCarregar = String(localized: "Não foi possível carregar os turnos.", bundle: bundleApresentacao)
        static let contatoEncerrado = String(localized: "Contato encerrado. O contato fica disponível até 7 dias depois do turno.", bundle: bundleApresentacao)
        static let lembretesEVisibilidade = String(localized: "Liberado com a confirmação. Fica visível até 7 dias depois do turno. Você recebe lembretes 24 h e 3 h antes.", bundle: bundleApresentacao)
        static let verNoMapas = String(localized: "Ver no Mapas", bundle: bundleApresentacao)
        static let quemRecebe = String(localized: "quem recebe", bundle: bundleApresentacao)
    }

    static func simNao(_ valor: Bool) -> String { valor ? String(localized: "sim", bundle: bundleApresentacao) : String(localized: "não", bundle: bundleApresentacao) }

    /// Reputação do estabelecimento vista pelo profissional (US08).
    static func reputacaoDoEstabelecimento(_ reputacao: Reputacao) -> String {
        reputacao.semHistorico
            ? String(localized: "Sem histórico", bundle: bundleApresentacao)
            : String(localized: "Trabalhariam lá de novo: \(reputacao.positivas) de \(reputacao.total)", bundle: bundleApresentacao)
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

    public enum Avaliacao {
        public static let titulo = String(localized: "Avaliar turno", bundle: bundleApresentacao)
        public static let perguntaProfissional = String(localized: "Você trabalharia nesse local de novo?", bundle: bundleApresentacao)
        public static let perguntaContratante = String(localized: "Chamaria este profissional de novo?", bundle: bundleApresentacao)
        public static let explicacao = String(
            localized: "Sua resposta é anônima e compõe a reputação do estabelecimento no Frila. Cada turno concluído conta para o índice de recomendação.",
            bundle: bundleApresentacao
        )
        public static let explicacaoContratante = String(
            localized: "Sua resposta é anônima e compõe a reputação do profissional no Frila. Cada turno concluído conta para o índice de recomendação.",
            bundle: bundleApresentacao
        )
        public static let botaoEnviar = String(localized: "Enviar avaliação", bundle: bundleApresentacao)
        public static let avaliadoSucesso = String(localized: "Avaliação registrada com sucesso!", bundle: bundleApresentacao)
        public static let avaliadoOffline = String(localized: "Avaliação salva. Será enviada quando a internet voltar.", bundle: bundleApresentacao)
        public static let suaResposta = String(localized: "Sua resposta", bundle: bundleApresentacao)
        public static let erroIndisponivel = String(localized: "A avaliação só fica disponível após o término do turno e com presença confirmada.", bundle: bundleApresentacao)
        public static let erroJaRegistrada = String(localized: "Esta avaliação já foi registrada.", bundle: bundleApresentacao)
        public static let erroSemRede = String(localized: "Sem conexão. Tente novamente quando a internet voltar.", bundle: bundleApresentacao)
        public static let erroGenerico = String(localized: "Não foi possível enviar a avaliação. Tente novamente.", bundle: bundleApresentacao)
        public static let erroSelecioneResposta = String(localized: "Selecione Sim ou Não para avaliar.", bundle: bundleApresentacao)
        public static let cartaoTitulo = String(localized: "Avaliação do turno", bundle: bundleApresentacao)
        public static let cartaoChamada = String(localized: "Como foi sua experiência no turno?", bundle: bundleApresentacao)
        public static let botaoAvaliar = String(localized: "Avaliar turno", bundle: bundleApresentacao)
        public static let botaoVerAvaliacao = String(localized: "Ver avaliação", bundle: bundleApresentacao)
        public static let statusAvaliado = String(localized: "Turno avaliado", bundle: bundleApresentacao)
        public static func statusResposta(_ resposta: Bool) -> String {
            resposta
                ? String(localized: "Turno avaliado · Resposta: Sim", bundle: bundleApresentacao)
                : String(localized: "Turno avaliado · Resposta: Não", bundle: bundleApresentacao)
        }
    }
}
