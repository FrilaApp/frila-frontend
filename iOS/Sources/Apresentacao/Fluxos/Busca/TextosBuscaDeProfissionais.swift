import Foundation
import FrilaDominio

/// Textos da busca de profissionais. Provisórios: as telas são PROVISÓRIAS e o Fabrício troca o texto no high-fi.
public enum TextosBuscaDeProfissionais {
    // MARK: Erros e avisos (usados pelo view model)
    // TODO texto do Fabrício
    public static let limiteDeBuscas = String(localized: "Você fez muitas buscas em pouco tempo. Aguarde um pouco e tente de novo.", bundle: bundleApresentacao)
    // TODO texto do Fabrício
    public static let indisponivel = String(localized: "A busca de profissionais está indisponível no momento.", bundle: bundleApresentacao)
    // TODO texto do Fabrício
    public static let erro = String(localized: "Não foi possível buscar agora. Verifique sua conexão e tente novamente.", bundle: bundleApresentacao)
    // TODO texto do Fabrício
    public static let erroAoCarregarMais = String(localized: "Não foi possível carregar mais profissionais. Tente novamente.", bundle: bundleApresentacao)
    // TODO texto do Fabrício
    public static let limiteDeSelecao = String(localized: "Você pode chamar até 3 profissionais de uma vez.", bundle: bundleApresentacao)
    // TODO texto do Fabrício
    public static let semPermissao = String(localized: "Sua conta não tem permissão para buscar profissionais.", bundle: bundleApresentacao)
    // TODO texto do Fabrício
    public static let contaSuspensa = String(localized: "Sua conta está suspensa e não pode buscar profissionais agora.", bundle: bundleApresentacao)

    // MARK: Tela da busca (provisória)
    public static let titulo = String(localized: "Encontrar profissional", bundle: bundleApresentacao)
    public static let filtros = String(localized: "Filtros", bundle: bundleApresentacao)
    public static let servico = String(localized: "Serviço", bundle: bundleApresentacao)
    public static let escolhaOServico = String(localized: "Escolha um serviço", bundle: bundleApresentacao)
    public static let regiao = String(localized: "Região", bundle: bundleApresentacao)
    public static let regiaoDoEstabelecimento = String(localized: "Região do meu estabelecimento", bundle: bundleApresentacao)
    public static let buscarPorHorario = String(localized: "Buscar por horário", bundle: bundleApresentacao)
    public static let inicio = String(localized: "Início", bundle: bundleApresentacao)
    public static let termino = String(localized: "Término", bundle: bundleApresentacao)
    public static let buscar = String(localized: "Buscar", bundle: bundleApresentacao)
    public static let buscando = String(localized: "Buscando profissionais", bundle: bundleApresentacao)
    /// A mesma chave do catálogo que a presença usa (sem entrada nova).
    public static let enviando = String(localized: "Enviando…", bundle: bundleApresentacao)
    public static let profissionais = String(localized: "Profissionais", bundle: bundleApresentacao)
    public static let disponivelNesseHorario = String(localized: "Disponível nesse horário", bundle: bundleApresentacao)
    public static let semAvaliacoes = String(localized: "Sem avaliações ainda", bundle: bundleApresentacao)
    public static let nenhumEncontrado = String(localized: "Nenhum profissional encontrado com esses filtros. Você pode publicar a vaga para todos.", bundle: bundleApresentacao)
    public static let carregarMais = String(localized: "Carregar mais", bundle: bundleApresentacao)
    public static let tentarDeNovo = String(localized: "Tentar de novo", bundle: bundleApresentacao)
    public static let chamarSelecionados = String(localized: "Chamar selecionados", bundle: bundleApresentacao)
    public static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
    public static func selecionados(_ quantos: Int) -> String {
        String(localized: "\(quantos) de 3 selecionados", bundle: bundleApresentacao)
    }
    public static func selecionar(_ nome: String) -> String {
        String(localized: "Selecionar \(nome)", bundle: bundleApresentacao)
    }
    public static func desmarcar(_ nome: String) -> String {
        String(localized: "Desmarcar \(nome)", bundle: bundleApresentacao)
    }

    // MARK: Folha de chamada e resultado por pessoa
    public static let folhaTitulo = String(localized: "Chamar profissionais", bundle: bundleApresentacao)
    public static let folhaExplicacao = String(localized: "O mesmo valor total e o mesmo horário vão para cada profissional selecionado.", bundle: bundleApresentacao)
    public static let enviarChamadas = String(localized: "Enviar chamadas", bundle: bundleApresentacao)
    public static let resultadoEnviada = String(localized: "Chamada enviada", bundle: bundleApresentacao)
    public static let resultadoPedeConfirmacao = String(localized: "Falta confirmar o aviso da chamada recorrente", bundle: bundleApresentacao)
    public static let resultadoNaoEnviada = String(localized: "Ainda não saiu: o envio ficou incerto. Toque em Chamar selecionados para tentar de novo.", bundle: bundleApresentacao)
    public static let envioIncerto = String(localized: "Um envio ficou incerto e a vaga pode já ter sido criada. Toque em Tentar de novo para concluir antes de buscar ou trocar as pessoas escolhidas.", bundle: bundleApresentacao)
    public static let catalogoIndisponivel = String(localized: "Não foi possível carregar os serviços e as regiões agora. Verifique sua conexão e tente de novo.", bundle: bundleApresentacao)
    public static let resultados = String(localized: "Resultado das chamadas", bundle: bundleApresentacao)

    // MARK: Preferências do profissional
    public static let aceitoChamadas = String(localized: "Aceito chamadas diretas", bundle: bundleApresentacao)
    public static let aceitoChamadasExplicacao = String(localized: "Quem contrata pode te achar na busca e te chamar direto, sem publicar uma vaga.", bundle: bundleApresentacao)
    public static let apareceNaBusca = String(localized: "Você aparece na busca de profissionais.", bundle: bundleApresentacao)
    public static let paraAparecerNaBusca = String(localized: "Para aparecer na busca falta:", bundle: bundleApresentacao)
    public static let pendenciaSemServico = String(localized: "Cadastrar ao menos um serviço com preço.", bundle: bundleApresentacao)
    public static let pendenciaSemRegiao = String(localized: "Marcar uma região de atendimento ou \"Atendo todo o DF\".", bundle: bundleApresentacao)
    public static let pendenciaPausado = String(localized: "Terminar a pausa de novas chamadas.", bundle: bundleApresentacao)
    public static let pendenciaSemAparelho = String(localized: "Atualizar o app em um dos seus aparelhos.", bundle: bundleApresentacao)

    public static func pendencia(_ pendencia: PendenciaParaBusca) -> String {
        switch pendencia {
        case .semServicoComPreco: pendenciaSemServico
        case .semRegiao: pendenciaSemRegiao
        case .pausado: pendenciaPausado
        case .semAparelhoAtualizado: pendenciaSemAparelho
        }
    }
}
