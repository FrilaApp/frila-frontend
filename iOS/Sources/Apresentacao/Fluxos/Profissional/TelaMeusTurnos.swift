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

/// Cartão de turno do profissional (T7 do protótipo, "Card de vaga" sem a ação): o selo da etapa, a casa e a função,
/// as linhas de dado (quando e onde) e o valor. Tocar abre o turno; o cartão não leva botão.
public struct CartaoMeuTurno: View {
    @Environment(\.dynamicTypeSize) private var tamanhoDoTexto
    private let turno: Turno
    private let formatador = FormatadorFrila()

    public init(turno: Turno) {
        self.turno = turno
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            selo
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text(verbatim: turno.contraparte.nome)
                    .font(FrilaTipo.nome)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: turno.vaga.funcao)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                FrilaLinhaDeDado(icone: "clock") { Text(verbatim: formatador.intervalo(turno.vaga.periodo)) }
                FrilaLinhaDeDado(icone: "mappin") { Text(verbatim: turno.vaga.local) }
            }
            FrilaPriceTag(texto: formatador.dinheiro(turno.valorAcordado),
                          leitura: formatador.dinheiroFalado(turno.valorAcordado), tamanho: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .combine)
    }

    /// O status do turno vem no selo: cancelado, não verificado ou a etapa em que ele está.
    @ViewBuilder
    private var selo: some View {
        if turno.cancelado {
            SeloDeStatus(verbatim: TextosDoProfissional.Turnos.canceladoTitulo, estilo: .encerrado)
                .seloSemQuebrarPalavra(tamanhoDoTexto)
        } else if turno.verificacao == .naoVerificado {
            SeloDeStatus(verbatim: TextosDoProfissional.Turnos.naoVerificadoTitulo, estilo: .contorno)
                .seloSemQuebrarPalavra(tamanhoDoTexto)
        } else {
            let etapa = EtapaDoTurno.atual(aCaminho: turno.aCaminhoEm != nil, presenca: turno.checkin != nil,
                                           concluido: turno.checkout != nil)
            let dados = etapa.selo
            SeloDeStatus(verbatim: dados.titulo, estilo: dados.estilo, icone: tamanhoDoTexto.isAccessibilitySize ? nil : dados.icone)
                .seloSemQuebrarPalavra(tamanhoDoTexto)
        }
    }
}

/// O nome da tela de uma raiz de aba, sem título de página repetindo a aba (D-DS-14): a barra fica vazia, e o nome
/// continua existindo para o leitor de tela e para quem procura a barra pelo nome.
private struct NomeDaTelaSoParaOLeitorDeTela: ViewModifier {
    let nome: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(Text(verbatim: nome))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(verbatim: nome)
                        .opacity(0)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

/// Lista de turnos do profissional (#105; T7 do protótipo). Tocar num cartão abre o turno. A raiz abre sem título
/// de página: o primeiro elemento é o conteúdo. Sem o agrupamento Hoje, Próximos e Histórico do protótipo: ele pede
/// regra de dia e faturado que a lista não tem.
public struct TelaMeusTurnos: View {
    @Bindable private var viewModel: MeusTurnosViewModel
    private let abrir: (Turno) -> Void

    public init(viewModel: MeusTurnosViewModel, abrir: @escaping (Turno) -> Void) {
        self.viewModel = viewModel
        self.abrir = abrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
                if case let .carregada(_, origem) = viewModel.estado, origem == .cache {
                    AvisoFrila(verbatim: TextosDoProfissional.Turnos.avisoCache, tom: .informativo)
                        .accessibilityIdentifier("aviso-cache-turnos")
                }

                conteudo
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.bloco)
            .padding(.bottom, FrilaEspaco.grupo)
        }
        .background(FrilaCor.fundo)
        .modifier(NomeDaTelaSoParaOLeitorDeTela(nome: TextosDoProfissional.Turnos.tituloMeusTurnos))
        .refreshable { await viewModel.atualizar() }
        .task { if viewModel.estado == .ociosa { await viewModel.carregar() } }
        .atualizacaoAutomatica(.meusTurnos, recarregar: viewModel.atualizarEmSilencio)
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
                LazyVStack(spacing: FrilaEspaco.bloco) {
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
