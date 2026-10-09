import Foundation
import FrilaDominio
#if canImport(MessageUI)
import MessageUI
#endif
import Observation
import UIKit

/// Contexto com os dados do turno necessários para gerar o e-mail pré-preenchido de suporte.
public struct ContextoSuporteTurno: Sendable, Equatable {
    public let turnoID: UUID
    public let funcao: String
    public let contratante: String
    public let profissional: String
    public let inicio: Date
    public let fim: Date
    public let endereco: String

    public init(
        turnoID: UUID,
        funcao: String,
        contratante: String,
        profissional: String,
        inicio: Date,
        fim: Date,
        endereco: String
    ) {
        self.turnoID = turnoID
        self.funcao = funcao
        self.contratante = contratante
        self.profissional = profissional
        self.inicio = inicio
        self.fim = fim
        self.endereco = endereco
    }

    /// Cria o contexto a partir do turno visto pelo profissional.
    public init(turno: Turno, nomeProfissional: String? = nil) {
        self.init(
            turnoID: turno.id,
            funcao: turno.vaga.funcao,
            contratante: turno.contraparte.nome,
            profissional: nomeProfissional ?? "Profissional do turno",
            inicio: turno.vaga.periodo.inicio,
            fim: turno.vaga.periodo.fim,
            endereco: turno.vaga.local
        )
    }

    /// Cria o contexto a partir do turno acompanhado pelo contratante.
    public init(turnoAcompanhado: TurnoAcompanhado, nomeContratante: String? = nil) {
        self.init(
            turnoID: turnoAcompanhado.posicao.turnoID ?? turnoAcompanhado.posicao.id,
            funcao: turnoAcompanhado.vaga.funcao,
            contratante: nomeContratante ?? "Contratante",
            profissional: turnoAcompanhado.posicao.profissional?.nome ?? "Profissional do turno",
            inicio: turnoAcompanhado.vaga.periodo.inicio,
            fim: turnoAcompanhado.vaga.periodo.fim,
            endereco: turnoAcompanhado.vaga.local
        )
    }

    /// Data e horário do turno formatados no padrão do Frila.
    public var horarioFormatado: String {
        let formatador = FormatadorFrila()
        if let periodo = try? Periodo(inicio: inicio, fim: fim) {
            return formatador.intervalo(periodo)
        } else {
            return "\(formatador.dataEHora(inicio)) – \(formatador.hora(fim))"
        }
    }
}

/// Motivos de suporte disponíveis na folha do turno.
public enum MotivoSuporteTurno: String, CaseIterable, Identifiable, Hashable, Equatable, Sendable {
    case riscoSeguranca = "risco_seguranca"
    case atrasoOuImprevisto = "atraso_imprevisto"
    case problemaNoLocal = "problema_local"
    case dificuldadePresenca = "dificuldade_presenca"
    case outro = "outro"

    public var id: String { rawValue }

    public var rotulo: String {
        switch self {
        case .riscoSeguranca:
            TextosDoSuporte.motivoRiscoSeguranca
        case .atrasoOuImprevisto:
            TextosDoSuporte.motivoAtrasoOuImprevisto
        case .problemaNoLocal:
            TextosDoSuporte.motivoProblemaNoLocal
        case .dificuldadePresenca:
            TextosDoSuporte.motivoDificuldadePresenca
        case .outro:
            TextosDoSuporte.motivoOutro
        }
    }

    public var ehRiscoSeguranca: Bool {
        self == .riscoSeguranca
    }

    /// Mapeia para a categoria oficial do contrato 0.2.40 (UC14, RF23).
    public var categoriaSuporte: CategoriaSuporte {
        switch self {
        case .riscoSeguranca: .seguranca
        case .atrasoOuImprevisto: .atraso
        case .problemaNoLocal: .endereco
        case .dificuldadePresenca: .conduta
        case .outro: .outro
        }
    }
}

