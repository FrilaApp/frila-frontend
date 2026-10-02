import FrilaDominio
import Observation
import SwiftUI

public enum CampoRepublicarVaga: Hashable, Sendable {
    case inicio
    case fim
}

public enum TextosRepublicarVaga {
    public static let titulo = String(localized: "Republicar vaga", bundle: bundleApresentacao)
    public static let subtitulo = String(localized: "Os dados da vaga anterior foram copiados. Escolha a nova data e horário.", bundle: bundleApresentacao)
    public static let funcao = String(localized: "Função", bundle: bundleApresentacao)
    public static let local = String(localized: "Local", bundle: bundleApresentacao)
    public static let valor = String(localized: "Valor", bundle: bundleApresentacao)
    public static let posicoes = String(localized: "Posições", bundle: bundleApresentacao)
    public static let posicoesFormat = String(localized: "%d posições", bundle: bundleApresentacao)
    public static let modo = String(localized: "Modo de preenchimento", bundle: bundleApresentacao)
    public static let modoSelecao = String(localized: "Modo seleção", bundle: bundleApresentacao)
    public static let modoUrgencia = String(localized: "Modo urgência", bundle: bundleApresentacao)
    public static let novoPeriodo = String(localized: "Novo período", bundle: bundleApresentacao)
    public static let dataInicio = String(localized: "Início", bundle: bundleApresentacao)
    public static let dataFim = String(localized: "Término", bundle: bundleApresentacao)
    public static let confirmar = String(localized: "Confirmar republicação", bundle: bundleApresentacao)
    public static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleApresentacao)
    public static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    public static let sucesso = String(localized: "Vaga republicada com sucesso!", bundle: bundleApresentacao)

    // Mensagens de validação e regras (RN02, RN03, RN18, RN24)
    public static let inicioNoPassado = String(localized: "A data e horário de início devem ser no futuro.", bundle: bundleApresentacao)
    public static let fimAntesDoInicio = String(localized: "O horário de término deve ser após o início.", bundle: bundleApresentacao)
    public static let turnoCurto = String(localized: "O turno deve ter pelo menos 2 horas.", bundle: bundleApresentacao)
    public static let turnoLongo = String(localized: "O turno não pode ultrapassar 16 horas.", bundle: bundleApresentacao)
    public static let selecaoSemAntecedencia = String(localized: "Vagas no modo seleção exigem pelo menos 24 horas de antecedência.", bundle: bundleApresentacao)
    public static let horarioInvalido = String(localized: "Horário informado não é válido.", bundle: bundleApresentacao)

    // Mensagens de erro da API (contrato /rpc/republicar_vaga e publicar_vaga)
    public static let naoEncontrado = String(localized: "A vaga original não foi encontrada.", bundle: bundleApresentacao)
    public static let semPermissao = String(localized: "Você não tem permissão para republicar esta vaga.", bundle: bundleApresentacao)
    public static let vagaOculta = String(localized: "Esta vaga foi ocultada pela moderação e não pode ser republicada.", bundle: bundleApresentacao)
    public static let perfilIncompativel = String(localized: "Apenas contratantes podem republicar vagas.", bundle: bundleApresentacao)
    public static let semRede = String(localized: "Sem conexão com a internet. A solicitação foi guardada para envio.", bundle: bundleApresentacao)
    public static let erroGenerico = String(localized: "Não foi possível republicar a vaga. Tente novamente.", bundle: bundleApresentacao)
}

@MainActor @Observable
public final class RepublicarVagaViewModel {
    public let vagaOriginal: VagaNoPainel
    public var inicio: Date
    public var fim: Date
    public private(set) var enviando = false
    public private(set) var resultado: VagaPublicada?
    public private(set) var mensagemErro: String?
    public private(set) var erros: [CampoRepublicarVaga: String] = [:]
    public private(set) var chave: UUID?
    public private(set) var camposBloqueados = false

    private let republicarAPI: @Sendable (UUID, Periodo, UUID) async throws -> VagaPublicada
    private let fila: (any FilaDeAcoes)?
    private let agora: @Sendable () -> Date
    private let aoConcluir: (@Sendable (VagaPublicada) async -> Void)?

    public init(
        vagaOriginal: VagaNoPainel,
        api: any ApiCliente,
        fila: (any FilaDeAcoes)? = nil,
        agora: @escaping @Sendable () -> Date = Date.init,
        aoConcluir: (@Sendable (VagaPublicada) async -> Void)? = nil
    ) {
        self.vagaOriginal = vagaOriginal
        self.fila = fila
        self.agora = agora
        self.aoConcluir = aoConcluir
        let inicioPadrao = agora().addingTimeInterval(3 * 3600)
        self.inicio = inicioPadrao
        self.fim = inicioPadrao.addingTimeInterval(4 * 3600)
        self.republicarAPI = { id, periodo, chave in
            try await api.republicarVaga(id: id, periodo: periodo, chave: chave)
        }
    }

