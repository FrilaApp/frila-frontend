import FrilaDominio
import SwiftUI

public struct EnderecoPontoBase: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let logradouro: String
    public let bairro: String

    public init(id: UUID = UUID(), logradouro: String, bairro: String) {
        self.id = id
        self.logradouro = logradouro
        self.bairro = bairro
    }

    public static let padroes: [EnderecoPontoBase] = [
        EnderecoPontoBase(id: UUID(uuidString: "11111111-0000-0000-0000-000000000001")!, logradouro: "SQS 308, Bloco A", bairro: "Asa Sul"),
        EnderecoPontoBase(id: UUID(uuidString: "11111111-0000-0000-0000-000000000002")!, logradouro: "SQS 308, Bloco B", bairro: "Asa Sul"),
        EnderecoPontoBase(id: UUID(uuidString: "11111111-0000-0000-0000-000000000003")!, logradouro: "SQS 308, Bloco C", bairro: "Asa Sul"),
        EnderecoPontoBase(id: UUID(uuidString: "11111111-0000-0000-0000-000000000004")!, logradouro: "SQS 308, Bloco D", bairro: "Asa Sul")
    ]
}

/// T1c · Escolher o ponto base (#104).
/// Sheet nativa onde o profissional busca e escolhe seu endereço de referência.
public struct TelaEscolhaPontoBase: View {
    @Environment(\.dismiss) private var dismiss
    @State private var busca: String
    @State private var selecionadoID: UUID?
    @State private var avisoAcessibilidade: String = ""
    private let enderecos: [EnderecoPontoBase]
    private let aoSelecionar: ((EnderecoPontoBase) -> Void)?
    private let aoConcluir: (() -> Void)?

    public init(
        buscaInicial: String = "SQS 308",
        selecionadoID: UUID? = UUID(uuidString: "11111111-0000-0000-0000-000000000003"),
        enderecos: [EnderecoPontoBase] = EnderecoPontoBase.padroes,
        aoSelecionar: ((EnderecoPontoBase) -> Void)? = nil,
        aoConcluir: (() -> Void)? = nil
    ) {
        _busca = State(initialValue: buscaInicial)
        _selecionadoID = State(initialValue: selecionadoID)
        self.enderecos = enderecos
        self.aoSelecionar = aoSelecionar
        self.aoConcluir = aoConcluir
    }

    private var enderecosFiltrados: [EnderecoPontoBase] {
        let termo = busca.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if termo.isEmpty {
            return enderecos
        }
        return enderecos.filter {
            $0.logradouro.lowercased().contains(termo) || $0.bairro.lowercased().contains(termo)
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                cabecalhoETopo
                    .padding(.horizontal, FrilaEspaco.medio)
                    .padding(.top, FrilaEspaco.compacto)

                if enderecosFiltrados.isEmpty {
                    estadoVazio
                        .padding(.horizontal, FrilaEspaco.medio)
                        .padding(.top, FrilaEspaco.grande)
                    Spacer()
                } else {
                    listaDeEnderecos
                }
            }
            .background(FrilaCor.fundo.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        aoConcluir?()
                        dismiss()
                    } label: {
                        Text(verbatim: TextosLote4.concluir)
                            .font(FrilaTipo.corpo.weight(.semibold))
                            .foregroundStyle(FrilaCor.texto)
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .accessibilityIdentifier("ponto-base-concluir")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tela-escolha-ponto-base")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var cabecalhoETopo: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosLote4.pontoBase)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: TextosLote4.pontoBaseApoio)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .padding(.bottom, FrilaEspaco.compacto)

            campoDeBusca
        }
    }

    private var campoDeBusca: some View {
        HStack(spacing: FrilaEspaco.pequeno) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FrilaCor.textoSecundario)
                .font(FrilaTipo.corpo)
                .accessibilityHidden(true)

            TextField(
                text: $busca,
                prompt: Text(verbatim: TextosLote4.buscarEndereco).foregroundStyle(FrilaCor.textoSecundario)
            ) {
                Text(verbatim: TextosLote4.buscarEndereco)
            }
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("ponto-base-campo-busca")

            if !busca.isEmpty {
                Button {
                    busca = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: TextosLote4.limparBusca))
                .accessibilityIdentifier("ponto-base-limpar-busca")
            }
        }
        .padding(.horizontal, FrilaEspaco.compacto)
        .frame(minHeight: FrilaMetrica.alvoMinimo)
        .background(FrilaCor.superficieDoCampo, in: RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FrilaRaio.entrada, style: .continuous)
                .strokeBorder(FrilaCor.bordaDoCampo, lineWidth: 1)
        )
    }

    private var listaDeEnderecos: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(enderecosFiltrados) { endereco in
                    linhaDeEndereco(endereco)
                    if endereco.id != enderecosFiltrados.last?.id {
                        Rectangle()
                            .fill(FrilaCor.divisoria)
                            .frame(height: 1)
                            .padding(.leading, FrilaEspaco.medio + 24)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.top, FrilaEspaco.pequeno)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lista-enderecos-ponto-base")
    }

    private func linhaDeEndereco(_ endereco: EnderecoPontoBase) -> some View {
        let selecionado = selecionadoID == endereco.id
        return Button {
            selecionadoID = endereco.id
            aoSelecionar?(endereco)
            avisoAcessibilidade = TextosLote4.salvo
            UIAccessibility.post(notification: .announcement, argument: TextosLote4.salvo)
        } label: {
            HStack(spacing: FrilaEspaco.compacto) {
                Image(systemName: "mappin")
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                    Text(verbatim: endereco.logradouro)
                        .font(FrilaTipo.corpo)
                        .foregroundStyle(FrilaCor.texto)

                    Text(verbatim: endereco.bairro)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                }

                Spacer(minLength: 0)

                if selecionado {
                    Image(systemName: "checkmark")
                        .font(FrilaTipo.corpo.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, FrilaEspaco.medio)
            .padding(.vertical, FrilaEspaco.compacto)
            .frame(minHeight: FrilaMetrica.alvoMinimo)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selecionado ? [.isSelected] : [])
        .accessibilityLabel(Text(verbatim: "\(endereco.logradouro), \(endereco.bairro)"))
        .accessibilityIdentifier("endereco-\(endereco.id)")
    }

    private var estadoVazio: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosLote4.buscaSemResultado(busca))
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: TextosLote4.dicaBuscaSemResultado)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ponto-base-sem-resultado")
    }
}
