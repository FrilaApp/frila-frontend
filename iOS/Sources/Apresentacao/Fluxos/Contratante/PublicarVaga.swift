import FrilaDominio
import MapKit
import Observation
import SwiftUI

private final class MarcadorPublicarVaga: NSObject {}
private let bundlePublicarVaga = Bundle(for: MarcadorPublicarVaga.self)

private enum TextosPublicarVaga {
    static let titulo = String(localized: "Publicar vaga", bundle: bundlePublicarVaga)
    static let funcao = String(localized: "Função", bundle: bundlePublicarVaga)
    static let selecioneFuncao = String(localized: "Selecione uma função", bundle: bundlePublicarVaga)
    static let dataInicio = String(localized: "Início", bundle: bundlePublicarVaga)
    static let dataFim = String(localized: "Fim", bundle: bundlePublicarVaga)
    static let endereco = String(localized: "Endereço do turno", bundle: bundlePublicarVaga)
    static let enderecoAjuda = String(localized: "Vem do cadastro do estabelecimento; você pode ajustar o texto.", bundle: bundlePublicarVaga)
    static let valor = String(localized: "Valor por posição", bundle: bundlePublicarVaga)
    static let valorExemplo = String(localized: "R$ 0,00", bundle: bundlePublicarVaga)
    static let formatoValor = String(localized: "R$ %d,%02d", bundle: bundlePublicarVaga)
    static let valorAjuda = String(localized: "O profissional recebe o valor integral", bundle: bundlePublicarVaga)
    static let posicoes = String(localized: "Vagas", bundle: bundlePublicarVaga)
    static let posicoesExemplo = String(localized: "1", bundle: bundlePublicarVaga)
    static let inclusos = String(localized: "O que está incluso", bundle: bundlePublicarVaga)
    static let refeicao = String(localized: "Refeição", bundle: bundlePublicarVaga)
    static let transporte = String(localized: "Transporte", bundle: bundlePublicarVaga)
    static let material = String(localized: "Material próprio", bundle: bundlePublicarVaga)
    static let sim = String(localized: "Sim", bundle: bundlePublicarVaga)
    static let nao = String(localized: "Não", bundle: bundlePublicarVaga)
    static let responsavel = String(localized: "Quem recebe no local", bundle: bundlePublicarVaga)
    static let alerta = String(localized: "Avisar se a vaga seguir vazia", bundle: bundlePublicarVaga)
    static let alertaTresHoras = String(localized: "3 horas antes", bundle: bundlePublicarVaga)
    static let alertaDuasHoras = String(localized: "2 horas antes", bundle: bundlePublicarVaga)
    static let alertaSeisHoras = String(localized: "6 horas antes", bundle: bundlePublicarVaga)
    static let maisOpcoes = String(localized: "Mais opções: traje, rateio e observações", bundle: bundlePublicarVaga)
    static let traje = String(localized: "Traje", bundle: bundlePublicarVaga)
    static let rateio = String(localized: "Participa do rateio dos 10%", bundle: bundlePublicarVaga)
    static let observacoes = String(localized: "Observações", bundle: bundlePublicarVaga)
    static let publicar = String(localized: "Publicar vaga", bundle: bundlePublicarVaga)
    static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundlePublicarVaga)
    static let avisoRN10 = String(localized: "Após a confirmação, o telefone do responsável será mostrado ao profissional para combinar o turno.", bundle: bundlePublicarVaga)
    static let campoObrigatorio = String(localized: "Preencha este campo.", bundle: bundlePublicarVaga)
    static let campoInvalido = String(localized: "Confira o valor informado.", bundle: bundlePublicarVaga)
    static let erroPublicar = String(localized: "Não foi possível publicar a vaga. Tente novamente.", bundle: bundlePublicarVaga)
    static let semFuncoes = String(localized: "Não foi possível carregar as funções.", bundle: bundlePublicarVaga)
    static let funcaoCampo = String(localized: "Escolha uma função.", bundle: bundlePublicarVaga)
    static let localCampo = String(localized: "Informe o endereço.", bundle: bundlePublicarVaga)
    static let valorCampo = String(localized: "Informe um valor maior que zero.", bundle: bundlePublicarVaga)
    static let posicoesCampo = String(localized: "Informe de 1 a 200 vagas.", bundle: bundlePublicarVaga)
    static let horarioCampo = String(localized: "O fim precisa ser depois do início, e o início deve estar no futuro.", bundle: bundlePublicarVaga)
    static let estabelecimentoCampo = String(localized: "Não encontramos o estabelecimento cadastrado.", bundle: bundlePublicarVaga)
    static let responsavelCampo = String(localized: "Informe quem recebe o profissional no local.", bundle: bundlePublicarVaga)
    static let falhaFila = String(localized: "Não foi possível guardar a publicação neste aparelho.", bundle: bundlePublicarVaga)
    static let verificandoPendente = String(localized: "Verificando publicação pendente…", bundle: bundlePublicarVaga)
    static let pendenteDescricao = String(localized: "Há uma publicação pendente. Tente novamente para concluir sem criar outra vaga.", bundle: bundlePublicarVaga)
    static let modo = String(localized: "Como preencher a vaga", bundle: bundlePublicarVaga)
    static let modoUrgencia = String(localized: "Urgência", bundle: bundlePublicarVaga)
    static let modoSelecao = String(localized: "Seleção", bundle: bundlePublicarVaga)
    static let modoUrgenciaExplicacao = String(localized: "O primeiro profissional que aceitar é confirmado na hora.", bundle: bundlePublicarVaga)
    static let modoSelecaoExplicacao = String(localized: "Você escolhe entre os candidatos. O início precisa estar a mais de 24 horas, e a vaga fecha sozinha 24 horas antes se ninguém for escolhido.", bundle: bundlePublicarVaga)
    static let modoIndisponivel = String(localized: "O modo seleção ainda não está disponível. Publique no modo urgência.", bundle: bundlePublicarVaga)
}

