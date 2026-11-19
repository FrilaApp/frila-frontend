import FrilaDominio
import SwiftUI

/// V11 da conferência visual da 1.1: enviada a chamada, a folha mostra o que foi combinado, até quando o
/// profissional responde e o caminho para acompanhar a chamada (CD-RF09), no lugar de um aviso solto.
///
/// Desenho (R6): a confirmação em aviso, o prazo em destaque, o resumo num grupo de linhas (o valor, que é o dinheiro
/// principal, na Prodigy) e o caminho para acompanhar como link. Sem laranja: o botão do envio já ficou para trás.
struct ResumoDaChamadaEnviada: View {
    let chamada: Chamada
    let valorCentavos: Int
    let inicio: Date
    let fim: Date
    let responsavel: String
    /// Sem a API, a folha não abre o Acompanhar (quem a mostra não tem como carregar as chamadas).
    let api: (any ApiCliente)?
    private let formatador = FormatadorFrila()

    init(chamada: Chamada, valorCentavos: Int, inicio: Date, fim: Date, responsavel: String, api: (any ApiCliente)?) {
        self.chamada = chamada
        self.valorCentavos = valorCentavos
        self.inicio = inicio
        self.fim = fim
        self.responsavel = responsavel
        self.api = api
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                AvisoFrila(verbatim: TextosChamadaDireta.sucesso, tom: .informativo)
                Text(verbatim: TextosChamadaDireta.prazoDeResposta(formatador.dataEHora(chamada.expiraEm)))
                    .font(FrilaTipo.nome)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("prazo-chamada-enviada")
            }
            FrilaGrupoDeLinhas(verbatim: TextosChamadaDireta.resumoDaChamada, linhasComIcone: false) {
                // O valor já passou pela RN29 no envio; o `max` só protege o `Dinheiro` de um estado inválido.
                linha(TextosChamadaDireta.valor, formatador.dinheiro(Dinheiro(centavos: max(0, valorCentavos))), destaque: true)
                linha(TextosChamadaDireta.horario,
                      FormatoDeHorarioDoTurno().comDia(inicio: inicio, fim: fim))
                linha(TextosChamadaDireta.responsavel, responsavel.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            if let api {
                NavigationLink {
                    TelaAcompanharChamadas(viewModel: AcompanharChamadasViewModel(vagaID: chamada.vagaID, api: api))
                } label: {
                    Text(verbatim: TextosChamadaDireta.acompanharTitulo)
                }
                .buttonStyle(.frilaLink)
                .accessibilityIdentifier("acompanhar-chamada-enviada")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linha(_ rotulo: String, _ valor: String, destaque: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            Text(verbatim: rotulo)
                .font(FrilaTipo.apoio)
                .foregroundStyle(FrilaCor.textoSecundario)
            Text(verbatim: valor)
                .font(destaque ? FrilaTipo.valorDoRodape : FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, FrilaMedidaDeLinha.margem)
        .padding(.vertical, FrilaEspaco.item)
        .frame(minHeight: FrilaMetrica.alvo, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
