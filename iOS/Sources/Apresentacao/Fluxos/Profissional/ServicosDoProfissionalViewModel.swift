import Foundation
import FrilaDominio
import Observation

public struct ServicoEmEdicao: Identifiable, Equatable {
    public var id: UUID { funcao.id }
    let funcao: Funcao
    var habilitado: Bool
    var dados: ServicoOferecido
    var valor: String
    var valorMaximo: String

    init(funcao: Funcao, existente: ServicoOferecido?) {
        self.funcao = funcao; habilitado = existente != nil
        dados = existente ?? ServicoOferecido(funcaoID: funcao.id, unidade: .aCombinar)
        valor = existente?.valorCentavos.map(Self.texto) ?? ""
        valorMaximo = existente?.valorMaxCentavos.map(Self.texto) ?? ""
    }

    private static func texto(_ centavos: Int) -> String { "\(centavos / 100)," + String(format: "%02d", centavos % 100) }

    static func centavos(_ texto: String) throws -> Int? {
        let texto = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if texto.isEmpty { return nil }
        guard texto.range(of: #"^[0-9]{1,5}(,[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let decimal = Decimal(string: texto.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) else {
            throw ErroDaApi(codigo: .campoInvalido, detalhes: "valor_centavos")
        }
        return NSDecimalNumber(decimal: decimal * 100).intValue
    }

    func oferta() throws -> ServicoOferecido {
        var oferta = dados
        oferta.valorCentavos = dados.unidade == .aCombinar ? nil : try Self.centavos(valor)
        do { oferta.valorMaxCentavos = try Self.centavos(valorMaximo) }
        catch { throw ErroDaApi(codigo: .campoInvalido, detalhes: "valor_max_centavos") }
        try oferta.validar()
        return oferta
    }

    mutating func trocarUnidade() {
        dados.valorMaxCentavos = nil; valorMaximo = ""
        dados.horasIncluidas = dados.unidade == .diaria ? 8 : nil
        dados.minimoHoras = nil; dados.duracaoTipicaH = nil; dados.atePessoas = nil
        dados.descricaoPacote = dados.unidade == .pacote ? "" : nil
        dados.minimoPessoas = dados.unidade == .porPessoa ? 1 : nil
    }
}

@MainActor @Observable
public final class ServicosDoProfissionalViewModel {
    var rascunhos: [ServicoEmEdicao] = []
    private(set) var especialidades: [UUID: [Especialidade]] = [:]
    private(set) var carregando = false
    private(set) var carregou = false
    private(set) var salvando = false
    private(set) var sucesso = false
    private(set) var erro: ErroDaApi?
    private(set) var funcaoComErro: UUID?
    private let api: any ApiCliente

    public init(api: any ApiCliente) { self.api = api }

    func limparSucesso() { sucesso = false }

    func carregar() async {
        guard !carregando, !carregou else { return }
        carregando = true; erro = nil
        defer { carregando = false }
        do {
            let perfil = try await api.meuPerfilProfissional()
            let existentes = try await api.meusServicos()
            var catalogo: [UUID: [Especialidade]] = [:]
            for funcao in perfil.funcoes {
                catalogo[funcao.id] = try await api.especialidades(funcaoID: funcao.id).filter { $0.ativo == true && $0.funcaoID == funcao.id }
            }
            especialidades = catalogo
            rascunhos = perfil.funcoes.map { funcao in ServicoEmEdicao(funcao: funcao, existente: existentes.first { $0.id == funcao.id }?.servico) }
            carregou = true
        } catch { self.erro = (error as? ErroDaApi) ?? ErroDaApi(codigo: .respostaInvalida) }
    }

    func salvar() async {
        guard carregou, !salvando else { return }
        salvando = true; sucesso = false; erro = nil; funcaoComErro = nil
        defer { salvando = false }
        do {
            var ofertas: [ServicoOferecido] = []
            for rascunho in rascunhos where rascunho.habilitado {
                funcaoComErro = rascunho.id
                ofertas.append(try rascunho.oferta())
            }
            funcaoComErro = nil
            _ = try await api.definirServicos(ofertas)
            sucesso = true
        } catch { self.erro = (error as? ErroDaApi) ?? ErroDaApi(codigo: .respostaInvalida) }
    }
}
