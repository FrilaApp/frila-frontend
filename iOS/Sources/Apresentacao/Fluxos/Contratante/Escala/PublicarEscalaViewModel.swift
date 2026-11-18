import FrilaDominio
import Observation
import SwiftUI

public enum CampoDoEventoDaEscala: Hashable, Sendable {
    case nome
    case data
}

public enum CampoDaVagaDaEscala: Hashable, Sendable {
    case funcao
    case horario
    case modo
    case valor
    case pessoas
    case responsavel
    case traje
    case observacoes
}

/// Uma vaga do formulário da escala, com o que a vaga avulsa tem: modo, responsável no local, inclusos, traje e
/// observações (a mesma escala sai igual na web, no Android e no iOS). O valor fica em centavos como texto (a máscara do
/// campo de valor escreve assim). O rateio dos 10% não é perguntado: vai nulo, como na web e no Android.
public struct VagaDoFormularioDaEscala: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var funcaoID: UUID?
    public var inicio: Date
    public var fim: Date
    public var modo: ModoPreenchimento = .urgencia
    public var valorTexto: String
    public var pessoas: Int
    public var responsavelLocal: String = ""
    public var refeicao = false
    public var transporte = false
    public var materialProprio = false
    public var traje = ""
    public var observacoes = ""

    public var valorCentavos: Int { Int(valorTexto.filter(\.isNumber)) ?? 0 }
}

/// O que a tela mostra de errado: uma mensagem geral (junto ao botão) e a de cada campo marcado.
public struct ErrosDaEscala: Equatable, Sendable {
    public var geral: String?
    public var evento: [CampoDoEventoDaEscala: String] = [:]
    public var vagas: [UUID: [CampoDaVagaDaEscala: String]] = [:]

    public var vazio: Bool { geral == nil && evento.isEmpty && vagas.values.allSatisfy(\.isEmpty) }
}

/// A escala de evento da casa (contrato 0.2.96, `publicar_escala`): um evento e de 1 a 10 vagas, publicadas de uma vez,
/// tudo ou nada. Não passa pela fila offline: uma escala é uma só chamada.
///
/// Idempotência (DINHEIRO: vaga em dobro): a `chave` é uma só para a escala inteira e nasce com cada montagem do pedido.
/// Tudo que não é recusa definitiva (`recusaDefinitivaDePublicacao`, mais 401 e 429, que também não gravam nada) é
/// resultado INCERTO: sem rede, prazo vencido, resposta ilegível, um 502 ou 504 sem envelope (`.desconhecido`). A escala
/// montada fica guardada em `tentativaIncerta`, os campos travam, e o "Tentar de novo" manda o MESMO corpo com a MESMA
/// chave, que o servidor devolve sem publicar de novo. A chave só sai depois de sucesso ou de recusa definitiva.
/// A `GuardaDaEscala` mantém este modelo vivo, com a chave, enquanto houver tentativa incerta, mesmo que a pessoa cancele.
@MainActor @Observable
public final class PublicarEscalaViewModel {
    public let estabelecimento: Estabelecimento

    public var nome = "" {
        didSet { editou(evento: .nome) }
    }
    /// O dia do evento. Ao mudar, as vagas andam o mesmo tanto de dias, com as mesmas horas.
    public var data: Date {
        didSet {
            deslocarVagas(de: oldValue, para: data)
            editou(evento: .data)
        }
    }

    public private(set) var vagas: [VagaDoFormularioDaEscala]
    public private(set) var funcoes: [Funcao] = []
    public private(set) var carregandoFuncoes = false
    public private(set) var funcoesIndisponiveis = false
    public private(set) var enviando = false
    public private(set) var erros = ErrosDaEscala()
    public private(set) var resultado: EscalaPublicada?
    /// A escala que saiu sem resposta conhecida: o "Tentar de novo" a manda de novo, com a mesma chave.
    public private(set) var tentativaIncerta: PublicacaoEscala?
    /// Sobe a cada tentativa de publicar que termina com uma mensagem geral, mesmo repetida: a tela rola até ela e move o
    /// foco de acessibilidade para ela (quem só aumenta a letra, em AX5, não a veria no alto da rolagem).
    public private(set) var avisosDaAcao = 0