public enum CampoPublicacaoVaga: String, CaseIterable, Sendable {
    case estabelecimento
    case funcao
    case inicio
    case fim
    case local
    case ponto
    case valor
    case posicoes
    case responsavel
    case inclusos
    case traje
    case rateio
    case observacoes
    case modo
}

@MainActor @Observable
public final class PublicarVagaViewModel {
    public var estabelecimento: Estabelecimento?
    public var funcoes: [Funcao]
    public var funcaoID: UUID?
    public var inicio: Date
    public var fim: Date
    public var local: String
    public var valorTexto = ""
    public var posicoesTexto = "1"
    public var refeicao = false
    public var transporte = false
    public var materialProprio = false
    public var responsavelLocal = ""
    public var alertaAntecedenciaMinutos = 180
    /// Urgência confirma o primeiro que aceitar; seleção deixa a casa escolher entre os candidatos (RN24).
    public var modo = ModoPreenchimento.urgencia
    public var traje = ""
    public var participaRateio: Bool? = false
    public var observacoes = ""
    public var mostrandoMaisOpcoes = false
    public private(set) var carregandoFuncoes = false
    public private(set) var enviando = false
    public private(set) var erros: [CampoPublicacaoVaga: String] = [:]
    public private(set) var mensagemErro: String?
    public private(set) var recusaDaFila: AcaoRecusada?
    public private(set) var resultado: VagaPublicada?
    public private(set) var publicacaoPendente: PublicacaoVaga?
    public private(set) var restaurandoPublicacao: Bool

    private let carregar: @Sendable () async throws -> [Funcao]
    private let publicarAPI: @Sendable (PublicacaoVaga) async throws -> VagaPublicada
    private let fila: any FilaDeAcoes
    private var acaoPendente: AcaoPendente?
    private let agora: @Sendable () -> Date

