import FrilaDominio
import MapKit
import Observation
import SwiftUI
import UIKit

private final class MarcadorPublicarVaga: NSObject {}
private let bundlePublicarVaga = Bundle(for: MarcadorPublicarVaga.self)

enum TextosPublicarVaga {
    static let titulo = String(localized: "Nova vaga", bundle: bundleApresentacao)
    static let funcao = String(localized: "Função", bundle: bundleApresentacao)
    static let selecioneFuncao = String(localized: "Selecione uma função", bundle: bundleApresentacao)
    static let dataInicio = String(localized: "Início", bundle: bundleApresentacao)
    static let dataFim = String(localized: "Fim", bundle: bundleApresentacao)
    static let quando = String(localized: "Quando", bundle: bundleApresentacao)
    static let hoje = String(localized: "Hoje", bundle: bundleApresentacao)
    static let amanha = String(localized: "Amanhã", bundle: bundleApresentacao)
    static let terminaNoMesmoDia = String(localized: "Termina no mesmo dia: %@, às %@.", bundle: bundleApresentacao)
    static let terminaNoDiaSeguinte = String(localized: "Termina no dia seguinte: %@, às %@.", bundle: bundleApresentacao)
    static let terminaEm = String(localized: "Termina em %@, às %@.", bundle: bundleApresentacao)
    static let local = String(localized: "Local", bundle: bundleApresentacao)
    static let endereco = String(localized: "Endereço do turno", bundle: bundleApresentacao)
    static let enderecoAjuda = String(localized: "Ponto confirmado no mapa no cadastro. O check-in dos profissionais usa este ponto.", bundle: bundleApresentacao)
    static let valor = String(localized: "Valor por pessoa", bundle: bundleApresentacao)
    static let valorExemplo = String(localized: "R$ 0,00", bundle: bundleApresentacao)
    static let formatoValor = String(localized: "R$ %d,%02d", bundle: bundleApresentacao)
    static let valorAjuda = String(localized: "O profissional recebe o valor integral", bundle: bundleApresentacao)
    static let posicoes = String(localized: "Posições", bundle: bundleApresentacao)
    static let ajustarPosicoes = String(localized: "Ajustar posições", bundle: bundleApresentacao)
    static let posicoesExemplo = String(localized: "1", bundle: bundleApresentacao)
    static let totalDaVaga = String(localized: "Total da vaga: %@", bundle: bundleApresentacao)
    static let inclusos = String(localized: "Inclusos e o que levar", bundle: bundleApresentacao)
    static let refeicao = String(localized: "Refeição inclusa", bundle: bundleApresentacao)
    static let transporte = String(localized: "Transporte incluso", bundle: bundleApresentacao)
    static let material = String(localized: "Precisa levar material", bundle: bundleApresentacao)
    static let sim = String(localized: "Sim", bundle: bundleApresentacao)
    static let nao = String(localized: "Não", bundle: bundleApresentacao)
    static let responsavel = String(localized: "Quem recebe o profissional no local", bundle: bundleApresentacao)
    static let alerta = String(localized: "Avisar se a vaga seguir vazia", bundle: bundleApresentacao)
    static let alertaTresHoras = String(localized: "3 horas antes", bundle: bundleApresentacao)
    static let alertaDuasHoras = String(localized: "2 horas antes", bundle: bundleApresentacao)
    static let alertaSeisHoras = String(localized: "6 horas antes", bundle: bundleApresentacao)
    static let maisOpcoes = String(localized: "Mais opções", bundle: bundleApresentacao)
    static let maisOpcoesAjuda = String(localized: "Traje, rateio dos 10% e observações", bundle: bundleApresentacao)
    static let maisOpcoesAjudaEstudio = String(localized: "Rateio dos 10%, observações e aviso se a vaga seguir vazia", bundle: bundleApresentacao)
    static let maisOpcoesAberto = String(localized: "Aberto", bundle: bundleApresentacao)
    static let maisOpcoesFechado = String(localized: "Fechado", bundle: bundleApresentacao)
    static let observacoesAjuda = String(localized: "Aparece no detalhe da vaga, antes do aceite.", bundle: bundleApresentacao)
    static let traje = String(localized: "Traje", bundle: bundleApresentacao)
    static let rateio = String(localized: "Participa do rateio dos 10%", bundle: bundleApresentacao)
    static let observacoes = String(localized: "Observações", bundle: bundleApresentacao)
    static let telefoneResponsavel = String(localized: "Telefone do responsável", bundle: bundleApresentacao)
    static let publicar = String(localized: "Publicar vaga", bundle: bundleApresentacao)
    static let tentarNovamente = String(localized: "Tentar novamente", bundle: bundleApresentacao)
    static let avisoRN10 = String(localized: "Após a confirmação, o telefone do responsável será mostrado ao profissional para combinar o turno.", bundle: bundleApresentacao)
    static let campoObrigatorio = String(localized: "Preencha este campo.", bundle: bundleApresentacao)
    static let campoInvalido = String(localized: "Confira o valor informado.", bundle: bundleApresentacao)
    static let erroPublicar = String(localized: "Não foi possível publicar a vaga. Tente novamente.", bundle: bundleApresentacao)
    static let semFuncoes = String(localized: "Não foi possível carregar as funções.", bundle: bundleApresentacao)
    static let funcaoCampo = String(localized: "Escolha uma função.", bundle: bundleApresentacao)
    static let localCampo = String(localized: "Informe o endereço.", bundle: bundleApresentacao)
    static let valorCampo = String(localized: "Informe um valor maior que zero.", bundle: bundleApresentacao)
    static let posicoesCampo = String(localized: "Informe de 1 a 200 posições.", bundle: bundleApresentacao)
    static let horarioCampo = String(localized: "O fim precisa ser depois do início, e o início deve estar no futuro.", bundle: bundleApresentacao)
    static let estabelecimentoCampo = String(localized: "Não encontramos o estabelecimento cadastrado.", bundle: bundleApresentacao)
    static let responsavelCampo = String(localized: "Informe quem recebe o profissional no local.", bundle: bundleApresentacao)
    static let falhaFila = String(localized: "Não foi possível guardar a publicação neste aparelho.", bundle: bundleApresentacao)
    static let verificandoPendente = String(localized: "Verificando publicação pendente…", bundle: bundleApresentacao)
    static let pendenteDescricao = String(localized: "Há uma publicação pendente. Tente novamente para concluir sem criar outra vaga.", bundle: bundleApresentacao)
    static let modo = String(localized: "Como preencher a vaga", bundle: bundleApresentacao)
    static let modoUrgencia = String(localized: "Urgência", bundle: bundleApresentacao)
    static let modoSelecao = String(localized: "Seleção", bundle: bundleApresentacao)
    static let modoUrgenciaExplicacao = String(localized: "O primeiro profissional que aceitar é confirmado na hora.", bundle: bundleApresentacao)
    static let modoSelecaoExplicacao = String(localized: "Você escolhe entre os candidatos. O início precisa estar a mais de 24 horas, e a vaga fecha sozinha 24 horas antes se ninguém for escolhido.", bundle: bundleApresentacao)
    static let modoIndisponivel = String(localized: "O modo seleção ainda não está disponível. Publique no modo urgência.", bundle: bundleApresentacao)
    /// MS-RF01: a opção Seleção só aparece com o início a mais de 24 horas (RN24).
    static let modoSelecaoSoComAntecedencia = String(localized: "A seleção fica disponível para vagas que começam em mais de 24 horas.", bundle: bundleApresentacao)
    /// D2 (0.2.38): o prazo exato de escolha, mostrado na publicação.
    static let modoSelecaoPrazo = String(localized: "Você terá até %@ para escolher. Depois disso a vaga fecha sozinha.", bundle: bundleApresentacao)
    static let modoSelecaoPrazoCurto = String(localized: "Prazo curto: você terá menos de 12 horas para escolher antes de a vaga fechar.", bundle: bundleApresentacao)
    static let voltar = String(localized: "Voltar", bundle: bundleApresentacao)
    static let cancelar = String(localized: "Cancelar", bundle: bundleApresentacao)
    static let publicacaoContinua = String(localized: "A publicação continua e será concluída quando a conexão voltar.", bundle: bundleApresentacao)
    static let menosTresHorasTitulo = String(localized: "Começa em menos de 3 horas.", bundle: bundleApresentacao)
    static let menosTresHorasCorpo = String(localized: "Não haverá o aviso de 3 h antes: enquanto seguir vazia, a vaga fica em Precisa de atenção, em Minhas vagas.", bundle: bundleApresentacao)
    static let resumoSingular = String(localized: "%d posição · %@ · %@, %@ às %@", bundle: bundleApresentacao)
    static let resumoPlural = String(localized: "%d posições · %@ · %@, %@ às %@", bundle: bundleApresentacao)
    static let escolhaFuncao = String(localized: "Escolha a função", bundle: bundleApresentacao)
    static let resumoTotalSingular = String(localized: "Valor de 1 pessoa, pago direto a ela", bundle: bundleApresentacao)
    static let resumoTotalPlural = String(localized: "Soma de %d pessoas, pago direto a cada uma", bundle: bundleApresentacao)
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
    public var estabelecimento: Estabelecimento? {
        didSet {
            limparErroSeValido(.estabelecimento)
            limparErroSeValido(.ponto)
        }
    }
    public var funcoes: [Funcao] {
        didSet {
            limparErroSeValido(.funcao)
        }
    }
    public var funcaoID: UUID? {
        didSet {
            limparErroSeValido(.funcao)
        }
    }
    public var inicio: Date {
        didSet {
            let duracao = fim.timeIntervalSince(oldValue)
            if duracao > 0 {
                fim = inicio.addingTimeInterval(duracao)
            }
            ajustarModoAoInicio()
            limparErroSeValido(.inicio)
            limparErroSeValido(.fim)
        }
    }
    public var fim: Date {
        didSet {
            limparErroSeValido(.fim)
        }
    }
    public var local: String {
        didSet {
            limparErroSeValido(.local)
        }
    }
    public var valorTexto = "" {
        didSet {
            limparErroSeValido(.valor)
        }
    }
    public var posicoesTexto = "1" {
        didSet {
            limparErroSeValido(.posicoes)
        }
    }
    public var refeicao = false {
        didSet {
            limparErroSeValido(.inclusos)
        }
    }
    public var transporte = false {
        didSet {
            limparErroSeValido(.inclusos)
        }
    }
    public var materialProprio = false {
        didSet {
            limparErroSeValido(.inclusos)
        }
    }
    public var responsavelLocal = "" {
        didSet {
            limparErroSeValido(.responsavel)
        }
    }
    public var alertaAntecedenciaMinutos = 180
    /// Urgência confirma o primeiro que aceitar; seleção deixa a casa escolher entre os candidatos (RN24).
    public var modo = ModoPreenchimento.urgencia {
        didSet {
            limparErroSeValido(.modo)
            limparErroSeValido(.inicio)
        }
    }
    public var traje = "" {
        didSet {
            limparErroSeValido(.traje)
        }
    }
    public var participaRateio: Bool? = false {
        didSet {
            limparErroSeValido(.rateio)
        }
    }
    public var observacoes = "" {
        didSet {
            limparErroSeValido(.observacoes)
        }
    }
    /// O rateio como Sim/Não para controles de dois estados: sem resposta conta como "Não".
    public var participaRateioOuNao: Bool {
        get { participaRateio ?? false }
        set { participaRateio = newValue }
    }
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
    public var valorTotalCentavos: Int {
        guard let posicoes = Int(posicoesTexto), posicoes > 0 else { return 0 }
        return valorCentavos * posicoes
    }