    private let carregar: @Sendable () async throws -> [Funcao]
    private let publicarAPI: @Sendable (PublicacaoEscala) async throws -> EscalaPublicada
    private let agora: @Sendable () -> Date
    private let novoID: @Sendable () -> UUID
    /// O prazo de cada `await` de rede; o teste injeta um menor.
    private let prazo: Duration

    public convenience init(
        api: any ApiCliente, estabelecimento: Estabelecimento, agora: @escaping @Sendable () -> Date = Date.init,
        prazo: Duration = .seconds(20)
    ) {
        self.init(
            estabelecimento: estabelecimento, agora: agora, prazo: prazo,
            carregar: { try await api.funcoes() },
            publicar: { try await api.publicarEscala($0) }
        )
    }

    public init(
        estabelecimento: Estabelecimento,
        funcoes: [Funcao] = [],
        agora: @escaping @Sendable () -> Date = Date.init,
        prazo: Duration = .seconds(20),
        novoID: @escaping @Sendable () -> UUID = UUID.init,
        carregar: (@Sendable () async throws -> [Funcao])? = nil,
        publicar: @escaping @Sendable (PublicacaoEscala) async throws -> EscalaPublicada
    ) {
        self.estabelecimento = estabelecimento
        self.funcoes = funcoes
        self.agora = agora
        self.novoID = novoID
        self.prazo = prazo
        self.carregar = carregar ?? { funcoes }
        publicarAPI = publicar
        // O evento começa amanhã; a primeira vaga, às 18h daquele dia, por cinco horas.
        let amanha = Self.calendario.date(byAdding: .day, value: 1, to: agora()) ?? agora()
        data = amanha
        vagas = [Self.vagaVazia(id: novoID(), dia: amanha)]
    }

    // MARK: Estado derivado

    /// Enquanto uma tentativa incerta espera, os campos não mudam: a mesma chave não pode virar outro pedido.
    public var camposBloqueados: Bool { tentativaIncerta != nil || enviando }
    public var podeAdicionarVaga: Bool { vagas.count < PublicacaoEscala.limiteDeVagas && !camposBloqueados }
    public var podeRemoverVaga: Bool { vagas.count > 1 && !camposBloqueados }
    public var totalDePessoas: Int { vagas.reduce(0) { $0 + $1.pessoas } }

    public func funcao(de vaga: VagaDoFormularioDaEscala) -> Funcao? {
        funcoes.first { $0.id == vaga.funcaoID }
    }

    /// RN24: a seleção só existe com o início a mais de 24 horas do relógio do aparelho (o do servidor é que vale).
    public func selecaoDisponivel(_ vaga: VagaDoFormularioDaEscala) -> Bool {
        vaga.inicio > agora().addingTimeInterval(RegraDaSelecao.antecedencia)
    }

    /// Até quando a casa escolhe, 24 h antes do início; `nil` fora do modo seleção.
    public func prazoDeEscolha(_ vaga: VagaDoFormularioDaEscala) -> Date? {
        guard vaga.modo == .selecao, selecaoDisponivel(vaga) else { return nil }
        return RegraDaSelecao.prazoDeEscolha(inicio: vaga.inicio)
    }

    /// Quantas vagas a escala publicou, depois do resultado.
    public var vagasPublicadas: Int { resultado?.vagas.count ?? 0 }

    // MARK: Funções

    public func carregarFuncoes() async {
        guard funcoes.isEmpty, !carregandoFuncoes else { return }
        carregandoFuncoes = true
        funcoesIndisponiveis = false
        defer { carregandoFuncoes = false }
        let fonte = carregar
        do {
            funcoes = try await PrazoDaAbertura.esperar(prazo) { try await fonte() }
            funcoesIndisponiveis = funcoes.isEmpty
        } catch is CancellationError {
            // A saída da tela cancela o carregamento, sem apresentar uma falha.
        } catch {
            funcoesIndisponiveis = true
        }
    }

