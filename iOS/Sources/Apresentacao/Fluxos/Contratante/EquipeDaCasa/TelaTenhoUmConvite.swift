import FrilaDominio
import SwiftUI

/// "Tenho um convite": quem recebeu o link da casa cola aqui o link ou o código e entra na equipe (`aceitar_convite_membro`).
/// O app não abre o link sozinho (sem deep link): a tela explica o colar numa frase só. O botão e a mensagem da recusa ficam no
/// rodapé ancorado (D-DS-09). Depois do aceite, "Abrir a casa" leva a pessoa para a casa em que ela entrou.
public struct TelaTenhoUmConvite: View {
    @State private var modelo: TenhoUmConviteViewModel
    @FocusState private var campoEmFoco: Bool
    private let aoAceitar: () -> Void
    private let aoAbrirCasa: (UUID) -> Void

    public init(modelo: TenhoUmConviteViewModel, aoAceitar: @escaping () -> Void = {}, aoAbrirCasa: @escaping (UUID) -> Void = { _ in }) {
        _modelo = State(initialValue: modelo)
        self.aoAceitar = aoAceitar
        self.aoAbrirCasa = aoAbrirCasa
    }

    public var body: some View {
        Group {
            if let aceito = modelo.aceito {
                confirmacao(aceito)
            } else {
                formulario
            }
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(Text(verbatim: TextosDaEquipeDaCasa.conviteTitulo))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: modelo.aceito) { _, novo in
            if novo != nil { aoAceitar() }
        }
        .accessibilityIdentifier("tela-tenho-um-convite")
    }

    // MARK: Formulário

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                    Text(verbatim: TextosDaEquipeDaCasa.conviteTitulo)
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: TextosDaEquipeDaCasa.conviteExplicacao)
                        .font(FrilaTipo.meta)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("convite-explicacao")
                }
                VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                    Text(verbatim: TextosDaEquipeDaCasa.conviteCampo)
                        .font(FrilaTipo.rotuloDoCampo)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                    CampoFrila(verbatim: TextosDaEquipeDaCasa.conviteExemplo, texto: $modelo.texto, emFoco: campoEmFoco)
                        .accessibilityLabel(Text(verbatim: TextosDaEquipeDaCasa.conviteCampo))
                        .focused($campoEmFoco)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { Task { await modelo.aceitarConvite() } }
                        .disabled(modelo.enviando)
                        .accessibilityIdentifier("convite-campo")
                }
            }
            .padding(.horizontal, FrilaEspaco.bloco)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.horizontal)
        }
        .scrollDismissesKeyboard(.interactively)
        .rodapeAncorado {
            if let erro = modelo.erro {
                MensagemJuntoAoBotao(verbatim: erro)
                    .accessibilityIdentifier("convite-erro")
            }
            BotaoPrimario(verbatim: modelo.enviando ? TextosDaEquipeDaCasa.conviteAceitando : TextosDaEquipeDaCasa.conviteAceitar,
                          carregando: modelo.enviando) {
                campoEmFoco = false
                Task { await modelo.aceitarConvite() }
            }
            .accessibilityIdentifier("convite-aceitar")
        }
    }

    // MARK: Convite aceito

    private func confirmacao(_ aceito: ConviteAceito) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                Text(verbatim: TextosDaEquipeDaCasa.conviteAceitoTitulo)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("convite-aceito")
                Text(verbatim: aceito.papel.map { String(format: TextosDaEquipeDaCasa.conviteAceito, $0.rotuloDaEquipe.lowercased()) }
                        ?? TextosDaEquipeDaCasa.conviteAceitoSemPapel)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(FrilaEspaco.bloco)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .rodapeAncorado {
            if let casa = aceito.estabelecimentoID {
                BotaoPrimario(verbatim: TextosDaEquipeDaCasa.conviteAbrirCasa) { aoAbrirCasa(casa) }
                    .accessibilityIdentifier("convite-abrir-casa")
            }
        }
    }
}
