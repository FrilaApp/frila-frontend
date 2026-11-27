import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

/// As telas provisórias da busca (F-035.4): o que a folha de chamada pede e a publicação que abre preenchida.
@Suite("Busca de profissionais: telas provisórias")
@MainActor
struct BuscaDeProfissionaisTelasTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let funcaoA = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")
    private let funcaoB = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, nome: "Cozinheiro", categoria: "Cozinha")

    private func casa() throws -> Estabelecimento {
        Estabelecimento(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô", tipo: .foodService,
                        endereco: "Rua das Flores, 10", regiaoAdministrativa: "Águas Claras",
                        ponto: try Coordenada(latitude: -15.78, longitude: -47.93))
    }

    // MARK: Publicar para todos abre preenchida

    @Test("Com rascunho da busca, a publicação abre com o serviço e o horário buscados")
    func publicacaoAbrePreenchida() async throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let fixo = agora
        let vaga = PublicarVagaViewModel(estabelecimento: try casa(), funcoes: [funcaoA, funcaoB], fila: fila, agora: { fixo }) { _ in
            throw ErroDaApi(codigo: .semRede)
        }
        let inicio = agora.addingTimeInterval(30 * 3600)
        let horario = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(5 * 3600))
        vaga.preencher(com: RascunhoDeVagaDaBusca(estabelecimentoID: try casa().id, funcaoID: funcaoB.id, regiaoID: 3, horario: horario))
        #expect(vaga.funcaoID == funcaoB.id)
        #expect(vaga.inicio == horario.inicio)
        #expect(vaga.fim == horario.fim)
        let estudio = FormularioEstudioDeVaga(vaga: vaga, agora: { fixo })
        #expect(estudio.rascunhoInicial.role == "Cozinheiro")
    }

    @Test("Sem rascunho, a publicação abre como sempre: nada preenchido")
    func publicacaoSemRascunhoIgualAHoje() throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let fixo = agora
        let vaga = PublicarVagaViewModel(estabelecimento: try casa(), funcoes: [funcaoA], fila: fila, agora: { fixo }) { _ in
            throw ErroDaApi(codigo: .semRede)
        }
        let inicioAntes = vaga.inicio, fimAntes = vaga.fim
        vaga.preencher(com: nil)
        #expect(vaga.funcaoID == nil)
        #expect(vaga.inicio == inicioAntes)
        #expect(vaga.fim == fimAntes)
    }

    @Test("Rascunho sem horário só preenche o serviço")
    func rascunhoSemHorario() throws {
        let fila = ArmazenamentoSwiftData(modelContainer: try PersistenciaFrila.criarContainer(emMemoria: true))
        let fixo = agora
        let vaga = PublicarVagaViewModel(estabelecimento: try casa(), funcoes: [funcaoA], fila: fila, agora: { fixo }) { _ in
            throw ErroDaApi(codigo: .semRede)
        }
        let inicioAntes = vaga.inicio
        vaga.preencher(com: RascunhoDeVagaDaBusca(estabelecimentoID: try casa().id, funcaoID: funcaoA.id))
        #expect(vaga.funcaoID == funcaoA.id)
        #expect(vaga.inicio == inicioAntes)
    }

    // MARK: Folha de chamada

    @Test("B-124: na folha da busca, o valor fora da faixa só avisa, e o envio segue liberado com o valor digitado", arguments: [
        ("49,99", 4_999, "Valor muito baixo."), ("2000,01", 200_001, "Valor muito alto, confira."),
    ])
    func valorForaDaFaixaNaFolhaSoAvisa(texto: String, centavos: Int, aviso: String) throws {
        let fixo = agora
        let rascunho = RascunhoDaChamadaDaBusca(horario: nil, responsavel: "Bistrô", agora: { fixo })
        #expect(rascunho.avisoDoValor == nil, "sem valor não há aviso novo")
        rascunho.valorTexto = texto
        rascunho.totalConfirmado = true

        #expect(rascunho.avisoDoValor == aviso)
        #expect(rascunho.oQueFalta == nil)
        #expect(rascunho.podeEnviar)
        #expect(try rascunho.trabalho(casa: casa(), funcaoID: funcaoA.id)?.valor.centavos == centavos)
        rascunho.valorTexto = "180"
        #expect(rascunho.avisoDoValor == nil)
    }

    @Test("A folha só deixa enviar com valor, confirmação do total, responsável, 2 h de antecedência e turno de 2 a 16 h")
    func regrasDaFolha() throws {
        let fixo = agora
        let rascunho = RascunhoDaChamadaDaBusca(horario: nil, responsavel: "Bistrô", agora: { fixo })
        #expect(rascunho.oQueFalta == TextosChamadaDireta.faltaValor)
        rascunho.valorTexto = "180"
        #expect(rascunho.valorCentavos == 18_000)
        #expect(rascunho.oQueFalta == TextosChamadaDireta.faltaConfirmarTotal)
        rascunho.totalConfirmado = true
        #expect(rascunho.podeEnviar)
        rascunho.responsavel = "  "
        #expect(rascunho.oQueFalta == TextosChamadaDireta.faltaResponsavel)
        rascunho.responsavel = "Bistrô"
        rascunho.inicio = agora.addingTimeInterval(3600)
        rascunho.fim = rascunho.inicio.addingTimeInterval(4 * 3600)
        #expect(rascunho.oQueFalta == TextosChamadaDireta.faltaAntecedencia)
        rascunho.inicio = agora.addingTimeInterval(5 * 3600)
        rascunho.fim = rascunho.inicio.addingTimeInterval(17 * 3600)
        #expect(rascunho.oQueFalta == TextosChamadaDireta.faltaDuracao)
        rascunho.fim = rascunho.inicio.addingTimeInterval(1 * 3600)
        #expect(rascunho.oQueFalta == TextosChamadaDireta.faltaDuracao)
        rascunho.fim = rascunho.inicio.addingTimeInterval(8 * 3600)
        #expect(rascunho.podeEnviar)
        rascunho.valorTexto = "abc"
        #expect(rascunho.valorCentavos == nil)
        rascunho.valorTexto = "180,50"
        #expect(rascunho.valorCentavos == 18_050)
    }

    @Test("O horário do filtro vira o horário da folha, editável, e o trabalho leva a casa e o serviço buscados")
    func trabalhoDaFolha() throws {
        let fixo = agora
        let inicio = agora.addingTimeInterval(30 * 3600)
        let horario = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(6 * 3600))
        let rascunho = RascunhoDaChamadaDaBusca(horario: horario, responsavel: "Bistrô", agora: { fixo })
        #expect(rascunho.inicio == horario.inicio)
        #expect(rascunho.fim == horario.fim)
        #expect(try rascunho.trabalho(casa: casa(), funcaoID: funcaoA.id) == nil, "sem valor não há trabalho")
        rascunho.valorTexto = "200"
        rascunho.totalConfirmado = true
        rascunho.recado = "Traga o avental"
        let trabalho = try #require(try rascunho.trabalho(casa: casa(), funcaoID: funcaoA.id))
        #expect(trabalho.funcaoID == funcaoA.id)
        #expect(trabalho.estabelecimentoID == (try casa()).id)
        #expect(trabalho.valor.centavos == 20_000)
        #expect(trabalho.periodo == horario)
        #expect(trabalho.responsavelLocal == "Bistrô")
        #expect(trabalho.posicoes == 1)
        #expect(rascunho.recadoOuNada == "Traga o avental")
        rascunho.recado = ""
        #expect(rascunho.recadoOuNada == nil)
    }

    // MARK: Preferências

    @Test("A chave da busca liga a seção Aceito chamadas diretas só quando o servidor liga")
    func chaveDaSecao() async {
        let ligada = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .buscaDeProfissionais))
        #expect(!ligada.buscaHabilitada)
        await ligada.carregar()
        #expect(ligada.buscaHabilitada)
        let desligada = PreferenciasChamadaViewModel(api: ApiClienteEmMemoria(cenario: .chamadaDireta))
        await desligada.carregar()
        #expect(!desligada.buscaHabilitada)
    }

    @Test("Cada pendência tem um texto próprio")
    func textosDasPendencias() {
        let textos = PendenciaParaBusca.allCases.map(TextosBuscaDeProfissionais.pendencia)
        #expect(Set(textos).count == PendenciaParaBusca.allCases.count)
        #expect(textos.allSatisfy { !$0.isEmpty })
    }
}