    // MARK: Vagas

    public func adicionarVaga() {
        guard podeAdicionarVaga else { return }
        var nova = Self.vagaVazia(id: novoID(), dia: data)
        // Mais uma função no mesmo turno é o caso comum: a vaga nova nasce com o horário e o responsável da anterior.
        if let ultima = vagas.last {
            nova.inicio = ultima.inicio
            nova.fim = ultima.fim
            nova.responsavelLocal = ultima.responsavelLocal
        }
        vagas.append(nova)
        editou()
    }

    public func removerVaga(id: UUID) {
        guard podeRemoverVaga else { return }
        vagas.removeAll { $0.id == id }
        erros.vagas[id] = nil
        editou()
    }

    /// Muda uma vaga do formulário e tira a marca do campo que a pessoa acabou de mexer.
    public func atualizar(_ id: UUID, _ mudanca: (inout VagaDoFormularioDaEscala) -> Void) {
        guard !camposBloqueados, let indice = vagas.firstIndex(where: { $0.id == id }) else { return }
        let antes = vagas[indice]
        var depois = antes
        mudanca(&depois)
        // O fim anda junto com o início, como no publicar vaga.
        if depois.inicio != antes.inicio {
            let duracao = antes.fim.timeIntervalSince(antes.inicio)
            if duracao > 0, depois.fim == antes.fim { depois.fim = depois.inicio.addingTimeInterval(duracao) }
        }
        depois.pessoas = min(max(depois.pessoas, 1), PublicacaoEscala.limiteDePosicoes)
        // A seleção deixou de caber com o novo início: volta para urgência, que é o que a tela oferece.
        if depois.modo == .selecao, !selecaoDisponivel(depois) { depois.modo = .urgencia }
        vagas[indice] = depois
        if depois.funcaoID != antes.funcaoID { erros.vagas[id]?[.funcao] = nil }
        if depois.inicio != antes.inicio || depois.fim != antes.fim {
            erros.vagas[id]?[.horario] = nil
            erros.vagas[id]?[.modo] = nil
        }
        if depois.modo != antes.modo { erros.vagas[id]?[.modo] = nil }
        if depois.valorTexto != antes.valorTexto { erros.vagas[id]?[.valor] = nil }
        if depois.pessoas != antes.pessoas { erros.vagas[id]?[.pessoas] = nil }
        if depois.responsavelLocal != antes.responsavelLocal { erros.vagas[id]?[.responsavel] = nil }
        if depois.traje != antes.traje { erros.vagas[id]?[.traje] = nil }
        if depois.observacoes != antes.observacoes { erros.vagas[id]?[.observacoes] = nil }
        editou()
    }

    /// Escolhe o modo da vaga. A seleção é recusada, com a mensagem no campo, quando o início não está a mais de 24 horas.
    public func escolherModo(_ modo: ModoPreenchimento, em id: UUID) {
        guard !camposBloqueados, let vaga = vagas.first(where: { $0.id == id }) else { return }
        if modo == .selecao, !selecaoDisponivel(vaga) {
            erros.vagas[id, default: [:]][.modo] = TextosRepublicarVaga.selecaoSemAntecedencia
            return
        }
        atualizar(id) { $0.modo = modo }
    }

    public func aumentarPessoas(em id: UUID) { atualizar(id) { $0.pessoas += 1 } }
    public func diminuirPessoas(em id: UUID) { atualizar(id) { $0.pessoas -= 1 } }

    // MARK: Validação local