    public init(api: any ApiCliente, fila: any FilaDeAcoes, estabelecimento: Estabelecimento, agora: @escaping @Sendable () -> Date = Date.init) {
        self.estabelecimento = estabelecimento
        funcoes = []
        funcaoID = nil
        let inicioPadrao = agora().addingTimeInterval(3 * 60 * 60)
        inicio = inicioPadrao
        fim = inicioPadrao.addingTimeInterval(3 * 60 * 60)
        local = estabelecimento.endereco
        self.fila = fila
        self.agora = agora
        restaurandoPublicacao = true
        carregar = { try await api.funcoes() }
        publicarAPI = { try await api.publicarVaga($0) }
    }

    public init(
        estabelecimento: Estabelecimento?,
        funcoes: [Funcao] = [],
        fila: any FilaDeAcoes,
        agora: @escaping @Sendable () -> Date = Date.init,
        publicar: @escaping @Sendable (PublicacaoVaga) async throws -> VagaPublicada
    ) {
        self.estabelecimento = estabelecimento
        self.funcoes = funcoes
        funcaoID = nil
        let inicioPadrao = agora().addingTimeInterval(3 * 60 * 60)
        inicio = inicioPadrao
        fim = inicioPadrao.addingTimeInterval(3 * 60 * 60)
        local = estabelecimento?.endereco ?? ""
        self.fila = fila
        self.agora = agora
        restaurandoPublicacao = false
        carregar = { funcoes }
        publicarAPI = publicar
    }

    public var camposBloqueados: Bool { publicacaoPendente != nil }
    public var valorCentavos: Int { Int(valorTexto.filter(\.isNumber)) ?? 0 }

    public func carregarRecusaDaFila() async {
        recusaDaFila = (try? await fila.recusadas().first { $0.tipo == .publicacaoVaga && $0.estabelecimentoID == estabelecimento?.id }) ?? nil
        if let recusaDaFila, acaoPendente?.id == recusaDaFila.id {
            acaoPendente = nil
            publicacaoPendente = nil
        }
    }

    public func restaurarPublicacaoPendente() async {
        await carregarRecusaDaFila()
        restaurandoPublicacao = true
        defer { restaurandoPublicacao = false }
        do {
            let pendentes = try await fila.pendentes()
            if let estabelecimentoID = estabelecimento?.id,
               let acao = pendentes.first(where: {
                   $0.tipo == .publicacaoVaga && $0.publicacao?.estabelecimentoID == estabelecimentoID
               }), let publicacao = acao.publicacao {
                acaoPendente = acao
                publicacaoPendente = publicacao
            }
        } catch {
            mensagemErro = TextosPublicarVaga.falhaFila
        }
    }

