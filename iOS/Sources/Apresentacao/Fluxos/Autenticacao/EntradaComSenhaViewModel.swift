import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class EntradaComSenhaViewModel {
    private let api: any ApiCliente
    private let provedorSocial: any ProvedorUIAutenticacaoSocial
    public var email: String
    public var senha: String = ""
    public var carregando: Bool = false
    public var erro: String?

    /// Identifica a tentativa corrente para que uma chamada cancelada ou atrasada nunca sobrescreva
    /// o estado nem entregue um destino obsoleto para uma tentativa posterior.
    private var tentativaAtual: UUID?

    public init(
        api: any ApiCliente,
        emailInicial: String = "",
        provedorSocial: (any ProvedorUIAutenticacaoSocial)? = nil
    ) {
        self.api = api
        self.email = emailInicial
        self.provedorSocial = provedorSocial ?? AutenticadorSocialNativo()
    }

    /// Apple e Google aparecem sempre juntos (diretriz 4.8 da App Store), somente quando habilitados no build.
    public var mostrarLoginSocial: Bool {
        api.suportaLoginSocial
    }

    public var emailNormalizado: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public var emailValido: Bool {
        let limpo = emailNormalizado
        guard limpo.contains("@") else { return false }
        let partes = limpo.split(separator: "@")
        guard partes.count == 2, !partes[0].isEmpty, partes[1].contains(".") else { return false }
        return true
    }

    public func cancelarTentativaAtual() {
        tentativaAtual = nil
        carregando = false
    }

    public func entrar() async -> DestinoCodigo? {
        guard !carregando else { return nil }
        let limpo = emailNormalizado
        guard emailValido else {
            erro = String(localized: "Informe um e-mail válido.", bundle: bundleApresentacao)
            return nil
        }
        guard !senha.isEmpty else {
            erro = String(localized: "Digite sua senha para entrar.", bundle: bundleApresentacao)
            return nil
        }
        if DemonstracaoContas.ehEmailDeDemonstracao(limpo) {
            erro = String(localized: "Esta conta entra apenas com código por e-mail.", bundle: bundleApresentacao)
            return nil
        }

        let tentativa = UUID()
        tentativaAtual = tentativa
        carregando = true
        erro = nil
        let senhaEnviada = senha

        defer {
            if tentativaAtual == tentativa {
                carregando = false
            }
        }

        let resultado: ResultadoEntradaComSenha
        do {
            resultado = try await api.entrarComSenha(email: limpo, senha: senhaEnviada)
        } catch is CancellationError {
            return nil
        } catch let erroApi as ErroDaApi {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            tratarErroDeEntrada(erroApi)
            return nil
        } catch {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = String(localized: "Não foi possível entrar agora. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }

        guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }

        switch resultado {
        case let .desafioOTP(desafioID, _):
            senha = ""
            return .desafioOTP(email: limpo, desafioID: desafioID)
        case let .autenticado(precisaDefinirSenha):
            do {
                let destino = try await DestinoDaConta.avaliar(api: api, emailParaCadastro: limpo)
                guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
                senha = ""
                let proximo: DestinoCodigo
                switch destino {
                case let .cadastro(emailCad):
                    proximo = .cadastro(email: emailCad ?? limpo)
                case .profissional:
                    DestinoGuardado.salvar(.profissional)
                    proximo = .destino(.profissional)
                case .funcoesEHorarios:
                    DestinoGuardado.salvar(.funcoesEHorarios)
                    proximo = .destino(.funcoesEHorarios)
                case .contratante:
                    DestinoGuardado.salvar(.contratante)
                    proximo = .destino(.contratante)
                case let .contaSuspensa(situacao):
                    proximo = .destino(.contaSuspensa(situacao))
                case .definirSenhaObrigatoria:
                    proximo = .cadastro(email: limpo)
                }
                return precisaDefinirSenha ? .definirSenha(proximo) : proximo
            } catch is CancellationError {
                return nil
            } catch let erroApi as ErroDaApi {
                guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
                erro = MensagemDoErroAPI.texto(erroApi)
                return nil
            } catch {
                guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
                erro = String(localized: "Não foi possível entrar agora. Tente novamente.", bundle: bundleApresentacao)
                return nil
            }
        }
    }

    public func entrarComApple() async -> DestinoCodigo? {
        guard !carregando, api.suportaLoginSocial else { return nil }
        let tentativa = UUID()
        tentativaAtual = tentativa
        carregando = true
        erro = nil

        defer {
            if tentativaAtual == tentativa {
                carregando = false
            }
        }

        do {
            let nonceBruto = SegurancaOAuthSocial.gerarNonceBruto()
            let nonceSha256 = SegurancaOAuthSocial.sha256Hex(nonceBruto)
            let credencial = try await provedorSocial.solicitarApple(nonceSha256: nonceSha256)
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }

            let resultado = try await api.entrarComApple(idToken: credencial.idToken, nonce: nonceBruto)
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }

            let emailResolvido = resultado.email ?? credencial.email ?? ""
            return await resolverDestinoAposSocial(email: emailResolvido, tentativa: tentativa)
        } catch is CancellationError {
            return nil
        } catch let erroSocial as ErroEntradaSocial {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            tratarErroSocial(erroSocial)
            return nil
        } catch {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = String(localized: "Não foi possível entrar agora. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }
    }

    public func entrarComGoogle() async -> DestinoCodigo? {
        guard !carregando, api.suportaLoginSocial else { return nil }
        let tentativa = UUID()
        tentativaAtual = tentativa
        carregando = true
        erro = nil

        defer {
            if tentativaAtual == tentativa {
                carregando = false
            }
        }

        do {
            let verifier = SegurancaOAuthSocial.gerarVerifierPKCE()
            let challenge = SegurancaOAuthSocial.desafioPKCES256(verifier)
            let txLocal = SegurancaOAuthSocial.gerarState()
            var redirectComps = URLComponents(url: SegurancaOAuthSocial.urlCallbackPadrao, resolvingAgainstBaseURL: false)
            redirectComps?.queryItems = [URLQueryItem(name: "tx", value: txLocal)]
            let redirectTo = redirectComps?.url ?? SegurancaOAuthSocial.urlCallbackPadrao

            let inicio = try await api.iniciarLoginSocialPKCE(
                provedor: .google,
                redirectTo: redirectTo,
                codeChallenge: challenge
            )
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }

            let callbackURL = try await provedorSocial.abrirSessaoWebOAuth(
                url: inicio.urlAutorizacao,
                esquemaCallback: SegurancaOAuthSocial.esquemaCallbackPadrao
            )
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }

            let codigo = try SegurancaOAuthSocial.extrairCodigoDoCallback(
                url: callbackURL,
                esquemaEsperado: SegurancaOAuthSocial.esquemaCallbackPadrao,
                stateEsperado: txLocal
            ).get()

            let resultado = try await api.concluirLoginSocialPKCE(
                provedor: .google,
                transacaoID: inicio.transacaoID,
                codigo: codigo,
                verifier: verifier
            )
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }

            return await resolverDestinoAposSocial(email: resultado.email ?? "", tentativa: tentativa)
        } catch is CancellationError {
            return nil
        } catch let erroSocial as ErroEntradaSocial {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            tratarErroSocial(erroSocial)
            return nil
        } catch {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = String(localized: "Não foi possível entrar agora. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }
    }

    private func resolverDestinoAposSocial(email: String, tentativa: UUID) async -> DestinoCodigo? {
        do {
            let destino = try await DestinoDaConta.avaliar(api: api, emailParaCadastro: email)
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            senha = ""
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
                return .cadastro(email: email)
            }
        } catch is CancellationError {
            return nil
        } catch let erroApi as ErroDaApi {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = MensagemDoErroAPI.texto(erroApi)
            return nil
        } catch {
            guard tentativaAtual == tentativa, !Task.isCancelled else { return nil }
            erro = String(localized: "Não foi possível entrar agora. Tente novamente.", bundle: bundleApresentacao)
            return nil
        }
    }

    private func tratarErroSocial(_ erroSocial: ErroEntradaSocial) {
        switch erroSocial {
        case .cancelado:
            erro = nil
        case .conflitoDeIdentidade:
            erro = String(
                localized: "Esta conta social não pôde ser vinculada automaticamente. Entre com seu e-mail e senha.",
                bundle: bundleApresentacao
            )
        case .limiteExcedido:
            erro = String(
                localized: "Muitas tentativas. Aguarde um minuto e tente novamente.",
                bundle: bundleApresentacao
            )
        case .rede:
            erro = String(
                localized: "Sem conexão no momento. Tente novamente em instantes.",
                bundle: bundleApresentacao
            )
        case .callbackInvalido, .provedorIndisponivel:
            erro = String(
                localized: "Não foi possível concluir a entrada agora. Tente novamente ou use e-mail e senha.",
                bundle: bundleApresentacao
            )
        }
    }

    private func tratarErroDeEntrada(_ erroApi: ErroDaApi) {
        if erroApi.codigo == .naoAutenticado {
            erro = String(localized: "E-mail ou senha incorretos. Confira os dados ou entre com código.", bundle: bundleApresentacao)
        } else {
            erro = MensagemDoErroAPI.texto(erroApi)
        }
    }
}
