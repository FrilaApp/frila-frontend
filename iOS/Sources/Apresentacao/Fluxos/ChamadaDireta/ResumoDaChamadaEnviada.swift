import FrilaDominio
import SwiftUI

/// V11 da conferência visual da 1.1: enviada a chamada, a folha mostra o que foi combinado, até quando o
/// profissional responde e o caminho para acompanhar a chamada (CD-RF09), no lugar de um aviso solto.
struct ResumoDaChamadaEnviada: View {
    let chamada: Chamada
    let valorCentavos: Int
    let inicio: Date
    let fim: Date
    let responsavel: String
    /// Sem a API, a folha não abre o Acompanhar (quem a mostra não tem como carregar as chamadas).
    let api: (any ApiCliente)?
    private let formatador = FormatadorFrila()

    var body: some View {
        Section {
            AvisoFrila(verbatim: TextosChamadaDireta.sucesso, tom: .informativo)
            Text(verbatim: TextosChamadaDireta.prazoDeResposta(formatador.dataEHora(chamada.expiraEm)))
                .font(FrilaTipo.resumo)
                .foregroundStyle(FrilaCor.alerta)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("prazo-chamada-enviada")
        }
        Section(TextosChamadaDireta.resumoDaChamada) {
            // O valor já passou pela RN29 no envio; o `max` só protege o `Dinheiro` de um estado inválido.
            linha(TextosChamadaDireta.valor, formatador.dinheiro(Dinheiro(centavos: max(0, valorCentavos))))
            linha(TextosChamadaDireta.horario,
                  TextosChamadaDireta.intervalo(inicio: formatador.dataEHora(inicio), fim: formatador.hora(fim)))
            linha(TextosChamadaDireta.responsavel, responsavel.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        .accessibilityIdentifier("resumo-chamada-enviada")
        if let api {
            Section {
                NavigationLink {
                    TelaAcompanharChamadas(viewModel: AcompanharChamadasViewModel(vagaID: chamada.vagaID, api: api))
                } label: {
                    RotuloDeLinha(TextosChamadaDireta.acompanharTitulo)
                }
                .accessibilityIdentifier("acompanhar-chamada-enviada")
            }
        }
    }

    private func linha(_ rotulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: rotulo)
                .font(FrilaTipo.nota)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
