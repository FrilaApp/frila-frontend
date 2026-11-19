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
    public static let fechar = String(localized: "Fechar", bundle: bundleApresentacao)
    public static let tentativaContinua = String(localized: "A republicação continua e será concluída quando a conexão voltar.", bundle: bundleApresentacao)
    public static let erroAoLerFila = String(localized: "Não foi possível verificar a republicação pendente. Tente novamente antes de confirmar.", bundle: bundleApresentacao)
    public static let sucesso = String(localized: "Vaga republicada.", bundle: bundleApresentacao)

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
    public static let vagaOculta = String(localized: "Esta vaga está em revisão pela Equipe Frila e não pode ser republicada.", bundle: bundleApresentacao)
    public static let perfilIncompativel = String(localized: "Apenas contratantes podem republicar vagas.", bundle: bundleApresentacao)
    public static let semRede = String(localized: "Sem conexão com a internet. A solicitação foi guardada para envio.", bundle: bundleApresentacao)
    public static let erroGenerico = String(localized: "Não foi possível republicar a vaga. Tente novamente.", bundle: bundleApresentacao)
}

@MainActor @Observable
public final class RepublicarVagaViewModel {
    public let vagaOriginal: VagaNoPainel
    public var inicio: Date {
        didSet {
            let duracao = fim.timeIntervalSince(oldValue)
            if duracao > 0 {
                fim = inicio.addingTimeInterval(duracao)
            }
        }
    }
    public var fim: Date
    public private(set) var enviando = false
    public private(set) var resultado: VagaPublicada?
    public private(set) var mensagemErro: String?
    public private(set) var recusaDaFila: AcaoRecusada?
    public private(set) var erros: [CampoRepublicarVaga: String] = [:]
    public private(set) var chave: UUID?
    public private(set) var camposBloqueados = false
    public private(set) var republicacaoPendente: RepublicacaoVaga?
    public private(set) var acaoPendente: AcaoPendente?

