import Foundation
import FrilaDominio
import Observation

/// A leitura do código de check-in pelo profissional (contrato 0.2.68, desenho do check-in por código).
/// Só a lógica: a tela e os textos esperam o desenho. Quem a usa mede a distância no toque e a passa
/// aqui; o app nunca manda a coordenada.
///
/// - Acima do raio (`RegraDePresenca.raioDoCodigoMetros`), com a distância medida, o código **não** é
///   enviado e a tentativa não é gasta ("chegue mais perto"). Sem posição, o código segue.
/// - Fora da fila offline e sem repetição sozinha: se a resposta se perder, a tentativa errada pode ter
///   sido gravada, e repetir contaria outra e anteciparia o bloqueio (0.2.69). Quem usa relê o turno e
///   deixa a pessoa digitar de novo.
@MainActor @Observable
public final class ValidacaoDoCodigoViewModel {
    public enum Resultado: Equatable, Sendable {
        case aguardando
        case enviando
        /// Recusa da API (0.2.76): profissional fora do raio de proximidade. Tentativa não é queimada.
        case foraDoRaio
        /// Acima do raio: nada foi enviado, e a tentativa continua inteira.
        case chegueMaisPerto(distanciaMetros: Int)
        /// Sem localização: nada foi enviado ou a API recusou (0.2.76); orienta a pedir confirmação ao responsável.
        case semLocalizacao
        /// Não são 6 dígitos: nada foi enviado (o servidor também não contaria como tentativa).
        case formatoInvalido
        /// Presença verificada pelo código (`tipo: codigo`).
        case verificado(ResultadoRegistro)
        /// `409 checkin_ja_confirmado`: outra leitura ou a casa chegou antes. Presença verificada; relê o turno.
        case jaVerificado
        /// `422 codigo_invalido`: um motivo só, que o app não decifra. Conta como tentativa.
        case invalido
        /// `409 codigo_bloqueado`: `temporario` (espere) ou `encerrado` (vale a confirmação manual).
        case bloqueado(BloqueioDoCodigo)
        /// `403 recurso_desligado`: a chave está desligada para a casa do turno.
        case recursoDesligado
        /// Sem resposta (rede ou prazo): não repete sozinho; relê o turno e deixa digitar de novo.
        case respostaPerdida
        case falhou(ErroDaApi)
    }

    public let turnoID: UUID
    public private(set) var resultado: Resultado = .aguardando

    private let api: any ApiCliente
    private let medirDistancia: @MainActor () async -> Int?

    /// `medirDistancia` lê a localização no toque e devolve só a distância até o local (nunca a coordenada);
    /// `nil` sem posição. Por padrão não mede.
    public init(
        turnoID: UUID,
        api: any ApiCliente,
        medirDistancia: @escaping @MainActor () async -> Int? = { nil }
    ) {
        self.turnoID = turnoID
        self.api = api
        self.medirDistancia = medirDistancia
    }

    /// `true` com os 6 dígitos ASCII que o contrato pede (`^[0-9]{6}$`).
    nonisolated public static func formatoValido(_ codigo: String) -> Bool {
        codigo.count == 6 && codigo.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Mede a distância no toque e valida. Com o código fora do formato, nem lê a localização.
    public func validarMedindo(codigo: String) async {
        guard resultado != .enviando else { return }
        guard Self.formatoValido(codigo) else {
            resultado = .formatoInvalido
            return
        }
        resultado = .enviando
        let distancia = await medirDistancia()
        switch RegraDePresenca.decisaoDoEnvioDoCodigoSemiauto(distanciaMetros: distancia) {
        case .semLocalizacao:
            resultado = .semLocalizacao
            return
        case let .chegueMaisPerto(metros):
            resultado = .chegueMaisPerto(distanciaMetros: metros)
            return
        case .liberado:
            break
        }
        await enviar(codigo: codigo, distanciaMetros: distancia)
    }

    public func validar(codigo: String, distanciaMetros: Int?) async {
        guard resultado != .enviando else { return }
        guard Self.formatoValido(codigo) else {
            resultado = .formatoInvalido
            return
        }
        if case let .chegueMaisPerto(distancia) = RegraDePresenca.decisaoDoEnvioDoCodigo(distanciaMetros: distanciaMetros) {
            resultado = .chegueMaisPerto(distanciaMetros: distancia)
            return
        }
        resultado = .enviando
        await enviar(codigo: codigo, distanciaMetros: distanciaMetros)
    }

    private func enviar(codigo: String, distanciaMetros: Int?) async {
        do {
            let registro = try await api.validarCodigoCheckin(turnoID: turnoID, codigo: codigo, distanciaMetros: distanciaMetros)
            resultado = .verificado(registro)
        } catch let erro as ErroDaApi {
            resultado = Self.resultado(para: erro)
        } catch {
            resultado = .respostaPerdida
        }
    }

    private static func resultado(para erro: ErroDaApi) -> Resultado {
        if erro.recursoDesligado { return .recursoDesligado }
        switch erro.codigo {
        case .foraDoRaio: return .foraDoRaio
        case .semLocalizacao: return .semLocalizacao
        case .codigoInvalido: return .invalido
        case .codigoBloqueado: return .bloqueado(erro.bloqueioDoCodigo ?? .encerrado)
        case .checkinJaConfirmado: return .jaVerificado
        case .campoInvalido: return .formatoInvalido
        case .semRede: return .respostaPerdida
        default: return .falhou(erro)
        }
    }
}
