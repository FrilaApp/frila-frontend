import Foundation
import FrilaDominio
import Observation

public indirect enum DestinoCodigo: Equatable, Sendable {
    case cadastro(email: String)
    case destino(DestinoAposEntrada)
    case desafioOTP(email: String, desafioID: String)
    case definirSenha(DestinoCodigo)
}

@MainActor @Observable
public final class CodigoViewModel {
    public enum Modo: Equatable, Sendable {
        case entrada
        case recuperacao
        case loginDispositivo(desafioID: String)
    }

    private let api: any ApiCliente
    public let email: String
    public let modo: Modo
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
    public var avisoDeColagem: String?
    public var lembrarDispositivo: Bool = false
    public private(set) var precisaDefinirSenhaAposConfirmacao: Bool = false
    public private(set) var dispositivoLembradoNaConfirmacao: Bool = false

    /// Quanto tempo o código vale depois de enviado: 600 s (10 min), o `mailer_otp_exp` do Auth no Prod
    /// (confirmado pela Forja em 13/11/2026; o e-mail diz o mesmo). Mudou no Auth? Mude aqui no mesmo dia.
    public static let validadeDoCodigo: TimeInterval = 600

    private let relogio: any Relogio
    /// Quando o último código foi pedido (primeiro envio ou reenvio).
    private var codigoPedidoEm: Date
    private var desafioIDAtual: String?
    private var tarefaTemporizador: Task<Void, Never>?

    public init(api: any ApiCliente, email: String, modo: Modo = .entrada, relogio: any Relogio = RelogioDoSistema()) {
        self.api = api
        self.modo = modo
        self.relogio = relogio
        self.codigoPedidoEm = relogio.agora
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if case let .loginDispositivo(desafioID) = modo {
            self.desafioIDAtual = desafioID
        }
        iniciarTemporizador()
    }

