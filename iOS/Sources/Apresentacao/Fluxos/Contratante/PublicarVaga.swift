import FrilaDominio
import MapKit
import Observation
import SwiftUI
import UIKit

private final class MarcadorPublicarVaga: NSObject {}
private let bundlePublicarVaga = Bundle(for: MarcadorPublicarVaga.self)

private enum TextosPublicarVaga {
    static let titulo = String(localized: "Nova vaga", bundle: bundleApresentacao)
    static let funcao = String(localized: "Função", bundle: bundleApresentacao)
    static let selecioneFuncao = String(localized: "Selecione uma função", bundle: bundleApresentacao)
    static let dataInicio = String(localized: "Início", bundle: bundleApresentacao)
    static let dataFim = String(localized: "Fim", bundle: bundleApresentacao)
    static let quando = String(localized: "Quando", bundle: bundleApresentacao)
    static let hoje = String(localized: "Hoje", bundle: bundleApresentacao)
    static let amanha = String(localized: "Amanhã", bundle: bundleApresentacao)
    static let terminaNoMesmoDia = String(localized: "Termina no mesmo dia: %@, às %@.", bundle: bundleApresentacao)
    static let terminaNoDiaSeguinte = String(localized: "Termina no dia seguinte: %@, às %@.", bundle: bundleApresentacao)
    static let terminaEm = String(localized: "Termina em %@, às %@.", bundle: bundleApresentacao)
    static let local = String(localized: "Local", bundle: bundleApresentacao)
    static let endereco = String(localized: "Endereço do turno", bundle: bundleApresentacao)
    static let enderecoAjuda = String(localized: "Ponto confirmado no mapa no cadastro. O check-in dos profissionais usa este ponto.", bundle: bundleApresentacao)
    static let valor = String(localized: "Valor por pessoa", bundle: bundleApresentacao)
    static let valorExemplo = String(localized: "R$ 0,00", bundle: bundleApresentacao)
    static let formatoValor = String(localized: "R$ %d,%02d", bundle: bundleApresentacao)
    static let valorAjuda = String(localized: "O profissional recebe o valor integral", bundle: bundleApresentacao)
    static let posicoes = String(localized: "Posições", bundle: bundleApresentacao)
    static let ajustarPosicoes = String(localized: "Ajustar posições", bundle: bundleApresentacao)
    static let posicoesExemplo = String(localized: "1", bundle: bundleApresentacao)
    static let totalDaVaga = String(localized: "Total da vaga: %@", bundle: bundleApresentacao)
    static let inclusos = String(localized: "Inclusos e o que levar", bundle: bundleApresentacao)
    static let refeicao = String(localized: "Refeição inclusa", bundle: bundleApresentacao)
    static let transporte = String(localized: "Transporte incluso", bundle: bundleApresentacao)
    static let material = String(localized: "Precisa levar material", bundle: bundleApresentacao)
    static let sim = String(localized: "Sim", bundle: bundleApresentacao)
    static let nao = String(localized: "Não", bundle: bundleApresentacao)
    static let responsavel = String(localized: "Quem recebe o profissional no local", bundle: bundleApresentacao)
    static let alerta = String(localized: "Avisar se a vaga seguir vazia", bundle: bundleApresentacao)
    static let alertaTresHoras = String(localized: "3 horas antes", bundle: bundleApresentacao)
    static let alertaDuasHoras = String(localized: "2 horas antes", bundle: bundleApresentacao)
    static let alertaSeisHoras = String(localized: "6 horas antes", bundle: bundleApresentacao)
    static let maisOpcoes = String(localized: "Mais opções", bundle: bundleApresentacao)
    static let maisOpcoesAjuda = String(localized: "Traje, rateio dos 10% e observações", bundle: bundleApresentacao)
    static let traje = String(localized: "Traje", bundle: bundleApresentacao)
    static let rateio = String(localized: "Participa do rateio dos 10%", bundle: bundleApresentacao)
    static let observacoes = String(localized: "Observações", bundle: bundleApresentacao)
    static let telefoneResponsavel = String(localized: "Telefone do responsável", bundle: bundleApresentacao)
    static let publicar = String(localized: "Publicar vaga", bundle: bundleApresentacao)
    static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleApresentacao)
    static let avisoRN10 = String(localized: "Após a confirmação, o telefone do responsável será mostrado ao profissional para combinar o turno.", bundle: bundleApresentacao)
    static let campoObrigatorio = String(localized: "Preencha este campo.", bundle: bundleApresentacao)
    static let campoInvalido = String(localized: "Confira o valor informado.", bundle: bundleApresentacao)
    static let erroPublicar = String(localized: "Não foi possível publicar a vaga. Tente novamente.", bundle: bundleApresentacao)
    static let semFuncoes = String(localized: "Não foi possível carregar as funções.", bundle: bundleApresentacao)
    static let funcaoCampo = String(localized: "Escolha uma função.", bundle: bundleApresentacao)
    static let localCampo = String(localized: "Informe o endereço.", bundle: bundleApresentacao)
    static let valorCampo = String(localized: "Informe um valor maior que zero.", bundle: bundleApresentacao)
    static let posicoesCampo = String(localized: "Informe de 1 a 200 posições.", bundle: bundleApresentacao)
    static let horarioCampo = String(localized: "O fim precisa ser depois do início, e o início deve estar no futuro.", bundle: bundleApresentacao)
    static let estabelecimentoCampo = String(localized: "Não encontramos o estabelecimento cadastrado.", bundle: bundleApresentacao)
    static let responsavelCampo = String(localized: "Informe quem recebe o profissional no local.", bundle: bundleApresentacao)
    static let falhaFila = String(localized: "Não foi possível guardar a publicação neste aparelho.", bundle: bundleApresentacao)
    static let verificandoPendente = String(localized: "Verificando publicação pendente…", bundle: bundleApresentacao)
    static let pendenteDescricao = String(localized: "Há uma publicação pendente. Tente novamente para concluir sem criar outra vaga.", bundle: bundleApresentacao)
    static let modo = String(localized: "Como preencher a vaga", bundle: bundleApresentacao)
    static let modoUrgencia = String(localized: "Urgência", bundle: bundleApresentacao)
    static let modoSelecao = String(localized: "Seleção", bundle: bundleApresentacao)
    static let modoUrgenciaExplicacao = String(localized: "O primeiro profissional que aceitar é confirmado na hora.", bundle: bundleApresentacao)
    static let modoSelecaoExplicacao = String(localized: "Você escolhe entre os candidatos. O início precisa estar a mais de 24 horas, e a vaga fecha sozinha 24 horas antes se ninguém for escolhido.", bundle: bundleApresentacao)
    static let modoIndisponivel = String(localized: "O modo seleção ainda não está disponível. Publique no modo urgência.", bundle: bundleApresentacao)
    /// MS-RF01: a opção Seleção só aparece com o início a mais de 24 horas (RN24).
    static let modoSelecaoSoComAntecedencia = String(localized: "A seleção fica disponível para vagas que começam em mais de 24 horas.", bundle: bundleApresentacao)
    /// D2 (0.2.38): o prazo exato de escolha, mostrado na publicação.
    static let modoSelecaoPrazo = String(localized: "Você terá até %@ para escolher. Depois disso a vaga fecha sozinha.", bundle: bundleApresentacao)
    static let modoSelecaoPrazoCurto = String(localized: "Prazo curto: você terá menos de 12 horas para escolher antes de a vaga fechar.", bundle: bundleApresentacao)
    static let voltar = String(localized: "Voltar", bundle: bundleApresentacao)
    static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    static let publicacaoContinua = String(localized: "A publicação continua e será concluída quando a conexão voltar.", bundle: bundleApresentacao)
    static let menosTresHorasTitulo = String(localized: "Começa em menos de 3 horas.", bundle: bundleApresentacao)
    static let menosTresHorasCorpo = String(localized: "Não haverá o aviso de 3 h antes: enquanto seguir vazia, a vaga fica em Precisa de atenção, em Minhas vagas.", bundle: bundleApresentacao)
    static let resumoSingular = String(localized: "%d posição · %@ · %@, %@ às %@", bundle: bundleApresentacao)
    static let resumoPlural = String(localized: "%d posições · %@ · %@, %@ às %@", bundle: bundleApresentacao)
    static let escolhaFuncao = String(localized: "Escolha a função", bundle: bundleApresentacao)
    static let resumoTotalSingular = String(localized: "Valor de 1 pessoa, pago direto a ela", bundle: bundleApresentacao)
    static let resumoTotalPlural = String(localized: "Soma de %d pessoas, pago direto a cada uma", bundle: bundleApresentacao)
}