    public func carregarFuncoes() async {
        guard funcoes.isEmpty, !carregandoFuncoes else { return }
        carregandoFuncoes = true
        defer { carregandoFuncoes = false }
        do {
            funcoes = try await carregar()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-FRILA_CADASTRO_UI_TEST") {
                if funcaoID == nil, let primeira = funcoes.first {
                    funcaoID = primeira.id
                }
                if valorTexto.isEmpty { valorTexto = "14000" }
                if responsavelLocal.isEmpty { responsavelLocal = "Gerente de Teste" }
            }
            #endif
        }
        catch { mensagemErro = TextosPublicarVaga.semFuncoes }
    }

    public func validar() -> Bool {
        erros = [:]
        if estabelecimento == nil { erros[.estabelecimento] = TextosPublicarVaga.estabelecimentoCampo }
        if !funcoes.contains(where: { $0.id == funcaoID }) { erros[.funcao] = TextosPublicarVaga.funcaoCampo }
        if inicio <= agora() { erros[.inicio] = TextosPublicarVaga.horarioCampo }
        // RN24: a vaga de seleção fecha 24 h antes do início; com 24 h ou menos ela nasceria fechada,
        // e o servidor a recusa. O relógio que vale é o dele: esta conferência só poupa a viagem.
        else if modo == .selecao, inicio <= agora().addingTimeInterval(Self.antecedenciaDaSelecao) {
            erros[.inicio] = TextosRepublicarVaga.selecaoSemAntecedencia
        }
        if fim <= inicio { erros[.fim] = TextosPublicarVaga.horarioCampo }
        if local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { erros[.local] = TextosPublicarVaga.localCampo }
        if estabelecimento?.ponto.latitude.isFinite != true || estabelecimento?.ponto.longitude.isFinite != true {
            erros[.ponto] = TextosPublicarVaga.estabelecimentoCampo
        }
        if valorCentavos < 1 { erros[.valor] = TextosPublicarVaga.valorCampo }
        if let posicoes = Int(posicoesTexto), (1...200).contains(posicoes) == false { erros[.posicoes] = TextosPublicarVaga.posicoesCampo }
        else if Int(posicoesTexto) == nil { erros[.posicoes] = TextosPublicarVaga.posicoesCampo }
        if responsavelLocal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { erros[.responsavel] = TextosPublicarVaga.responsavelCampo }
        return erros.isEmpty
    }

    public func publicar() async {
        guard !enviando, !restaurandoPublicacao else { return }
        if publicacaoPendente == nil {
            guard validar(), let estabelecimento, let funcao = funcoes.first(where: { $0.id == funcaoID }),
                  let periodo = try? Periodo(inicio: inicio, fim: fim),
                  let ponto = try? Coordenada(latitude: estabelecimento.ponto.latitude, longitude: estabelecimento.ponto.longitude)
            else { return }
            let nova = PublicacaoVaga(
                estabelecimentoID: estabelecimento.id,
                funcaoID: funcao.id,
                periodo: periodo,
                local: local.trimmingCharacters(in: .whitespacesAndNewlines),
                // Contrato 0.2.20: a região do turno vem preenchida com a do estabelecimento.
                regiaoAdministrativa: estabelecimento.regiaoAdministrativa,
                ponto: ponto,
                valor: Dinheiro(centavos: valorCentavos),
                posicoes: Int(posicoesTexto) ?? 1,
                inclusos: Inclusos(refeicao: refeicao, transporte: transporte, exigeMaterialProprio: materialProprio),
                responsavelLocal: responsavelLocal.trimmingCharacters(in: .whitespacesAndNewlines),
                traje: traje.trimmingCharacters(in: .whitespacesAndNewlines).nilSeVazio,
                participaRateio: participaRateio,
                observacoes: observacoes.trimmingCharacters(in: .whitespacesAndNewlines).nilSeVazio,
                modo: modo,
                alertaAntecedenciaMinutos: alertaAntecedenciaMinutos,
                chave: UUID()
            )
            publicacaoPendente = nova
            acaoPendente = AcaoPendente(tipo: .publicacaoVaga, instanteDoToque: agora(), chave: nova.chave, publicacao: nova)
        }
        guard let acaoPendente, let publicacao = publicacaoPendente else { return }
        enviando = true
        mensagemErro = nil
        defer { enviando = false }
        do {
            try await fila.enfileirar(acaoPendente)
        } catch {
            mensagemErro = TextosPublicarVaga.falhaFila
            return
        }
        do {
            resultado = try await publicarAPI(publicacao)
            try? await fila.remover(id: acaoPendente.id)
            publicacaoPendente = nil
            self.acaoPendente = nil
        } catch let erro as ErroDaApi {
            tratar(erro)
            if erro.codigo.recusaDefinitivaDePublicacao {
                try? await fila.remover(id: acaoPendente.id)
                publicacaoPendente = nil
                self.acaoPendente = nil
            }
        } catch {
            mensagemErro = TextosPublicarVaga.erroPublicar
        }
    }

    private static let antecedenciaDaSelecao: TimeInterval = 24 * 60 * 60

    private func tratar(_ erro: ErroDaApi) {
        if erro.codigo == .selecaoSemAntecedencia {
            // O servidor conta as 24 horas pelo relógio dele, que pode não ser o do aparelho.
            erros[.inicio] = TextosRepublicarVaga.selecaoSemAntecedencia
            mensagemErro = TextosRepublicarVaga.selecaoSemAntecedencia
        } else if erro.codigo == .campoInvalido, erro.detalhes == "modo" {
            // Até o contrato 0.2.23 o servidor recusava o modo seleção assim.
            erros[.modo] = TextosPublicarVaga.modoIndisponivel
            mensagemErro = TextosPublicarVaga.modoIndisponivel
        } else if erro.codigo == .campoObrigatorio || erro.codigo == .campoInvalido {
            if let campo = Self.campo(erro.detalhes) {
                erros[campo] = erro.codigo == .campoObrigatorio ? TextosPublicarVaga.campoObrigatorio : TextosPublicarVaga.campoInvalido
            } else {
                mensagemErro = TextosPublicarVaga.erroPublicar
            }
        } else if erro.codigo == .horarioInvalido {
            erros[.inicio] = TextosPublicarVaga.horarioCampo
            erros[.fim] = TextosPublicarVaga.horarioCampo
        } else {
            mensagemErro = TextosPublicarVaga.erroPublicar
        }
    }

    private static func campo(_ nome: String?) -> CampoPublicacaoVaga? {
        switch nome {
        case "estabelecimento_id": .estabelecimento
        case "funcao_id": .funcao
        case "inicio_em": .inicio
        case "fim_em": .fim
        case "local": .local
        case "ponto", "latitude", "longitude": .ponto
        case "valor_centavos": .valor
        case "posicoes": .posicoes
        case "responsavel_local": .responsavel
        case "inclui_refeicao", "inclui_transporte", "exige_material_proprio": .inclusos
        case "traje": .traje
        case "participa_rateio": .rateio
        case "observacoes": .observacoes
        case "modo": .modo
        default: nil
        }
    }
}

