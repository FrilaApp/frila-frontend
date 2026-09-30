import Foundation
import FrilaDominio
import Observation

public enum DestinoCodigo: Equatable, Sendable {
    case cadastro(email: String)
    case destino(DestinoAposEntrada)
}

@MainActor @Observable
public final class CodigoViewModel {
    private let api: any ApiCliente
    public let email: String
    public var codigo: String = "" {
        didSet {
            let apenasDigitos = codigo.filter(\.isNumber)
            if apenasDigitos.count > 6 {
                codigo = String(apenasDigitos.prefix(6))
            } else if apenasDigitos != codigo {
                codigo = apenasDigitos
            }
        }
    }
    public var carregando: Bool = false
    public var segundosRestantes: Int = 60
    public var erro: String?
    public var mensagemInformativa: String?

    private var tarefaTemporizador: Task<Void, Never>?

    public init(api: any ApiCliente, email: String) {
        self.api = api
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        iniciarTemporizador()
    }

    public func iniciarTemporizador() {
        segundosRestantes = 60
        tarefaTemporizador?.cancel()
        tarefaTemporizador = Task { [weak self] in
            while let self, self.segundosRestantes > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.segundosRestantes -= 1
            }
        }
    }

    public var podeReenviar: Bool {
        segundosRestantes == 0 && !carregando
    }

    public var codigoValido: Bool {
        codigo.count == 6 && codigo.allSatisfy(\.isNumber)
    }

    public var textoAcessibilidadeCodigo: String {
        if codigo.isEmpty {
            return String(localized: "Vazio", bundle: bundleApresentacao)
        }
        return codigo.map(String.init).joined(separator: ", ")
    }

    public func reenviarCodigo() async {
        guard podeReenviar else { return }
        carregando = true
        erro = nil
        mensagemInformativa = nil
        defer { carregando = false }

        if !DemonstracaoContas.ehEmailDeDemonstracao(email) {
            do {
                try await api.solicitarCodigo(email: email)
            } catch let erroApi as ErroDaApi {
                erro = MensagemDoErroAPI.texto(erroApi)
                return
            } catch {
                erro = String(localized: "Não foi possível reenviar o código. Tente novamente.", bundle: bundleApresentacao)
                return
            }
        }
        iniciarTemporizador()
        mensagemInformativa = String(localized: "Novo código enviado para seu e-mail.", bundle: bundleApresentacao)
    }

    public func confirmarCodigo() async -> DestinoCodigo? {
        guard codigoValido else {
            erro = String(localized: "Digite os 6 números do código.", bundle: bundleApresentacao)
            return nil
        }
        carregando = true
        erro = nil
        mensagemInformativa = nil
        defer { carregando = false }

        do {
            if DemonstracaoContas.ehEmailDeDemonstracao(email) {
                try await api.entrarDemonstracao(email: email, codigo: codigo)
            } else {
                try await api.verificarCodigo(email: email, codigo: codigo)
            }

            return await avaliarConta()
        } catch let erroApi as ErroDaApi {
            tratarErroDeVerificacao(erroApi)
            return nil
        } catch {
            erro = String(localized: "Não foi possível confirmar o código. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }
    }

    private func tratarErroDeVerificacao(_ erroApi: ErroDaApi) {
        if erroApi.codigo == .naoAutenticado {
            if erroApi.codigoOriginal == "otp_expired" {
                erro = String(localized: "Código expirado. Peça um novo código para continuar.", bundle: bundleApresentacao)
            } else {
                erro = String(localized: "Código incorreto. Confira os números e tente novamente.", bundle: bundleApresentacao)
            }
        } else if erroApi.codigo == .naoEncontrado {
            erro = String(localized: "Código incorreto. Confira os números e tente novamente.", bundle: bundleApresentacao)
        } else {
            erro = MensagemDoErroAPI.texto(erroApi)
        }
    }

    private func avaliarConta() async -> DestinoCodigo {
        do {
            let conta = try await api.minhaConta()
            // Quem já tem conta pula o cadastro
            switch conta.perfil {
            case .profissional:
                do {
                    _ = try await api.meuPerfilProfissional()
                    return .destino(.profissional(conta))
                } catch {
                    // Sem perfil profissional vai para Funções e horários (#98)
                    return .destino(.funcoesEHorarios(conta))
                }
            case .contratante:
                return .destino(.contratante(conta))
            }
        } catch let erroApi as ErroDaApi where erroApi.codigo == .naoEncontrado {
            // Primeiro acesso: não tem conta ainda
            return .cadastro(email: email)
        } catch {
            return .cadastro(email: email)
        }
    }
}