    public init(
        vagaOriginal: VagaNoPainel,
        fila: (any FilaDeAcoes)? = nil,
        agora: @escaping @Sendable () -> Date = Date.init,
        republicar: @escaping @Sendable (UUID, Periodo, UUID) async throws -> VagaPublicada,
        aoConcluir: (@Sendable (VagaPublicada) async -> Void)? = nil
    ) {
        self.vagaOriginal = vagaOriginal
        self.fila = fila
        self.agora = agora
        self.aoConcluir = aoConcluir
        let inicioPadrao = agora().addingTimeInterval(3 * 3600)
        self.inicio = inicioPadrao
        self.fim = inicioPadrao.addingTimeInterval(4 * 3600)
        self.republicarAPI = republicar
    }

    public func validar() -> Bool {
        erros = [:]
        let instanteAtual = agora()

        if inicio <= instanteAtual {
            erros[.inicio] = TextosRepublicarVaga.inicioNoPassado
        }

        if fim <= inicio {
            erros[.fim] = TextosRepublicarVaga.fimAntesDoInicio
        } else {
            let duracao = fim.timeIntervalSince(inicio)
            if duracao < 2 * 3600 {
                erros[.fim] = TextosRepublicarVaga.turnoCurto
            } else if duracao > 16 * 3600 {
                erros[.fim] = TextosRepublicarVaga.turnoLongo
            }
        }

        if vagaOriginal.modo == .selecao {
            let antecedenciaMinima = instanteAtual.addingTimeInterval(24 * 3600)
            if inicio <= antecedenciaMinima {
                erros[.inicio] = TextosRepublicarVaga.selecaoSemAntecedencia
            }
        }

        return erros.isEmpty
    }

    public func republicar() async {
        guard !enviando else { return }

        // Validação local apenas se não estiver reenviando após falha de rede com campos bloqueados
        if !camposBloqueados {
            guard validar() else { return }
        }

        guard let periodo = try? Periodo(inicio: inicio, fim: fim) else {
            erros[.fim] = TextosRepublicarVaga.horarioInvalido
            return
        }

        let chaveEnvio = self.chave ?? UUID()
        self.chave = chaveEnvio

        enviando = true
        mensagemErro = nil
        defer { enviando = false }

        let acaoPendente = AcaoPendente(
            tipo: .publicacaoVaga,
            instanteDoToque: agora(),
            chave: chaveEnvio
        )

        if let fila {
            do {
                try await fila.enfileirar(acaoPendente)
            } catch {
                // Falha ao registrar na fila não impede o envio direto
            }
        }

        do {
            let vagaPublicada = try await republicarAPI(vagaOriginal.vaga.id, periodo, chaveEnvio)
            resultado = vagaPublicada
            camposBloqueados = false
            if let fila {
                try? await fila.remover(id: acaoPendente.id)
            }
            await aoConcluir?(vagaPublicada)
        } catch let erro as ErroDaApi {
            tratarErro(erro)
            if erro.codigo.recusaDefinitivaDePublicacao || erro.codigo == .vagaOculta {
                camposBloqueados = false
                if let fila {
                    try? await fila.remover(id: acaoPendente.id)
                }
            } else {
                // Erro transitório ou sem rede: campos travados para reenvio idempotente
                camposBloqueados = true
            }
        } catch {
            mensagemErro = TextosRepublicarVaga.erroGenerico
            camposBloqueados = true
        }
    }

    private func tratarErro(_ erro: ErroDaApi) {
        switch erro.codigo {
        case .naoEncontrado:
            mensagemErro = TextosRepublicarVaga.naoEncontrado
        case .semPermissao, .contaSuspensa:
            mensagemErro = TextosRepublicarVaga.semPermissao
        case .vagaOculta:
            mensagemErro = TextosRepublicarVaga.vagaOculta
        case .perfilIncompativel:
            mensagemErro = TextosRepublicarVaga.perfilIncompativel
        case .selecaoSemAntecedencia:
            erros[.inicio] = TextosRepublicarVaga.selecaoSemAntecedencia
            mensagemErro = TextosRepublicarVaga.selecaoSemAntecedencia
        case .horarioInvalido:
            erros[.inicio] = TextosRepublicarVaga.horarioInvalido
            erros[.fim] = TextosRepublicarVaga.horarioInvalido
            mensagemErro = TextosRepublicarVaga.horarioInvalido
        case .campoObrigatorio, .campoInvalido:
            mensagemErro = TextosRepublicarVaga.horarioInvalido
        case .semRede:
            mensagemErro = TextosRepublicarVaga.semRede
        default:
            mensagemErro = TextosRepublicarVaga.erroGenerico
        }
    }
}

