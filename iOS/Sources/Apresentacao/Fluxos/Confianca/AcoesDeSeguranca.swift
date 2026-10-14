import FrilaDominio
import SwiftUI

/// Ações de denunciar e bloquear de um perfil (#39), com a folha de denúncia do quadro "Denuncia" do MidFi do Fabrício.
struct AcoesDeSeguranca: View {
    @ScaledMetric(relativeTo: .body) private var colunaDoIcone: CGFloat = 28
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
                linha(icone: "exclamationmark.bubble", titulo: TextosDaSeguranca.denunciar, corDoIcone: FrilaCor.textoSecundario, corDoTexto: FrilaCor.texto)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: "\(TextosDaSeguranca.denunciar) \(nomeAlvo)"))
            .accessibilityIdentifier(identificadorDenunciar)

            Button { confirmandoBloqueio = true } label: {
                linha(icone: "nosign", titulo: TextosDaSeguranca.bloquear, corDoIcone: FrilaCor.perigo, corDoTexto: FrilaCor.perigo)
            }
            .buttonStyle(.plain)
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

    /// Linha de ação: ícone em coluna fixa e texto, com toque de pelo menos 44 pt.
    private func linha(icone: String, titulo: String, corDoIcone: Color, corDoTexto: Color) -> some View {
        HStack(spacing: FrilaEspaco.compacto) {
            Image(systemName: icone)
                .font(FrilaTipo.corpo)
                .foregroundStyle(corDoIcone)
                .frame(width: colunaDoIcone)
                .accessibilityHidden(true)
            Text(verbatim: titulo)
                .font(FrilaTipo.corpo)
                .foregroundStyle(corDoTexto)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Folha de denúncia, no quadro "Denuncia" do MidFi: campos em superfícies brancas sobre o fundo cinza,
/// atalhos de emergência quando o motivo é risco à segurança e tela de protocolo com círculo de 72 pt.
private struct FolhaDeDenuncia: View {
    @ScaledMetric(relativeTo: .body) private var colunaDoIcone: CGFloat = 28
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: SegurancaViewModel
    @AccessibilityFocusState private var protocoloEmFoco: Bool
    @FocusState private var focoNoRelato: Bool

    var body: some View {
        NavigationStack {
            Form {
                if let protocolo = model.protocolo {
                    Section {
                        VStack(spacing: FrilaEspaco.compacto) {
                            Image(systemName: "checkmark")
                                .font(.title)
                                .foregroundStyle(FrilaCor.textoSecundario)
                                .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                                .background(FrilaCor.controle, in: Circle())
                                .accessibilityHidden(true)
                            Text(verbatim: TextosDaSeguranca.enviada)
                                .font(FrilaTipo.tituloDeEstado)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityFocused($protocoloEmFoco)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, FrilaEspaco.medio)
                        .listRowBackground(Color.clear)
                    }
                    Section {
                        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                            Text(verbatim: TextosDaSeguranca.protocolo)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Text(verbatim: protocolo.ocorrenciaID.uuidString)
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("protocolo-denuncia")
                        VStack(alignment: .leading, spacing: FrilaEspaco.fio) {
                            Text(verbatim: TextosDaSeguranca.prazo)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.textoSecundario)
                            Text(verbatim: String(format: "%02d/%02d/%04d", protocolo.prazoRespostaAte.dia,
                                                 protocolo.prazoRespostaAte.mes, protocolo.prazoRespostaAte.ano))
                                .font(FrilaTipo.corpo.monospacedDigit())
                                .foregroundStyle(FrilaCor.texto)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("prazo-denuncia")
                    }
                    .listRowBackground(FrilaCor.superficie)
                } else {
                    Section {
                        Picker(TextosDaSeguranca.motivo, selection: $model.motivo) {
                            ForEach(MotivoDenuncia.allCases, id: \.self) { motivo in
                                Text(verbatim: TextosDaSeguranca.nome(motivo)).tag(motivo)
                            }
                        }
                        .pickerStyle(.navigationLink)
                        .font(FrilaTipo.corpo)
                        .accessibilityIdentifier("motivo-denuncia")

                        TextField(TextosDaSeguranca.relato, text: $model.relato, axis: .vertical)
                            .font(FrilaTipo.valorDoCampo)
                            .lineLimit(4...10)
                            .focused($focoNoRelato)
                            .accessibilityIdentifier("relato-denuncia")

                        Text(verbatim: TextosDaSeguranca.relatoMinimo)
                            .font(FrilaTipo.nota)
                            .foregroundStyle(FrilaCor.textoSecundario)
                    }
                    .listRowBackground(FrilaCor.superficie)
                    .disabled(model.enviando)

                    if model.motivo == .riscoSeguranca {
                        Section {
                            Text(verbatim: TextosDaSeguranca.emergencia)
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.texto)
                                .accessibilityIdentifier("aviso-risco-imediato")
                            atalhoDeEmergencia(TextosDaSeguranca.policia, numero: "190")
                            atalhoDeEmergencia(TextosDaSeguranca.mulher, numero: "180")
                        }
                        .listRowBackground(FrilaCor.controle)
                    }

                    if let erro = model.erroDenuncia {
                        AvisoFrila(verbatim: erro, tom: .erro).accessibilityIdentifier("erro-denuncia")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(FrilaCor.fundo.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if model.protocolo == nil {
                    VStack(spacing: FrilaEspaco.minimo) {
                        BotaoPrimario(verbatim: TextosDaSeguranca.enviar, carregando: model.enviando) {
                            Task { await model.denunciar() }
                        }
                        .disabled(!model.relatoValido || model.enviando)
                        .accessibilityIdentifier("enviar-denuncia")
                    }
                    .padding(FrilaEspaco.medio)
                    .background(FrilaCor.fundo.opacity(0.95))
                }
            }
            .navigationTitle(TextosDaSeguranca.denunciar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(TextosDaSeguranca.fechar) { dismiss() }
                        .accessibilityShowsLargeContentViewer {
                            Text(verbatim: TextosDaSeguranca.fechar)
                        }
                        .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                        .disabled(model.enviando)
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

    /// Atalho de ligação de emergência: ícone em coluna fixa e toque de pelo menos 44 pt.
    private func atalhoDeEmergencia(_ titulo: String, numero: String) -> some View {
        Link(destination: URL(string: "tel:\(numero)")!) {
            HStack(spacing: FrilaEspaco.compacto) {
                Image(systemName: "phone.fill")
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .frame(width: colunaDoIcone)
                    .accessibilityHidden(true)
                Text(verbatim: titulo)
                    .font(FrilaTipo.rotuloDoCampo)
                    .foregroundStyle(FrilaCor.texto)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: FrilaMetrica.alvoMinimo, alignment: .leading)
            .contentShape(Rectangle())
        }
    }
}

/// Perfil público de quem está do outro lado do turno, com as ações de segurança (#39).
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
                        Text(verbatim: perfil.nome).font(FrilaTipo.tituloGrande).accessibilityAddTraits(.isHeader)
                        if !perfil.funcoes.isEmpty {
                            Text(verbatim: perfil.funcoes.joined(separator: ", "))
                                .font(FrilaTipo.meta)
                                .foregroundStyle(FrilaCor.textoSecundario)
                        }
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
