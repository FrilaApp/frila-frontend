import FrilaDominio
import SwiftUI

/// Ações de segurança (#39): denunciar e bloquear, com a folha de denúncia.
/// Desenho do sistema do Fabrício (extrapolado: a tela não está no protótipo). São ações de risco: abrem com a ação
/// discreta (texto sublinhado em `textoSecundario`, uma por linha, no fim da tela), sem vermelho. A consequência do
/// bloqueio vem escrita na confirmação nativa que já existia.
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
        chamadaID: UUID? = nil,
        api: any ApiCliente,
        bloqueios: BloqueiosDaSessao,
        cacheEquipe: CacheEquipeDeConfianca = .compartilhado,
        identificadorDenunciar: String = "denunciar",
        identificadorBloquear: String = "bloquear",
        identificadorConfirmarBloqueio: String = "confirmar-bloqueio",
        aoBloquear: (@Sendable () async -> Void)? = nil
    ) {
        _model = State(initialValue: SegurancaViewModel(
            perfil: perfil,
            turnoID: turnoID,
            chamadaID: chamadaID,
            api: api,
            bloqueios: bloqueios,
            cacheEquipe: cacheEquipe,
            aoBloquear: aoBloquear
        ))
        self.nomeAlvo = perfil.nome
        self.identificadorDenunciar = identificadorDenunciar
        self.identificadorBloquear = identificadorBloquear
        self.identificadorConfirmarBloqueio = identificadorConfirmarBloqueio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let erro = model.erroBloqueio {
                MensagemJuntoAoBotao(verbatim: erro)
                    .padding(.bottom, FrilaEspaco.item)
                    .accessibilityIdentifier("erro-bloqueio")
            }

            Button { denunciando = true } label: { Text(verbatim: TextosDaSeguranca.denunciar) }
                .buttonStyle(.frilaAcaoDiscreta)
                .accessibilityLabel(Text(verbatim: "\(TextosDaSeguranca.denunciar) \(nomeAlvo)"))
                .accessibilityIdentifier(identificadorDenunciar)

            Button { confirmandoBloqueio = true } label: { Text(verbatim: TextosDaSeguranca.bloquear) }
                .buttonStyle(.frilaAcaoDiscreta)
                .accessibilityLabel(Text(verbatim: "\(TextosDaSeguranca.bloquear) \(nomeAlvo)"))
                .disabled(model.bloqueando || model.bloqueado)
                .accessibilityIdentifier(identificadorBloquear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert(TextosDaSeguranca.confirmarBloqueio, isPresented: $confirmandoBloqueio) {
            Button(TextosDaSeguranca.cancelar, role: .cancel) {}
            Button(TextosDaSeguranca.bloquear, role: .destructive) { Task { await model.bloquear() } }
                .accessibilityIdentifier(identificadorConfirmarBloqueio)
        } message: { Text(verbatim: TextosDaSeguranca.efeitoBloqueio) }
        .sheet(isPresented: $denunciando) {
            FolhaDeDenuncia(model: model)
                .presentationCornerRadius(FrilaRaio.folha)
                .presentationDragIndicator(.visible)
        }
    }
}