    public private(set) var restaurandoTentativa = false
    public private(set) var tentativaRestaurada: Bool
    public var podeConfirmar: Bool { tentativaRestaurada && !enviando }
    public var textoAoFechar: String {
        republicacaoPendente == nil ? TextosRepublicarVaga.cancelar : TextosRepublicarVaga.fechar
    }

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
        self.tentativaRestaurada = fila == nil
        self.agora = agora
        self.aoConcluir = aoConcluir
        let antecedencia: TimeInterval = vagaOriginal.modo == .selecao ? 25 * 3600 : 3 * 3600
        let inicioPadrao = agora().addingTimeInterval(antecedencia)
        self.inicio = inicioPadrao
        let duracaoOriginal = vagaOriginal.vaga.periodo.fim.timeIntervalSince(vagaOriginal.vaga.periodo.inicio)
        self.fim = inicioPadrao.addingTimeInterval(duracaoOriginal)
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
        self.tentativaRestaurada = fila == nil
        self.agora = agora
        self.aoConcluir = aoConcluir
        let antecedencia: TimeInterval = vagaOriginal.modo == .selecao ? 25 * 3600 : 3 * 3600
        let inicioPadrao = agora().addingTimeInterval(antecedencia)
        self.inicio = inicioPadrao
        let duracaoOriginal = vagaOriginal.vaga.periodo.fim.timeIntervalSince(vagaOriginal.vaga.periodo.inicio)
        self.fim = inicioPadrao.addingTimeInterval(duracaoOriginal)
        self.republicarAPI = republicar
    }

    public func fecharAvisoDaFila() async {
        guard let recusa = recusaDaFila else { return }
        do {
            try await fila?.reconhecerRecusa(id: recusa.id)
            await carregarRecusaDaFila()
        } catch { /* Mantém o aviso se o reconhecimento não foi gravado. */ }
    }

    public func carregarRecusaDaFila() async {
        let recusadas = (try? await fila?.recusadas().filter { $0.tipo == .republicacaoVaga && $0.vagaID == vagaOriginal.vaga.id }) ?? []
        recusaDaFila = recusadas.first { $0.id == acaoPendente?.id } ?? recusadas.first
        if let recusaDaFila, acaoPendente?.id == recusaDaFila.id {
            acaoPendente = nil
            republicacaoPendente = nil
            camposBloqueados = false
        }
    }

    public func restaurarTentativaPendente() async {
        await carregarRecusaDaFila()
        guard !tentativaRestaurada, !restaurandoTentativa, let fila else { return }
        restaurandoTentativa = true
        defer { restaurandoTentativa = false }
        do {
            let pendentes = try await fila.pendentes()
            if let acao = pendentes.first(where: {
                $0.tipo == .republicacaoVaga && $0.republicacao?.vagaID == vagaOriginal.vaga.id
            }), let rep = acao.republicacao {
                self.acaoPendente = acao
                self.republicacaoPendente = rep
                self.chave = acao.chave
                self.inicio = rep.periodo.inicio
                self.fim = rep.periodo.fim
                self.camposBloqueados = true
            }
            tentativaRestaurada = true
            mensagemErro = nil
        } catch {
            mensagemErro = TextosRepublicarVaga.erroAoLerFila
        }
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
        guard !enviando, resultado == nil else { return }
        if !tentativaRestaurada { await restaurarTentativaPendente() }
        guard tentativaRestaurada else { return }

        // Se ainda não temos uma tentativa congelada, validamos e congelamos
        if republicacaoPendente == nil {
            guard validar() else { return }
            guard let periodo = try? Periodo(inicio: inicio, fim: fim) else {
                erros[.fim] = TextosRepublicarVaga.horarioInvalido
                return
            }
            let chaveEnvio = self.chave ?? UUID()
            self.chave = chaveEnvio
            let rep = RepublicacaoVaga(vagaID: vagaOriginal.vaga.id, periodo: periodo)
            let acao = AcaoPendente(
                tipo: .republicacaoVaga,
                instanteDoToque: agora(),
                chave: chaveEnvio,
                republicacao: rep
            )
            self.republicacaoPendente = rep
            self.acaoPendente = acao
        }

        guard let acao = acaoPendente, let rep = republicacaoPendente else { return }

        enviando = true
        mensagemErro = nil
        defer { enviando = false }

        if let fila {
            do {
                try await fila.enfileirar(acao)
            } catch {
                // Falha ao registrar na fila não impede o envio direto
            }
        }

        do {
            let vagaPublicada = try await republicarAPI(rep.vagaID, rep.periodo, acao.chave)
            camposBloqueados = false
            try? await fila?.resolverRecusas(acao)
            recusaDaFila = nil
            if let fila {
                try? await fila.remover(id: acao.id)
            }
            republicacaoPendente = nil
            acaoPendente = nil
            await aoConcluir?(vagaPublicada)
            resultado = vagaPublicada
        } catch let erro as ErroDaApi {
            if erro.codigo == .semRede {
                // Sem rede: campos travados para reenvio e a republicação continua na fila.
                // Não define mensagemErro para exibir apenas o aviso azul de continuação.
                camposBloqueados = true
                mensagemErro = nil
            } else {
                tratarErro(erro)
                if erro.codigo.recusaDefinitivaDePublicacao || erro.codigo == .vagaOculta {
                    camposBloqueados = false
                    if let fila {
                        try? await fila.remover(id: acao.id)
                    }
                    republicacaoPendente = nil
                    acaoPendente = nil
                } else {
                    // Erro transitório: campos travados para reenvio idempotente
                    camposBloqueados = true
                }
            }
        } catch is URLError {
            camposBloqueados = true
            mensagemErro = nil
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
            mensagemErro = nil
        default:
            mensagemErro = TextosRepublicarVaga.erroGenerico
        }
    }
}