public enum CampoPublicacaoVaga: String, CaseIterable, Sendable {
    case estabelecimento
    case funcao
    case inicio
    case fim
    case local
    case ponto
    case valor
    case posicoes
    case responsavel
    case inclusos
    case traje
    case rateio
    case observacoes
    case modo
}

@MainActor @Observable
public final class PublicarVagaViewModel {
    public var estabelecimento: Estabelecimento?
    public var funcoes: [Funcao]
    public var funcaoID: UUID?
    public var inicio: Date {
        didSet {
            let duracao = fim.timeIntervalSince(oldValue)
            if duracao > 0 {
                fim = inicio.addingTimeInterval(duracao)
            }
            ajustarModoAoInicio()
        }
    }
    public var fim: Date
    public var local: String
    public var valorTexto = ""
    public var posicoesTexto = "1"
    public var refeicao = false
    public var transporte = false
    public var materialProprio = false
    public var responsavelLocal = ""
    public var alertaAntecedenciaMinutos = 180
    /// Urgência confirma o primeiro que aceitar; seleção deixa a casa escolher entre os candidatos (RN24).
    public var modo = ModoPreenchimento.urgencia
    public var traje = ""
    public var participaRateio: Bool? = false
    public var observacoes = ""
    public var mostrandoMaisOpcoes = false
    public private(set) var carregandoFuncoes = false
    public private(set) var enviando = false
    public private(set) var erros: [CampoPublicacaoVaga: String] = [:]
    public private(set) var mensagemErro: String?
    public private(set) var recusaDaFila: AcaoRecusada?
    public private(set) var resultado: VagaPublicada?
    public private(set) var publicacaoPendente: PublicacaoVaga?
    public private(set) var restaurandoPublicacao: Bool

    private let carregar: @Sendable () async throws -> [Funcao]
    private let publicarAPI: @Sendable (PublicacaoVaga) async throws -> VagaPublicada
    private let fila: any FilaDeAcoes
    private var acaoPendente: AcaoPendente?
    private let agora: @Sendable () -> Date

    public init(api: any ApiCliente, fila: any FilaDeAcoes, estabelecimento: Estabelecimento, agora: @escaping @Sendable () -> Date = Date.init) {
        self.estabelecimento = estabelecimento
        funcoes = []
        funcaoID = nil
        let inicioPadrao = agora().addingTimeInterval(3 * 60 * 60)
        inicio = inicioPadrao
        fim = inicioPadrao.addingTimeInterval(3 * 60 * 60)
        local = estabelecimento.endereco
        self.fila = fila
        self.agora = agora
        restaurandoPublicacao = true
        carregar = { try await api.funcoes() }
        publicarAPI = { try await api.publicarVaga($0) }
    }

    public init(
        estabelecimento: Estabelecimento?,
        funcoes: [Funcao] = [],
        fila: any FilaDeAcoes,
        agora: @escaping @Sendable () -> Date = Date.init,
        publicar: @escaping @Sendable (PublicacaoVaga) async throws -> VagaPublicada
    ) {
        self.estabelecimento = estabelecimento
        self.funcoes = funcoes
        funcaoID = nil
        let inicioPadrao = agora().addingTimeInterval(3 * 60 * 60)
        inicio = inicioPadrao
        fim = inicioPadrao.addingTimeInterval(3 * 60 * 60)
        local = estabelecimento?.endereco ?? ""
        self.fila = fila
        self.agora = agora
        restaurandoPublicacao = false
        carregar = { funcoes }
        publicarAPI = publicar
    }

    public var camposBloqueados: Bool { publicacaoPendente != nil }
    public var valorCentavos: Int { Int(valorTexto.filter(\.isNumber)) ?? 0 }
    public var valorTotalCentavos: Int {
        guard let posicoes = Int(posicoesTexto), posicoes > 0 else { return 0 }
        return valorCentavos * posicoes
    }

    private var posicoesValidas: Int? {
        guard let valor = Int(posicoesTexto), valor >= 1 else { return nil }
        return min(valor, 200)
    }

    public func incrementarPosicoes() {
        guard let atual = posicoesValidas else {
            posicoesTexto = "1"
            return
        }
        if atual < 200 {
            posicoesTexto = String(atual + 1)
        } else {
            posicoesTexto = "200"
        }
    }

    public func decrementarPosicoes() {
        guard let atual = posicoesValidas else {
            posicoesTexto = "1"
            return
        }
        if atual > 1 {
            posicoesTexto = String(atual - 1)
        } else {
            posicoesTexto = "1"
        }
    }
    public var textoAoFechar: String {
        (publicacaoPendente != nil || resultado != nil) ? TextosPublicarVaga.voltar : TextosPublicarVaga.cancelar
    }
    public var mostraAvisoPublicacaoContinua: Bool {
        publicacaoPendente != nil && resultado == nil && !enviando
    }

    public func fecharAvisoDaFila() async {
        guard let recusa = recusaDaFila else { return }
        do {
            try await fila.reconhecerRecusa(id: recusa.id)
            await carregarRecusaDaFila()
        } catch { /* Mantém o aviso se o reconhecimento não foi gravado. */ }
    }

    public func carregarRecusaDaFila() async {
        let recusadas = (try? await fila.recusadas().filter { $0.tipo == .publicacaoVaga && $0.estabelecimentoID == estabelecimento?.id }) ?? []
        recusaDaFila = recusadas.first { $0.id == acaoPendente?.id } ?? recusadas.first
        if let recusaDaFila, acaoPendente?.id == recusaDaFila.id {
            acaoPendente = nil
            publicacaoPendente = nil
        }
    }

    public func restaurarPublicacaoPendente() async {
        await carregarRecusaDaFila()
        restaurandoPublicacao = true
        defer { restaurandoPublicacao = false }
        do {
            let pendentes = try await fila.pendentes()
            if let estabelecimentoID = estabelecimento?.id,
               let acao = pendentes.first(where: {
                   $0.tipo == .publicacaoVaga && $0.publicacao?.estabelecimentoID == estabelecimentoID
               }), let publicacao = acao.publicacao {
                acaoPendente = acao
                publicacaoPendente = publicacao
                preencherComPublicacao(publicacao)
            }
        } catch {
            mensagemErro = TextosPublicarVaga.falhaFila
        }
    }

    private func preencherComPublicacao(_ publicacao: PublicacaoVaga) {
        funcaoID = publicacao.funcaoID
        inicio = publicacao.periodo.inicio
        fim = publicacao.periodo.fim
        local = publicacao.local
        valorTexto = String(publicacao.valor.centavos)
        posicoesTexto = String(publicacao.posicoes)
        refeicao = publicacao.inclusos.refeicao
        transporte = publicacao.inclusos.transporte
        materialProprio = publicacao.inclusos.exigeMaterialProprio
        responsavelLocal = publicacao.responsavelLocal
        traje = publicacao.traje ?? ""
        participaRateio = publicacao.participaRateio
        observacoes = publicacao.observacoes ?? ""
        modo = publicacao.modo
        if let alerta = publicacao.alertaAntecedenciaMinutos {
            alertaAntecedenciaMinutos = alerta
        }
        if !(publicacao.traje ?? "").isEmpty || !(publicacao.observacoes ?? "").isEmpty || (publicacao.participaRateio == true) {
            mostrandoMaisOpcoes = true
        }
    }