/// View model para a folha de acionamento do suporte no turno (US22, RF23, contrato 0.2.40).
@MainActor @Observable
public final class SuporteTurnoViewModel: Identifiable {
    public let dados: ContextoSuporteTurno
    public let emailDestino: String
    public let api: (any ApiCliente)?
    public var motivo: MotivoSuporteTurno
    public var relato: String
    public private(set) var copiadoComSucesso: Bool = false
    public private(set) var falhaAoAbrirEmail: Bool = false
    public var mostrandoCompositorNativo: Bool = false

    /// Chave de idempotência (SU-RN02, F1). Permanece a mesma em tentativas do mesmo chamado.
    public let chaveIdempotente: UUID
    /// Protocolo devolvido pela RPC abrir_suporte (contrato 0.2.40).
    public private(set) var protocolo: Protocolo?
    /// Indica se a RPC está sendo executada.
    public private(set) var enviando: Bool = false
    /// Mensagem de recusa amigável (403 conta suspensa, 429 limite diário, etc.).
    public private(set) var mensagemDeErro: String?

    private let verificadorPodeEnviarEmail: (@Sendable () -> Bool)?
    private let copiador: (@Sendable (String) -> Void)?

    public init(
        dados: ContextoSuporteTurno,
        api: (any ApiCliente)? = nil,
        emailDestino: String = "suporte@frila.app",
        motivoInicial: MotivoSuporteTurno = .atrasoOuImprevisto,
        relatoInicial: String = "",
        chaveIdempotente: UUID = UUID(),
        verificadorPodeEnviarEmail: (@Sendable () -> Bool)? = nil,
        copiador: (@Sendable (String) -> Void)? = nil
    ) {
        self.dados = dados
        self.api = api
        self.emailDestino = emailDestino
        self.motivo = motivoInicial
        self.relato = relatoInicial
        self.chaveIdempotente = chaveIdempotente
        self.verificadorPodeEnviarEmail = verificadorPodeEnviarEmail
        self.copiador = copiador
    }

    public var ehRiscoSeguranca: Bool {
        motivo.ehRiscoSeguranca
    }

    /// Assunto padronizado com o protocolo curto quando registrado, ou identificador do turno (contrato 0.2.40, SU-RN04).
    public var assuntoEmail: String {
        if let protocolo {
            return "[Frila Suporte #\(protocolo.protocoloCurto)] \(dados.funcao)"
        }
        return "[Turno \(dados.turnoID)] \(dados.funcao)"
    }

    /// Corpo estruturado com as partes, horários e relato.
    public var corpoEmail: String {
        let relatoLimpo = relato.trimmingCharacters(in: .whitespacesAndNewlines)
        let relatoFinal = relatoLimpo.isEmpty ? "Nenhum relato adicional informado." : relatoLimpo

        var linhas = [
            "Identificação do Turno:",
            "- ID: \(dados.turnoID)",
            "- Função: \(dados.funcao)",
            "- Contratante: \(dados.contratante)",
            "- Profissional: \(dados.profissional)",
            "- Horário: \(dados.horarioFormatado)",
            "- Local: \(dados.endereco)"
        ]

        if let protocolo {
            linhas.append("- Protocolo: #\(protocolo.protocoloCurto)")
            linhas.append("- Prazo de resposta: até \(FormatadorFrila().data(protocolo.prazoRespostaAte))")
        }

        linhas.append("")
        linhas.append("Motivo do Chamado:")
        linhas.append(motivo.rotulo)
        linhas.append("")
        linhas.append("Relato:")
        linhas.append(relatoFinal)

        return linhas.joined(separator: "\n")
    }

    /// Conteúdo completo para cópia (caso o usuário envie de outro cliente).
    public var conteudoParaCopia: String {
        """
        Para: \(emailDestino)
        Assunto: \(assuntoEmail)

        \(corpoEmail)
        """
    }

