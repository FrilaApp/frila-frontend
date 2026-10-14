import FrilaDominio
import SwiftUI

/// Linha de um cartão de turno do MidFi: ícone de 16 pt em texto secundário numa coluna de largura fixa
/// (que cresce com o texto) e o texto ao lado.
struct LinhaDoTurnoComIcone: View {
    @ScaledMetric(relativeTo: .subheadline) private var larguraDoIcone: CGFloat = 20
    let icone: String
    let texto: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.pequeno) {
            Image(systemName: icone)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .frame(width: larguraDoIcone)
                .accessibilityHidden(true)
            Text(verbatim: texto)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Cartão de turno do quadro "MeuTurno" do MidFi: função e casa à esquerda, valor acordado à direita,
/// data e local com ícone, e o estado do turno depois de uma divisória.
public struct CartaoMeuTurno: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let turno: Turno
    private let formatador = FormatadorFrila()

    public init(turno: Turno) {
        self.turno = turno
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.faixa) {
            cabecalho
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                LinhaDoTurnoComIcone(icone: "clock", texto: formatador.intervalo(turno.vaga.periodo))
                LinhaDoTurnoComIcone(icone: "mappin.and.ellipse", texto: turno.vaga.local)
            }
            if turno.cancelado {
                Divider().overlay(FrilaCor.divisoria)
                Label {
                    Text(verbatim: TextosDoProfissional.Turnos.canceladoTitulo)
                } icon: {
                    Image(systemName: "xmark.circle")
                }
                .font(FrilaTipo.meta.weight(.semibold))
                .foregroundStyle(FrilaCor.texto)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var cabecalho: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                funcaoECasa
                valor
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: FrilaEspaco.compacto) {
                funcaoECasa
                Spacer(minLength: FrilaEspaco.pequeno)
                valor
            }
        }
    }

    private var funcaoECasa: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: turno.vaga.funcao)
                .font(FrilaTipo.rotuloDoCampo)
                .foregroundStyle(FrilaCor.texto)
            Text(verbatim: turno.contraparte.nome)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
        }
    }

    private var valor: some View {
        Text(verbatim: formatador.dinheiro(turno.valorAcordado))
            .font(FrilaTipo.preco)
            .monospacedDigit()
            .foregroundStyle(FrilaCor.texto)
    }
}

/// Lista de turnos do profissional (#105), no quadro "MeuTurno" do MidFi do Fabrício. Tocar num cartão abre o turno.
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
                    AvisoFrila(verbatim: TextosDoProfissional.Turnos.avisoCache, tom: .informativo)
                        .accessibilityIdentifier("aviso-cache-turnos")
                }

                conteudo
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(Text(verbatim: TextosDoProfissional.Turnos.tituloMeusTurnos))
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
                    verbatim: TextosDoProfissional.Turnos.vazioTitulo,
                    mensagem: TextosDoProfissional.Turnos.vazioMensagem
                )
                .accessibilityIdentifier("meus-turnos-vazio")
            } else {
                LazyVStack(spacing: FrilaEspaco.compacto) {
                    ForEach(turnos) { turno in
                        Button { abrir(turno) } label: { CartaoMeuTurno(turno: turno) }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.grande, style: .continuous))
                            .accessibilityIdentifier("meu-turno-\(turno.id.uuidString)")
                            .accessibilityHint(String(localized: "Abre o detalhe do turno", bundle: bundleApresentacao))
                    }
                }
            }
        case let .falha(mensagem):
            VStack(spacing: FrilaEspaco.medio) {
                AvisoFrila(verbatim: mensagem, tom: .alerta)
                BotaoSecundario("Tentar novamente") { Task { await viewModel.carregar() } }
            }
            .accessibilityIdentifier("meus-turnos-erro")
        }
    }
}
