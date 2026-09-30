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
    }

    enum Turnos {
        static let tituloMeusTurnos = String(localized: "Meus turnos")
        static let tituloMeuTurno = String(localized: "Meu turno")
        static let confirmadoTitulo = String(localized: "Você está confirmado")
        static let avisoCache = String(localized: "Modo offline: exibindo dados salvos anteriormente.")
        static let vazioTitulo = String(localized: "Nenhum turno confirmado")
        static let vazioMensagem = String(localized: "Quando você tiver turnos confirmados, eles aparecerão aqui.")
        static let erroAoCarregar = String(localized: "Não foi possível carregar os turnos.")
        static let contatoEncerrado = String(localized: "Contato encerrado. O contato fica disponível até 7 dias depois do turno.")
        static let lembretesEVisibilidade = String(localized: "Liberado com a confirmação. Fica visível até 7 dias depois do turno. Você recebe lembretes 24 h e 3 h antes.")
        static let verNoMapas = String(localized: "Ver no Mapas")
        static let quemRecebe = String(localized: "quem recebe")
    }

    static func simNao(_ valor: Bool) -> String { valor ? String(localized: "sim") : String(localized: "não") }

    /// Reputação do estabelecimento vista pelo profissional (US08).
    static func reputacaoDoEstabelecimento(_ reputacao: Reputacao) -> String {
        reputacao.semHistorico
            ? String(localized: "Sem histórico")
            : String(localized: "Trabalhariam lá de novo: \(reputacao.positivas) de \(reputacao.total)")
    }
}
