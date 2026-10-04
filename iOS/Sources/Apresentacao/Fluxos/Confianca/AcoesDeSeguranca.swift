import FrilaDominio
import SwiftUI

struct AcoesDeSeguranca: View {
    @State private var model: SegurancaViewModel
    @State private var denunciando = false
    @State private var confirmandoBloqueio = false
    private let nomeAlvo: String
    private let identificadorDenunciar: String
    private let identificadorBloquear: String
    private let identificadorConfirmarBloqueio: String

    init(
        perfil: PerfilPublico,
        turnoID: UUID? = nil,
        api: any ApiCliente,
        bloqueios: BloqueiosDaSessao,
        identificadorDenunciar: String = "denunciar",
        identificadorBloquear: String = "bloquear",
        identificadorConfirmarBloqueio: String = "confirmar-bloqueio"
    ) {
        _model = State(initialValue: SegurancaViewModel(perfil: perfil, turnoID: turnoID, api: api, bloqueios: bloqueios))
        self.nomeAlvo = perfil.nome
        self.identificadorDenunciar = identificadorDenunciar
        self.identificadorBloquear = identificadorBloquear
        self.identificadorConfirmarBloqueio = identificadorConfirmarBloqueio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.pequeno) {
            Button { denunciando = true } label: {
                Text(verbatim: TextosDaSeguranca.denunciar)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(verbatim: "\(TextosDaSeguranca.denunciar) \(nomeAlvo)"))
            .accessibilityIdentifier(identificadorDenunciar)

            Button { confirmandoBloqueio = true } label: {
                Text(verbatim: TextosDaSeguranca.bloquear)
                    .frame(minHeight: FrilaMetrica.alvoMinimo)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(verbatim: "\(TextosDaSeguranca.bloquear) \(nomeAlvo)"))
            .disabled(model.bloqueando || model.bloqueado)
            .accessibilityIdentifier(identificadorBloquear)

            if model.bloqueando { ProgressView() }
            if let erro = model.erroBloqueio {
                AvisoFrila(verbatim: erro, tom: .erro).accessibilityIdentifier("erro-bloqueio")
            }
        }
        .alert(TextosDaSeguranca.confirmarBloqueio, isPresented: $confirmandoBloqueio) {
            Button(TextosDaSeguranca.cancelar, role: .cancel) {}
            Button(TextosDaSeguranca.bloquear, role: .destructive) { Task { await model.bloquear() } }
                .accessibilityIdentifier(identificadorConfirmarBloqueio)
        } message: { Text(verbatim: TextosDaSeguranca.efeitoBloqueio) }
        .sheet(isPresented: $denunciando) { FolhaDeDenuncia(model: model) }
    }
}