    public func iniciarTemporizador(segundos: Int = 60) {
        codigoPedidoEm = relogio.agora
        segundosRestantes = max(1, segundos)
        tarefaTemporizador?.cancel()
        tarefaTemporizador = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { break }
                guard self.segundosRestantes > 0 else { break }
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

    /// Recebe o que o `PasteButton` entregou. Só o código extraído é guardado; o resto do texto é descartado.
    public func colar(_ textos: [String]) {
        var encontrado: String?
        for texto in textos {
            if let codigoExtraido = ExtratorDeCodigo.extrair(de: texto) {
                encontrado = codigoExtraido
                break
            }
        }
        guard let encontrado else {
            avisoDeColagem = String(localized: "Não encontramos um código no que você copiou. Copie os 6 números do e-mail e toque em Colar.", bundle: bundleApresentacao)
            return
        }
        avisoDeColagem = nil
        erro = nil
        codigo = encontrado
    }

    /// O que o VoiceOver anuncia depois de um reenvio: só o sucesso. Com erro (ou sem reenvio, no `guard` da contagem),
    /// o erro na tela já diz o que houve, e anunciar "Novo código enviado" seria falso.
    public var anuncioDoReenvio: String? {
        erro == nil ? mensagemInformativa : nil
    }

    public func reenviarCodigo() async {
        guard podeReenviar else { return }
        carregando = true
        erro = nil
        mensagemInformativa = nil
        defer { carregando = false }

        switch modo {
        case .entrada:
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

        case .recuperacao:
            // Recuperação nunca cria usuário novo (`shouldCreateUser: false`) e não usa fallback de demo.
            do {
                try await api.solicitarCodigoDeRecuperacao(email: email)
                guard !Task.isCancelled else { return }
                iniciarTemporizador()
                mensagemInformativa = String(localized: "Novo código enviado para seu e-mail.", bundle: bundleApresentacao)
            } catch is CancellationError {
                return
            } catch let erroApi as ErroDaApi {
                guard !Task.isCancelled else { return }
                if erroApi.codigo == .naoEncontrado
                    || erroApi.codigoOriginal == "otp_disabled"
                    || erroApi.codigoOriginal == "user_not_found" {
                    iniciarTemporizador()
                    mensagemInformativa = String(
                        localized: "Se existir uma conta ativa com este e-mail, enviaremos um novo código.",
                        bundle: bundleApresentacao
                    )
                    return
                }
                erro = MensagemDoErroAPI.texto(erroApi)
            } catch {
                guard !Task.isCancelled else { return }
                erro = String(localized: "Não foi possível reenviar o código. Tente novamente.", bundle: bundleApresentacao)
            }

        case .loginDispositivo:
            guard let desafioID = desafioIDAtual else {
                erro = String(localized: "Não foi possível reenviar o código. Tente novamente.", bundle: bundleApresentacao)
                return
            }
            do {
                let resposta = try await api.reenviarDispositivoOTP(desafioID: desafioID)
                guard !Task.isCancelled else { return }
                desafioIDAtual = resposta.desafioID
                iniciarTemporizador(segundos: resposta.reenviarEmSegundos)
                mensagemInformativa = String(localized: "Novo código enviado para seu e-mail.", bundle: bundleApresentacao)
            } catch is CancellationError {
                return
            } catch let erroApi as ErroDaApi {
                guard !Task.isCancelled else { return }
                tratarErroDeVerificacao(erroApi)
            } catch {
                guard !Task.isCancelled else { return }
                erro = String(localized: "Não foi possível reenviar o código. Tente novamente.", bundle: bundleApresentacao)
            }
        }
    }

    public func confirmarCodigo() async -> DestinoCodigo? {
        guard !carregando else { return nil }
        guard codigoValido else {
            erro = String(localized: "Digite os 6 números do código.", bundle: bundleApresentacao)
            return nil
        }
        carregando = true
        erro = nil
        mensagemInformativa = nil
        precisaDefinirSenhaAposConfirmacao = false
        dispositivoLembradoNaConfirmacao = false
        defer { carregando = false }

        do {
            if modo == .entrada, DemonstracaoContas.ehEmailDeDemonstracao(email) {
                try await api.entrarDemonstracao(email: email, codigo: codigo)
            } else {
                let origem: OrigemConfirmacaoDispositivoOTP
                switch modo {
                case .entrada:
                    origem = .cadastro(email: email)
                case .recuperacao:
                    origem = .recuperacao(email: email)
                case .loginDispositivo:
                    guard let desafioID = desafioIDAtual else {
                        erro = String(localized: "Código expirado. Volte e entre novamente.", bundle: bundleApresentacao)
                        return nil
                    }
                    origem = .loginDispositivo(desafioID: desafioID)
                }
                let resultado = try await api.confirmarDispositivoOTP(
                    origem: origem,
                    codigo: codigo,
                    lembrarDispositivo: lembrarDispositivo
                )
                precisaDefinirSenhaAposConfirmacao = resultado.precisaDefinirSenha
                dispositivoLembradoNaConfirmacao = resultado.dispositivoLembrado
            }
        } catch is CancellationError {
            return nil
        } catch let erroApi as ErroDaApi {
            tratarErroDeVerificacao(erroApi)
            return nil
        } catch {
            erro = String(localized: "Não foi possível confirmar o código. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }

        guard !Task.isCancelled else { return nil }

        do {
            let destino = try await DestinoDaConta.avaliar(api: api, emailParaCadastro: email)
            switch destino {
            case let .cadastro(emailCad):
                return .cadastro(email: emailCad ?? email)
            case .profissional:
                DestinoGuardado.salvar(.profissional)
                return .destino(.profissional)
            case .funcoesEHorarios:
                DestinoGuardado.salvar(.funcoesEHorarios)
                return .destino(.funcoesEHorarios)
            case .contratante:
                DestinoGuardado.salvar(.contratante)
                return .destino(.contratante)
            case let .contaSuspensa(situacao):
                return .destino(.contaSuspensa(situacao))
            case .definirSenhaObrigatoria:
                return .definirSenha(.cadastro(email: email))
            }
        } catch let erroApi as ErroDaApi {
            erro = MensagemDoErroAPI.texto(erroApi)
            return nil
        } catch {
            erro = String(localized: "Não foi possível confirmar o código. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }
    }

    private func tratarErroDeVerificacao(_ erroApi: ErroDaApi) {
        if erroApi.codigoOriginal == "desafio_expirado" {
            erro = String(localized: "Código expirado. Peça um novo código para continuar.", bundle: bundleApresentacao)
            return
        }
        if erroApi.codigoOriginal == "desafio_ja_usado" {
            erro = String(localized: "Este código já foi usado. Peça um novo código para continuar.", bundle: bundleApresentacao)
            return
        }
        if erroApi.codigo == .naoAutenticado {
            // O GoTrue devolve `otp_expired` para o código errado e para o vencido. Só o tempo desde o pedido
            // distingue os dois: dentro da validade, o que se digitou está errado.
            let vencido = relogio.agora.timeIntervalSince(codigoPedidoEm) >= Self.validadeDoCodigo
            if erroApi.codigoOriginal == "otp_expired", vencido {
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
}
