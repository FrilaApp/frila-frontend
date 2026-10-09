import FrilaDominio
import MapKit
import Observation
import SwiftUI
import UIKit

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
    /// MS-RF01: a opção Seleção só aparece com o início a mais de 24 horas (RN24).
    static let modoSelecaoSoComAntecedencia = String(localized: "A seleção fica disponível para vagas que começam em mais de 24 horas.", bundle: bundlePublicarVaga)
    /// D2 (0.2.38): o prazo exato de escolha, mostrado na publicação.
    static let modoSelecaoPrazo = String(localized: "Você terá até %@ para escolher. Depois disso a vaga fecha sozinha.", bundle: bundlePublicarVaga)
    static let modoSelecaoPrazoCurto = String(localized: "Prazo curto: você terá menos de 12 horas para escolher antes de a vaga fechar.", bundle: bundlePublicarVaga)
    static let voltar = String(localized: "Voltar", bundle: bundleApresentacao)
    static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    static let publicacaoContinua = String(localized: "A publicação continua e será concluída quando a conexão voltar.", bundle: bundleApresentacao)
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
    public var textoAoFechar: String {
        (publicacaoPendente != nil || resultado != nil) ? TextosPublicarVaga.voltar : TextosPublicarVaga.cancelar
    }
    public var mostraAvisoPublicacaoContinua: Bool {
        publicacaoPendente != nil && resultado == nil && !enviando
    }

    public func fecharAvisoDaFila() async {
        guard let recusa = recusaDaFila else { return }
        do {
            try await fila.reconhecerRecusa(id: recusa.id)
            await carregarRecusaDaFila()
        } catch { /* Mantém o aviso se o reconhecimento não foi gravado. */ }
    }

    public func carregarRecusaDaFila() async {
        let recusadas = (try? await fila.recusadas().filter { $0.tipo == .publicacaoVaga && $0.estabelecimentoID == estabelecimento?.id }) ?? []
        recusaDaFila = recusadas.first { $0.id == acaoPendente?.id } ?? recusadas.first
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
                preencherComPublicacao(publicacao)
            }
        } catch {
            mensagemErro = TextosPublicarVaga.falhaFila
        }
    }

    private func preencherComPublicacao(_ publicacao: PublicacaoVaga) {
        funcaoID = publicacao.funcaoID
        inicio = publicacao.periodo.inicio
        fim = publicacao.periodo.fim
        local = publicacao.local
        valorTexto = String(publicacao.valor.centavos)
        posicoesTexto = String(publicacao.posicoes)
        refeicao = publicacao.inclusos.refeicao
        transporte = publicacao.inclusos.transporte
        materialProprio = publicacao.inclusos.exigeMaterialProprio
        responsavelLocal = publicacao.responsavelLocal
        traje = publicacao.traje ?? ""
        participaRateio = publicacao.participaRateio
        observacoes = publicacao.observacoes ?? ""
        modo = publicacao.modo
        if let alerta = publicacao.alertaAntecedenciaMinutos {
            alertaAntecedenciaMinutos = alerta
        }
        if !(publicacao.traje ?? "").isEmpty || !(publicacao.observacoes ?? "").isEmpty || (publicacao.participaRateio == true) {
            mostrandoMaisOpcoes = true
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
                // `-FRILA_PUBLICAR_INICIO_EM_HORAS <n>`: o início daqui a n horas, para o teste de
                // interface ver a opção Seleção com e sem as 24 horas.
                let argumentos = ProcessInfo.processInfo.arguments
                if let indice = argumentos.firstIndex(of: "-FRILA_PUBLICAR_INICIO_EM_HORAS"), argumentos.indices.contains(indice + 1),
                   let horas = Double(argumentos[indice + 1]) {
                    inicio = agora().addingTimeInterval(horas * 60 * 60)
                    fim = inicio.addingTimeInterval(4 * 60 * 60)
                }
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
            publicacaoPendente = nil
            self.acaoPendente = nil
            mensagemErro = TextosPublicarVaga.falhaFila
            return
        }
        do {
            resultado = try await publicarAPI(publicacao)
            try? await fila.resolverRecusas(acaoPendente)
            recusaDaFila = nil
            try? await fila.remover(id: acaoPendente.id)
            publicacaoPendente = nil
            self.acaoPendente = nil
        } catch let erro as ErroDaApi {
            if erro.codigo == .semRede {
                // Sem rede: a publicação continua na fila em segundo plano.
                // Não define mensagemErro para exibir apenas o aviso azul de continuação.
                mensagemErro = nil
            } else {
                tratar(erro)
                if erro.codigo.recusaDefinitivaDePublicacao {
                    try? await fila.remover(id: acaoPendente.id)
                    publicacaoPendente = nil
                    self.acaoPendente = nil
                }
            }
        } catch is URLError {
            // Falha de rede: continua na fila sem erro vermelho.
            mensagemErro = nil
        } catch {
            mensagemErro = TextosPublicarVaga.erroPublicar
        }
    }

    private static let antecedenciaDaSelecao = RegraDaSelecao.antecedencia
    /// D2: abaixo disso a janela de escolha é "curta" e o formulário avisa. Inferência do app: o
    /// requisito pede o aviso sem fixar o limite.
    static let janelaDeEscolhaCurta: TimeInterval = 12 * 60 * 60

    /// MS-RF01: a opção Seleção só é oferecida com o início a mais de 24 horas do relógio do
    /// aparelho; o servidor continua recusando se o pedido chegar (`422 selecao_sem_antecedencia`).
    public var selecaoDisponivel: Bool {
        inicio > agora().addingTimeInterval(Self.antecedenciaDaSelecao)
    }

    /// D2 (MS-RF02): até quando a casa escolhe, 24 h antes do início; `nil` fora do modo seleção.
    public var prazoDeEscolha: Date? {
        guard modo == .selecao, selecaoDisponivel else { return nil }
        return RegraDaSelecao.prazoDeEscolha(inicio: inicio)
    }

    /// A vaga nasce com menos de 12 horas para escolher: o formulário avisa antes de publicar.
    public var janelaDeEscolhaCurta: Bool {
        guard let prazo = prazoDeEscolha else { return false }
        return prazo.timeIntervalSince(agora()) < Self.janelaDeEscolhaCurta
    }

    /// O início mudou: se a seleção deixou de caber, o modo volta a urgência, que é o que a tela
    /// oferece. Chamado pela tela a cada mudança do início.
    public func ajustarModoAoInicio() {
        if modo == .selecao, !selecaoDisponivel { modo = .urgencia }
    }

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
        } else if erro.codigo == .semRede {
            mensagemErro = nil
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
    private let aoCancelar: (() -> Void)?
    @State private var mostrandoPerfilEstabelecimento = false
    @Environment(PermissaoDePushModelo.self) private var permissaoDePush: PermissaoDePushModelo?

    public init(api: any ApiCliente, fila: any FilaDeAcoes, estabelecimento: Estabelecimento, telefoneResponsavel: String, sair: @escaping () -> Void = {}, aoPublicar: @escaping () -> Void = {}, aoCancelar: (() -> Void)? = nil) {
        self.api = api
        self.sair = sair
        self.aoPublicar = aoPublicar
        self.aoCancelar = aoCancelar
        _model = State(initialValue: PublicarVagaViewModel(api: api, fila: fila, estabelecimento: estabelecimento))
        _regiaoMapa = State(initialValue: MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: estabelecimento.ponto.latitude, longitude: estabelecimento.ponto.longitude), span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)))
        self.telefoneResponsavel = telefoneResponsavel
    }

    public var body: some View {
        NavigationStack {
            formulario
                .toolbar {
                    // Quem veio de Minhas vagas tem para onde voltar; no primeiro acesso, não.
                    if let aoCancelar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: aoCancelar) {
                                Text(verbatim: model.textoAoFechar)
                                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                                    .contentShape(Rectangle())
                            }
                            .disabled(model.enviando || model.restaurandoPublicacao)
                            .accessibilityIdentifier("cancelar-publicacao")
                        }
                    }
                    if aoCancelar == nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { mostrandoPerfilEstabelecimento = true } label: {
                                Image(systemName: "building.2.crop.circle")
                                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                            }
                            .accessibilityLabel(String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao))
                        }
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
                    seletorSimNao(TextosPublicarVaga.refeicao, valor: $model.refeicao).erroDeCampoFrila(model.erros[.inclusos])
                    seletorSimNao(TextosPublicarVaga.transporte, valor: $model.transporte).accessibilityHint(Text(verbatim: model.erros[.inclusos] ?? ""))
                    seletorSimNao(TextosPublicarVaga.material, valor: $model.materialProprio).accessibilityHint(Text(verbatim: model.erros[.inclusos] ?? ""))
                    if let erro = model.erros[.inclusos] { Text(verbatim: erro).font(.caption).foregroundStyle(FrilaCor.perigo) }
                }.padding(FrilaEspaco.medio).background(FrilaCor.superficie, in: RoundedRectangle(cornerRadius: FrilaRaio.medio))
                    .disabled(model.camposBloqueados)
                campo(.responsavel, titulo: TextosPublicarVaga.responsavel) {
                    CampoFrila(verbatim: TextosPublicarVaga.responsavel, texto: $model.responsavelLocal)
                }
                campo(.modo, titulo: TextosPublicarVaga.modo) {
                    // MS-RF01: "Seleção" só com o início a mais de 24 horas; abaixo disso a opção
                    // não aparece, e o modo volta a urgência se a data mudou depois da escolha.
                    Picker(TextosPublicarVaga.modo, selection: $model.modo) {
                        Text(verbatim: TextosPublicarVaga.modoUrgencia).tag(ModoPreenchimento.urgencia)
                        if model.selecaoDisponivel {
                            Text(verbatim: TextosPublicarVaga.modoSelecao).tag(ModoPreenchimento.selecao)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text(verbatim: TextosPublicarVaga.modo))
                    .accessibilityIdentifier("modo-vaga-picker")
                    Text(verbatim: model.modo == .selecao ? TextosPublicarVaga.modoSelecaoExplicacao : TextosPublicarVaga.modoUrgenciaExplicacao)
                        .font(.caption)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .accessibilityIdentifier("modo-vaga-explicacao")
                    if !model.selecaoDisponivel {
                        Text(verbatim: TextosPublicarVaga.modoSelecaoSoComAntecedencia)
                            .font(.caption)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .accessibilityIdentifier("modo-selecao-indisponivel")
                    }
                    // D2: o prazo exato de escolha, e o aviso quando ele é curto.
                    if let prazo = model.prazoDeEscolha {
                        Text(verbatim: String(format: TextosPublicarVaga.modoSelecaoPrazo, FormatadorFrila().dataEHora(prazo)))
                            .font(.caption.weight(.semibold))
                            .accessibilityIdentifier("prazo-de-escolha-publicacao")
                        if model.janelaDeEscolhaCurta {
                            AvisoFrila(verbatim: TextosPublicarVaga.modoSelecaoPrazoCurto, tom: .alerta)
                                .accessibilityIdentifier("prazo-de-escolha-curto")
                        }
                    }
                }
                .onChange(of: model.inicio) { _, _ in model.ajustarModoAoInicio() }
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
                        seletorSimNao(TextosPublicarVaga.rateio, valor: Binding(get: { model.participaRateio ?? false }, set: { model.participaRateio = $0 })).erroDeCampoFrila(model.erros[.rateio])
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
                    BotaoSecundario("Fechar") { Task { await model.fecharAvisoDaFila() } }
                        .accessibilityIdentifier("fechar-aviso-publicacao-recusada")
                }
                if let erro = model.mensagemErro {
                    AvisoFrila(verbatim: erro, tom: .erro)
                        .accessibilityIdentifier("aviso-erro-publicacao")
                }
                if model.mostraAvisoPublicacaoContinua {
                    AvisoFrila(verbatim: TextosPublicarVaga.publicacaoContinua, tom: .informativo)
                        .accessibilityIdentifier("aviso-publicacao-continua")
                }
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
        .interactiveDismissDisabled(model.enviando || model.restaurandoPublicacao)
        .accessibilityIdentifier("publicar-vaga-formulario")
    }

    private var campoValor: some View {
        campo(.valor, titulo: TextosPublicarVaga.valor) {
            CampoValorVaga(texto: $model.valorTexto)
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

    private func erroDoCampo(_ campo: CampoPublicacaoVaga) -> String? {
        let erros = [model.erros[campo], campo == .local ? model.erros[.ponto] : nil].compactMap { $0 }
        return erros.isEmpty ? nil : erros.joined(separator: ". ")
    }

    @ViewBuilder private func campo<Conteudo: View>(_ campo: CampoPublicacaoVaga, titulo: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: titulo).font(.headline)
            conteudo().erroDeCampoFrila(erroDoCampo(campo))
            if let erro = model.erros[campo] { Text(verbatim: erro).font(.caption).foregroundStyle(FrilaCor.perigo).accessibilityIdentifier("erro-publicacao-\(campo.rawValue)") }
        }
        .disabled(model.camposBloqueados)
    }

    private func campoOpcional<Conteudo: View>(_ campo: CampoPublicacaoVaga, titulo: String, @ViewBuilder conteudo: () -> Conteudo) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: titulo).font(.headline)
            conteudo().erroDeCampoFrila(erroDoCampo(campo))
            if let erro = model.erros[campo] { Text(verbatim: erro).font(.caption).foregroundStyle(FrilaCor.perigo) }
        }
            .disabled(model.camposBloqueados)
    }

    private func datePicker(_ titulo: String, date: Binding<Date>, field: CampoPublicacaoVaga) -> some View {
        campo(field, titulo: titulo) {
            if dynamicTypeSize.isAccessibilitySize {
                DatePicker(titulo, selection: date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                    .accessibilityIdentifier("datepicker-\(field.rawValue)")
            } else {
                DatePicker(titulo, selection: date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .minimumScaleFactor(0.7)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityIdentifier("datepicker-\(field.rawValue)")
            }
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
                HStack(spacing: FrilaEspaco.minimo) {
                    if valor.wrappedValue == escolha {
                        Image(systemName: "checkmark")
                            .accessibilityIdentifier(escolha ? "icone-checkmark-sim" : "icone-checkmark-nao")
                    }
                    Text(verbatim: rotulo).font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, FrilaEspaco.minimo)
                .frame(minWidth: 48, minHeight: FrilaMetrica.alvoMinimo)
                .background(valor.wrappedValue == escolha ? FrilaCor.texto : FrilaCor.superficie, in: Capsule())
                .foregroundStyle(valor.wrappedValue == escolha ? FrilaCor.fundo : FrilaCor.texto)
                .overlay(Capsule().stroke(FrilaCor.textoSecundario.opacity(0.4)))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(valor.wrappedValue == escolha ? .isSelected : [])
        }
    }

}

/// Máscara usada no formulário de publicar, inclusive ao abrir por Minhas vagas.
struct CampoValorVaga: UIViewRepresentable {
    @Binding var texto: String
    @Environment(\.isEnabled) private var habilitado

    func makeCoordinator() -> Coordenador { Coordenador(texto: $texto) }

    func makeUIView(context: Context) -> UITextField {
        let campo = UITextField()
        campo.keyboardType = .numberPad
        campo.borderStyle = .none
        campo.font = .preferredFont(forTextStyle: .body)
        campo.adjustsFontForContentSizeCategory = true
        campo.textColor = FrilaCor.textoUIKit
        campo.placeholder = TextosPublicarVaga.valorExemplo
        campo.accessibilityLabel = TextosPublicarVaga.valor
        campo.accessibilityIdentifier = "valor-vaga-campo"
        campo.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        campo.addTarget(context.coordinator, action: #selector(Coordenador.editar(_:)), for: .editingChanged)
        return campo
    }

    func updateUIView(_ campo: UITextField, context: Context) {
        context.coordinator.texto = $texto
        campo.isEnabled = habilitado
        let formatado = Self.formatarCentavos(Int(texto.filter(\.isNumber)) ?? 0)
        if campo.text != formatado { campo.text = formatado }
    }

    @MainActor
    final class Coordenador: NSObject {
        var texto: Binding<String>

        init(texto: Binding<String>) { self.texto = texto }

        @objc func editar(_ campo: UITextField) {
            let centavos = Int((campo.text ?? "").filter(\.isNumber)) ?? 0
            // Reescreve no próprio evento, antes da próxima tecla. Um binding formatado depende
            // da renderização do SwiftUI e pode sobrescrever teclas rápidas com um valor antigo.
            campo.text = CampoValorVaga.formatarCentavos(centavos)
            campo.selectedTextRange = campo.textRange(from: campo.endOfDocument, to: campo.endOfDocument)
            texto.wrappedValue = String(centavos)
        }
    }

    static func formatarCentavos(_ centavos: Int) -> String {
        let reais = centavos / 100
        let resto = centavos % 100
        return String(format: TextosPublicarVaga.formatoValor, reais, resto)
    }
}