private struct FolhaDeDenuncia: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: SegurancaViewModel
    @AccessibilityFocusState private var protocoloEmFoco: Bool
    @FocusState private var focoNoRelato: Bool

    var body: some View {
        NavigationStack {
            Form {
                if let protocolo = model.protocolo {
                    Section {
                        Text(verbatim: TextosDaSeguranca.enviada)
                            .font(.headline).accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($protocoloEmFoco)
                        VStack(alignment: .leading) {
                            Text(verbatim: TextosDaSeguranca.protocolo)
                            Text(verbatim: protocolo.ocorrenciaID.uuidString)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("protocolo-denuncia")
                        VStack(alignment: .leading) {
                            Text(verbatim: TextosDaSeguranca.prazo)
                            Text(verbatim: String(format: "%02d/%02d/%04d", protocolo.prazoRespostaAte.dia,
                                                 protocolo.prazoRespostaAte.mes, protocolo.prazoRespostaAte.ano))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("prazo-denuncia")
                    }
                } else {
                    Section {
                        Picker(TextosDaSeguranca.motivo, selection: $model.motivo) {
                            ForEach(MotivoDenuncia.allCases, id: \.self) { motivo in
                                Text(verbatim: TextosDaSeguranca.nome(motivo)).tag(motivo)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .accessibilityIdentifier("motivo-denuncia")

                        TextField(TextosDaSeguranca.relato, text: $model.relato, axis: .vertical)
                            .lineLimit(4...10)
                            .focused($focoNoRelato)
                            .accessibilityIdentifier("relato-denuncia")

                        Text(verbatim: TextosDaSeguranca.relatoMinimo).font(.caption)
                    }
                    .disabled(model.enviando)

                    if model.motivo == .riscoSeguranca {
                        Section {
                            Text(verbatim: TextosDaSeguranca.emergencia).accessibilityIdentifier("aviso-risco-imediato")
                            Link(TextosDaSeguranca.policia, destination: URL(string: "tel:190")!)
                            Link(TextosDaSeguranca.mulher, destination: URL(string: "tel:180")!)
                        }
                    }

                    if let erro = model.erroDenuncia {
                        AvisoFrila(verbatim: erro, tom: .erro).accessibilityIdentifier("erro-denuncia")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if model.protocolo == nil {
                    VStack(spacing: FrilaEspaco.minimo) {
                        if model.enviando {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                        } else {
                            Button {
                                Task { await model.denunciar() }
                            } label: {
                                Text(verbatim: TextosDaSeguranca.enviar)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FrilaCor.primaria)
                            .disabled(!model.relatoValido || model.enviando)
                            .accessibilityIdentifier("enviar-denuncia")
                        }
                    }
                    .padding(FrilaEspaco.medio)
                    .background(FrilaCor.fundo.opacity(0.95))
                }
            }
            .navigationTitle(TextosDaSeguranca.denunciar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(TextosDaSeguranca.fechar) { dismiss() }.disabled(model.enviando)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focoNoRelato = false
                    } label: {
                        Text(verbatim: TextosDaSeguranca.ok)
                    }
                    .accessibilityLabel(Text(verbatim: TextosDaSeguranca.recolherTeclado))
                    .accessibilityIdentifier("recolher-teclado")
                }
            }
            .interactiveDismissDisabled(model.enviando)
            .onChange(of: model.protocolo) { protocoloEmFoco = model.protocolo != nil }
            .onAppear { if model.protocolo != nil { protocoloEmFoco = true } }
        }
    }
}

struct TelaPerfilPublico: View {
    @State private var model: PerfilPublicoViewModel
    let perfil: PerfilPublico
    let api: any ApiCliente
    let bloqueios: BloqueiosDaSessao

    init(perfil: PerfilPublico, api: any ApiCliente, bloqueios: BloqueiosDaSessao) {
        self.perfil = perfil
        self.api = api
        self.bloqueios = bloqueios
        _model = State(initialValue: PerfilPublicoViewModel(id: perfil.id, api: api))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.medio) {
                if bloqueios.contem(perfil) {
                    indisponivel
                } else {
                    switch model.estado {
                    case .carregando: EstadoCarregando()
                    case .indisponivel: indisponivel
                    case let .falha(erro):
                        EstadoErro(verbatim: erro) { Task { await model.carregar() } }
                    case let .carregado(perfil):
                        Text(verbatim: perfil.nome).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                        if !perfil.funcoes.isEmpty { Text(verbatim: perfil.funcoes.joined(separator: ", ")) }
                        SeloReputacao(perfil.reputacao)
                        AcoesDeSeguranca(perfil: perfil, api: api, bloqueios: bloqueios)
                            .id(perfil.id)
                    }
                }
            }
            .padding(FrilaEspaco.medio)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosDaSeguranca.perfil)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(perfil.tipo == .profissional ? "perfil-publico-contratante" : "perfil-publico-estabelecimento")
        .task { await model.carregar() }
    }

    private var indisponivel: some View {
        AvisoFrila(verbatim: TextosDaSeguranca.indisponivel, tom: .informativo)
            .accessibilityIdentifier("perfil-indisponivel")
    }
}
