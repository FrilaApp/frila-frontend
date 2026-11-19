import FrilaDominio
import SwiftUI

extension PapelMembro {
    /// O papel como a equipe da casa o mostra ("Administrador", "Operador").
    var rotuloDaEquipe: String {
        switch self {
        case .administrador: TextosDaEquipeDaCasa.papelAdministrador
        case .operador: TextosDaEquipeDaCasa.papelOperador
        }
    }
}

/// Equipe da casa (RF21, US24): quem faz parte, convidar por link, remover e tornar administrador. Só o administrador chega
/// aqui pela Conta e só ele vê a lista e as ações; o servidor continua sendo a regra (um 403 tira as ações da tela). No sistema
/// do Fabrício: grupo de linhas para as pessoas, campo e botão primário para o convite, e a folha de confirmação das ações.
public struct TelaEquipeDaCasa: View {
    @State private var modelo: EquipeDaCasaViewModel
    @FocusState private var emailEmFoco: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let aoPerderAdministracao: () -> Void
    private let formatador = FormatadorFrila()

    public init(modelo: EquipeDaCasaViewModel, aoPerderAdministracao: @escaping () -> Void = {}) {
        _modelo = State(initialValue: modelo)
        self.aoPerderAdministracao = aoPerderAdministracao
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                cabecalho
                if let mensagem = modelo.erroDaAcao ?? modelo.aviso {
                    MensagemJuntoAoBotao(verbatim: mensagem)
                        .accessibilityIdentifier("equipe-mensagem")
                }
                listaDaEquipe
                if modelo.podeGerenciar { secaoDoConvite }
            }
            .padding(.horizontal, FrilaEspaco.bloco)
            .padding(.top, FrilaEspaco.item)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.horizontal)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FrilaCor.fundo.ignoresSafeArea())
        .navigationTitle(Text(verbatim: TextosDaEquipeDaCasa.titulo))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: Binding(get: { modelo.pendente != nil }, set: { if !$0 { modelo.cancelarConfirmacao() } })) {
            folhaDeConfirmacao
        }
        .task { await modelo.carregar() }
        .onChange(of: modelo.podeGerenciar) { _, pode in
            if !pode { aoPerderAdministracao() }
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
            Text(verbatim: TextosDaEquipeDaCasa.titulo)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: TextosDaEquipeDaCasa.explicacao)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: A lista

    @ViewBuilder
    private var listaDaEquipe: some View {
        switch modelo.lista {
        case .carregando:
            EstadoCarregando()
        case .soAdministrador:
            Text(verbatim: TextosDaEquipeDaCasa.soAdministrador)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("equipe-so-administrador")
        case let .erro(mensagem):
            EstadoErro(verbatim: mensagem) { Task { await modelo.carregar() } }
                .accessibilityIdentifier("equipe-erro")
        case let .conteudo(membros):
            if membros.isEmpty {
                Text(verbatim: TextosDaEquipeDaCasa.vazia)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .accessibilityIdentifier("equipe-vazia")
            } else {
                FrilaGrupoDeLinhas(verbatim: TextosDaEquipeDaCasa.lista, linhasComIcone: false) {
                    ForEach(membros) { membro in linhaDoMembro(membro) }
                }
            }
        }
    }

    private func linhaDoMembro(_ membro: MembroDaCasa) -> some View {
        let id = membro.id.uuidString.lowercased()
        return VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                Text(verbatim: membro.nome)
                    .font(FrilaTipo.rotuloSecundario)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: detalhe(de: membro))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Nome e detalhe são uma pessoa só para o leitor de tela; as ações seguem separadas, cada uma com o nome da pessoa.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("equipe-membro-\(id)")
            // "Você" não tem Remover nem Tornar administrador: o app não oferece sair da casa por aqui.
            if modelo.podeGerenciar, !membro.eVoce, membro.papelConhecido {
                acoes(de: membro, id: id)
            }
        }
        .padding(.horizontal, FrilaMedidaDeLinha.margem)
        .padding(.vertical, FrilaEspaco.item)
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvo, alignment: .leading)
    }

    /// "Administrador · Você · Desde 14/10/2025".
    private func detalhe(de membro: MembroDaCasa) -> String {
        var partes = [membro.papelConhecido ? membro.papel.rotuloDaEquipe : TextosDaEquipeDaCasa.papelDesconhecido]
        if membro.eVoce { partes.append(TextosDaEquipeDaCasa.voce) }
        if let desde = membro.desde { partes.append(String(format: TextosDaEquipeDaCasa.desde, formatador.data(desde))) }
        return partes.joined(separator: " · ")
    }

    @ViewBuilder
    private func acoes(de membro: MembroDaCasa, id: String) -> some View {
        let remover = Button { modelo.pedirConfirmacao(.remover, membro: membro) } label: {
            Text(verbatim: TextosDaEquipeDaCasa.remover)
        }
        .buttonStyle(.frilaLink)
        .disabled(modelo.ocupado)
        .accessibilityLabel(Text(verbatim: String(format: TextosDaEquipeDaCasa.removerDe, membro.nome)))
        .accessibilityIdentifier("equipe-remover-\(id)")

        let transferir = Button { modelo.pedirConfirmacao(.transferir, membro: membro) } label: {
            Text(verbatim: TextosDaEquipeDaCasa.transferir)
        }
        .buttonStyle(.frilaLink)
        .disabled(modelo.ocupado)
        .accessibilityLabel(Text(verbatim: String(format: TextosDaEquipeDaCasa.transferirDe, membro.nome)))
        .accessibilityIdentifier("equipe-transferir-\(id)")

        // Só um operador vira administrador. Em tamanho de acessibilidade as duas ações empilham.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 0) {
                remover
                if membro.papel == .operador { transferir }
            }
        } else {
            HStack(spacing: FrilaEspaco.grupo) {
                remover
                if membro.papel == .operador { transferir }
            }
        }
    }

    // MARK: Convidar

    private var secaoDoConvite: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text(verbatim: TextosDaEquipeDaCasa.convidar)
                .font(FrilaTipo.secao)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                Text(verbatim: TextosDaEquipeDaCasa.email)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
                CampoFrila(verbatim: TextosDaEquipeDaCasa.emailExemplo, texto: $modelo.email, emFoco: emailEmFoco)
                    .accessibilityLabel(Text(verbatim: TextosDaEquipeDaCasa.email))
                    .focused($emailEmFoco)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { emailEmFoco = false }
                    .erroDeCampoFrila(modelo.erroDoEmail)
                    .disabled(modelo.gerandoConvite)
                    .accessibilityIdentifier("equipe-email")
                if let erro = modelo.erroDoEmail {
                    Text(verbatim: erro)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("equipe-erro-email")
                }
            }

            FrilaGrupoDeLinhas(verbatim: TextosDaEquipeDaCasa.papel, linhasComIcone: false) {
                FrilaLinhaDeOpcao(titulo: PapelMembro.operador.rotuloDaEquipe, remate: .marcada(modelo.papelConvidado == .operador)) {
                    modelo.papelConvidado = .operador
                }
                .accessibilityIdentifier("equipe-papel-operador")
                FrilaLinhaDeOpcao(titulo: PapelMembro.administrador.rotuloDaEquipe, remate: .marcada(modelo.papelConvidado == .administrador)) {
                    modelo.papelConvidado = .administrador
                }
                .accessibilityIdentifier("equipe-papel-administrador")
            }

            if let erro = modelo.erroDoConvite {
                MensagemJuntoAoBotao(verbatim: erro)
                    .accessibilityIdentifier("equipe-erro-convite")
            }
            BotaoPrimario(verbatim: modelo.gerandoConvite ? TextosDaEquipeDaCasa.gerando : TextosDaEquipeDaCasa.gerarConvite,
                          carregando: modelo.gerandoConvite) {
                emailEmFoco = false
                Task { await modelo.gerarConvite() }
            }
            .accessibilityIdentifier("equipe-gerar-convite")

            if let convite = modelo.convite { cartaoDoConvite(convite) }
        }
    }

    private func cartaoDoConvite(_ convite: ConviteGerado) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            Text(verbatim: String(format: TextosDaEquipeDaCasa.convitePara, convite.email))
                .font(FrilaTipo.tituloDoCartao)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: convite.expiraEm.map { String(format: TextosDaEquipeDaCasa.convitePronto, formatador.dataEHora($0)) }
                    ?? TextosDaEquipeDaCasa.conviteProntoSemPrazo)
                .font(FrilaTipo.meta)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("equipe-convite-pronto")
            VStack(alignment: .leading, spacing: FrilaEspaco.minimo) {
                Text(verbatim: TextosDaEquipeDaCasa.linkDoConvite)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.texto)
                Text(verbatim: convite.link)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.texto)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("equipe-convite-link")
            }
            ShareLink(item: convite.link, subject: Text(verbatim: TextosDaEquipeDaCasa.compartilharTitulo)) {
                Text(verbatim: TextosDaEquipeDaCasa.compartilhar)
            }
            .buttonStyle(EstiloDoBotaoFrila(papel: .secundario))
            .accessibilityIdentifier("equipe-compartilhar-convite")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityElement(children: .contain)
    }

    // MARK: Confirmação

    /// Mesmo padrão da saída da conta: título rolável e ações fixas, Cancelar primeiro.
    private var folhaDeConfirmacao: some View {
        let pendente = modelo.pendente
        return ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.item) {
                Text(verbatim: pendente?.acao == .transferir ? TextosDaEquipeDaCasa.confirmarTransferencia : TextosDaEquipeDaCasa.confirmarRemocao)
                    .font(FrilaTipo.tituloDeEstado)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: String(format: pendente?.acao == .transferir ? TextosDaEquipeDaCasa.efeitoTransferencia : TextosDaEquipeDaCasa.efeitoRemocao,
                                      pendente?.nome ?? ""))
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("equipe-confirmar-efeito")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(FrilaEspaco.bloco)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FrilaEspaco.pequeno) {
                BotaoSecundario(verbatim: TextosDaEquipeDaCasa.cancelar) { modelo.cancelarConfirmacao() }
                    .accessibilityIdentifier("equipe-confirmar-cancelar")
                BotaoPrimario(verbatim: pendente?.acao == .transferir ? TextosDaEquipeDaCasa.transferir : TextosDaEquipeDaCasa.remover) {
                    Task { await modelo.confirmar() }
                }
                .accessibilityIdentifier("equipe-confirmar")
            }
            .padding(FrilaEspaco.bloco)
            .background(FrilaCor.fundo)
        }
        .background(FrilaCor.fundo)
        .presentationDetents([.large])
        .presentationCornerRadius(FrilaRaio.folha)
        .presentationDragIndicator(.visible)
    }
}
