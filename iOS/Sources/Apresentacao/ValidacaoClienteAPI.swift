import FrilaDominio
import SwiftUI

/// Texto que chega à interface a partir do erro tipado. O código original continua disponível para
/// telemetria, mas nunca é mostrado à pessoa que usa o app.
public enum MensagemDoErroAPI {
    public static func texto(_ erro: ErroDaApi) -> String {
        switch erro.codigo {
        case .posicaoJaPreenchida:
            "Esta vaga acabou de ser preenchida. Escolha outra oportunidade."
        case .vagaEncerrada:
            "Esta vaga não está mais disponível."
        case .checkinPendente:
            "Faça o check-in antes de continuar."
        case .checkinJaConfirmado:
            "Este check-in já foi confirmado."
        case .posicaoNaoCancelavel:
            "Esta posição não pode mais ser cancelada."
        case .semRede:
            "Sem conexão. Tente novamente quando a internet voltar."
        case .naoAutenticado:
            "Sua sessão expirou. Entre novamente para continuar."
        case .semPermissao, .perfilIncompativel:
            "Sua conta não pode realizar esta ação."
        case .limiteExcedido:
            "Você fez muitas tentativas. Aguarde um instante e tente novamente."
        default:
            "Não foi possível concluir esta ação. Tente novamente."
        }
    }
}

/// Superfície exclusiva de builds Debug para conferir o cliente real sem registrar dados pessoais.
/// O botão de conflito só aparece quando a API é o `ApiClienteEmMemoria` (quem decide é o `FrilaApp`).
public struct ValidacaoClienteAPI: View {
    private let api: any ApiCliente
    private let permitirSimulacaoDeConflito: Bool

    @State private var email = ""
    @State private var codigo = ""
    @State private var carregando = false
    @State private var mensagemDeSucesso: String?
    @State private var erro: ErroDaApi?
    @State private var sessao: EstadoDaSessao = .conferindo

    public init(api: any ApiCliente, permitirSimulacaoDeConflito: Bool) {
        self.api = api
        self.permitirSimulacaoDeConflito = permitirSimulacaoDeConflito
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Text("Validação do cliente").font(.title3.bold())
            Text("Use um e-mail de teste que a equipe controla. O endereço e o código não são registrados em logs.")
                .font(.footnote)
                .foregroundStyle(FrilaCor.textoSecundario)

            Text(sessao.texto)
                .font(.footnote)
                .accessibilityIdentifier("validacao-sessao")

            CampoFrila("E-mail de teste", texto: $email)
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .accessibilityIdentifier("validacao-email")
            BotaoPrimario("Enviar código", carregando: carregando) { solicitarCodigo() }
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("validacao-enviar-codigo")

            CampoCodigo(codigo: $codigo)
                .accessibilityIdentifier("validacao-codigo")
            BotaoSecundario("Confirmar código") { confirmarCodigo() }
                .disabled(codigo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || carregando)
                .accessibilityIdentifier("validacao-confirmar-codigo")

            if permitirSimulacaoDeConflito {
                BotaoSecundario("Simular vaga preenchida") { simularVagaPreenchida() }
                    .disabled(carregando)
                    .accessibilityIdentifier("validacao-simular-conflito")
            }

            if let mensagemDeSucesso {
                AvisoFrila(LocalizedStringKey(mensagemDeSucesso), tom: .informativo)
                    .accessibilityIdentifier("validacao-sucesso")
            }

            if let erro {
                AlertaDoErroAPI(erro: erro)
            }
        }
        // Ao abrir, mostra se a sessão guardada no Keychain sobreviveu ao fechamento do app.
        .task { await conferirSessao() }
    }

    private func conferirSessao() async {
        sessao = await api.possuiSessao() ? .ativa : .ausente
    }

    private func solicitarCodigo() {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        executar {
            try await api.solicitarCodigo(email: email)
            return "Código enviado. Consulte a caixa de entrada do e-mail de teste."
        }
    }

    private func confirmarCodigo() {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let codigo = codigo.trimmingCharacters(in: .whitespacesAndNewlines)
        executar {
            try await api.verificarCodigo(email: email, codigo: codigo)
            return "Código confirmado. A sessão foi aberta neste aparelho."
        }
    }

    private func simularVagaPreenchida() {
        executar {
            let vagas = try await api.vagasAbertas()
            guard let vaga = vagas.first else {
                throw ErroDaApi(codigo: .respostaInvalida)
            }
            _ = try await api.candidatar(vagaID: vaga.id)
            return "A simulação não encontrou o conflito esperado."
        }
    }

    private func executar(_ operacao: @escaping @Sendable () async throws -> String) {
        carregando = true
        mensagemDeSucesso = nil
        erro = nil
        Task { @MainActor in
            defer { carregando = false }
            do {
                mensagemDeSucesso = try await operacao()
                codigo = ""
                await conferirSessao()
            } catch let erro as ErroDaApi {
                self.erro = erro
            } catch {
                self.erro = ErroDaApi(codigo: .desconhecido, codigoOriginal: String(reflecting: type(of: error)))
            }
        }
    }
}

enum EstadoDaSessao: Equatable {
    case conferindo, ativa, ausente

    var texto: String {
        switch self {
        case .conferindo: "Conferindo a sessão deste aparelho…"
        case .ativa: "Sessão ativa neste aparelho."
        case .ausente: "Nenhuma sessão neste aparelho."
        }
    }
}

public struct AlertaDoErroAPI: View {
    public let erro: ErroDaApi

    public init(erro: ErroDaApi) {
        self.erro = erro
    }

    public var body: some View {
        AvisoFrila(LocalizedStringKey(MensagemDoErroAPI.texto(erro)), tom: .erro)
            .accessibilityIdentifier("erro-api-\(erro.codigo.rawValue)")
    }
}