    private var posicoesValidas: Int? {
        guard let valor = Int(posicoesTexto), valor >= 1 else { return nil }
        return min(valor, 200)
    }

    public func incrementarPosicoes() {
        guard let atual = posicoesValidas else {
            posicoesTexto = "1"
            return
        }
        if atual < 200 {
            posicoesTexto = String(atual + 1)
        } else {
            posicoesTexto = "200"
        }
    }

    public func decrementarPosicoes() {
        guard let atual = posicoesValidas else {
            posicoesTexto = "1"
            return
        }
        if atual > 1 {
            posicoesTexto = String(atual - 1)
        } else {
            posicoesTexto = "1"
        }
    }
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

    private func campoValido(_ campo: CampoPublicacaoVaga) -> Bool {
        switch campo {
        case .estabelecimento:
            return estabelecimento != nil
        case .funcao:
            return funcoes.contains(where: { $0.id == funcaoID })
        case .inicio:
            if inicio <= agora() { return false }
            if modo == .selecao, inicio <= agora().addingTimeInterval(Self.antecedenciaDaSelecao) { return false }
            return true
        case .fim:
            return fim > inicio
        case .local:
            return !local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .ponto:
            guard let ponto = estabelecimento?.ponto else { return false }
            return ponto.latitude.isFinite && ponto.longitude.isFinite
        case .valor:
            return valorCentavos >= 1
        case .posicoes:
            guard let posicoes = Int(posicoesTexto) else { return false }
            return (1...200).contains(posicoes)
        case .responsavel:
            return !responsavelLocal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .inclusos, .traje, .rateio, .observacoes, .modo:
            return true
        }
    }

