import Foundation
import FrilaDominio
import Observation

/// "Por que recebo vagas" (RF27, cartão #18): os critérios reais de `criteriosDeNotificacao` e o
/// pedido de revisão do despacho por `pedirRevisaoDespacho`. O texto explicativo continua sendo do
/// app; daqui saem só os dados e o protocolo.
@MainActor @Observable
public final class PorQueReceboVagasViewModel {
    public enum Estado: Equatable, Sendable {
        case carregando
        /// Sem função, grade nem equipe, ou sem perfil profissional (`naoEncontrado`).
        case vazio
        case conteudo(CriteriosDeNotificacao)
        case semRede
        case erro
    }

    public private(set) var estado: Estado = .carregando
    public var mostrarFormulario = false
    public var relato = ""
    public private(set) var enviando = false
    public private(set) var protocolo: Protocolo?
    public private(set) var mensagemErro: String?

    private let carregarCriterios: @Sendable () async throws -> CriteriosDeNotificacao
    private let pedirRevisao: @Sendable (String) async throws -> Protocolo

    public init(
        criterios: @escaping @Sendable () async throws -> CriteriosDeNotificacao,
        pedirRevisao: @escaping @Sendable (String) async throws -> Protocolo
    ) {
        carregarCriterios = criterios
        self.pedirRevisao = pedirRevisao
    }

    public convenience init(api: any ApiCliente) {
        self.init(
            criterios: { try await api.criteriosDeNotificacao() },
            pedirRevisao: { relato in try await api.pedirRevisaoDespacho(relato: relato) }
        )
    }

    public var criterios: CriteriosDeNotificacao? {
        if case let .conteudo(criterios) = estado { criterios } else { nil }
    }

    public var relatoValido: Bool {
        relato.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    /// Um pedido por abertura da tela: enviado, o botão dá lugar ao protocolo.
    public var podeContestar: Bool {
        protocolo == nil && !enviando
    }

    public func carregar() async {
        estado = .carregando
        do {
            let criterios = try await carregarCriterios()
            estado = criterios.semCriterios ? .vazio : .conteudo(criterios)
        } catch let erroApi as ErroDaApi {
            switch erroApi.codigo {
            case .semRede: estado = .semRede
            case .naoEncontrado: estado = .vazio
            default: estado = .erro
            }
        } catch {
            estado = .erro
        }
    }

    public func abrirFormulario() {
        guard podeContestar else { return }
        mostrarFormulario = true
        mensagemErro = nil
    }

    public func cancelarFormulario() {
        mostrarFormulario = false
        mensagemErro = nil
    }

    public func contestar() async {
        let relatoLimpo = relato.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !relatoLimpo.isEmpty else {
            mensagemErro = TextosPorQueReceboVagas.relatoObrigatorio
            return
        }
        guard relatoLimpo.count >= 10 else {
            mensagemErro = TextosPorQueReceboVagas.relatoMinimo
            return
        }
        guard podeContestar else { return }

        enviando = true
        mensagemErro = nil
        defer { enviando = false }
        do {
            protocolo = try await pedirRevisao(relatoLimpo)
            mostrarFormulario = false
        } catch let erroApi as ErroDaApi {
            mensagemErro = Self.mensagem(para: erroApi)
        } catch {
            mensagemErro = TextosPorQueReceboVagas.erroEnviar
        }
    }

    /// Cada recusa que o contrato lista para `pedir_revisao_despacho`: o campo (422), a conta
    /// suspensa (403 com `conta_suspensa`) e o limite (429). O resto é o erro genérico.
    static func mensagem(para erro: ErroDaApi) -> String {
        switch erro.codigo {
        case .campoObrigatorio: TextosPorQueReceboVagas.relatoObrigatorio
        case .campoInvalido: TextosPorQueReceboVagas.relatoMinimo
        case .contaSuspensa: TextosPorQueReceboVagas.contaSuspensa
        case .semPermissao where erro.detalhes == "conta_suspensa": TextosPorQueReceboVagas.contaSuspensa
        case .limiteExcedido: TextosPorQueReceboVagas.limiteExcedido
        case .semRede: TextosPorQueReceboVagas.erroSemRede
        default: TextosPorQueReceboVagas.erroEnviar
        }
    }

    // MARK: Texto dos critérios

    /// "Sexta-feira: 18:00 às 02:00 (dia seguinte)", no formato de Funções e horários.
    public static func descricao(_ janela: JanelaDeDisponibilidade) -> String {
        let dia = PerfilProfissionalViewModel.nomeDoDia(janela.diaDaSemana)
        let base = String(localized: "\(janela.inicio.contrato) às \(janela.fim.contrato)", bundle: bundleApresentacao)
        guard janela.atravessaMeiaNoite else { return "\(dia): \(base)" }
        let sufixo = String(localized: "(dia seguinte)", bundle: bundleApresentacao)
        return "\(dia): \(base) \(sufixo)"
    }

    /// "Até 15 km do seu ponto base." O parâmetro vem do servidor como número: inteiro sai sem
    /// casas, e uma fração sai com vírgula.
    public static func descricaoDistancia(_ km: Double) -> String {
        let formatador = NumberFormatter()
        formatador.locale = FormatadorFrila.locale
        formatador.numberStyle = .decimal
        formatador.maximumFractionDigits = 1
        let texto = formatador.string(from: NSNumber(value: km)) ?? String(km)
        return TextosPorQueReceboVagas.distancia(texto)
    }
}