    /// URL `mailto:` pré-preenchida para fallback quando o Mail nativo não estiver configurado.
    public var urlMailto: URL? {
        var componentes = URLComponents()
        componentes.scheme = "mailto"
        componentes.path = emailDestino
        componentes.queryItems = [
            URLQueryItem(name: "subject", value: assuntoEmail),
            URLQueryItem(name: "body", value: corpoEmail)
        ]
        return componentes.url
    }

    /// Verifica se o dispositivo possui conta de e-mail pronta no cliente nativo da Apple.
    public var podeEnviarEmailNativo: Bool {
        if let verificadorPodeEnviarEmail {
            return verificadorPodeEnviarEmail()
        }
        #if canImport(MessageUI)
        return MFMailComposeViewController.canSendMail()
        #else
        return false
        #endif
    }

    /// Copia o conteúdo estruturado para a área de transferência do sistema.
    public func copiarDadosParaTransferencia() {
        if let copiador {
            copiador(conteudoParaCopia)
        } else {
            UIPasteboard.general.string = conteudoParaCopia
        }
        copiadoComSucesso = true
    }

    /// O compositor nativo fechou (enviado, salvo ou cancelado). Sem isto o `.sheet(isPresented:)`
    /// continuava verdadeiro depois de o UIKit dispensar o compositor, e o botão de e-mail não
    /// abria de novo até fechar a folha.
    public func compositorConcluido() {
        mostrandoCompositorNativo = false
    }

    /// Registra que a tentativa de abertura do e-mail não teve sucesso pelo sistema.
    public func registrarFalhaAoAbrirEmail() {
        falhaAoAbrirEmail = true
    }

    /// Abre o suporte chamando a RPC abrir_suporte e, em seguida, dispara o cliente de e-mail (SU-RF03).
    public func registrarEEnviar(abridorURL: ((URL) -> Void)? = nil) async {
        mensagemDeErro = nil
        falhaAoAbrirEmail = false

        if let api, protocolo == nil {
            enviando = true
            defer { enviando = false }
            do {
                let prot = try await api.abrirSuporte(
                    turnoID: dados.turnoID,
                    categoria: motivo.categoriaSuporte,
                    chave: chaveIdempotente
                )
                self.protocolo = prot
            } catch let erro as ErroDaApi {
                if erro.codigo == .semPermissao && erro.detalhes == "conta_suspensa" {
                    mensagemDeErro = TextosDoSuporte.contaSuspensa
                } else if erro.codigo == .limiteExcedido {
                    mensagemDeErro = TextosDoSuporte.limiteExcedido
                } else {
                    mensagemDeErro = TextosDoSuporte.erroAoRegistrarChamado
                }
                return
            } catch {
                mensagemDeErro = TextosDoSuporte.erroAoRegistrarChamado
                return
            }
        }

        abrirEmail(comAbridorURL: abridorURL)
    }

    /// Aciona a abertura de e-mail: se nativo disponível, abre compositor; senão, dispara URL mailto.
    public func abrirEmail(comAbridorURL abrirURL: ((URL) -> Void)? = nil) {
        falhaAoAbrirEmail = false
        if podeEnviarEmailNativo {
            mostrandoCompositorNativo = true
        } else if let url = urlMailto, let abrirURL {
            abrirURL(url)
        } else {
            falhaAoAbrirEmail = true
        }
    }

    /// Aciona a abertura de e-mail recebendo o retorno da tentativa do sistema.
    public func abrirEmail(comAbridorComResultado abrirURL: ((URL, @escaping (Bool) -> Void) -> Void)?) {
        falhaAoAbrirEmail = false
        if podeEnviarEmailNativo {
            mostrandoCompositorNativo = true
        } else if let url = urlMailto, let abrirURL {
            abrirURL(url) { [weak self] aceito in
                if !aceito {
                    self?.falhaAoAbrirEmail = true
                }
            }
        } else {
            falhaAoAbrirEmail = true
        }
    }
}