    private func limparErroSeValido(_ campo: CampoPublicacaoVaga) {
        guard erros[campo] != nil else { return }
        if campoValido(campo) {
            erros.removeValue(forKey: campo)
        }
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

/// Máscara de valor em reais (UIKit) usada pelos formulários de publicar.
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
        campo.delegate = context.coordinator
        return campo
    }

    func updateUIView(_ campo: UITextField, context: Context) {
        context.coordinator.texto = $texto
        campo.isEnabled = habilitado
        let formatado = Self.formatarCentavos(Int(texto.filter(\.isNumber)) ?? 0)
        if campo.text != formatado { campo.text = formatado }
    }

    @MainActor
    final class Coordenador: NSObject, UITextFieldDelegate {
        var texto: Binding<String>

        init(texto: Binding<String>) { self.texto = texto }

        // O campo sempre mostra "R$ 0,00"; um toque à esquerda deixa o cursor antes do "R$".
        // Dígito novo entra sempre no fim e apagar tira sempre o último, onde quer que esteja o cursor.
        func textField(_ campo: UITextField, shouldChangeCharactersIn intervalo: NSRange, replacementString novo: String) -> Bool {
            var digitos = (campo.text ?? "").filter(\.isNumber)
            if novo.isEmpty {
                digitos = String(digitos.dropLast())
            } else {
                digitos += novo.filter(\.isNumber)
            }
            campo.text = digitos
            editar(campo)
            return false
        }

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