    public func carregarFuncoes() async {
        guard funcoes.isEmpty, !carregandoFuncoes else { return }
        carregandoFuncoes = true
        defer { carregandoFuncoes = false }
        do {
            funcoes = try await carregar()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-FRILA_CADASTRO_UI_TEST") {
                if funcaoID == nil, let primeira = funcoes.first {
                    funcaoID = primeira.id
                }
                if valorTexto.isEmpty { valorTexto = "14000" }
                if responsavelLocal.isEmpty { responsavelLocal = "Gerente de Teste" }
                // `-FRILA_PUBLICAR_INICIO_EM_HORAS <n>`: o início daqui a n horas, para o teste de
                // interface ver a opção Seleção com e sem as 24 horas.
                let argumentos = ProcessInfo.processInfo.arguments
                if let indice = argumentos.firstIndex(of: "-FRILA_PUBLICAR_INICIO_EM_HORAS"), argumentos.indices.contains(indice + 1),
                   let horas = Double(argumentos[indice + 1]) {
                    inicio = agora().addingTimeInterval(horas * 60 * 60)
                }
            }
            #endif
        }
        catch { mensagemErro = TextosPublicarVaga.semFuncoes }
    }

    public func validar() -> Bool {
        erros = [:]
        if estabelecimento == nil { erros[.estabelecimento] = TextosPublicarVaga.estabelecimentoCampo }
        if !funcoes.contains(where: { $0.id == funcaoID }) { erros[.funcao] = TextosPublicarVaga.funcaoCampo }
        if inicio <= agora() { erros[.inicio] = TextosPublicarVaga.horarioCampo }
        // RN24: a vaga de seleção fecha 24 h antes do início; com 24 h ou menos ela nasceria fechada,
        // e o servidor a recusa. O relógio que vale é o dele: esta conferência só poupa a viagem.
        else if modo == .selecao, inicio <= agora().addingTimeInterval(Self.antecedenciaDaSelecao) {
            erros[.inicio] = TextosRepublicarVaga.selecaoSemAntecedencia
        }
        if fim <= inicio { erros[.fim] = TextosPublicarVaga.horarioCampo }
        if local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { erros[.local] = TextosPublicarVaga.localCampo }
        if estabelecimento?.ponto.latitude.isFinite != true || estabelecimento?.ponto.longitude.isFinite != true {
            erros[.ponto] = TextosPublicarVaga.estabelecimentoCampo
        }
        if valorCentavos < 1 { erros[.valor] = TextosPublicarVaga.valorCampo }
        if let posicoes = Int(posicoesTexto), (1...200).contains(posicoes) == false { erros[.posicoes] = TextosPublicarVaga.posicoesCampo }
        else if Int(posicoesTexto) == nil { erros[.posicoes] = TextosPublicarVaga.posicoesCampo }
        if responsavelLocal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { erros[.responsavel] = TextosPublicarVaga.responsavelCampo }
        return erros.isEmpty
    }

    public func publicar() async {
        guard !enviando, !restaurandoPublicacao else { return }
        if publicacaoPendente == nil {
            guard validar(), let estabelecimento, let funcao = funcoes.first(where: { $0.id == funcaoID }),
                  let periodo = try? Periodo(inicio: inicio, fim: fim),
                  let ponto = try? Coordenada(latitude: estabelecimento.ponto.latitude, longitude: estabelecimento.ponto.longitude)
            else { return }
            let nova = PublicacaoVaga(
                estabelecimentoID: estabelecimento.id,
                funcaoID: funcao.id,
                periodo: periodo,
                local: local.trimmingCharacters(in: .whitespacesAndNewlines),
                // Contrato 0.2.20: a região do turno vem preenchida com a do estabelecimento.
                regiaoAdministrativa: estabelecimento.regiaoAdministrativa,
                ponto: ponto,
                valor: Dinheiro(centavos: valorCentavos),
                posicoes: Int(posicoesTexto) ?? 1,
                inclusos: Inclusos(refeicao: refeicao, transporte: transporte, exigeMaterialProprio: materialProprio),
                responsavelLocal: responsavelLocal.trimmingCharacters(in: .whitespacesAndNewlines),
                traje: traje.trimmingCharacters(in: .whitespacesAndNewlines).nilSeVazio,
                participaRateio: participaRateio,
                observacoes: observacoes.trimmingCharacters(in: .whitespacesAndNewlines).nilSeVazio,
                modo: modo,
                alertaAntecedenciaMinutos: alertaAntecedenciaMinutos,
                chave: UUID()
            )
            publicacaoPendente = nova
            acaoPendente = AcaoPendente(tipo: .publicacaoVaga, instanteDoToque: agora(), chave: nova.chave, publicacao: nova)
        }
        guard let acaoPendente, let publicacao = publicacaoPendente else { return }
        enviando = true
        mensagemErro = nil
        defer { enviando = false }
        do {
            try await fila.enfileirar(acaoPendente)
        } catch {
            publicacaoPendente = nil
            self.acaoPendente = nil
            mensagemErro = TextosPublicarVaga.falhaFila
            return
        }
        do {
            resultado = try await publicarAPI(publicacao)
            try? await fila.resolverRecusas(acaoPendente)
            recusaDaFila = nil
            try? await fila.remover(id: acaoPendente.id)
            publicacaoPendente = nil
            self.acaoPendente = nil
        } catch let erro as ErroDaApi {
            if erro.codigo == .semRede {
                // Sem rede: a publicação continua na fila em segundo plano.
                // Não define mensagemErro para exibir apenas o aviso azul de continuação.
                mensagemErro = nil
            } else {
                tratar(erro)
                if erro.codigo.recusaDefinitivaDePublicacao {
                    try? await fila.remover(id: acaoPendente.id)
                    publicacaoPendente = nil
                    self.acaoPendente = nil
                }
            }
        } catch is URLError {
            // Falha de rede: continua na fila sem erro vermelho.
            mensagemErro = nil
        } catch {
            mensagemErro = TextosPublicarVaga.erroPublicar
        }
    }

    private static let antecedenciaDaSelecao = RegraDaSelecao.antecedencia
    /// D2: abaixo disso a janela de escolha é "curta" e o formulário avisa. Inferência do app: o
    /// requisito pede o aviso sem fixar o limite.
    static let janelaDeEscolhaCurta: TimeInterval = 12 * 60 * 60

    /// MS-RF01: a opção Seleção só é oferecida com o início a mais de 24 horas do relógio do
    /// aparelho; o servidor continua recusando se o pedido chegar (`422 selecao_sem_antecedencia`).
    public var selecaoDisponivel: Bool {
        inicio > agora().addingTimeInterval(Self.antecedenciaDaSelecao)
    }

    /// D2 (MS-RF02): até quando a casa escolhe, 24 h antes do início; `nil` fora do modo seleção.
    public var prazoDeEscolha: Date? {
        guard modo == .selecao, selecaoDisponivel else { return nil }
        return RegraDaSelecao.prazoDeEscolha(inicio: inicio)
    }

    /// A vaga nasce com menos de 12 horas para escolher: o formulário avisa antes de publicar.
    public var janelaDeEscolhaCurta: Bool {
        guard let prazo = prazoDeEscolha else { return false }
        return prazo.timeIntervalSince(agora()) < Self.janelaDeEscolhaCurta
    }

    /// O início mudou: se a seleção deixou de caber, o modo volta a urgência, que é o que a tela
    /// oferece. Chamado pela tela a cada mudança do início.
    public func ajustarModoAoInicio() {
        if modo == .selecao, !selecaoDisponivel { modo = .urgencia }
    }

    private func tratar(_ erro: ErroDaApi) {
        if erro.codigo == .selecaoSemAntecedencia {
            // O servidor conta as 24 horas pelo relógio dele, que pode não ser o do aparelho.
            erros[.inicio] = TextosRepublicarVaga.selecaoSemAntecedencia
            mensagemErro = TextosRepublicarVaga.selecaoSemAntecedencia
        } else if erro.codigo == .campoInvalido, erro.detalhes == "modo" {
            // Até o contrato 0.2.23 o servidor recusava o modo seleção assim.
            erros[.modo] = TextosPublicarVaga.modoIndisponivel
            mensagemErro = TextosPublicarVaga.modoIndisponivel
        } else if erro.codigo == .campoObrigatorio || erro.codigo == .campoInvalido {
            if let campo = Self.campo(erro.detalhes) {
                erros[campo] = erro.codigo == .campoObrigatorio ? TextosPublicarVaga.campoObrigatorio : TextosPublicarVaga.campoInvalido
            } else {
                mensagemErro = TextosPublicarVaga.erroPublicar
            }
        } else if erro.codigo == .horarioInvalido {
            erros[.inicio] = TextosPublicarVaga.horarioCampo
            erros[.fim] = TextosPublicarVaga.horarioCampo
        } else if erro.codigo == .semRede {
            mensagemErro = nil
        } else {
            mensagemErro = TextosPublicarVaga.erroPublicar
        }
    }

    private static func campo(_ nome: String?) -> CampoPublicacaoVaga? {
        switch nome {
        case "estabelecimento_id": .estabelecimento
        case "funcao_id": .funcao
        case "inicio_em": .inicio
        case "fim_em": .fim
        case "local": .local
        case "ponto", "latitude", "longitude": .ponto
        case "valor_centavos": .valor
        case "posicoes": .posicoes
        case "responsavel_local": .responsavel
        case "inclui_refeicao", "inclui_transporte", "exige_material_proprio": .inclusos
        case "traje": .traje
        case "participa_rateio": .rateio
        case "observacoes": .observacoes
        case "modo": .modo
        default: nil
        }
    }
}

