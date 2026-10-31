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

/// Cartão de turno do profissional, no mesmo padrão de placa de museu da origem (`CartaoVaga`):
/// casa em caixa alta na `entity` (`FrilaTipo.resumo`), função em `FrilaTipo.tituloDoCartao`,
/// linhas de dados entre dois fios `FrilaCor.divisoria` e valor em `FrilaTipo.preco`.
public struct CartaoMeuTurno: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let turno: Turno
    private let formatador = FormatadorFrila()

    public init(turno: Turno) {
        self.turno = turno
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.compacto) {
            cabecalho
            VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
                LinhaDoTurnoComIcone(icone: "clock", texto: formatador.intervalo(turno.vaga.periodo))
                LinhaDoTurnoComIcone(icone: "mappin", texto: turno.vaga.local)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, FrilaEspaco.pequeno)
            .overlay(alignment: .top) { fio }
            .overlay(alignment: .bottom) { fio }
            if turno.cancelado {
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

    private var fio: some View {
        Rectangle().fill(FrilaCor.divisoria).frame(height: 1).accessibilityHidden(true)
    }

    @ViewBuilder
    private var cabecalho: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                casaEFuncao
                valor
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: FrilaEspaco.compacto) {
                    casaEFuncao
                    Spacer(minLength: FrilaEspaco.pequeno)
                    valor
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    casaEFuncao
                    valor
                }
            }
        }
    }

    private var casaEFuncao: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
            Text(verbatim: turno.contraparte.nome)
                .font(FrilaTipo.resumo)
                .textCase(.uppercase)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityLabel(Text(verbatim: turno.contraparte.nome))
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: turno.vaga.funcao)
                .font(FrilaTipo.tituloDoCartao)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var valor: some View {
        FrilaPriceTag(texto: formatador.dinheiro(turno.valorAcordado),
                      leitura: formatador.dinheiroFalado(turno.valorAcordado), tamanho: 18)
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
                            .contentShape(RoundedRectangle(cornerRadius: FrilaRaio.cartao, style: .continuous))
                            .accessibilityIdentifier("meu-turno-\(turno.id.uuidString)")
                            .accessibilityHint(String(localized: "Abre o detalhe do turno", bundle: bundleApresentacao))
                    }
                }
            }
        case let .falha(mensagem):
            EstadoErro(verbatim: mensagem) {
                Task { await viewModel.carregar() }
            }
            .accessibilityIdentifier("meus-turnos-erro")
        }
    }
}