/// Denúncia: o motivo em lista com visto (escolha única), o relato em campo de várias linhas, os atalhos de emergência
/// e, depois do envio, o protocolo e o prazo. O botão primário fica ancorado embaixo, com o erro logo acima.
public struct FolhaDeDenuncia: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Bindable var model: SegurancaViewModel
    @AccessibilityFocusState private var protocoloEmFoco: Bool
    @FocusState private var focoNoRelato: Bool

    public init(model: SegurancaViewModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                    if let protocolo = model.protocolo {
                        confirmacao(protocolo)
                    } else {
                        formulario
                    }
                }
                .padding(.horizontal, FrilaEspaco.grupo)
                .padding(.top, FrilaEspaco.bloco)
                .padding(.bottom, FrilaEspaco.grupo)
                .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(FrilaCor.fundo.ignoresSafeArea())
            .rodapeAncorado {
                if model.protocolo == nil {
                    if let erro = model.erroDenuncia {
                        MensagemJuntoAoBotao(verbatim: erro)
                            .accessibilityIdentifier("erro-denuncia")
                    }
                    BotaoPrimario(verbatim: TextosDaSeguranca.enviar, carregando: model.enviando) {
                        Task { await model.denunciar() }
                    }
                    .disabled(!model.relatoValido || model.enviando)
                    .accessibilityIdentifier("enviar-denuncia")
                } else {
                    BotaoPrimario(verbatim: TextosDaSeguranca.concluir) {
                        dismiss()
                    }
                    .accessibilityIdentifier("concluir-denuncia")
                }
            }
            .navigationTitle(TextosDaSeguranca.denunciar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: TextosDaSeguranca.fechar)
                            .fixedSize()
                            .frame(minWidth: FrilaMetrica.alvoMinimo, minHeight: FrilaMetrica.alvoMinimo)
                    }
                    .fixedSize()
                    .accessibilityShowsLargeContentViewer {
                        Text(verbatim: TextosDaSeguranca.fechar)
                    }
                    .disabled(model.enviando)
                    .accessibilityIdentifier("fechar-denuncia")
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
        .frilaKeyboardDismissScope()
    }

    // MARK: - Formulário

    @ViewBuilder
    private var formulario: some View {
        // Escolha única: lista com visto em tinta, no lugar do seletor de navegação.
        FrilaGrupoDeLinhas(verbatim: TextosDaSeguranca.motivo, linhasComIcone: false) {
            ForEach(MotivoDenuncia.allCases, id: \.self) { motivo in
                FrilaLinhaDeOpcao(titulo: TextosDaSeguranca.nome(motivo), remate: .marcada(model.motivo == motivo)) {
                    model.motivo = motivo
                }
                .accessibilityIdentifier("motivo-denuncia-\(motivo.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("motivo-denuncia")
        .disabled(model.enviando)

        if model.podeDenunciarFoto {
            Toggle(isOn: $model.sobreAFoto) {
                VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                    Text(verbatim: TextosDaSeguranca.sobreAFoto)
                        .font(FrilaTipo.rotuloSecundario)
                        .foregroundStyle(FrilaCor.texto)
                    Text(verbatim: TextosDaSeguranca.sobreAFotoExplicacao)
                        .font(FrilaTipo.apoio)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(FrilaCor.primaria)
            .disabled(model.enviando)
            .accessibilityIdentifier("denuncia-sobre-foto")
        }

        relato

        if model.motivo == .riscoSeguranca {
            emergencia(naConfirmacao: false)
        }
    }

    private var relato: some View {
        let contagem = model.relato.trimmingCharacters(in: .whitespacesAndNewlines).count
        return VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosDaSeguranca.relato)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .accessibilityAddTraits(.isHeader)

            TextField(TextosDaSeguranca.relato, text: $model.relato, axis: .vertical)
                .lineLimit(4...10)
                .textFieldStyle(.plain)
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.texto)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .caixaDoCampoFrila(emFoco: focoNoRelato)
                .focused($focoNoRelato)
                .disabled(model.enviando)
                .accessibilityIdentifier("relato-denuncia")
                .accessibilityHint(Text(verbatim: model.relatoValido ? TextosDaSeguranca.relatoValidoAcessibilidade : "\(contagem)/10"))
                .frilaFormField(id: "denuncia-relato", isFocused: focoNoRelato, onDismiss: { focoNoRelato = false })

            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: TextosDaSeguranca.relatoMinimo)
                    .font(FrilaTipo.legenda)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: FrilaEspaco.item)
                if model.relatoValido {
                    // O visto de "relato válido", em tinta (sem verde): decorativo, o estado também vai no rótulo do contador.
                    Image(systemName: "checkmark")
                        .font(FrilaTipo.legenda.weight(.semibold))
                        .foregroundStyle(FrilaCor.texto)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("icone-relato-valido-denuncia")
                }
                Text(verbatim: "\(contagem)/10")
                    .font(FrilaTipo.legenda.monospacedDigit())
                    .foregroundStyle(model.relatoValido ? FrilaCor.texto : FrilaCor.textoSecundario)
                    .accessibilityIdentifier("contador-relato-denuncia")
                    .accessibilityLabel(Text(verbatim: model.relatoValido ? TextosDaSeguranca.relatoValidoAcessibilidade : "\(contagem)/10"))
            }
        }
    }

    // MARK: - Confirmação

    @ViewBuilder
    private func confirmacao(_ protocolo: Protocolo) -> some View {
        Text(verbatim: TextosDaSeguranca.enviada)
            .font(FrilaTipo.tituloDaTela)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($protocoloEmFoco)

        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text(verbatim: TextosDaSeguranca.protocolo)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: protocolo.ocorrenciaID.uuidString)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("protocolo-denuncia")

            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                Text(verbatim: TextosDaSeguranca.prazo)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                Text(verbatim: String(format: "%02d/%02d/%04d", protocolo.prazoRespostaAte.dia,
                                     protocolo.prazoRespostaAte.mes, protocolo.prazoRespostaAte.ano))
                    .font(FrilaTipo.corpo.monospacedDigit())
                    .foregroundStyle(FrilaCor.texto)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("prazo-denuncia")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()

        emergencia(naConfirmacao: true)
    }

    // MARK: - Emergência

    /// O aviso de risco imediato e os dois atalhos de ligação, em botão secundário (sem vermelho). O aviso é de bloco,
    /// neutro; o toque abre a ligação do sistema. Na confirmação do envio o mesmo aviso aparece com o outro identificador.
    private func emergencia(naConfirmacao: Bool) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            avisoDeRiscoImediato(naConfirmacao: naConfirmacao)
            atalhoDeEmergencia(TextosDaSeguranca.policia, numero: "190")
            atalhoDeEmergencia(TextosDaSeguranca.mulher, numero: "180")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func avisoDeRiscoImediato(naConfirmacao: Bool) -> some View {
        let texto = Text(verbatim: TextosDaSeguranca.emergencia)
            .font(FrilaTipo.corpo)
            .foregroundStyle(FrilaCor.texto)
            .fixedSize(horizontal: false, vertical: true)
        if naConfirmacao {
            texto.accessibilityIdentifier("aviso-risco-imediato-confirmacao")
        } else {
            texto.accessibilityIdentifier("aviso-risco-imediato")
        }
    }

    private func atalhoDeEmergencia(_ titulo: String, numero: String) -> some View {
        BotaoSecundario(verbatim: titulo) {
            if let url = URL(string: "tel:\(numero)") { openURL(url) }
        }
        .accessibilityIdentifier("atalho-emergencia-\(numero)")
    }
}