private extension String {
    var nilSeVazio: String? { isEmpty ? nil : self }
}

private struct AvisoNeutroLocal: View {
    let icone: String
    let texto: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityHidden(true)
            Text(verbatim: texto)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .background(FrilaCor.controle, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
    }
}

/// Formulário de publicar vaga, nos campos e cartões dos quadros "Publicar" e "PublicarCopia" do MidFi do Fabrício.
public struct TelaPublicarVaga: View {
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: PublicarVagaViewModel
    @State private var regiaoMapa: MKCoordinateRegion
    private let telefoneResponsavel: String
    private let api: any ApiCliente
    private let sair: () -> Void
    private let aoPublicar: () -> Void
    private let aoCancelar: (() -> Void)?
    @State private var mostrandoPerfilEstabelecimento = false
    @State private var tentativaEnvio = 0
    @Environment(PermissaoDePushModelo.self) private var permissaoDePush: PermissaoDePushModelo?

    public init(api: any ApiCliente, fila: any FilaDeAcoes, estabelecimento: Estabelecimento, telefoneResponsavel: String, sair: @escaping () -> Void = {}, aoPublicar: @escaping () -> Void = {}, aoCancelar: (() -> Void)? = nil) {
        self.api = api
        self.sair = sair
        self.aoPublicar = aoPublicar
        self.aoCancelar = aoCancelar
        _model = State(initialValue: PublicarVagaViewModel(api: api, fila: fila, estabelecimento: estabelecimento))
        _regiaoMapa = State(initialValue: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: estabelecimento.ponto.latitude, longitude: estabelecimento.ponto.longitude), span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)))
        self.telefoneResponsavel = telefoneResponsavel
    }

    public var body: some View {
        NavigationStack {
            formulario
                .toolbar {
                    // Quem veio de Minhas vagas tem para onde voltar; no primeiro acesso, não.
                    if let aoCancelar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: aoCancelar) {
                                Text(verbatim: model.textoAoFechar)
                                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityShowsLargeContentViewer {
                                Text(verbatim: model.textoAoFechar)
                            }
                            .disabled(model.enviando || model.restaurandoPublicacao)
                            .accessibilityIdentifier("cancelar-publicacao")
                        }
                    }
                    if aoCancelar == nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { mostrandoPerfilEstabelecimento = true } label: {
                                Image(systemName: "building.2.crop.circle")
                                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                            }
                            .accessibilityLabel(String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao))
                            .accessibilityShowsLargeContentViewer()
                        }
                    }
                }
        }
        .sheet(isPresented: $mostrandoPerfilEstabelecimento) {
            NavigationStack {
                TelaPerfilEstabelecimento(api: api, sair: sair)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                mostrandoPerfilEstabelecimento = false
                            } label: {
                                Text("Fechar", bundle: bundleApresentacao)
                                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                            }
                            .accessibilityShowsLargeContentViewer()
                        }
                    }
            }
        }
        // A vaga publicada é o momento de explicar a notificação a quem contrata (#8): é por ela
        // que chega o aviso de quem aceitou.
        .onChange(of: model.resultado != nil) { _, publicou in
            if publicou { Task { await permissaoDePush?.oferecer() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await model.carregarRecusaDaFila() }
        }
        .onChange(of: model.resultado != nil) { _, publicado in
            if publicado {
                aoPublicar()
            }
        }
    }

    private var formulario: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grande) {
                    avisosDeTopo

                    secaoFuncao
                        .id("campo-funcao")

                    secaoQuando
                        .id("campo-quando")

                    secaoLocal
                        .id("campo-local")

                    secaoPosicoesEValor

                    secaoInclusos
                        .id("campo-inclusos")

                    secaoResponsavel
                        .id("campo-responsavel")

                    secaoModo
                        .id("campo-modo")

                    secaoAlerta

                    secaoMaisOpcoes

                    secaoContato
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.top, FrilaEspaco.medio)
                .padding(.bottom, FrilaEspaco.enorme)
                .containerRelativeFrame(.horizontal)
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationTitle(Text(verbatim: TextosPublicarVaga.titulo))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(model.enviando || model.restaurandoPublicacao)
            .accessibilityIdentifier("publicar-vaga-formulario")
            .barraInferiorFixa {
                barraInferiorConteudo
            }
            .onChange(of: tentativaEnvio) { _, _ in
                rolarParaPrimeiroErro(proxy: proxy)
            }
            .task {
                await model.restaurarPublicacaoPendente()
                await model.carregarFuncoes()
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                let modoCaptura: String? = {
                    if let idx = args.firstIndex(of: "-FRILA_CAPTURA"), idx + 1 < args.count {
                        return args[idx + 1]
                    }
                    for arg in args where arg.hasPrefix("-FRILA_CAPTURA=") {
                        return String(arg.dropFirst("-FRILA_CAPTURA=".count))
                    }
                    return nil
                }()
                if let modoCaptura {
                    if modoCaptura == "menos3h" {
                        model.inicio = Date().addingTimeInterval(2 * 60 * 60)
                    } else if modoCaptura == "erro-funcao" {
                        model.funcaoID = nil
                        _ = model.validar()
                        tentativaEnvio += 1
                    } else if modoCaptura == "meio" {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        proxy.scrollTo("campo-local", anchor: .top)
                    }
                }
                #endif
            }
        }
    }

    @ViewBuilder
    private var avisosDeTopo: some View {
        if model.restaurandoPublicacao {
            AvisoNeutroLocal(icone: "arrow.triangle.2.circlepath", texto: TextosPublicarVaga.verificandoPendente)
        } else if model.camposBloqueados {
            AvisoNeutroLocal(icone: "info.circle", texto: TextosPublicarVaga.pendenteDescricao)
        }
        if let erro = model.erros[.estabelecimento] {
            AvisoNeutroLocal(icone: "exclamationmark.triangle", texto: erro)
        }
        if let recusa = model.recusaDaFila {
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                AvisoNeutroLocal(icone: "exclamationmark.triangle", texto: TextosDaFila.texto(recusa.tipo))
                    .accessibilityIdentifier("aviso-publicacao-recusada")
                BotaoSecundario(verbatim: String(localized: "Fechar", bundle: bundleApresentacao)) { Task { await model.fecharAvisoDaFila() } }
                    .accessibilityIdentifier("fechar-aviso-publicacao-recusada")
            }
        }
        if let erro = model.mensagemErro {
            AvisoNeutroLocal(icone: "exclamationmark.triangle", texto: erro)
                .accessibilityIdentifier("aviso-erro-publicacao")
        }
        if model.mostraAvisoPublicacaoContinua {
            AvisoNeutroLocal(icone: "wifi.slash", texto: TextosPublicarVaga.publicacaoContinua)
                .accessibilityIdentifier("aviso-publicacao-continua")
        }
    }

    @ViewBuilder
    private var secaoFuncao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.funcao)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            Picker(TextosPublicarVaga.funcao, selection: $model.funcaoID) {
                Text(verbatim: TextosPublicarVaga.selecioneFuncao).tag(UUID?.none)
                ForEach(model.funcoes) { funcao in
                    Text(verbatim: funcao.nome).tag(Optional(funcao.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(FrilaCor.texto)
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                    .strokeBorder(model.erros[.funcao] != nil ? FrilaCor.texto : FrilaCor.borda, lineWidth: model.erros[.funcao] != nil ? 2 : 1)
            )
            .accessibilityLabel(Text(verbatim: TextosPublicarVaga.funcao))
            .accessibilityIdentifier("funcao-vaga-picker")
            .disabled(model.camposBloqueados)

            mensagemDeErroAbaixo(model.erros[.funcao], identifier: "erro-publicacao-funcao")
        }
    }

    @ViewBuilder
    private var secaoQuando: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.quando)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            HStack(spacing: FrilaEspaco.pequeno) {
                chipData(rotulo: TextosPublicarVaga.hoje, selecionado: isHoje) {
                    selecionarDiaHoje()
                }
                chipData(rotulo: TextosPublicarVaga.amanha, selecionado: isAmanha) {
                    selecionarDiaAmanha()
                }
            }
            .disabled(model.camposBloqueados)

            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                datePicker(TextosPublicarVaga.dataInicio, date: $model.inicio, field: .inicio)
                datePicker(TextosPublicarVaga.dataFim, date: $model.fim, field: .fim)
            }
            .onChange(of: model.inicio) { _, _ in
                model.ajustarModoAoInicio()
            }

            if let ajuda = ajudaTermino {
                HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
                    Image(systemName: ajuda.icone)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityHidden(true)
                    Text(verbatim: ajuda.texto)
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
            }

            mensagemDeErroAbaixo(model.erros[.inicio], identifier: "erro-publicacao-inicio")
            mensagemDeErroAbaixo(model.erros[.fim], identifier: "erro-publicacao-fim")
        }
    }

    private func datePicker(_ titulo: String, date: Binding<Date>, field: CampoPublicacaoVaga) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: titulo)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            if dynamicTypeSize.isAccessibilitySize {
                DatePicker(titulo, selection: date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .tint(FrilaCor.texto)
                    .accessibilityIdentifier("datepicker-\(field.rawValue)")
            } else {
                DatePicker(titulo, selection: date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(FrilaCor.texto)
                    .accessibilityIdentifier("datepicker-\(field.rawValue)")
            }
        }
        .disabled(model.camposBloqueados)
    }

    @ViewBuilder
    private var secaoLocal: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.local)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            HStack(alignment: .top, spacing: FrilaEspaco.medio) {
                Image(systemName: "mappin")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 20, alignment: .center)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: model.estabelecimento?.nome ?? "")
                        .font(FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)

                    TextField(
                        TextosPublicarVaga.endereco,
                        text: $model.local
                    )
                    .textFieldStyle(.plain)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .accessibilityLabel(Text(verbatim: TextosPublicarVaga.endereco))
                }
            }
            .padding(FrilaEspaco.medio)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                    .strokeBorder((model.erros[.local] != nil) ? FrilaCor.texto : FrilaCor.divisoria, lineWidth: (model.erros[.local] != nil) ? 2 : 1)
            )

            Map(initialPosition: .region(regiaoMapa)) {
                Marker(model.estabelecimento?.nome ?? "", coordinate: CLLocationCoordinate2D(latitude: regiaoMapa.center.latitude, longitude: regiaoMapa.center.longitude))
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                    .strokeBorder(FrilaCor.borda, lineWidth: 1)
            )
            .allowsHitTesting(false)

            Text(verbatim: TextosPublicarVaga.enderecoAjuda)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)

            mensagemDeErroAbaixo(model.erros[.local], identifier: "erro-publicacao-local")
            mensagemDeErroAbaixo(model.erros[.ponto], identifier: "erro-publicacao-ponto")
        }
    }

    @ViewBuilder
    private var secaoPosicoesEValor: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                blocoPosicoes
                    .id("campo-posicoes")
                blocoValor
                    .id("campo-valor")
            }
        } else {
            HStack(alignment: .top, spacing: FrilaEspaco.medio) {
                blocoPosicoes
                    .id("campo-posicoes")
                blocoValor
                    .id("campo-valor")
            }
        }
    }

    private var blocoPosicoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.posicoes)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            HStack(spacing: FrilaEspaco.minimo) {
                CampoPosicoesVaga(texto: $model.posicoesTexto)
                    .frame(minHeight: FrilaMetrica.alturaDoCampo)
                    .accessibilityLabel(Text(verbatim: TextosPublicarVaga.posicoes))
                    .accessibilityIdentifier("posicoes-vaga-campo")
                Stepper(
                    "",
                    onIncrement: { model.incrementarPosicoes() },
                    onDecrement: { model.decrementarPosicoes() }
                )
                .labelsHidden()
                .accessibilityLabel(Text(verbatim: TextosPublicarVaga.ajustarPosicoes))
                .accessibilityValue(Text(verbatim: model.posicoesTexto))
                .accessibilityIdentifier("posicoes-vaga-stepper")
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                    .strokeBorder(model.erros[.posicoes] != nil ? FrilaCor.texto : FrilaCor.borda, lineWidth: model.erros[.posicoes] != nil ? 2 : 1)
            )
            .disabled(model.camposBloqueados)

            mensagemDeErroAbaixo(model.erros[.posicoes], identifier: "erro-publicacao-posicoes")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blocoValor: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.valor)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            CampoValorVaga(texto: $model.valorTexto)
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                        .strokeBorder(model.erros[.valor] != nil ? FrilaCor.texto : FrilaCor.borda, lineWidth: model.erros[.valor] != nil ? 2 : 1)
                )
                .accessibilityLabel(Text(verbatim: TextosPublicarVaga.valor))
                .accessibilityIdentifier("valor-vaga-campo")
                .disabled(model.camposBloqueados)

            Text(verbatim: TextosPublicarVaga.valorAjuda)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)

            mensagemDeErroAbaixo(model.erros[.valor], identifier: "erro-publicacao-valor")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var secaoInclusos: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.inclusos)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            VStack(spacing: 0) {
                linhaSimNao(TextosPublicarVaga.refeicao, valor: $model.refeicao)
                Divider().background(FrilaCor.divisoria)
                linhaSimNao(TextosPublicarVaga.transporte, valor: $model.transporte)
                Divider().background(FrilaCor.divisoria)
                linhaSimNao(TextosPublicarVaga.material, valor: $model.materialProprio)
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous)
                    .strokeBorder(model.erros[.inclusos] != nil ? FrilaCor.texto : FrilaCor.divisoria, lineWidth: model.erros[.inclusos] != nil ? 2 : 1)
            )
            .disabled(model.camposBloqueados)

            mensagemDeErroAbaixo(model.erros[.inclusos], identifier: "erro-publicacao-inclusos")
        }
    }

    private func linhaSimNao(_ titulo: String, valor: Binding<Bool>) -> some View {
        HStack {
            Text(verbatim: titulo)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)

            Spacer()

            HStack(spacing: FrilaEspaco.minimo) {
                ForEach([(true, TextosPublicarVaga.sim), (false, TextosPublicarVaga.nao)], id: \.0) { escolha, rotulo in
                    Button {
                        valor.wrappedValue = escolha
                    } label: {
                        HStack(spacing: FrilaEspaco.minimo) {
                            if valor.wrappedValue == escolha {
                                Image(systemName: "checkmark")
                                    .accessibilityIdentifier(escolha ? "icone-checkmark-sim" : "icone-checkmark-nao")
                            }
                            Text(verbatim: rotulo)
                                .font(FrilaTipo.chip)
                        }
                        .padding(.horizontal, FrilaEspaco.compacto)
                        .frame(minWidth: 56, minHeight: 32)
                        .background(valor.wrappedValue == escolha ? FrilaCor.primaria : FrilaCor.superficie, in: Capsule())
                        .foregroundStyle(valor.wrappedValue == escolha ? FrilaCor.sobrePrimaria : FrilaCor.texto)
                        .overlay(Capsule().strokeBorder(valor.wrappedValue == escolha ? Color.clear : FrilaCor.borda, lineWidth: 1))
                        .frame(minHeight: FrilaMetrica.alvoMinimo)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(valor.wrappedValue == escolha ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, FrilaEspaco.compacto)
        .frame(minHeight: FrilaMetrica.alturaDoCampo)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var secaoResponsavel: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.responsavel)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            TextField(
                TextosPublicarVaga.responsavel,
                text: $model.responsavelLocal
            )
            .textFieldStyle(.plain)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                    .strokeBorder(model.erros[.responsavel] != nil ? FrilaCor.texto : FrilaCor.borda, lineWidth: model.erros[.responsavel] != nil ? 2 : 1)
            )
            .accessibilityLabel(Text(verbatim: TextosPublicarVaga.responsavel))
            .accessibilityIdentifier("responsavel-local-campo")
            .disabled(model.camposBloqueados)

            mensagemDeErroAbaixo(model.erros[.responsavel], identifier: "erro-publicacao-responsavel")
        }
    }

    @ViewBuilder
    private var secaoModo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.modo)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            Picker(TextosPublicarVaga.modo, selection: $model.modo) {
                Text(verbatim: TextosPublicarVaga.modoUrgencia).tag(ModoPreenchimento.urgencia)
                if model.selecaoDisponivel {
                    Text(verbatim: TextosPublicarVaga.modoSelecao).tag(ModoPreenchimento.selecao)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Text(verbatim: TextosPublicarVaga.modo))
            .accessibilityIdentifier("modo-vaga-picker")
            .disabled(model.camposBloqueados)

            if !model.selecaoDisponivel {
                Text(verbatim: TextosPublicarVaga.modoSelecaoSoComAntecedencia)
                    .font(FrilaTipo.nota)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("modo-selecao-indisponivel")
            }

            if let prazo = model.prazoDeEscolha {
                Text(verbatim: String(format: TextosPublicarVaga.modoSelecaoPrazo, FormatadorFrila().dataEHora(prazo)))
                    .font(FrilaTipo.nota.weight(.semibold))
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityIdentifier("prazo-de-escolha-publicacao")

                if model.janelaDeEscolhaCurta {
                    AvisoNeutroLocal(icone: "exclamationmark.triangle", texto: TextosPublicarVaga.modoSelecaoPrazoCurto)
                        .accessibilityIdentifier("prazo-de-escolha-curto")
                }
            }

            mensagemDeErroAbaixo(model.erros[.modo], identifier: "erro-publicacao-modo")
        }
    }

    @ViewBuilder
    private var secaoAlerta: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.alerta)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            if dynamicTypeSize.isAccessibilitySize {
                Picker(TextosPublicarVaga.alerta, selection: $model.alertaAntecedenciaMinutos) {
                    Text(verbatim: TextosPublicarVaga.alertaTresHoras).tag(180)
                    Text(verbatim: TextosPublicarVaga.alertaDuasHoras).tag(120)
                    Text(verbatim: TextosPublicarVaga.alertaSeisHoras).tag(360)
                }
                .pickerStyle(.menu)
                .accessibilityLabel(Text(verbatim: TextosPublicarVaga.alerta))
                .accessibilityIdentifier("alerta-vaga-picker")
                .tint(FrilaCor.texto)
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .leading)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
            } else {
                Picker(TextosPublicarVaga.alerta, selection: $model.alertaAntecedenciaMinutos) {
                    Text(verbatim: TextosPublicarVaga.alertaTresHoras).tag(180)
                    Text(verbatim: TextosPublicarVaga.alertaDuasHoras).tag(120)
                    Text(verbatim: TextosPublicarVaga.alertaSeisHoras).tag(360)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text(verbatim: TextosPublicarVaga.alerta))
                .accessibilityIdentifier("alerta-vaga-picker")
            }
        }
        .disabled(model.camposBloqueados)
    }

    @ViewBuilder
    private var secaoMaisOpcoes: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Button {
                withAnimation(FrilaMovimento.animacao(.easeInOut(duration: 0.2), reduzir: reduzirMovimento)) {
                    model.mostrandoMaisOpcoes.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: TextosPublicarVaga.maisOpcoes)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                        Text(verbatim: TextosPublicarVaga.maisOpcoesAjuda)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    Spacer()
                    Image(systemName: model.mostrandoMaisOpcoes ? "chevron.up" : "chevron.down")
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }
                .padding(.horizontal, FrilaEspaco.medio)
                .padding(.vertical, FrilaEspaco.compacto)
                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                        .strokeBorder(FrilaCor.borda, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.camposBloqueados)
            .accessibilityIdentifier("mais-opcoes-botao")

            if model.mostrandoMaisOpcoes {
                VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text(verbatim: TextosPublicarVaga.traje)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                        CampoFrila(verbatim: TextosPublicarVaga.traje, texto: $model.traje)
                            .id("campo-traje")
                        mensagemDeErroAbaixo(model.erros[.traje], identifier: "erro-publicacao-traje")
                    }

                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        linhaSimNao(TextosPublicarVaga.rateio, valor: Binding(
                            get: { model.participaRateio ?? false },
                            set: { model.participaRateio = $0 }
                        ))
                        .padding(.horizontal, FrilaEspaco.medio)
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous).strokeBorder(FrilaCor.borda, lineWidth: 1))
                        .id("campo-rateio")
                        mensagemDeErroAbaixo(model.erros[.rateio], identifier: "erro-publicacao-rateio")
                    }

                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        Text(verbatim: TextosPublicarVaga.observacoes)
                            .font(FrilaTipo.meta.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                        TextField(TextosPublicarVaga.observacoes, text: $model.observacoes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .padding(FrilaEspaco.medio)
                            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo, alignment: .topLeading)
                            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                                    .strokeBorder(model.erros[.observacoes] != nil ? FrilaCor.texto : FrilaCor.borda, lineWidth: model.erros[.observacoes] != nil ? 2 : 1)
                            )
                            .accessibilityIdentifier("observacoes-vaga-campo")
                            .id("campo-observacoes")
                        mensagemDeErroAbaixo(model.erros[.observacoes], identifier: "erro-publicacao-observacoes")
                    }
                }
                .disabled(model.camposBloqueados)
            }
        }
    }

    @ViewBuilder
    private var secaoContato: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: TextosPublicarVaga.telefoneResponsavel)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)

            HStack {
                Text(verbatim: formatarTelefoneResponsavel(telefoneResponsavel))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                Spacer()
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alturaDoCampo)
            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FrilaRaio.aviso, style: .continuous)
                    .strokeBorder(FrilaCor.borda, lineWidth: 1)
            )

            Text(verbatim: TextosPublicarVaga.avisoRN10)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private var barraInferiorConteudo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text(verbatim: resumoTexto)
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
                .lineLimit(2)

            blocoPrecoECta

            if inicioEmMenosDe3Horas {
                HStack(alignment: .top, spacing: FrilaEspaco.minimo) {
                    Image(systemName: "clock")
                        .font(FrilaTipo.nota)
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityHidden(true)
                    (Text(verbatim: TextosPublicarVaga.menosTresHorasTitulo + " ")
                        .font(FrilaTipo.nota.weight(.semibold)) +
                     Text(verbatim: TextosPublicarVaga.menosTresHorasCorpo)
                        .font(FrilaTipo.nota))
                        .foregroundStyle(FrilaCor.texto)
                }
            }

            Text(verbatim: model.modo == .selecao ? TextosPublicarVaga.modoSelecaoExplicacao : TextosPublicarVaga.modoUrgenciaExplicacao)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityIdentifier("modo-vaga-explicacao")
        }
        .padding(.horizontal, FrilaEspaco.medio)
        .padding(.vertical, FrilaEspaco.compacto)
    }

    @ViewBuilder
    private var blocoPrecoECta: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                blocoTotalPreco
                botaoPublicarCta
            }
        } else {
            HStack(alignment: .center, spacing: FrilaEspaco.medio) {
                blocoTotalPreco
                    .frame(maxWidth: .infinity, alignment: .leading)
                botaoPublicarCta
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var blocoTotalPreco: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: FormatadorFrila().dinheiro(Dinheiro(centavos: model.valorTotalCentavos)))
                .font(FrilaTipo.preco)
                .monospacedDigit()
                .foregroundStyle(FrilaCor.texto)
                .accessibilityIdentifier("total-vaga-calculado")

            Text(verbatim: resumoTotalTexto)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private var botaoPublicarCta: some View {
        BotaoPrimario(
            verbatim: model.camposBloqueados ? TextosPublicarVaga.tentarNovamente : TextosPublicarVaga.publicar,
            carregando: model.enviando
        ) {
            Task {
                await model.publicar()
                tentativaEnvio += 1
                if model.resultado != nil {
                    aoPublicar()
                }
            }
        }
        .lineLimit(1)
        .disabled(model.enviando || model.restaurandoPublicacao)
        .accessibilityIdentifier("publicar-vaga-botao")
    }

    private var resumoTexto: String {
        let posicoes = Int(model.posicoesTexto) ?? 1
        let funcaoNome = model.funcoes.first(where: { $0.id == model.funcaoID })?.nome ?? TextosPublicarVaga.escolhaFuncao
        let dataStr = formatarDataResumo(model.inicio)
        let horaIni = formatarHoraResumo(model.inicio)
        let horaFim = formatarHoraResumo(model.fim)
        if posicoes == 1 {
            return String(format: TextosPublicarVaga.resumoSingular, posicoes, funcaoNome, dataStr, horaIni, horaFim)
        } else {
            return String(format: TextosPublicarVaga.resumoPlural, posicoes, funcaoNome, dataStr, horaIni, horaFim)
        }
    }

    private var resumoTotalTexto: String {
        let posicoes = Int(model.posicoesTexto) ?? 1
        if posicoes == 1 {
            return TextosPublicarVaga.resumoTotalSingular
        } else {
            return String(format: TextosPublicarVaga.resumoTotalPlural, posicoes)
        }
    }

    private var inicioEmMenosDe3Horas: Bool {
        let agora = Date()
        return model.inicio > agora && model.inicio.timeIntervalSince(agora) < 3 * 60 * 60
    }

    private var calendarioSp: Calendar {
        var cal = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "America/Sao_Paulo") {
            cal.timeZone = tz
        }
        return cal
    }

    private var isHoje: Bool {
        calendarioSp.isDateInToday(model.inicio)
    }

    private var isAmanha: Bool {
        calendarioSp.isDateInTomorrow(model.inicio)
    }

    private func selecionarDiaHoje() {
        ajustarDataInicio(para: Date())
    }

    private func selecionarDiaAmanha() {
        if let amanha = calendarioSp.date(byAdding: .day, value: 1, to: Date()) {
            ajustarDataInicio(para: amanha)
        }
    }

    private func ajustarDataInicio(para dataAlvo: Date) {
        let cal = calendarioSp
        let compsAlvo = cal.dateComponents([.year, .month, .day], from: dataAlvo)
        var compsInicio = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: model.inicio)
        compsInicio.year = compsAlvo.year
        compsInicio.month = compsAlvo.month
        compsInicio.day = compsAlvo.day
        if let novaData = cal.date(from: compsInicio) {
            model.inicio = novaData
        }
    }

    private func chipData(rotulo: String, selecionado: Bool, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            HStack(spacing: FrilaEspaco.minimo) {
                if selecionado {
                    Image(systemName: "checkmark")
                        .font(FrilaTipo.chip)
                        .foregroundStyle(FrilaCor.sobrePrimaria)
                }
                Text(verbatim: rotulo)
                    .font(FrilaTipo.chip)
                    .foregroundStyle(selecionado ? FrilaCor.sobrePrimaria : FrilaCor.texto)
            }
            .padding(.horizontal, FrilaEspaco.compacto)
            .frame(minHeight: 36)
            .background(selecionado ? FrilaCor.primaria : FrilaCor.superficie, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(selecionado ? Color.clear : FrilaCor.borda, lineWidth: 1)
            )
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selecionado ? .isSelected : [])
    }

    private var ajudaTermino: (icone: String, texto: String)? {
        guard model.fim > model.inicio else { return nil }
        let cal = calendarioSp
        let dfData = DateFormatter()
        dfData.calendar = cal
        dfData.timeZone = cal.timeZone
        dfData.locale = Locale(identifier: "pt_BR")
        dfData.dateFormat = "EEE, dd/MM"
        let strData = dfData.string(from: model.fim).replacingOccurrences(of: ".", with: "")

        let dfHora = DateFormatter()
        dfHora.calendar = cal
        dfHora.timeZone = cal.timeZone
        dfHora.locale = Locale(identifier: "pt_BR")
        dfHora.dateFormat = "HH:mm"
        let strHora = dfHora.string(from: model.fim)

        let diaInicio = cal.startOfDay(for: model.inicio)
        let diaFim = cal.startOfDay(for: model.fim)
        let diffDias = cal.dateComponents([.day], from: diaInicio, to: diaFim).day ?? 0

        if diffDias == 0 {
            return ("clock", String(format: TextosPublicarVaga.terminaNoMesmoDia, strData, strHora))
        } else if diffDias == 1 {
            return ("moon", String(format: TextosPublicarVaga.terminaNoDiaSeguinte, strData, strHora))
        } else {
            return ("moon", String(format: TextosPublicarVaga.terminaEm, strData, strHora))
        }
    }

    private func formatarDataResumo(_ data: Date) -> String {
        let cal = calendarioSp
        let df = DateFormatter()
        df.calendar = cal
        df.timeZone = cal.timeZone
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "EEE, dd/MM"
        let formatada = df.string(from: data).replacingOccurrences(of: ".", with: "")
        if cal.isDateInToday(data) {
            return "hoje, \(formatada)"
        } else if cal.isDateInTomorrow(data) {
            return "amanhã, \(formatada)"
        } else {
            return formatada
        }
    }

    private func formatarHoraResumo(_ data: Date) -> String {
        let df = DateFormatter()
        df.calendar = calendarioSp
        df.timeZone = calendarioSp.timeZone
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "HH:mm"
        return df.string(from: data)
    }

    private func formatarTelefoneResponsavel(_ texto: String) -> String {
        let digitos = Array(texto.filter(\.isNumber))
        var corpo = digitos
        if (corpo.count == 12 || corpo.count == 13), corpo.prefix(2) == ["5", "5"] {
            corpo = Array(corpo.dropFirst(2))
        }
        if corpo.count == 11 {
            let ddd = String(corpo[0..<2])
            let parte1 = String(corpo[2..<7])
            let parte2 = String(corpo[7..<11])
            return "(\(ddd)) \(parte1)-\(parte2)"
        }
        if corpo.count == 10 {
            let ddd = String(corpo[0..<2])
            let parte1 = String(corpo[2..<6])
            let parte2 = String(corpo[6..<10])
            return "(\(ddd)) \(parte1)-\(parte2)"
        }
        return texto
    }

    @ViewBuilder
    private func mensagemDeErroAbaixo(_ erro: String?, identifier: String? = nil) -> some View {
        if let erro {
            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.minimo) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
                    .accessibilityHidden(true)
                Text(verbatim: erro)
                    .font(FrilaTipo.meta)
                    .foregroundStyle(FrilaCor.texto)
            }
            .accessibilityIdentifier(identifier ?? "")
        }
    }

    private func primeiroCampoComErro() -> String? {
        if model.erros[.funcao] != nil { return "campo-funcao" }
        if model.erros[.inicio] != nil || model.erros[.fim] != nil { return "campo-quando" }
        if model.erros[.local] != nil || model.erros[.ponto] != nil || model.erros[.estabelecimento] != nil { return "campo-local" }
        if model.erros[.posicoes] != nil { return "campo-posicoes" }
        if model.erros[.valor] != nil { return "campo-valor" }
        if model.erros[.inclusos] != nil { return "campo-inclusos" }
        if model.erros[.responsavel] != nil { return "campo-responsavel" }
        if model.erros[.modo] != nil { return "campo-modo" }
        if model.erros[.traje] != nil { return "campo-traje" }
        if model.erros[.rateio] != nil { return "campo-rateio" }
        if model.erros[.observacoes] != nil { return "campo-observacoes" }
        return nil
    }

    private func rolarParaPrimeiroErro(proxy: ScrollViewProxy) {
        guard let campoID = primeiroCampoComErro() else { return }
        withAnimation(FrilaMovimento.animacao(.easeInOut(duration: 0.3), reduzir: reduzirMovimento)) {
            proxy.scrollTo(campoID, anchor: .top)
        }
    }
}

