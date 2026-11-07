import Foundation
import FrilaDominio

enum TextosApresentacaoERegioes {
    static let titulo = String(localized: "Apresentação e regiões", bundle: bundleApresentacao)
    static let sobreMimTitulo = String(localized: "Sobre mim", bundle: bundleApresentacao)
    static let sobreMimDica = String(localized: "Conte há quanto tempo trabalha, onde já trabalhou e no que você é bom.", bundle: bundleApresentacao)
    static let sobreMimPrompt = String(localized: "Conte sobre você", bundle: bundleApresentacao)

    static let experienciaTitulo = String(localized: "Tempo de experiência", bundle: bundleApresentacao)
    static let experienciaDica = String(localized: "Selecione a faixa que melhor descreve sua trajetória.", bundle: bundleApresentacao)
    static let naoInformado = String(localized: "Não informado", bundle: bundleApresentacao)

    static let ondeTrabalheiTitulo = String(localized: "Onde já trabalhei", bundle: bundleApresentacao)
    static let ondeTrabalheiDica = String(localized: "Pode citar tipos de lugar ('buffet de casamento', 'bar no Sudoeste'). Evite nome e telefone de outras pessoas.", bundle: bundleApresentacao)
    static let ondeTrabalheiPrompt = String(localized: "Locais onde já atuou", bundle: bundleApresentacao)

    static let cursosTitulo = String(localized: "Cursos e certificados", bundle: bundleApresentacao)
    static let cursosDica = String(localized: "Ex.: 'Boas práticas de manipulação de alimentos', 'Curso de coquetelaria'.", bundle: bundleApresentacao)
    static let cursoPrompt = String(localized: "Nome do curso ou certificado", bundle: bundleApresentacao)
    static let adicionarCurso = String(localized: "Adicionar curso", bundle: bundleApresentacao)
    static let removerCurso = String(localized: "Remover curso", bundle: bundleApresentacao)

    static let idiomasTitulo = String(localized: "Idiomas", bundle: bundleApresentacao)
    static let idiomasDica = String(localized: "Selecione os idiomas em que você se comunica.", bundle: bundleApresentacao)

    static let regioesTitulo = String(localized: "Onde atendo", bundle: bundleApresentacao)
    static let regioesDica = String(localized: "Marque só onde você consegue chegar no horário.", bundle: bundleApresentacao)
    static let todoODF = String(localized: "Atender em todo o DF", bundle: bundleApresentacao)
    static let avisoPontoBase = String(localized: "A seleção de regiões define onde você quer atender, mas não altera o ponto base do seu cadastro nem o raio de 15 km do despacho de vagas normais.", bundle: bundleApresentacao)

    static let salvar = String(localized: "Salvar", bundle: bundleApresentacao)
    static let sucessoAoSalvar = String(localized: "Apresentação atualizada com sucesso.", bundle: bundleApresentacao)
    static let editarApresentacao = String(localized: "Editar apresentação e regiões", bundle: bundleApresentacao)
    static let linkApresentacaoSubtitulo = String(localized: "Sobre mim, experiência, cursos e regiões atendidas", bundle: bundleApresentacao)

    // Erros
    static let erroAntiContato = String(localized: "Tire telefone, e-mail, link ou Pix do texto. O Frila não troca contato entre as partes; depois do aceite, o turno mostra endereço e quem recebe.", bundle: bundleApresentacao)
    static let limiteSobreMimExcedido = String(localized: "O texto de Sobre mim não pode passar de 600 caracteres.", bundle: bundleApresentacao)
    static let limiteOndeTrabalheiExcedido = String(localized: "O texto de Onde já trabalhei não pode passar de 400 caracteres.", bundle: bundleApresentacao)
    static let limiteCursosAtingido = String(localized: "Você pode cadastrar no máximo 5 cursos.", bundle: bundleApresentacao)
    static let cursoMuitoLongo = String(localized: "O nome do curso não pode passar de 80 caracteres.", bundle: bundleApresentacao)
    static let erroRegioesInvalidas = String(localized: "Confira as regiões selecionadas.", bundle: bundleApresentacao)
    static let erroSemRede = String(localized: "Sem conexão com a internet. O rascunho continua salvo para tentar novamente.", bundle: bundleApresentacao)
    static let erroSalvar = String(localized: "Não foi possível salvar a apresentação. Verifique sua conexão e tente novamente.", bundle: bundleApresentacao)
    static let erroCarregar = String(localized: "Não foi possível carregar sua apresentação.", bundle: bundleApresentacao)

    static func textoExperiencia(_ faixa: ExperienciaFaixa) -> String {
        switch faixa {
        case .menosDe1Ano: String(localized: "Menos de 1 ano", bundle: bundleApresentacao)
        case .de1A3Anos: String(localized: "1 a 3 anos", bundle: bundleApresentacao)
        case .de3A5Anos: String(localized: "3 a 5 anos", bundle: bundleApresentacao)
        case .de5A10Anos: String(localized: "5 a 10 anos", bundle: bundleApresentacao)
        case .maisDe10Anos: String(localized: "Mais de 10 anos", bundle: bundleApresentacao)
        }
    }

    static func textoIdioma(_ idioma: Idioma) -> String {
        switch idioma {
        case .portugues: String(localized: "Português", bundle: bundleApresentacao)
        case .ingles: String(localized: "Inglês", bundle: bundleApresentacao)
        case .espanhol: String(localized: "Espanhol", bundle: bundleApresentacao)
        case .libras: String(localized: "Libras", bundle: bundleApresentacao)
        case .outro: String(localized: "Outro", bundle: bundleApresentacao)
        }
    }
}
