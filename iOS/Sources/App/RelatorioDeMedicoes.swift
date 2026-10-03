#if DEBUG || FRILA_MEDICAO
import Foundation
import FrilaDominio
import SwiftUI
import UIKit

/// Botão "Medições" sobre o app (#73): abre o relatório das aberturas e dos bytes, para coletar as
/// medições no aparelho sem Instruments. Só existe no Debug (com `-FRILA_MEDICAO`) e no build de
/// medição; o `conferir-release.sh` reprova o identificador em qualquer outro Release.
struct BotaoDeMedicoes: View {
    @State private var aberto = false

    var body: some View {
        Button {
            aberto = true
        } label: {
            Image(systemName: "stopwatch")
                .font(.body.weight(.semibold))
                .padding(10)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel(Text(verbatim: "Medições"))
        .accessibilityIdentifier("medicoes-abrir")
        .padding(.trailing, 12)
        .padding(.bottom, 72)
        .sheet(isPresented: $aberto) { FolhaDeMedicoes() }
    }
}

/// Textos fixos, sem localização: é uma ferramenta interna de medição, não uma tela do produto.
private struct FolhaDeMedicoes: View {
    @Environment(\.dismiss) private var fechar
    @State private var resumo = RegistroDeMedicoes.compartilhado.resumo()
    @State private var copiado = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(resumo.telas, id: \.tela) { tela in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: tela.tela.rawValue).font(.headline)
                            Text(verbatim: linha(tela)).font(.subheadline.monospacedDigit())
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("medicoes-\(tela.tela)")
                    }
                } header: {
                    Text(verbatim: "Abertura: do toque ao conteúdo da API")
                }
                Section {
                    Text(verbatim: "\(resumo.requisicoes) requisições · \(resumo.bytesTotais) B")
                        .font(.subheadline.monospacedDigit())
                        .accessibilityIdentifier("medicoes-bytes")
                    Text(verbatim: "Enviados \(resumo.bytesEnviados) B · recebidos \(resumo.bytesRecebidos) B")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                } header: {
                    Text(verbatim: "Rede (limite da sessão: 1 MB)")
                }
                Section {
                    Button {
                        UIPasteboard.general.string = resumo.texto
                        copiado = true
                    } label: {
                        Text(verbatim: copiado ? "Copiado" : "Copiar relatório")
                    }
                    .accessibilityIdentifier("medicoes-copiar")
                    // Zerar também esvazia o cache HTTP: a sessão de dados começa com o cache vazio.
                    Button(role: .destructive) {
                        URLCache.shared.removeAllCachedResponses()
                        RegistroDeMedicoes.compartilhado.zerar()
                        resumo = RegistroDeMedicoes.compartilhado.resumo()
                        copiado = false
                    } label: {
                        Text(verbatim: "Zerar")
                    }
                    .accessibilityIdentifier("medicoes-zerar")
                }
            }
            .navigationTitle(Text(verbatim: "Medições"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { fechar() } label: { Text(verbatim: "Fechar") }
                        .accessibilityIdentifier("medicoes-fechar")
                }
            }
        }
        .accessibilityIdentifier("medicoes-relatorio")
    }

    private func linha(_ tela: ResumoDeTela) -> String {
        guard tela.quantidade > 0 else { return "sem medições" }
        return "n=\(tela.quantidade) · p50 \(ResumoDasMedicoes.ms(tela.p50)) · p95 \(ResumoDasMedicoes.ms(tela.p95)) · máx \(ResumoDasMedicoes.ms(tela.maximo))"
    }
}
#endif