/// Máscara usada no formulário de publicar, inclusive ao abrir por Minhas vagas.
struct CampoValorVaga: UIViewRepresentable {
    @Binding var texto: String
    @Environment(\.isEnabled) private var habilitado

    func makeCoordinator() -> Coordenador { Coordenador(texto: $texto) }

    func makeUIView(context: Context) -> UITextField {
        let campo = UITextField()
        campo.keyboardType = .numberPad
        campo.borderStyle = .none
        campo.font = .preferredFont(forTextStyle: .body)
        campo.adjustsFontForContentSizeCategory = true
        campo.textColor = FrilaCor.textoUIKit
        campo.placeholder = TextosPublicarVaga.valorExemplo
        campo.accessibilityLabel = TextosPublicarVaga.valor
        campo.accessibilityIdentifier = "valor-vaga-campo"
        campo.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        campo.addTarget(context.coordinator, action: #selector(Coordenador.editar(_:)), for: .editingChanged)
        campo.delegate = context.coordinator
        return campo
    }

    func updateUIView(_ campo: UITextField, context: Context) {
        context.coordinator.texto = $texto
        campo.isEnabled = habilitado
        let formatado = Self.formatarCentavos(Int(texto.filter(\.isNumber)) ?? 0)
        if campo.text != formatado { campo.text = formatado }
    }

    @MainActor
    final class Coordenador: NSObject, UITextFieldDelegate {
        var texto: Binding<String>

        init(texto: Binding<String>) { self.texto = texto }

        // O campo sempre mostra "R$ 0,00"; um toque à esquerda deixa o cursor antes do "R$".
        // Dígito novo entra sempre no fim e apagar tira sempre o último, onde quer que esteja o cursor.
        func textField(_ campo: UITextField, shouldChangeCharactersIn intervalo: NSRange, replacementString novo: String) -> Bool {
            var digitos = (campo.text ?? "").filter(\.isNumber)
            if novo.isEmpty {
                digitos = String(digitos.dropLast())
            } else {
                digitos += novo.filter(\.isNumber)
            }
            campo.text = digitos
            editar(campo)
            return false
        }

        @objc func editar(_ campo: UITextField) {
            let centavos = Int((campo.text ?? "").filter(\.isNumber)) ?? 0
            // Reescreve no próprio evento, antes da próxima tecla. Um binding formatado depende
            // da renderização do SwiftUI e pode sobrescrever teclas rápidas com um valor antigo.
            campo.text = CampoValorVaga.formatarCentavos(centavos)
            campo.selectedTextRange = campo.textRange(from: campo.endOfDocument, to: campo.endOfDocument)
            texto.wrappedValue = String(centavos)
        }
    }

    static func formatarCentavos(_ centavos: Int) -> String {
        let reais = centavos / 100
        let resto = centavos % 100
        return String(format: TextosPublicarVaga.formatoValor, reais, resto)
    }
}

/// Campo numérico de posições com altura mínima de toque e comportamento UIKit compatível.
struct CampoPosicoesVaga: UIViewRepresentable {
    @Binding var texto: String
    @Environment(\.isEnabled) private var habilitado

