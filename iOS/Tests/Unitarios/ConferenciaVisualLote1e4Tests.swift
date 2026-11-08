import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

/// Lotes 1 e 4 da conferência visual da 1.1 (V7, V8, V13, V14, V15, V20, V23 e V24).
@Suite("Conferência visual da 1.1: lotes 1 e 4")
@MainActor
struct ConferenciaVisualLote1e4Tests {
    private let profissionalID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

    private func chamada() async throws -> (ApiClienteEmMemoria, ChamadaDiretaViewModel) {
        let api = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let perfil = try await api.perfilPublico(id: profissionalID)
        let model = ChamadaDiretaViewModel(api: api, profissionalID: profissionalID, estabelecimentoID: casa.id)
        await model.carregar()
        model.funcaoID = try #require(model.funcoes.first { perfil.funcoes.contains($0.nome) }).id
        return (api, model)
    }

    // MARK: V8: valor em reais, e não em centavos

    @Test("V8: digitar 180 vale R$ 180,00; 180,5 vale R$ 180,50; a vírgula no fim ainda vale 180")
    func valorEmReais() async throws {
        let (_, model) = try await chamada()
        model.valorTexto = "180"
        #expect(model.valorCentavos == 18_000)
        model.valorTexto = "180,"
        #expect(model.valorCentavos == 18_000)
        model.valorTexto = "180,5"
        #expect(model.valorCentavos == 18_050)
        model.valorTexto = ""
        #expect(model.valorCentavos == 0)
    }

    @Test("V8 e RN29: o campo só guarda algarismos e uma vírgula; '-500' vira 500, nunca negativo")
    func valorDigitadoSoAceitaAlgarismos() async throws {
        #expect(ChamadaDiretaViewModel.valorDigitado("-500") == "500")
        #expect(ChamadaDiretaViewModel.valorDigitado("R$ 1.234,567") == "1234,56")
        #expect(ChamadaDiretaViewModel.valorDigitado("12,3,4") == "12,34")
        #expect(ChamadaDiretaViewModel.valorDigitado(",5") == "0,5")
        #expect(ChamadaDiretaViewModel.valorDigitado("1234567") == "12345")
        #expect(ChamadaDiretaViewModel.valorDigitado("abc") == "")
        let (_, model) = try await chamada()
        model.valorTexto = ChamadaDiretaViewModel.valorDigitado("-500")
        #expect(model.valorCentavos == 50_000)
        // Mesmo um texto que não passou pela máscara não deixa o valor negativo.
        model.valorTexto = "-500"
        #expect(model.valorCentavos == 0)
    }

    @Test("Valor colado com ponto de milhar: 'R$ 1.500,00' vale R$ 1.500,00, e não R$ 1,50")
    func valorColadoComPontoDeMilhar() async throws {
        // Com vírgula, o ponto é separador de milhar.
        #expect(ChamadaDiretaViewModel.valorDigitado("R$ 1.500,00") == "1500,00")
        #expect(ChamadaDiretaViewModel.valorDigitado("1.500,5") == "1500,5")
        #expect(ChamadaDiretaViewModel.valorDigitado("12.345,67") == "12345,67")
        // Sem vírgula, o ponto só é milhar quando separa grupos de três algarismos.
        #expect(ChamadaDiretaViewModel.valorDigitado("1.500") == "1500")
        #expect(ChamadaDiretaViewModel.valorDigitado("12.345") == "12345")
        // Fora disso, o ponto continua sendo a vírgula decimal (teclado em outro idioma).
        #expect(ChamadaDiretaViewModel.valorDigitado("1.50") == "1,50")
        #expect(ChamadaDiretaViewModel.valorDigitado("1.5") == "1,5")
        #expect(ChamadaDiretaViewModel.valorDigitado("180.") == "180,")
        let (_, model) = try await chamada()
        model.valorTexto = ChamadaDiretaViewModel.valorDigitado("R$ 1.500,00")
        #expect(model.valorCentavos == 150_000)
    }

    @Test("V8: o valor que vem da vaga aparece em reais no campo")
    func textoEmReais() {
        #expect(ChamadaDiretaViewModel.textoEmReais(18_000) == "180")
        #expect(ChamadaDiretaViewModel.textoEmReais(18_050) == "180,50")
        #expect(ChamadaDiretaViewModel.textoEmReais(5) == "0,05")
    }

    @Test("V8: o total digitado em reais chega ao pedido em centavos")
    func pedidoEmCentavos() async throws {
        let (api, model) = try await chamada()
        model.valorTexto = "250,75"
        model.totalConfirmado = true
        await model.enviar()
        let pedido = try #require(await api.pedidosChamadaRecebidos.first)
        #expect(pedido.trabalho.valor.centavos == 25_075)
    }

    // MARK: V7: o botão desligado diz o que falta