private extension String {
    var nilSeVazio: String? { isEmpty ? nil : self }
}

public struct TelaPublicarVaga: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: PublicarVagaViewModel
    @State private var regiaoMapa: MKCoordinateRegion
    private let telefoneResponsavel: String
    private let api: any ApiCliente
    private let sair: () -> Void
    private let aoPublicar: () -> Void
    @State private var mostrandoPerfilEstabelecimento = false
    @Environment(PermissaoDePushModelo.self) private var permissaoDePush: PermissaoDePushModelo?

    public init(api: any ApiCliente, fila: any FilaDeAcoes, estabelecimento: Estabelecimento, telefoneResponsavel: String, sair: @escaping () -> Void = {}, aoPublicar: @escaping () -> Void = {}) {
        self.api = api
        self.sair = sair
        self.aoPublicar = aoPublicar
        _model = State(initialValue: PublicarVagaViewModel(api: api, fila: fila, estabelecimento: estabelecimento))
        _regiaoMapa = State(initialValue: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: estabelecimento.ponto.latitude, longitude: estabelecimento.ponto.longitude), span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)))
        self.telefoneResponsavel = telefoneResponsavel
    }

    public var body: some View {
        NavigationStack {
            formulario
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { mostrandoPerfilEstabelecimento = true } label: {
                            Image(systemName: "building.2.crop.circle")
                                .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        }
                        .accessibilityLabel(String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao))
                    }
                }
        }
        .sheet(isPresented: $mostrandoPerfilEstabelecimento) {
            NavigationStack {
                TelaPerfilEstabelecimento(api: api, sair: sair)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                mostrandoPerfilEstabelecimento = false
                            } label: {
                                Text("Fechar", bundle: bundleApresentacao)
                                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                            }
                        }
                    }
            }
        }
        // A vaga publicada é o momento de explicar a notificação a quem contrata (#8): é por ela
        // que chega o aviso de quem aceitou.
        .onChange(of: model.resultado != nil) { _, publicou in
            if publicou { Task { await permissaoDePush?.oferecer() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await model.carregarRecusaDaFila() }
        }
        .task {
            await model.restaurarPublicacaoPendente()
            await model.carregarFuncoes()
        }
        .onChange(of: model.resultado != nil) { _, publicado in
            if publicado {
                aoPublicar()
            }
        }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                Text(verbatim: TextosPublicarVaga.titulo).font(.largeTitle.bold())
                if model.restaurandoPublicacao {
                    AvisoFrila(verbatim: TextosPublicarVaga.verificandoPendente, tom: .informativo)
                } else if model.camposBloqueados {
                    AvisoFrila(verbatim: TextosPublicarVaga.pendenteDescricao, tom: .informativo)
                }
                if let erro = model.erros[.estabelecimento] { AvisoFrila(verbatim: erro, tom: .erro) }
                campo(.funcao, titulo: TextosPublicarVaga.funcao) {
                    Picker(TextosPublicarVaga.funcao, selection: $model.funcaoID) {
                        Text(verbatim: TextosPublicarVaga.selecioneFuncao).tag(UUID?.none)
                        ForEach(model.funcoes) { funcao in Text(verbatim: funcao.nome).tag(Optional(funcao.id)) }
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading).padding().background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    datePicker(TextosPublicarVaga.dataInicio, date: $model.inicio, field: .inicio)
                    datePicker(TextosPublicarVaga.dataFim, date: $model.fim, field: .fim)
                }
                campo(.local, titulo: TextosPublicarVaga.endereco) {
                    CampoFrila(verbatim: TextosPublicarVaga.endereco, texto: $model.local)
                    Text(verbatim: TextosPublicarVaga.enderecoAjuda).font(.caption).foregroundStyle(FrilaCor.textoSecundario)
                    Map(initialPosition: .region(regiaoMapa)) {
                        Marker(model.estabelecimento?.nome ?? "", coordinate: CLLocationCoordinate2D(latitude: regiaoMapa.center.latitude, longitude: regiaoMapa.center.longitude))
                    }.frame(height: 150).clipShape(RoundedRectangle(cornerRadius: FrilaRaio.medio)).allowsHitTesting(false)
                    if let erro = model.erros[.ponto] { Text(verbatim: erro).font(.caption).foregroundStyle(FrilaCor.perigo) }
                }
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                        campoValor
                        campoPosicoes
                    }
                } else {
                    HStack(alignment: .top, spacing: FrilaEspaco.pequeno) {
                        campoValor
                        campoPosicoes
                    }
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: TextosPublicarVaga.inclusos).font(.headline)
                    seletorSimNao(TextosPublicarVaga.refeicao, valor: $model.refeicao)
                    seletorSimNao(TextosPublicarVaga.transporte, valor: $model.transporte)
                    seletorSimNao(TextosPublicarVaga.material, valor: $model.materialProprio)
                    if let erro = model.erros[.inclusos] { Text(verbatim: erro).font(.caption).foregroundStyle(FrilaCor.perigo) }
                }.padding(FrilaEspaco.medio).background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                    .disabled(model.camposBloqueados)
                campo(.responsavel, titulo: TextosPublicarVaga.responsavel) {
                    CampoFrila(verbatim: TextosPublicarVaga.responsavel, texto: $model.responsavelLocal)
                }
                campo(.modo, titulo: TextosPublicarVaga.modo) {
                    Picker(TextosPublicarVaga.modo, selection: $model.modo) {
                        Text(verbatim: TextosPublicarVaga.modoUrgencia).tag(ModoPreenchimento.urgencia)
                        Text(verbatim: TextosPublicarVaga.modoSelecao).tag(ModoPreenchimento.selecao)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text(verbatim: TextosPublicarVaga.modo))
                    .accessibilityIdentifier("modo-vaga-picker")
                    Text(verbatim: model.modo == .selecao ? TextosPublicarVaga.modoSelecaoExplicacao : TextosPublicarVaga.modoUrgenciaExplicacao)
                        .font(.caption)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("modo-vaga-explicacao")
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: TextosPublicarVaga.alerta).font(.headline)
                    if dynamicTypeSize.isAccessibilitySize {
                        Picker(TextosPublicarVaga.alerta, selection: $model.alertaAntecedenciaMinutos) {
                            Text(verbatim: TextosPublicarVaga.alertaTresHoras).tag(180)
                            Text(verbatim: TextosPublicarVaga.alertaDuasHoras).tag(120)
                            Text(verbatim: TextosPublicarVaga.alertaSeisHoras).tag(360)
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel(Text(verbatim: TextosPublicarVaga.alerta))
                        .accessibilityIdentifier("alerta-vaga-picker")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                    } else {
                        Picker(TextosPublicarVaga.alerta, selection: $model.alertaAntecedenciaMinutos) {
                            Text(verbatim: TextosPublicarVaga.alertaTresHoras).tag(180)
                            Text(verbatim: TextosPublicarVaga.alertaDuasHoras).tag(120)
                            Text(verbatim: TextosPublicarVaga.alertaSeisHoras).tag(360)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel(Text(verbatim: TextosPublicarVaga.alerta))
                        .accessibilityIdentifier("alerta-vaga-picker")
                    }
                }.disabled(model.camposBloqueados)
                Button { model.mostrandoMaisOpcoes.toggle() } label: {
                    Text(verbatim: TextosPublicarVaga.maisOpcoes)
                        .underline()
                        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.camposBloqueados)
                .accessibilityIdentifier("mais-opcoes-botao")
                if model.mostrandoMaisOpcoes {
                    campoOpcional(.traje, titulo: TextosPublicarVaga.traje) { CampoFrila(verbatim: TextosPublicarVaga.traje, texto: $model.traje) }
                    VStack(alignment: .leading, spacing: 4) {
                        seletorSimNao(TextosPublicarVaga.rateio, valor: Binding(get: { model.participaRateio ?? false }, set: { model.participaRateio = $0 }))
                        if let erro = model.erros[.rateio] { Text(verbatim: erro).font(.caption).foregroundStyle(FrilaCor.perigo) }
                    }.disabled(model.camposBloqueados)
                    campoOpcional(.observacoes, titulo: TextosPublicarVaga.observacoes) {
                        TextField(TextosPublicarVaga.observacoes, text: $model.observacoes, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.plain)
                            .padding(FrilaEspaco.medio)
                            .frame(minHeight: FrilaMetrica.alvoMinimo)
                            .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                            .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.textoSecundario.opacity(0.35)))
                            .accessibilityIdentifier("observacoes-vaga-campo")
                    }
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    AvisoFrila(verbatim: TextosPublicarVaga.avisoRN10, tom: .informativo)
                    Text(verbatim: telefoneResponsavel).font(.subheadline).foregroundStyle(FrilaCor.textoSecundario)
                }
                if let recusa = model.recusaDaFila {
                    AvisoFrila(verbatim: TextosDaFila.texto(recusa.tipo), tom: .informativo)
                        .accessibilityIdentifier("aviso-publicacao-recusada")
                }
                if let erro = model.mensagemErro { AvisoFrila(verbatim: erro, tom: .erro) }
                BotaoPrimario(verbatim: model.camposBloqueados ? TextosPublicarVaga.tentarNovamente : TextosPublicarVaga.publicar, carregando: model.enviando) {
                    Task {
                        await model.publicar()
                        if model.resultado != nil {
                            aoPublicar()
                        }
                    }
                }
                .disabled(model.enviando || model.restaurandoPublicacao)
                .accessibilityIdentifier("publicar-vaga-botao")
            }
            .padding(FrilaEspaco.medio)
            .containerRelativeFrame(.horizontal)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(Text(verbatim: TextosPublicarVaga.titulo))
        .accessibilityIdentifier("publicar-vaga-formulario")
    }

    private var campoValor: some View {
        campo(.valor, titulo: TextosPublicarVaga.valor) {
            TextField(TextosPublicarVaga.valorExemplo, text: Binding(get: { Self.formatarCentavos(model.valorCentavos) }, set: { model.valorTexto = String($0.filter(\.isNumber)) }))
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.textoSecundario.opacity(0.35)))
                .accessibilityLabel(Text(verbatim: TextosPublicarVaga.valor))
                .accessibilityIdentifier("valor-vaga-campo")
            Text(verbatim: TextosPublicarVaga.valorAjuda).font(.caption).foregroundStyle(FrilaCor.sucesso)
        }
    }

    private var campoPosicoes: some View {
        campo(.posicoes, titulo: TextosPublicarVaga.posicoes) {
            TextField(TextosPublicarVaga.posicoesExemplo, text: $model.posicoesTexto)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .padding(.horizontal, FrilaEspaco.medio)
                .frame(minHeight: FrilaMetrica.alvoMinimo)
                .background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                .overlay(RoundedRectangle(cornerRadius: FrilaRaio.medio).stroke(FrilaCor.textoSecundario.opacity(0.35)))
                .accessibilityLabel(Text(verbatim: TextosPublicarVaga.posicoes))
                .accessibilityIdentifier("posicoes-vaga-campo")
        }
    }

    @ViewBuilder private func campo<Conteudo: View>(_ campo: CampoPublicacaoVaga, titulo: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: titulo).font(.headline)
            conteudo()
            if let erro = model.erros[campo] { Text(verbatim: erro).font(.caption).foregroundStyle(FrilaCor.perigo).accessibilityIdentifier("erro-publicacao-\(campo.rawValue)") }
        }
        .disabled(model.camposBloqueados)
    }

    private func campoOpcional<Conteudo: View>(_ campo: CampoPublicacaoVaga, titulo: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: titulo).font(.headline)
            conteudo()
            if let erro = model.erros[campo] { Text(verbatim: erro).font(.caption).foregroundStyle(FrilaCor.perigo) }
        }
            .disabled(model.camposBloqueados)
    }

    private func datePicker(_ titulo: String, date: Binding<Date>, field: CampoPublicacaoVaga) -> some View {
        campo(field, titulo: titulo) {
            DatePicker(titulo, selection: date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .minimumScaleFactor(0.7)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .accessibilityIdentifier("datepicker-\(field.rawValue)")
        }
    }

    @ViewBuilder
    private func seletorSimNao(_ titulo: String, valor: Binding<Bool>) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                    Text(verbatim: titulo).font(.subheadline)
                    HStack(spacing: FrilaEspaco.pequeno) {
                        botoesSimNao(valor: valor)
                    }
                }
            } else {
                HStack {
                    Text(verbatim: titulo).font(.subheadline)
                    Spacer()
                    botoesSimNao(valor: valor)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func botoesSimNao(valor: Binding<Bool>) -> some View {
        ForEach([(true, TextosPublicarVaga.sim), (false, TextosPublicarVaga.nao)], id: \.0) { escolha, rotulo in
            Button { valor.wrappedValue = escolha } label: {
                Text(verbatim: rotulo).font(.subheadline.weight(.semibold)).frame(minWidth: 48, minHeight: FrilaMetrica.alvoMinimo)
                    .background(valor.wrappedValue == escolha ? FrilaCor.texto : FrilaCor.superficie, in: Capsule())
                    .foregroundStyle(valor.wrappedValue == escolha ? FrilaCor.fundo : FrilaCor.texto)
                    .overlay(Capsule().stroke(FrilaCor.textoSecundario.opacity(0.4)))
            }.buttonStyle(.plain).accessibilityAddTraits(valor.wrappedValue == escolha ? .isSelected : [])
        }
    }

    private static func formatarCentavos(_ centavos: Int) -> String {
        let reais = centavos / 100
        let resto = centavos % 100
        return String(format: TextosPublicarVaga.formatoValor, reais, resto)
    }
}