    /// O que dá para conferir sem o servidor: o resto (termos no nome, antecedência, soma) é dele, e a recusa volta no campo.
    public func validar() -> Bool {
        var novos = ErrosDaEscala()
        let nome = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        if !(3...100).contains(nome.count) { novos.evento[.nome] = TextosDaEscala.Erro.nome }
        if DataCivil.deSaoPaulo(data) == nil { novos.evento[.data] = TextosDaEscala.Erro.data }

        let agora = agora()
        for vaga in vagas {
            var daVaga: [CampoDaVagaDaEscala: String] = [:]
            if !funcoes.contains(where: { $0.id == vaga.funcaoID }) { daVaga[.funcao] = TextosDaEscala.Erro.funcao }
            if vaga.inicio <= agora || vaga.fim <= vaga.inicio { daVaga[.horario] = TextosDaEscala.Erro.horario }
            if vaga.modo == .selecao, !selecaoDisponivel(vaga) { daVaga[.modo] = TextosRepublicarVaga.selecaoSemAntecedencia }
            if vaga.valorCentavos < 1 { daVaga[.valor] = TextosDaEscala.Erro.valor }
            if !(1...PublicacaoEscala.limiteDePosicoes).contains(vaga.pessoas) { daVaga[.pessoas] = TextosDaEscala.Erro.pessoas }
            if vaga.responsavelLocal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { daVaga[.responsavel] = TextosDaEscala.Erro.responsavel }
            if !daVaga.isEmpty { novos.vagas[vaga.id] = daVaga }
        }

        if !(1...PublicacaoEscala.limiteDeVagas).contains(vagas.count) {
            novos.geral = TextosDaEscala.Erro.quantidade
        } else if totalDePessoas > PublicacaoEscala.limiteDePosicoes {
            novos.geral = TextosDaEscala.Erro.somaDePessoas
        } else if !novos.evento.isEmpty || !novos.vagas.isEmpty {
            novos.geral = TextosDaEscala.Erro.temErro
        }
        erros = novos
        return novos.vazio
    }

    // MARK: Publicar

    public func publicar() async {
        guard !enviando, resultado == nil else { return }
        let escala: PublicacaoEscala
        if let incerta = tentativaIncerta {
            escala = incerta
        } else {
            guard validar(), let montada = montar() else {
                if erros.geral != nil { avisosDaAcao += 1 }
                return
            }
            escala = montada
        }
        enviando = true
        erros.geral = nil
        defer {
            enviando = false
            if erros.geral != nil { avisosDaAcao += 1 }
        }
        let fonte = publicarAPI
        do {
            resultado = try await PrazoDaAbertura.esperar(prazo) { try await fonte(escala) }
            tentativaIncerta = nil
        } catch let erro as ErroDaApi {
            if Self.recusaDefinitiva(erro) {
                tentativaIncerta = nil
                tratar(erro)
            } else {
                // Pode ter chegado: sem rede, prazo vencido, resposta ilegível, 502 ou 504 sem envelope. Guarda a mesma
                // escala, com a mesma chave: reenviar nunca a duplica.
                tentativaIncerta = escala
                erros.geral = TextosDaEscala.Erro.incerta
            }
        } catch {
            // A rede crua e o cancelamento (a saída da tela no meio do envio) também deixam a escala incerta.
            tentativaIncerta = escala
            if !(error is CancellationError) { erros.geral = TextosDaEscala.Erro.incerta }
        }
    }

    /// Só a recusa definitiva solta a chave: o servidor não gravou nada e repetir o mesmo corpo não vira sucesso. `429` e
    /// `401` também chegam antes de gravar.
    static func recusaDefinitiva(_ erro: ErroDaApi) -> Bool {
        erro.codigo.recusaDefinitivaDePublicacao || erro.codigo == .limiteExcedido || erro.codigo == .naoAutenticado
    }