    @Test("V7: sem valor, sem confirmar o total ou sem responsável, a tela diz o que falta; completo, não diz nada")
    func oQueFalta() async throws {
        let (_, model) = try await chamada()
        #expect(model.oQueFalta == TextosChamadaDireta.faltaValor)
        model.valorTexto = "180"
        #expect(model.oQueFalta == TextosChamadaDireta.faltaConfirmarTotal)
        model.totalConfirmado = true
        model.responsavel = "  "
        #expect(model.oQueFalta == TextosChamadaDireta.faltaResponsavel)
        model.responsavel = "Bistrô Ipê"
        model.fim = model.inicio.addingTimeInterval(3600)
        #expect(model.oQueFalta == TextosChamadaDireta.faltaDuracao)
        model.fim = model.inicio.addingTimeInterval(4 * 3600)
        #expect(model.oQueFalta == nil)
        #expect(model.podeEnviar)
        model.inicio = Date().addingTimeInterval(3600)
        model.fim = model.inicio.addingTimeInterval(4 * 3600)
        #expect(model.oQueFalta == TextosChamadaDireta.faltaAntecedencia)
        #expect(!model.podeEnviar)
    }

    // MARK: V10: horários que dá para escolher

    @Test("V10: o início mais cedo é agora + 2 h, e o término fica de 2 a 16 h depois do início")
    func horariosDaChamada() async throws {
        let agora = Date(timeIntervalSince1970: 1_800_000_000)
        let api = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let model = ChamadaDiretaViewModel(api: api, profissionalID: profissionalID, estabelecimentoID: casa.id,
                                           agora: { agora })
        #expect(model.inicioMinimo == agora.addingTimeInterval(2 * 3600))
        #expect(model.inicio >= model.inicioMinimo, "o padrão é amanhã, nunca agora")
        #expect(model.faixaDoTermino.lowerBound == model.inicio.addingTimeInterval(2 * 3600))
        #expect(model.faixaDoTermino.upperBound == model.inicio.addingTimeInterval(16 * 3600))
    }

    @Test("V10: mudar o início leva o término junto, com a mesma duração, sempre de 2 a 16 h")
    func terminoAcompanhaOInicio() async throws {
        let (_, model) = try await chamada()
        model.fim = model.inicio.addingTimeInterval(5 * 3600)
        model.inicio = model.inicio.addingTimeInterval(3 * 3600)
        #expect(model.fim.timeIntervalSince(model.inicio) == 5 * 3600)
        model.fim = model.inicio.addingTimeInterval(30 * 3600)
        model.inicio = model.inicio.addingTimeInterval(60)
        #expect(model.fim.timeIntervalSince(model.inicio) == 16 * 3600)
    }

    // MARK: V13 e V14: texto neutro e sem repetir

    @Test("V13: nenhum texto da escolha concorda o gênero com o nome da pessoa")
    func escolhaNeutra() {
        let textos = [
            TextosDosCandidatos.avisoDaEscolha, TextosDosCandidatos.avisoDaUltimaPosicao,
            TextosDosCandidatos.confirmado, TextosDosCandidatos.confirmadoEVagaPreenchida,
            TextosDosCandidatos.turnoSobreposto,
        ].map { String(format: $0, "Carla Menezes") }
        for texto in textos {
            #expect(!texto.contains("Carla Menezes será confirmado"), "\(texto)")
            #expect(!texto.contains("Carla Menezes foi confirmado"), "\(texto)")
        }
        #expect(TextosDoProfissional.Candidatura.confirmadoTitulo == "Turno confirmado")
        #expect(TextosDoProfissional.Turnos.confirmadoTitulo == "Turno confirmado")
    }

    @Test("V14: o resultado da escolha não repete o 'vaga preenchida' do aviso de seleção concluída")
    func semAvisoRepetido() {
        let resultado = TextosDosCandidatos.resultado(.confirmado(nome: "Carla Menezes", vagaPreenchida: true))
        #expect(resultado == "Você confirmou Carla Menezes. Os outros candidatos foram avisados.")
        #expect(!resultado.contains("preenchida"))
    }

    // MARK: V15: "por diária"

    @Test("V15: a diária diz 'por diária de 8 h'")
    func porDiaria() throws {
        let servico = ServicoOferecido(funcaoID: UUID(), unidade: .diaria, valorCentavos: 18_000, horasIncluidas: 8)
        let resumo = try #require(TextosDosServicos.resumoDoServico(servico))
        #expect(resumo.hasSuffix("por diária de 8 h"), "\(resumo)")
    }

    // MARK: V20: telefone com máscara

    @Test("V20: o telefone brasileiro aparece com máscara; outro formato aparece como veio")
    func telefone() {
        #expect(FormatoDeTelefone.paraExibir("+5561988887777") == "(61) 98888-7777")
        #expect(FormatoDeTelefone.paraExibir("+556133334444") == "(61) 3333-4444")
        #expect(FormatoDeTelefone.paraExibir("+351912345678") == "+351912345678")
        #expect(FormatoDeTelefone.paraExibir("") == "")
    }

    // MARK: V24: o contador do relato

    @Test("V24: o contador vai até 10/10 e não passa disso")
    func contadorDoRelato() {
        #expect(TelaPorQueReceboVagas.contador("abc") == "3/10")
        #expect(TelaPorQueReceboVagas.contador("  abc  ") == "3/10")
        #expect(TelaPorQueReceboVagas.contador(String(repeating: "a", count: 40)) == "10/10")
    }
}