/// Perfil público de quem está do outro lado do turno, com as ações de segurança (#39).
/// Tela de leitura: zero laranja. O nome é o título (como o perfil da casa do protótipo, T3b), a reputação vem escrita
/// como fato e as seções seguem em rótulo de grupo. Denunciar e bloquear ficam no fim, em ação discreta.
public struct TelaPerfilPublico: View {
    @State private var model: PerfilPublicoViewModel
    let perfil: PerfilPublico
    let api: any ApiCliente
    let bloqueios: BloqueiosDaSessao

    public init(perfil: PerfilPublico, api: any ApiCliente, bloqueios: BloqueiosDaSessao) {
        self.perfil = perfil
        self.api = api
        self.bloqueios = bloqueios
        _model = State(initialValue: PerfilPublicoViewModel(id: perfil.id, api: api))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                if bloqueios.contem(perfil) {
                    indisponivel
                } else {
                    switch model.estado {
                    case .carregando: EstadoCarregando()
                    case .indisponivel: indisponivel
                    case let .falha(erro):
                        EstadoErro(verbatim: erro) { Task { await model.carregar() } }
                    case let .carregado(perfil):
                        conteudo(perfil)
                        FrilaDivisoria()
                        AcoesDeSeguranca(perfil: perfil, api: api, bloqueios: bloqueios)
                            .id(perfil.id)
                    }
                }
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.vertical, FrilaEspaco.bloco)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo)
        .navigationTitle(TextosDaSeguranca.perfil)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(perfil.tipo == .profissional ? "perfil-publico-contratante" : "perfil-publico-estabelecimento")
        .task { await model.carregar() }
    }

    @ViewBuilder
    private func conteudo(_ perfil: PerfilPublico) -> some View {
        let reputacao = perfil.reputacao
        VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
            if perfil.tipo == .estabelecimento {
                cabecalhoDaCasa(perfil, reputacao: reputacao)
            } else {
                cabecalhoDoProfissional(perfil, reputacao: reputacao)

                if !perfil.servicos.isEmpty {
                    secao(String(localized: "Serviços oferecidos", bundle: bundleApresentacao), agrupar: false) {
                        ForEach(perfil.servicos) { servico in
                            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                                Text(verbatim: servico.funcao.nome)
                                    .font(FrilaTipo.nome)
                                    .foregroundStyle(FrilaCor.texto)
                                if let resumo = TextosDosServicos.resumoDoServico(servico.servico) {
                                    Text(verbatim: resumo)
                                        .font(FrilaTipo.apoio)
                                        .foregroundStyle(FrilaCor.textoSecundario)
                                }
                                if let inclui = servico.servico.itensInclusos, !inclui.isEmpty {
                                    Text(verbatim: inclui)
                                        .font(FrilaTipo.apoio)
                                        .foregroundStyle(FrilaCor.textoSecundario)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if !servico.especialidades.isEmpty {
                                    Text(verbatim: servico.especialidades.map(\.nome).joined(separator: ", "))
                                        .font(FrilaTipo.legenda)
                                        .foregroundStyle(FrilaCor.textoSecundario)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cartaoFrila()
                        }
                    }
                    .accessibilityIdentifier("perfil-publico-servicos")
                }

                if let apresentacao = perfil.apresentacao, !apresentacao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    secao(TextosApresentacaoERegioes.sobreMimTitulo) {
                        Text(verbatim: apresentacao)
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("perfil-publico-sobre-mim")
                }

                if perfil.experienciaFaixa != nil || (perfil.ondeTrabalhei != nil && !perfil.ondeTrabalhei!.isEmpty) {
                    secao(TextosApresentacaoERegioes.experienciaTitulo) {
                        if let faixa = perfil.experienciaFaixa {
                            Text(verbatim: TextosApresentacaoERegioes.textoExperiencia(faixa))
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                        }
                        if let onde = perfil.ondeTrabalhei, !onde.isEmpty {
                            Text(verbatim: onde)
                                .font(FrilaTipo.apoio)
                                .foregroundStyle(FrilaCor.textoSecundario)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityIdentifier("perfil-publico-experiencia")
                }

                if !perfil.cursos.isEmpty {
                    secao(TextosApresentacaoERegioes.cursosTitulo) {
                        ForEach(perfil.cursos, id: \.self) { curso in
                            Text(verbatim: "• \(curso)")
                                .font(FrilaTipo.corpo)
                                .foregroundStyle(FrilaCor.texto)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityIdentifier("perfil-publico-cursos")
                }

                if !perfil.idiomas.isEmpty {
                    secao(TextosApresentacaoERegioes.idiomasTitulo) {
                        Text(verbatim: perfil.idiomas.map { TextosApresentacaoERegioes.textoIdioma($0) }.joined(separator: ", "))
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("perfil-publico-idiomas")
                }

                if perfil.atendeTodoDF || !perfil.regioes.isEmpty {
                    secao(TextosApresentacaoERegioes.regioesTitulo) {
                        Text(verbatim: perfil.atendeTodoDF ? TextosApresentacaoERegioes.todoODF : perfil.regioes.map(\.nome).joined(separator: ", "))
                            .font(FrilaTipo.corpo)
                            .foregroundStyle(FrilaCor.texto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("perfil-publico-regioes")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A casa vista pelo profissional (T3b do protótipo, só com o que o perfil traz): o nome como título de tela, as
    /// funções em apoio e a reputação escrita como fato, na voz de quem avalia.
    private func cabecalhoDaCasa(_ perfil: PerfilPublico, reputacao: Reputacao) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: perfil.nome)
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !perfil.funcoes.isEmpty {
                Text(verbatim: perfil.funcoes.joined(separator: ", "))
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !reputacao.semHistorico {
                SeloReputacao(reputacao)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// O profissional visto pela casa: a foto aprovada (só quando existe), o nome, as funções e a reputação.
    private func cabecalhoDoProfissional(_ perfil: PerfilPublico, reputacao: Reputacao) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            HStack(alignment: .center, spacing: FrilaEspaco.bloco) {
                foto(perfil.fotoURL)
                VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                    Text(verbatim: perfil.nome)
                        .font(FrilaTipo.tituloDaTela)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if !perfil.funcoes.isEmpty {
                        Text(verbatim: perfil.funcoes.joined(separator: ", "))
                            .font(FrilaTipo.apoio)
                            .foregroundStyle(FrilaCor.textoSecundario)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            SeloReputacao(reputacao)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func foto(_ url: URL?) -> some View {
        if let url {
            AsyncImage(url: url) { fase in
                switch fase {
                case let .success(imagem):
                    imagem
                        .resizable()
                        .scaledToFill()
                default:
                    iconeDaPessoa
                }
            }
            .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
            .accessibilityHidden(true)
        } else {
            iconeDaPessoa
                .frame(width: FrilaMetrica.circuloDeEstado, height: FrilaMetrica.circuloDeEstado)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(FrilaCor.divisoria, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }

    private var iconeDaPessoa: some View {
        Image(systemName: "person.fill")
            .font(FrilaTipo.tituloDaTela)
            .foregroundStyle(FrilaCor.texto)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FrilaCor.controle)
    }

    /// Uma seção do perfil: o nome em rótulo de grupo (cabeçalho) e o conteúdo logo abaixo. `agrupar` junta o título e o
    /// conteúdo num elemento só para o leitor de tela; as seções de cartões (serviços) ficam soltas.
    @ViewBuilder
    private func secao<Conteudo: View>(
        _ titulo: String,
        agrupar: Bool = true,
        @ViewBuilder conteudo: () -> Conteudo
    ) -> some View {
        let miolo = VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: titulo)
                .font(FrilaTipo.rotuloDeGrupo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            conteudo()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if agrupar {
            miolo.accessibilityElement(children: .combine)
        } else {
            miolo.accessibilityElement(children: .contain)
        }
    }

    private var indisponivel: some View {
        AvisoFrila(verbatim: TextosDaSeguranca.indisponivel, tom: .informativo)
            .accessibilityIdentifier("perfil-indisponivel")
    }
}