    private func montar() -> PublicacaoEscala? {
        guard let dia = DataCivil.deSaoPaulo(data) else { return nil }
        let evento = EventoDaEscala(
            nome: nome.trimmingCharacters(in: .whitespacesAndNewlines), data: dia, local: estabelecimento.endereco,
            regiaoAdministrativa: estabelecimento.regiaoAdministrativa, ponto: estabelecimento.ponto
        )
        var itens: [VagaDaEscala] = []
        for vaga in vagas {
            guard let funcaoID = vaga.funcaoID, let periodo = try? Periodo(inicio: vaga.inicio, fim: vaga.fim) else { return nil }
            itens.append(VagaDaEscala(
                funcaoID: funcaoID, periodo: periodo, valor: Dinheiro(centavos: vaga.valorCentavos), posicoes: vaga.pessoas,
                inclusos: Inclusos(refeicao: vaga.refeicao, transporte: vaga.transporte, exigeMaterialProprio: vaga.materialProprio),
                responsavelLocal: vaga.responsavelLocal.trimmingCharacters(in: .whitespacesAndNewlines),
                traje: vaga.traje.trimmingCharacters(in: .whitespacesAndNewlines).nilSeVazio,
                participaRateio: nil,
                observacoes: vaga.observacoes.trimmingCharacters(in: .whitespacesAndNewlines).nilSeVazio,
                modo: vaga.modo
            ))
        }
        return PublicacaoEscala(estabelecimentoID: estabelecimento.id, evento: evento, vagas: itens, chave: novoID())
    }

    /// Recusa do servidor: nada foi publicado. O caminho do campo (`evento.nome`, `vagas[2].valor_centavos`, `vagas`,
    /// `posicoes`) vira a marca no campo certo, ou a mensagem geral quando o erro não é de um campo só.
    private func tratar(_ erro: ErroDaApi) {
        var novos = ErrosDaEscala()
        switch erro.codigo {
        case .campoObrigatorio, .campoInvalido:
            marcar(caminho: erro.detalhes, em: &novos)
        case .horarioInvalido:
            marcarVaga(deCaminho: erro.detalhes, campo: .horario, texto: TextosDaEscala.Erro.horario, em: &novos)
        case .selecaoSemAntecedencia:
            marcarVaga(deCaminho: erro.detalhes, campo: .modo, texto: TextosRepublicarVaga.selecaoSemAntecedencia, em: &novos)
        case .funcaoIncompativel:
            marcarVaga(deCaminho: erro.detalhes, campo: .funcao, texto: TextosDaEscala.Erro.funcao, em: &novos)
        case .semPermissao where erro.detalhes == CodigoErroAPI.contaSuspensa.rawValue, .contaSuspensa:
            novos.geral = TextosDaEscala.Erro.contaSuspensa
        case .semPermissao:
            novos.geral = TextosDaEscala.Erro.semPermissao
        case .perfilIncompativel:
            novos.geral = TextosDaEscala.Erro.perfilIncompativel
        case .naoAutenticado, .limiteExcedido:
            novos.geral = MensagemDoErroAPI.texto(erro)
        default:
            novos.geral = TextosDaEscala.Erro.generico
        }
        erros = novos
    }

    private func marcarVaga(deCaminho caminho: String?, campo: CampoDaVagaDaEscala, texto: String, em novos: inout ErrosDaEscala) {
        if let (indice, _) = Self.vaga(deCaminho: caminho), vagas.indices.contains(indice) {
            novos.vagas[vagas[indice].id] = [campo: texto]
            novos.geral = TextosDaEscala.Erro.temErro
        } else {
            novos.geral = TextosDaEscala.Erro.generico
        }
    }

    private func marcar(caminho: String?, em novos: inout ErrosDaEscala) {
        guard let caminho else {
            novos.geral = TextosDaEscala.Erro.generico
            return
        }
        switch caminho {
        case "evento.nome":
            novos.evento[.nome] = TextosDaEscala.Erro.nome
            novos.geral = TextosDaEscala.Erro.temErro
        case "evento.data":
            novos.evento[.data] = TextosDaEscala.Erro.data
            novos.geral = TextosDaEscala.Erro.temErro
        case "evento.local", "evento.regiao_administrativa", "evento.ponto":
            // Vêm do cadastro da casa: a pessoa conserta lá, não nesta tela.
            novos.geral = TextosDaEscala.Erro.cadastroDaCasa
        case "vagas":
            novos.geral = TextosDaEscala.Erro.quantidade
        case "posicoes":
            novos.geral = TextosDaEscala.Erro.somaDePessoas
        default:
            if let (indice, campo) = Self.vaga(deCaminho: caminho), vagas.indices.contains(indice), let marca = Self.campo(deItem: campo) {
                novos.vagas[vagas[indice].id] = [marca.campo: marca.texto]
                novos.geral = TextosDaEscala.Erro.temErro
            } else {
                novos.geral = TextosDaEscala.Erro.generico
            }
        }
    }

