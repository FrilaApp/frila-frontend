import Foundation
import FrilaDados
import FrilaDominio
@testable import FrilaApresentacao
import SwiftUI
import Testing
import UIKit

@Suite("LOG-017: composição dos cartões")
struct ComposicaoCartaoVagaTests {
    @Test("Mede três alturas e captura a lista de cenários nos dois temas")
    @MainActor
    func alturasECapturas() async throws {
        let api = ApiClienteEmMemoria()
        let base = try #require(try await api.vagasAbertas(.todas).first)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let agora = cal.startOfDay(for: .now)
        func amostra(dias: Int, cruza: Bool = false, longa: Bool = false, selecao: Bool = false, proxima: Bool = false) throws -> VagaNaLista {
            let dia = cal.date(byAdding: .day, value: dias, to: agora)!
            let inicio = proxima ? agora.addingTimeInterval(23 * 3600)
                : cal.date(bySettingHour: 20, minute: 18, second: 0, of: dia)!
            let casa = PerfilPublico(id: base.estabelecimento.id, tipo: base.estabelecimento.tipo,
                                    nome: longa ? "Restaurante e eventos do estabelecimento sintético" : base.estabelecimento.nome,
                                    reputacao: base.estabelecimento.reputacao)
            return VagaNaLista(id: UUID(),
                funcao: longa ? Funcao(id: base.funcao.id, nome: "Atendimento de salão e apoio em eventos", categoria: base.funcao.categoria) : base.funcao,
                estabelecimento: casa, periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(cruza ? 4 * 3600 : 2 * 3600)),
                local: base.local, regiaoAdministrativa: base.regiaoAdministrativa, distanciaKm: base.distanciaKm,
                valor: base.valor, posicoesAbertas: 2, inclusos: base.inclusos, modo: selecao ? .selecao : .urgencia)
        }
        let curto = try amostra(dias: 0)
        let longo = try amostra(dias: 1, longa: true)
        let cruza = try amostra(dias: 1, cruza: true)
        var alturas: [CGFloat] = []
        for (nome, vaga) in [("curto", curto), ("nome-longo", longo), ("cruza-dia", cruza)] {
            let host = UIHostingController(rootView: CartaoVaga(vaga).frame(width: 370))
            let altura = host.sizeThatFits(in: CGSize(width: 370, height: 2000)).height
            #expect(altura.isFinite && altura > 0)
            alturas.append(altura)
            print("LOG-017 altura \(nome): \(altura) pt, largura 370 pt")
        }
        #expect(alturas[1] > alturas[0], "O nome longo cresce sem cortar a placa")
        #expect(alturas[2] >= alturas[0], "A janela com dia do fim pode crescer")
        let rotulo = CartaoVaga(curto).rotuloDeAcessibilidade
        #expect(rotulo.contains("Hoje, "))
        #expect(rotulo.contains("confirmação imediata se elegível"))
        #expect(!rotulo.contains("·"))
        let vagas = [curto, longo, try amostra(dias: 8), cruza,
                     try amostra(dias: 2, selecao: true), try amostra(dias: 1, selecao: true, proxima: true)]
        for escuro in [false, true] {
            let conteudo = VStack(spacing: 16) {
                ForEach(vagas) { CartaoVaga($0) }
            }
            .padding(16).frame(width: 402).background(FrilaCor.fundo)
            .environment(\.colorScheme, escuro ? .dark : .light)
            let renderizador = ImageRenderer(content: conteudo)
            renderizador.scale = 2
            let imagem = try #require(renderizador.uiImage)
            let destino = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("LOG-017-lista-\(escuro ? "escuro" : "claro").png")
            try #require(imagem.pngData()).write(to: destino)
            print("LOG-017 captura: \(destino.path)")
        }
    }
}
