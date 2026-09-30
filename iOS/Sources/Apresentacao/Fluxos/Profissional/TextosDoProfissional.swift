// BAIXA FIDELIDADE DESCARTÁVEL: não é design final. Substitui por ora a alta fidelidade do
// profissional (#15) e os padrões de estado (#172).
//
// Textos PROVISÓRIOS, tirados do protótipo low-fi dos cartões #104/#105 (telas "Vagas no DF" e
// "Detalhe da vaga"). O guia de voz (#186) ainda não existe; quando existir, os textos mudam só aqui.

import Foundation
import FrilaDominio

enum TextosDoProfissional {
    enum Lista {
        static let titulo = "Vagas no DF"
        static let qualquerFuncao = "Qualquer função"
        static let qualquerData = "Qualquer data"
        static let hoje = "Hoje"
        static let amanha = "Amanhã"
        static let qualquerDistancia = "Qualquer distância"
        static func ateKm(_ km: Int) -> String { "Até \(km) km" }
        static let vazioTitulo = "Nenhuma vaga aberta"
        static let vazioMensagem = "Mude os filtros ou puxe para atualizar."
        static let erroMensagem = "Não foi possível carregar as vagas."
        static let semPontoDeReferencia = "Complete seu perfil com o ponto de partida para ver as vagas por distância."
        static let perfilIncompativel = "Esta lista é para quem trabalha como profissional."
        static let semConexaoMensagem = "Sem conexão. Tente de novo quando a internet voltar."
    }

    enum Detalhe {
        static let titulo = "Vaga"
        static let quando = "Quando"
        static let horario = "Horário"
        static let valor = "Valor"
        static let posicoes = "Posições"
        static let valorIntegral = "O valor é integral: o Frila não desconta taxa do turno."
        static let incluso = "O que está incluso"
        static let quemRecebe = "Quem recebe você"
        static let traje = "Traje"
        static let urgencia = "Urgência"
        static let urgenciaDetalhe = "quem aceitar primeiro fica com a vaga"
        static let selecao = "Seleção"
        static let selecaoDetalhe = "o estabelecimento escolhe entre os candidatos"
        static func avisoRN10(_ estabelecimento: String) -> String {
            "Ao confirmar, seu telefone e WhatsApp serão mostrados ao \(estabelecimento) para combinar o turno."
        }
        static let candidatar = "Candidatar-me"
        static let denunciar = "Denunciar"
        static let bloquear = "Bloquear"
        static let erroMensagem = "Não foi possível abrir esta vaga."
        static let naoEncontrada = "Esta vaga não está mais disponível."
    }

    /// Candidatura e resultados (#105). "Vaga preenchida" e "Meu turno" vêm do low-fi; inelegível, conta
    /// suspensa e vaga encerrada são textos provisórios autorizados pelo Cauê (o low-fi não tem essas telas).
    enum Candidatura {
        static let enviando = "Enviando candidatura…"
        static let voltarParaLista = "Ver outras vagas perto de você"

        static let confirmadoTitulo = "Você está confirmado"
        static let contato = "Contato"
        static let contatoLiberado = "Liberado com a confirmação. Fica visível até 7 dias depois do turno."
        static let abrirWhatsApp = "Abrir no WhatsApp"

        static let preenchidaTitulo = "Essa vaga já foi preenchida"
        static let preenchidaMensagem = "Outra pessoa aceitou antes. No modo urgência, quem aceita primeiro fica com a vaga. Nada muda na sua reputação."

        static let encerradaTitulo = "Essa vaga não está mais aberta"
        static let encerradaMensagem = "Ela foi cancelada, encerrada ou o horário de início já passou. Nada muda na sua reputação."

        static let sobrepostoTitulo = "Você já tem um turno nesse horário"
        static let sobrepostoMensagem = "O horário desta vaga coincide com um turno seu já confirmado. Não dá para estar em dois turnos ao mesmo tempo."

        static let funcaoTitulo = "Essa vaga pede outra função"
        static let funcaoMensagem = "A função desta vaga não está no seu perfil. Você pode ajustar suas funções no perfil."
        static let inelegivelTitulo = "Você não pode se candidatar a esta vaga"
        static let inelegivelMensagem = "O Frila não aceitou a candidatura para esta vaga."

        static let suspensaTitulo = "Sua conta está suspensa"
        static let suspensaMensagem = "Enquanto a suspensão durar, você não pode se candidatar a vagas. O motivo e o caminho para contestar ficam na área da sua conta."
        static let contestar = "Contestar a suspensão"
        static let contestarEmBreve = "A contestação chega numa próxima versão do app."

        static let naoEncontrada = "Esta vaga não está mais disponível. Volte para a lista e escolha outra."
        static let falha = "Não foi possível enviar a candidatura. Tente de novo."
        static let semConexao = "Sem conexão. A candidatura não foi enviada; tente de novo quando a internet voltar."
    }

    static func simNao(_ valor: Bool) -> String { valor ? "sim" : "não" }

    /// Reputação do estabelecimento vista pelo profissional (US08).
    static func reputacaoDoEstabelecimento(_ reputacao: Reputacao) -> String {
        reputacao.semHistorico ? "Sem histórico" : "Trabalhariam lá de novo: \(reputacao.positivas) de \(reputacao.total)"
    }
}
