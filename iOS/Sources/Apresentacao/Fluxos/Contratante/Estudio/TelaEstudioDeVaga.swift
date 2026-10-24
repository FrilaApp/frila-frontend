import FrilaDominio
import SwiftUI

/// O "Publicar vaga" do contratante: o Estúdio de Criação do FrilaLowPhase com a publicação do app.
/// Carrega as funções do servidor, restaura publicação pendente e abre o `FrilaJobCreationStudioView`
/// com os ganchos do app (avisos, modo da vaga, campos travados, rótulos do fechar e do publicar).
///
/// `aoCancelar` nulo é o primeiro acesso (logo depois do cadastro da casa): não há para onde voltar, o X
/// não aparece e a barra ganha o botão do perfil do estabelecimento, como no formulário antigo.
struct TelaEstudioDeVaga: View {
    @State private var formulario: FormularioEstudioDeVaga
    @State private var catalogoPronto = false
    @State private var mostrandoPerfilEstabelecimento = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(PermissaoDePushModelo.self) private var permissaoDePush: PermissaoDePushModelo?
    private let api: any ApiCliente
    private let sair: () -> Void
    private let aoPublicar: () -> Void
    private let aoCancelar: (() -> Void)?

    init(
        api: any ApiCliente, fila: any FilaDeAcoes, estabelecimento: Estabelecimento,
        sair: @escaping () -> Void = {}, aoPublicar: @escaping () -> Void, aoCancelar: (() -> Void)? = nil
    ) {
        _formulario = State(initialValue: FormularioEstudioDeVaga(vaga: PublicarVagaViewModel(api: api, fila: fila, estabelecimento: estabelecimento)))
        self.api = api
        self.sair = sair
        self.aoPublicar = aoPublicar
        self.aoCancelar = aoCancelar
    }

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Group {
            if catalogoPronto {
                estudio
            } else if let erro = formulario.vaga.mensagemErro {
                EstadoErro(verbatim: erro) { Task { await carregar() } }
            } else {
                ProgressView()
            }
        }
        .task { await carregar() }
        // A fila avisa quando uma publicação guardada foi recusada pelo servidor.
        .onReceive(NotificationCenter.default.publisher(for: .filaDeAcoesAtualizada)) { _ in
            Task { await formulario.vaga.carregarRecusaDaFila() }
        }
        .sheet(isPresented: $mostrandoPerfilEstabelecimento) {
            NavigationStack {
                TelaPerfilEstabelecimento(api: api, sair: sair)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                mostrandoPerfilEstabelecimento = false
                            } label: {
                                Text("Fechar", bundle: bundleApresentacao)
                                    .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                            }
                            .accessibilityShowsLargeContentViewer()
                        }
                    }
            }
        }
    }

    private var estudio: some View {
        let vaga = formulario.vaga
        return FrilaJobCreationStudioView(
            isDark: isDark,
            initialDraft: formulario.rascunhoInicial,
            onPublish: { _ in
                // A vaga publicada é o momento de explicar a notificação a quem contrata (#8).
                Task { await permissaoDePush?.oferecer() }
                aoPublicar()
            },
            onDismiss: { aoCancelar?() },
            publicar: { await formulario.publicar($0) },
            hooks: FrilaStudioHostHooks(
                banner: {
                    let avisos = AvisosDoEstudio(vaga: vaga, isDark: isDark)
                    return avisos.temConteudo ? AnyView(avisos) : nil
                },
                sectionFooter: { secao in complementoDaEtapa(secao, vaga: vaga) },
                fieldsLocked: { vaga.camposBloqueados },
                publishLabel: { vaga.publicacaoPendente != nil ? TextosPublicarVaga.tentarNovamente : nil },
                closeLabel: { vaga.textoAoFechar },
                showsClose: aoCancelar != nil,
                trailingToolbar: aoCancelar != nil ? nil : {
                    AnyView(
                        Button { mostrandoPerfilEstabelecimento = true } label: {
                            Image(systemName: "building.2.crop.circle")
                                .foregroundStyle(FrilaColor.dynamicTextPrimary(isDark: isDark))
                                .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        }
                        .accessibilityLabel(String(localized: "Perfil do estabelecimento", bundle: bundleApresentacao))
                        .accessibilityShowsLargeContentViewer()
                    )
                },
                onDraftChange: { formulario.sincronizar($0) }
            )
        )
    }

    /// O que o app acrescenta ao fim de cada etapa: o modo da vaga no Turno e "Mais opções" no Valor.
    private func complementoDaEtapa(_ secao: FrilaJobFormSection, vaga: PublicarVagaViewModel) -> AnyView? {
        switch secao {
        case .vaga: nil
        case .turno: AnyView(ModoDaVagaDoEstudio(vaga: vaga, isDark: isDark))
        case .valor: AnyView(MaisOpcoesDoEstudio(vaga: vaga, isDark: isDark))
        }
    }

    private func carregar() async {
        await formulario.vaga.restaurarPublicacaoPendente()
        await formulario.vaga.carregarFuncoes()
        guard !formulario.vaga.funcoes.isEmpty else { return }
        formulario.usarFuncoesNoCatalogo()
        catalogoPronto = true
    }
}
