import FrilaDominio
import SwiftUI

/// A explicação que vem antes do pedido do sistema: diz para que serve a notificação e deixa a
/// pessoa escolher. Sem ela, o pedido do sistema apareceria sem contexto, e ele só aparece uma vez.
/// Desenho do sistema do Fabrício, extrapolado (a tela não está no protótipo): título de tela, o fato em corpo, a amostra
/// da notificação num cartão, os itens com visto em linha de dado e, ancorado embaixo, o único botão laranja
/// ("Ativar notificações") com "Agora não" em botão secundário. Os textos continuam provisórios (`TextosDoPush`).
public struct TelaExplicacaoDoPush: View {
    private let modelo: PermissaoDePushModelo
    private let perfil: PerfilConta

    public init(modelo: PermissaoDePushModelo, perfil: PerfilConta) {
        self.modelo = modelo
        self.perfil = perfil
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FrilaEspaco.grupo) {
                cabecalho
                if perfil == .profissional {
                    amostraNotificacaoProfissional
                }
                itens
                Text(verbatim: TextosDoPush.Explicacao.rodape)
                    .font(FrilaTipo.apoio)
                    .foregroundStyle(FrilaCor.textoSecundario)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, FrilaEspaco.grupo)
            .padding(.top, FrilaEspaco.grupo)
            .padding(.bottom, FrilaEspaco.grupo)
            .frame(maxWidth: FrilaMetrica.larguraMaximaDeLeitura, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FrilaCor.fundo.ignoresSafeArea())
        .accessibilityIdentifier("explicacao-do-push")
        .rodapeAncorado {
            BotaoPrimario(verbatim: TextosDoPush.Explicacao.ativar, carregando: modelo.pedindo) {
                Task { await modelo.ativar() }
            }
            .disabled(modelo.pedindo)
            .accessibilityIdentifier("ativar-notificacoes")

            BotaoSecundario(verbatim: TextosDoPush.Explicacao.agoraNao) {
                modelo.agoraNao()
            }
            .disabled(modelo.pedindo)
            .accessibilityIdentifier("notificacoes-agora-nao")
        }
    }

    // MARK: - Cabeçalho

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.item) {
            Text(verbatim: TextosDoPush.Explicacao.titulo(perfil))
                .font(FrilaTipo.tituloDaTela)
                .foregroundStyle(FrilaCor.texto)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(verbatim: TextosDoPush.Explicacao.mensagem(perfil))
                .font(FrilaTipo.corpo)
                .foregroundStyle(FrilaCor.textoSecundario)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Amostra ilustrativa do profissional

    private var amostraNotificacaoProfissional: some View {
        HStack(alignment: .top, spacing: FrilaEspaco.compacto) {
            Text("F", bundle: bundleApresentacao)
                .font(FrilaTipo.nome)
                .foregroundStyle(FrilaCor.sobrePrimaria)
                .frame(width: 38, height: 38)
                .background(FrilaCor.primaria, in: RoundedRectangle(cornerRadius: FrilaRaio.pequeno, style: .continuous))

            VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: TextosDoPush.Explicacao.amostraCargoHorario)
                        .font(FrilaTipo.rotuloSecundario)
                        .foregroundStyle(FrilaCor.texto)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: FrilaEspaco.junto)
                    Text(verbatim: TextosDoPush.Explicacao.amostraAgora)
                        .font(FrilaTipo.legenda)
                        .foregroundStyle(FrilaCor.textoSecundario)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(verbatim: TextosDoPush.Explicacao.amostraDetalhe)
                    .font(FrilaTipo.corpo)
                    .foregroundStyle(FrilaCor.texto)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartaoFrila()
        .accessibilityHidden(true)
    }

    // MARK: - Itens do que chega

    private var itens: some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.bloco) {
            ForEach(TextosDoPush.Explicacao.itens(perfil), id: \.self) { item in
                FrilaLinhaDeDado(icone: "checkmark") {
                    Text(verbatim: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// O aviso fixo de quem está sem notificação, em Vagas e em Minhas vagas. Com a permissão negada,
/// o caminho é pelos Ajustes do sistema; se o sistema ainda não perguntou, é a tela de explicação.
/// Com a permissão concedida, ou sem o modelo no ambiente (prévias), não ocupa espaço.
/// O bloco segue o aviso neutro do quadro "VagasSemNotificacao" do MidFi do Fabrício.
public struct AvisoDePermissaoDePush: View {
    @Environment(PermissaoDePushModelo.self) private var modelo: PermissaoDePushModelo?
    private let perfil: PerfilConta
    #if DEBUG
    @State private var mostrarExplicacaoCaptura = false
    #endif

    public init(perfil: PerfilConta) {
        self.perfil = perfil
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let modelo {
                switch modelo.estado {
                case .negada:
                    aviso(TextosDoPush.Aviso.negada(perfil), tom: .alerta, botao: TextosDoPush.Aviso.abrirAjustes, id: "abrir-ajustes-de-notificacao") {
                        modelo.abrirAjustes()
                    }
                    .accessibilityIdentifier("aviso-push-negado")
                case .naoPedida:
                    aviso(TextosDoPush.Aviso.naoPedida(perfil), tom: .informativo, botao: TextosDoPush.Explicacao.ativar, id: "explicar-notificacoes") {
                        Task { await modelo.reabrir() }
                    }
                    .accessibilityIdentifier("aviso-push-nao-pedido")
                case .concedida, nil:
                    EmptyView()
                }
            }
            #if DEBUG
            if capturaPush != nil {
                Color.clear.frame(width: 1, height: 1)
            }
            #endif
        }
        #if DEBUG
        .onAppear {
            if capturaPush != nil {
                mostrarExplicacaoCaptura = true
            }
        }
        .sheet(isPresented: $mostrarExplicacaoCaptura) {
            if let modelo {
                TelaExplicacaoDoPush(
                    modelo: modelo,
                    perfil: perfilCaptura
                )
            }
        }
        #endif
    }

    #if DEBUG
    private var capturaPush: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-FRILA_CAPTURA"), idx + 1 < args.count else { return nil }
        let arg = args[idx + 1]
        if arg == "explicacao" || arg == "explicacao-contratante" {
            return arg
        }
        return nil
    }

    private var perfilCaptura: PerfilConta {
        if capturaPush == "explicacao-contratante" {
            return .contratante
        }
        return .profissional
    }
    #endif

    private func aviso(_ texto: String, tom: AvisoFrila.Tom, botao: String, id: String, acao: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: FrilaEspaco.junto) {
            AvisoFrila(verbatim: texto, tom: tom)
            // Abrir os Ajustes e reabrir a explicação são links (DESIGN.md do protótipo: "Link"), não um segundo botão.
            Button(action: acao) { Text(verbatim: botao) }
                .buttonStyle(.frilaLink)
                .accessibilityIdentifier(id)
        }
        .accessibilityElement(children: .contain)
    }
}