    func makeCoordinator() -> Coordenador { Coordenador(texto: $texto) }

    func makeUIView(context: Context) -> UITextField {
        let campo = UITextField()
        campo.keyboardType = .numberPad
        campo.borderStyle = .none
        campo.font = .preferredFont(forTextStyle: .body)
        campo.adjustsFontForContentSizeCategory = true
        campo.textColor = FrilaCor.textoUIKit
        campo.text = texto
        campo.placeholder = TextosPublicarVaga.posicoesExemplo
        campo.accessibilityLabel = TextosPublicarVaga.posicoes
        campo.accessibilityIdentifier = "posicoes-vaga-campo"
        campo.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        campo.setContentHuggingPriority(.defaultLow, for: .vertical)
        campo.addTarget(context.coordinator, action: #selector(Coordenador.editar(_:)), for: .editingChanged)
        campo.delegate = context.coordinator
        return campo
    }

    func updateUIView(_ campo: UITextField, context: Context) {
        context.coordinator.texto = $texto
        campo.isEnabled = habilitado
        if campo.text != texto { campo.text = texto }
    }

    @MainActor
    final class Coordenador: NSObject, UITextFieldDelegate {
        var texto: Binding<String>

        init(texto: Binding<String>) { self.texto = texto }

        func textField(_ campo: UITextField, shouldChangeCharactersIn intervalo: NSRange, replacementString novo: String) -> Bool {
            let permitidos = CharacterSet(charactersIn: "0123456789")
            let conjuntoNovo = CharacterSet(charactersIn: novo)
            return permitidos.isSuperset(of: conjuntoNovo)
        }

        @objc func editar(_ campo: UITextField) {
            texto.wrappedValue = campo.text ?? ""
        }
    }
}

private extension View {
    @ViewBuilder
    func barraInferiorFixa<Content: View>(@ViewBuilder conteudo: () -> Content) -> some View {
        VStack(spacing: 0) {
            self

            VStack(spacing: 0) {
                Rectangle()
                    .fill(FrilaCor.divisoria)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                conteudo()
            }
            .background(FrilaCor.superficie.ignoresSafeArea(edges: .bottom))
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
    }
}