public struct TelaRepublicarVaga: View {
    @State private var viewModel: RepublicarVagaViewModel
    @Environment(\.dismiss) private var dismiss
    private let aoFechar: (@Sendable () -> Void)?
    private let formatador = FormatadorFrila()

    public init(viewModel: RepublicarVagaViewModel, aoFechar: (@Sendable () -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.aoFechar = aoFechar
    }

    private func fechar() {
        aoFechar?()
        dismiss()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                cabecalho
                cartaoDadosCopiados
                secaoPeriodo
                if let erro = viewModel.mensagemErro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("aviso-erro-republicacao")
                }
                botoesAcao
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(TextosRepublicarVaga.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.resultado) { _, novo in
            if novo != nil {
                fechar()
            }
        }
        .accessibilityIdentifier("tela-republicar-vaga")
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosRepublicarVaga.titulo)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: TextosRepublicarVaga.subtitulo)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private var cartaoDadosCopiados: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: viewModel.vagaOriginal.vaga.funcao).font(.headline)
                    Spacer(minLength: FrilaEspaco.pequeno)
                    Text(verbatim: formatador.dinheiro(viewModel.vagaOriginal.vaga.valor)).font(.headline)
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: viewModel.vagaOriginal.vaga.funcao).font(.headline)
                    Text(verbatim: formatador.dinheiro(viewModel.vagaOriginal.vaga.valor)).font(.headline)
                }
            }

            Text(verbatim: viewModel.vagaOriginal.vaga.local)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.textoSecundario)

            if !viewModel.vagaOriginal.vaga.regiaoAdministrativa.isEmpty {
                Text(verbatim: viewModel.vagaOriginal.vaga.regiaoAdministrativa)
                    .font(.caption)
                    .foregroundStyle(FrilaCor.textoSecundario)
            }

            HStack {
                Text(verbatim: String(format: TextosRepublicarVaga.posicoesFormat, viewModel.vagaOriginal.posicoes.count))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(verbatim: viewModel.vagaOriginal.modo == .selecao ? TextosRepublicarVaga.modoSelecao : TextosRepublicarVaga.modoUrgencia)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FrilaCor.primaria)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cartao-dados-copiados-republicacao")
    }

    private var secaoPeriodo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
            Text(verbatim: TextosRepublicarVaga.novoPeriodo)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                DatePicker(
                    TextosRepublicarVaga.dataInicio,
                    selection: $viewModel.inicio,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(viewModel.camposBloqueados)
                .accessibilityIdentifier("campo-inicio-republicacao")

                if let erroInicio = viewModel.erros[.inicio] {
                    Text(verbatim: erroInicio)
                        .font(.caption)
                        .foregroundStyle(FrilaCor.perigo)
                        .accessibilityIdentifier("erro-inicio-republicacao")
                }
            }

            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                DatePicker(
                    TextosRepublicarVaga.dataFim,
                    selection: $viewModel.fim,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(viewModel.camposBloqueados)
                .accessibilityIdentifier("campo-fim-republicacao")

                if let erroFim = viewModel.erros[.fim] {
                    Text(verbatim: erroFim)
                        .font(.caption)
                        .foregroundStyle(FrilaCor.perigo)
                        .accessibilityIdentifier("erro-fim-republicacao")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FrilaEspaco.medio)
        .cartaoFrila()
    }

    private var botoesAcao: some View {
        VStack(spacing: FrilaEspaco.pequeno) {
            if viewModel.camposBloqueados {
                BotaoPrimario(verbatim: TextosRepublicarVaga.tentarNovamente, carregando: viewModel.enviando) {
                    Task { await viewModel.republicar() }
                }
                .accessibilityIdentifier("botao-tentar-novamente-republicacao")
            } else {
                BotaoPrimario(verbatim: TextosRepublicarVaga.confirmar, carregando: viewModel.enviando) {
                    Task { await viewModel.republicar() }
                }
                .accessibilityIdentifier("botao-confirmar-republicacao")
            }

            BotaoSecundario(verbatim: TextosRepublicarVaga.cancelar) {
                fechar()
            }
            .accessibilityIdentifier("botao-cancelar-republicacao")
        }
        .padding(.top, FrilaEspaco.pequeno)
    }
}

extension VagaNoPainel: @retroactive Identifiable {
    public var id: UUID { vaga.id }
}

