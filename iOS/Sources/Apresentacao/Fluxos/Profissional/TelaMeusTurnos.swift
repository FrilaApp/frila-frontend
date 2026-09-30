import FrilaDominio
import SwiftUI

public struct CartaoMeuTurno: View {
    private let turno: Turno
    private let formatador = FormatadorFrila()

    public init(turno: Turno) {
        self.turno = turno
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            HStack(alignment: .firstTextBaseline) {
                Text(turno.vaga.funcao).font(.headline)
                Spacer()
                Text(formatador.dinheiro(turno.valorAcordado))
                    .font(.headline)
                    .foregroundStyle(FrilaCor.primaria)
            }
            Text(turno.contraparte.nome)
                .font(.subheadline)
                .foregroundStyle(FrilaCor.textoSecundario)
            Label(formatador.intervalo(turno.vaga.periodo), systemImage: "calendar")
            Label(turno.vaga.local, systemImage: "mappin.and.ellipse")
        }
        .font(.subheadline)
        .foregroundStyle(FrilaCor.texto)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }
}

public struct TelaMeusTurnos: View {
    @Bindable private var viewModel: MeusTurnosViewModel
    private let abrir: (Turno) -> Void

    public init(viewModel: MeusTurnosViewModel, abrir: @escaping (Turno) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if case let .carregada(_, origem) = viewModel.estado, origem == .cache {
                    AvisoFrila(LocalizedStringKey(TextosDoProfissional.Turnos.avisoCache), tom: .informativo)
                        .accessibilityIdentifier("aviso-cache-turnos")
                }

                conteudo
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosDoProfissional.Turnos.tituloMeusTurnos)
        .refreshable { await viewModel.atualizar() }
        .task { if viewModel.estado == .ociosa { await viewModel.carregar() } }
        .accessibilityIdentifier("tela-meus-turnos")
    }

    @ViewBuilder
    private var conteudo: some View {
        switch viewModel.estado {
        case .ociosa, .carregando:
            EstadoCarregando()
        case let .carregada(turnos, _):
            if turnos.isEmpty {
                EstadoVazio(
                    LocalizedStringKey(TextosDoProfissional.Turnos.vazioTitulo),
                    mensagem: LocalizedStringKey(TextosDoProfissional.Turnos.vazioMensagem)
                )
                .accessibilityIdentifier("meus-turnos-vazio")
            } else {
                LazyVStack(spacing: FrilaEspaco.medio) {
                    ForEach(turnos) { turno in
                        Button { abrir(turno) } label: { CartaoMeuTurno(turno: turno) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("meu-turno-\(turno.id.uuidString)")
                            .accessibilityHint("Abre o detalhe do turno")
                    }
                }
            }
        case let .falha(mensagem):
            VStack(spacing: FrilaEspaco.medio) {
                AvisoFrila(LocalizedStringKey(mensagem), tom: .alerta)
                BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
            }
            .accessibilityIdentifier("meus-turnos-erro")
        }
    }
}
