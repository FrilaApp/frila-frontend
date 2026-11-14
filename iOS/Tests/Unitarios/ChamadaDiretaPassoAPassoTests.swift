import Foundation
import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Observation
import SwiftUI
import Testing
import UIKit

/// A casa que chama de novo pelo turno: o servidor só entrega `detalhe_vaga` ao profissional
/// (contratante recebe `422 perfil_incompativel`), então a leitura da vaga anterior é um extra.
private final class ApiDetalheDaVagaSoDoProfissional: ApiClienteEncaminhador, @unchecked Sendable {
    override func detalheDaVaga(id: UUID) async throws -> Vaga {
        throw ErroDaApi(codigo: .perfilIncompativel)
    }
}

/// Guarda o modelo que a tela mostra; trocar o modelo faz o anfitrião avaliar o corpo de novo,
/// como o `FluxoDoProfissional` faz quando o aviso de outra chamada troca a pilha.
@MainActor @Observable
private final class ModeloAtual {
    var atual: ChamadaRecebidaViewModel
    init(_ atual: ChamadaRecebidaViewModel) { self.atual = atual }
}

private struct AnfitriaoDaChamada: View {
    let modelo: ModeloAtual
    var body: some View {
        NavigationStack { TelaDetalheChamadaRecebida(viewModel: modelo.atual) }
    }
}

@Suite("Chamada direta: chamar de novo pelo turno, aviso de chamada nova e motivo da recusa", .serialized)
@MainActor
struct ChamadaDiretaPassoAPassoTests {
    private let profissionalID = UUID(uuidString: "80000000-0000-0000-0000-000000000001")!

    // MARK: - Chamar de novo pelo turno

    @Test("A folha do turno abre mesmo quando o servidor não entrega a vaga anterior a quem é contratante")
    func folhaDoTurnoAbreSemAVagaAnterior() async throws {
        let base = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let api = ApiDetalheDaVagaSoDoProfissional(base: base)
        let casa = try #require(try await base.meusEstabelecimentos().first)
        let dadosDaCasa = try await base.meuEstabelecimento(id: casa.id)
        let vagaDoTurno = UUID()

        let modelo = ChamadaDiretaViewModel(api: api, profissionalID: profissionalID,
                                            estabelecimentoID: casa.id, vagaID: vagaDoTurno)
        await modelo.carregar()

        #expect(modelo.erro == nil, "A folha não pode cair na mensagem de conexão por causa da vaga anterior")
        #expect(modelo.recursoHabilitado)
        #expect(!modelo.funcoes.isEmpty)
        #expect(modelo.funcaoID != nil)
        #expect(modelo.local == dadosDaCasa.endereco, "Sem a vaga anterior, os dados vêm da casa, como na Equipe de confiança")
        #expect(modelo.responsavel == dadosDaCasa.nome)
    }

    // MARK: - Aviso de chamada nova com a anterior ainda na pilha

    /// Uma chamada aberta da casa ao profissional, num servidor em memória só dela.
    private func abrirChamada() async throws -> (ApiClienteEmMemoria, UUID) {
        let api = ApiClienteEmMemoria(cenario: .chamadaDireta)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let perfil = try await api.perfilPublico(id: profissionalID)
        let criador = ChamadaDiretaViewModel(api: api, profissionalID: profissionalID, estabelecimentoID: casa.id)
        await criador.carregar()
        criador.funcaoID = try #require(criador.funcoes.first { perfil.funcoes.contains($0.nome) }).id
        criador.valorCentavos = 18_000
        criador.totalConfirmado = true
        criador.responsavel = "Gerente João"
        await criador.enviar()
        return (api, try #require(criador.resultado).id)
    }

    @Test("Tocar no aviso de uma chamada nova com a anterior aberta na pilha carrega a chamada nova")
    func avisoNovoCarregaAChamadaNova() async throws {
        let (api1, primeira) = try await abrirChamada()
        let (api2, segunda) = try await abrirChamada()
        #expect(primeira != segunda)

        let modelo1 = ChamadaRecebidaViewModel(chamadaID: primeira, api: api1)
        let modelo2 = ChamadaRecebidaViewModel(chamadaID: segunda, api: api2)
        let seletor = ModeloAtual(modelo1)

        let cena = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let raiz = UIHostingController(rootView: AnfitriaoDaChamada(modelo: seletor))
        let janela = UIWindow(windowScene: cena)
        janela.rootViewController = raiz
        janela.isHidden = false
        defer {
            janela.isHidden = true
            janela.rootViewController = nil
        }

        try await esperar { modelo1.detalhe != nil }
        #expect(modelo1.detalhe?.id == primeira)

        // O roteador troca [.chamadaDoAviso(1)] por [.chamadaDoAviso(2)] na mesma posição da pilha.
        seletor.atual = modelo2
        try await esperar { modelo2.detalhe != nil }

        #expect(modelo2.detalhe?.id == segunda,
                "A tela reaproveitou o modelo da chamada anterior e a chamada nova nunca foi carregada")
    }

    private func esperar(_ condicao: @MainActor () -> Bool) async throws {
        for _ in 0..<50 where !condicao() { try await Task.sleep(for: .milliseconds(100)) }
    }

    // MARK: - Motivo da recusa em Acompanhar chamadas

    @Test("O motivo da recusa aparece com o texto que o profissional escolheu, nunca com o código cru")
    func motivoComOTextoCerto() {
        let esperado: [MotivoRecusaChamada: String] = [
            .agenda: TextosChamadaDireta.motivoAgenda,
            .distancia: TextosChamadaDireta.motivoDistancia,
            .valor: TextosChamadaDireta.motivoValor,
            .tipoDeServico: TextosChamadaDireta.motivoTipoDeServico,
            .outro: TextosChamadaDireta.motivoOutro
        ]
        for motivo in MotivoRecusaChamada.allCases {
            let texto = TextosChamadaDireta.motivo(motivo)
            #expect(texto == esperado[motivo], "\(motivo)")
            #expect(texto != motivo.rawValue, "\(motivo) apareceria cru")
        }
    }
}