/// Republicação de uma vaga com os dados da anterior: cartão com o que foi copiado, o novo período e a confirmação
/// (um botão laranja, ancorado embaixo; "Cancelar" ou "Fechar" na barra da folha).
public struct TelaRepublicarVaga: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: RepublicarVagaViewModel
    @Environment(\.dismiss) private var dismiss
    private let aoFechar: (@Sendable () -> Void)?
    private let formatador = FormatadorFrila()
    private static let idDoInicio = "campo-inicio-republicacao"
    private static let idDoFim = "campo-fim-republicacao"
    /// O que a folha de horário está editando (só em tamanho de acessibilidade).
    @State private var editandoHorario: AlvoDeHorario?

    private enum AlvoDeHorario: Hashable, Identifiable {
        case inicio
        case fim
        var id: Self { self }
    }

    public init(viewModel: RepublicarVagaViewModel, aoFechar: (@Sendable () -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.aoFechar = aoFechar
    }

    private func fechar() {
        aoFechar?()
        dismiss()
    }

    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                cabecalho
                cartaoDadosCopiados
                secaoPeriodo
                if let recusa = viewModel.recusaDaFila {
                    VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                        AvisoFrila(verbatim: TextosDaFila.texto(recusa.tipo), tom: .informativo)
                            .accessibilityIdentifier("aviso-republicacao-recusada")
                        BotaoSecundario("Fechar") { Task { await viewModel.fecharAvisoDaFila() } }
                            .accessibilityIdentifier("fechar-aviso-republicacao-recusada")
                    }
                }
                if viewModel.republicacaoPendente != nil {
                    AvisoFrila(verbatim: TextosRepublicarVaga.tentativaContinua, tom: .informativo)
                        .accessibilityIdentifier("aviso-republicacao-continua")
                }
                if !viewModel.tentativaRestaurada, !viewModel.restaurandoTentativa, viewModel.mensagemErro != nil {
                    BotaoSecundario(verbatim: TextosRepublicarVaga.tentarNovamente) {
                        Task { await viewModel.restaurarTentativaPendente() }
                    }
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.vertical, FrilaEspaco.bloco)
            .containerRelativeFrame(.horizontal)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        // O identificador da tela fica na rolagem: no fim da cadeia ele passava por cima do botão do rodapé.
        .accessibilityIdentifier("tela-republicar-vaga")
        .rodapeAncorado { rodape }
        .navigationTitle(TextosRepublicarVaga.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Folha que só age no botão: "Cancelar" ou "Fechar" fica à esquerda, em tinta.
            ToolbarItem(placement: .cancellationAction) {
                Button(viewModel.textoAoFechar) { fechar() }
                    .tint(FrilaCor.texto)
                    .disabled(viewModel.enviando || viewModel.restaurandoTentativa)
                    .accessibilityIdentifier("botao-cancelar-republicacao")
            }
        }
        .sheet(item: $editandoHorario) { alvo in
            folhaDeHorario(alvo)
        }
        .onChange(of: viewModel.resultado) { _, novo in
            if novo != nil {
                fechar()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await viewModel.carregarRecusaDaFila() }
        }
        .task {
            await viewModel.restaurarTentativaPendente()
        }
        .interactiveDismissDisabled(viewModel.enviando || viewModel.restaurandoTentativa)
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosRepublicarVaga.titulo)
                .font(FrilaTipo.tituloDaTela)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: TextosRepublicarVaga.subtitulo)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cartaoDadosCopiados: some View {
        let original = viewModel.vagaOriginal
        return VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            if original.modo == .selecao {
                SeloDeStatus(verbatim: TextosRepublicarVaga.modoSelecao, estilo: .contorno)
            } else {
                SeloDeStatus(verbatim: TextosRepublicarVaga.modoUrgencia, estilo: .urgencia, icone: "bolt.fill")
            }
            Text(verbatim: original.vaga.funcao)
                .font(FrilaTipo.nome)
                .fixedSize(horizontal: false, vertical: true)
            FrilaLinhaDeDado(icone: "banknote") {
                Text(verbatim: formatador.dinheiro(original.vaga.valor))
                    .font(FrilaTipo.rotuloSecundario)
                    .accessibilityLabel(Text(verbatim: formatador.dinheiroFalado(original.vaga.valor)))
            }
            FrilaLinhaDeDado(icone: "mappin.and.ellipse") {
                Text(verbatim: original.vaga.regiaoAdministrativa.isEmpty
                     ? original.vaga.local
                     : "\(original.vaga.local), \(original.vaga.regiaoAdministrativa)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cartao-dados-copiados-republicacao")
    }

    private var secaoPeriodo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosRepublicarVaga.novoPeriodo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                    seletorPeriodo(
                        titulo: TextosRepublicarVaga.dataInicio,
                        data: $viewModel.inicio,
                        campoID: Self.idDoInicio
                    )
                    .disabled(viewModel.camposBloqueados || !viewModel.podeConfirmar)

                    if let erroInicio = viewModel.erros[.inicio] {
                        Text(verbatim: erroInicio)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("erro-inicio-republicacao")
                    }
                }

                VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                    seletorPeriodo(
                        titulo: TextosRepublicarVaga.dataFim,
                        data: $viewModel.fim,
                        campoID: Self.idDoFim
                    )
                    .disabled(viewModel.camposBloqueados || !viewModel.podeConfirmar)

                    if let erroFim = viewModel.erros[.fim] {
                        Text(verbatim: erroFim)
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("erro-fim-republicacao")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartaoFrila()
        }
    }

    @ViewBuilder
    private func seletorPeriodo(titulo: String, data: Binding<Date>, campoID: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: titulo)
                    .font(FrilaTipo.rotuloDeGrupo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                linhaDeHorario(
                    valor: formatador.dataEHora(data.wrappedValue),
                    id: campoID,
                    titulo: titulo,
                    alvo: campoID == Self.idDoInicio ? .inicio : .fim
                )
            }
        } else {
            DatePicker(
                titulo,
                selection: data,
                displayedComponents: [.date, .hourAndMinute]
            )
            .tint(FrilaCor.texto)
            .accessibilityIdentifier(campoID)
        }
    }

    /// Linha de AX que mostra o valor e abre a folha com as rodas.
    private func linhaDeHorario(valor: String, id: String, titulo: String, alvo: AlvoDeHorario) -> some View {
        Button { editandoHorario = alvo } label: {
            HStack(spacing: FrilaEspaco.item) {
                Text(verbatim: valor)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FrilaEspaco.item)
                Image(systemName: "chevron.forward")
                    .font(FrilaTipo.apoio.weight(.semibold))
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityHidden(true)
            }
            .caixaDoCampoFrila()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: titulo))
        .accessibilityValue(Text(verbatim: valor))
        .accessibilityIdentifier(id)
    }

    /// As rodas ficam numa folha, fora da rolagem: dentro dela, rolar a tela pelo meio giraria a roda e mudaria o horário.
    private func folhaDeHorario(_ alvo: AlvoDeHorario) -> some View {
        let titulo = alvo == .inicio ? TextosRepublicarVaga.dataInicio : TextosRepublicarVaga.dataFim
        let data = alvo == .inicio ? $viewModel.inicio : $viewModel.fim
        return NavigationStack {
            VStack(spacing: FrilaEspaco.bloco) {
                // Dia e hora em duas rodas: a roda com os dois não cabe na largura da tela em AX5.
                DatePicker(titulo, selection: data, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .environment(\.timeZone, FormatadorFrila.fuso)
                    .accessibilityIdentifier("republicar-seletor-data")
                DatePicker(titulo, selection: data, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .environment(\.timeZone, FormatadorFrila.fuso)
                    .accessibilityIdentifier("republicar-seletor-hora")
                Spacer(minLength: 0)
            }
            .padding(FrilaEspaco.bloco)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FrilaCor.fundo.ignoresSafeArea())
            .navigationTitle(Text(verbatim: titulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(TextosRepublicarVaga.fechar) { editandoHorario = nil }
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        .accessibilityIdentifier("republicar-fechar-horario")
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .accessibilityIdentifier("republicar-folha-de-horario")
    }

    /// O erro da ação fica logo acima do botão que o provocou; o botão laranja é o único da folha.
    private var rodape: some View {
        VStack(spacing: FrilaEspaco.item) {
            if let erro = viewModel.mensagemErro {
                MensagemJuntoAoBotao(verbatim: erro)
                    .accessibilityIdentifier("aviso-erro-republicacao")
            }
            if viewModel.camposBloqueados {
                BotaoPrimario(verbatim: TextosRepublicarVaga.tentarNovamente, carregando: viewModel.enviando) {
                    Task { await viewModel.republicar() }
                }
                .disabled(!viewModel.podeConfirmar)
                .accessibilityIdentifier("botao-tentar-novamente-republicacao")
            } else {
                BotaoPrimario(verbatim: TextosRepublicarVaga.confirmar, carregando: viewModel.enviando) {
                    Task { await viewModel.republicar() }
                }
                .disabled(!viewModel.podeConfirmar)
                .accessibilityIdentifier("botao-confirmar-republicacao")
            }
        }
    }
}

extension VagaNoPainel: @retroactive Identifiable {
    public var id: UUID { vaga.id }
}