    /// `vagas[2].valor_centavos` -> (2, "valor_centavos"); `vagas[1]` -> (1, nil).
    static func vaga(deCaminho caminho: String?) -> (Int, String?)? {
        guard let caminho, caminho.hasPrefix("vagas["), let fecha = caminho.firstIndex(of: "]") else { return nil }
        let miolo = caminho[caminho.index(caminho.startIndex, offsetBy: 6)..<fecha]
        guard let indice = Int(miolo) else { return nil }
        let resto = caminho[caminho.index(after: fecha)...]
        if resto.isEmpty { return (indice, nil) }
        guard resto.hasPrefix(".") else { return nil }
        return (indice, String(resto.dropFirst()))
    }

    private static func campo(deItem nome: String?) -> (campo: CampoDaVagaDaEscala, texto: String)? {
        switch nome {
        case "funcao_id": (.funcao, TextosDaEscala.Erro.funcao)
        case "inicio_em", "fim_em": (.horario, TextosDaEscala.Erro.horario)
        case "valor_centavos": (.valor, TextosDaEscala.Erro.valor)
        case "posicoes": (.pessoas, TextosDaEscala.Erro.pessoas)
        case "responsavel_local": (.responsavel, TextosDaEscala.Erro.responsavel)
        case "modo": (.modo, TextosPublicarVaga.modoIndisponivel)
        case "traje": (.traje, TextosPublicarVaga.campoInvalido)
        case "observacoes": (.observacoes, TextosPublicarVaga.campoInvalido)
        default: nil
        }
    }

    // MARK: Ajudantes

    private func editou(evento campo: CampoDoEventoDaEscala? = nil) {
        if let campo { erros.evento[campo] = nil }
        // A mensagem geral fica até a próxima tentativa de publicar: em AX ela está no alto da rolagem, e tirá-la enquanto a
        // pessoa digita encolheria o conteúdo e deslocaria o campo debaixo do dedo (o campo perdia o foco na segunda letra).
    }

    private func deslocarVagas(de antigo: Date, para novo: Date) {
        let calendario = Self.calendario
        let inicioAntigo = calendario.startOfDay(for: antigo)
        let inicioNovo = calendario.startOfDay(for: novo)
        guard let dias = calendario.dateComponents([.day], from: inicioAntigo, to: inicioNovo).day, dias != 0 else { return }
        vagas = vagas.map { vaga in
            var movida = vaga
            movida.inicio = calendario.date(byAdding: .day, value: dias, to: vaga.inicio) ?? vaga.inicio
            movida.fim = calendario.date(byAdding: .day, value: dias, to: vaga.fim) ?? vaga.fim
            if movida.modo == .selecao, !selecaoDisponivel(movida) { movida.modo = .urgencia }
            return movida
        }
    }

    /// O dia é o de Brasília, em qualquer fuso do aparelho.
    private static var calendario: Calendar {
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = FormatadorFrila.fuso
        return calendario
    }

    private static func vagaVazia(id: UUID, dia: Date) -> VagaDoFormularioDaEscala {
        let calendario = Self.calendario
        let inicio = calendario.date(bySettingHour: 18, minute: 0, second: 0, of: dia) ?? dia
        return VagaDoFormularioDaEscala(
            id: id, funcaoID: nil, inicio: inicio, fim: inicio.addingTimeInterval(5 * 60 * 60), valorTexto: "", pessoas: 1
        )
    }
}

private extension String {
    var nilSeVazio: String? { isEmpty ? nil : self }
}
