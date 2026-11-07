import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class ChamadaDiretaViewModel {
    public var inicio: Date
    public var fim: Date
    public var funcaoID: UUID?
    public var valorCentavos = 0 {
        didSet { if valorCentavos != oldValue { totalConfirmado = false } }
    }
    public var totalConfirmado = false
    public var recado = ""
    public var responsavel = ""
    public var refeicao = false
    public var transporte = false
    public var materialProprio = false
    public private(set) var funcoes: [Funcao] = []
    public private(set) var local = ""
    public private(set) var carregando = false
    public private(set) var enviando = false
    public private(set) var resultado: Chamada?
    public private(set) var erro: String?
    public var mostrarJ7 = false
    private var recorrenciaPendente = false
    public private(set) var tentativa: PedidoChamada?
    public private(set) var recursoHabilitado = false
    private var regiao = ""
    private var ponto: Coordenada?
    private let profissionalID: UUID
    private let estabelecimentoID: UUID
    private let vagaID: UUID?
    private let api: any ApiCliente
    private let agora: @Sendable () -> Date

    public init(api: any ApiCliente, profissionalID: UUID, estabelecimentoID: UUID,
                vagaID: UUID? = nil, agora: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.profissionalID = profissionalID
        self.estabelecimentoID = estabelecimentoID
        self.vagaID = vagaID
        self.agora = agora
        inicio = agora().addingTimeInterval(24 * 3600)
        fim = agora().addingTimeInterval(28 * 3600)
    }

    public var podeEnviar: Bool {
        !carregando && !enviando && resultado == nil && recursoHabilitado && totalConfirmado
            && funcaoID != nil && ponto != nil && valorCentavos > 0 && recado.count <= 300
            && !responsavel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && inicio.timeIntervalSince(agora()) >= 2 * 3600
            && (2 * 3600...16 * 3600).contains(fim.timeIntervalSince(inicio))
    }

    public func carregar() async {
        guard !carregando, ponto == nil else { return }
        carregando = true
        erro = nil
        defer { carregando = false }
        do {
            let api = api
            let estabelecimentoID = estabelecimentoID
            let vagaID = vagaID
            let dados = try await PrazoDaAbertura.esperar(.seconds(15)) {
                let configuracao = try await api.configuracaoDoApp()
                guard configuracao.recursos.chamadaDireta else { throw ErroDaApi(codigo: .recursoDesligado) }
                let casa = try await api.meuEstabelecimento(id: estabelecimentoID)
                let funcoes = try await api.funcoes()
                let vaga: Vaga?
                if let vagaID { vaga = try await api.detalheDaVaga(id: vagaID) } else { vaga = nil }
                return (casa, funcoes, vaga)
            }
            let (casa, catalogo, vaga) = dados
            funcoes = catalogo
            funcaoID = vaga?.funcao.id ?? catalogo.first?.id
            local = vaga?.local ?? casa.endereco
            regiao = vaga?.regiaoAdministrativa ?? casa.regiaoAdministrativa
            ponto = vaga?.ponto ?? casa.ponto
            responsavel = vaga?.responsavelLocal ?? casa.nome
            valorCentavos = vaga?.valor.centavos ?? 0
            refeicao = vaga?.inclusos.refeicao ?? false
            transporte = vaga?.inclusos.transporte ?? false
            materialProprio = vaga?.inclusos.exigeMaterialProprio ?? false
            if let vaga { fim = inicio.addingTimeInterval(vaga.periodo.fim.timeIntervalSince(vaga.periodo.inicio)) }
            recursoHabilitado = true
        } catch { erro = Self.mensagem(error) }
    }

    public func enviar(confirmoRecorrencia: Bool = false) async {
        guard podeEnviar else { return }
        // A confirmação J7 só pode ser enviada depois da recusa correspondente.
        guard !confirmoRecorrencia || recorrenciaPendente else { return }
        guard let funcaoID, let ponto, let periodo = try? Periodo(inicio: inicio, fim: fim),
              let valor = try? Dinheiro(centavos: valorCentavos) else { return }
        let original = tentativa ?? PedidoChamada(profissionalID: profissionalID, trabalho: PublicacaoVaga(
            estabelecimentoID: estabelecimentoID, funcaoID: funcaoID, periodo: periodo,
            local: local, regiaoAdministrativa: regiao, ponto: ponto, valor: valor, posicoes: 1,
            inclusos: Inclusos(refeicao: refeicao, transporte: transporte, exigeMaterialProprio: materialProprio),
            responsavelLocal: responsavel, modo: .urgencia, chave: UUID()),
            recado: recado.isEmpty ? nil : recado)
        let pedido = PedidoChamada(profissionalID: original.profissionalID, trabalho: original.trabalho,
                                  recado: original.recado, confirmoRecorrencia: confirmoRecorrencia || original.confirmoRecorrencia)
        tentativa = pedido
        enviando = true
        erro = nil
        defer { enviando = false }
        do {
            let api = api
            resultado = try await PrazoDaAbertura.esperar(.seconds(15)) { try await api.chamarProfissional(pedido) }
            mostrarJ7 = false
            recorrenciaPendente = false
        } catch let recusa as ErroDaApi where recusa.codigo == .recorrenciaNaoConfirmada {
            recorrenciaPendente = true
            mostrarJ7 = true
        } catch {
            erro = Self.mensagem(error)
        }
    }

    private static func mensagem(_ erro: Error) -> String {
        switch (erro as? ErroDaApi)?.codigo {
        case .chamadaJaAberta: TextosChamadaDireta.jaAberta
        case .chamadaIndisponivel, .profissionalIndisponivel, .naoEncontrado: TextosChamadaDireta.indisponivel
        case .limiteDeChamadas: TextosChamadaDireta.limite
        case .recursoDesligado: TextosChamadaDireta.desligado
        case .semPermissao where (erro as? ErroDaApi)?.detalhes == "recurso_desligado": TextosChamadaDireta.desligado
        default: TextosChamadaDireta.erro
        }
    }
}
